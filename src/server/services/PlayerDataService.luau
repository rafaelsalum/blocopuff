--!strict

-- Perfil persistente dos jogadores (DataStore). Regras de segurança:
--   * Trava de sessão: só um servidor por vez pode salvar o perfil de um
--     jogador. Ao entrar, o servidor grava sua JobId no perfil; ao sair,
--     salva e libera. Se outro servidor ainda segura o perfil (troca rápida
--     de servidor), tenta de novo por alguns segundos; se não conseguir,
--     o jogador joga com um perfil que NÃO é salvo nesta sessão.
--   * Toda soma vem do servidor (RoundService, ao fim de cada rodada), é
--     limitada por ProfileSchema.clampDelta e marcada com a chave da rodada:
--     a mesma rodada nunca é somada duas vezes, nem ao reconectar.
--   * Dados de uma versão mais nova do formato (atualização em andamento)
--     são carregados só para leitura, para não apagar campos novos.
--   * Quem sai no meio da rodada não recebe a rodada.
--   * Tickets (4.2): ganhos só no fim da rodada, calculados aqui; gastos só
--     na Puff Machine, numa única atualização do perfil (sem pausa entre
--     conferir o saldo e gastar), salva na hora.
--   * Dia do jogo (4.3): no login e no fim de cada rodada o servidor entrega
--     o retorno diário (uma vez por dia) e troca os desafios se o dia virou.
--     O progresso dos desafios sai da soma da rodada; concluir dá tickets
--     na hora. Conquistas secretas chegam do SecretAchievementService e
--     valem uma vez só (indexadas pelo id).
--   * Puffdex: os Puffs merecidos (nível e façanhas) são concedidos pelo
--     servidor ao carregar e depois de cada rodada. O inventário é indexado
--     pelo id do Puff: nada duplica ao reconectar.
--   * Nada que o jogador conquistou some (Puffs, conquistas, XP, tickets
--     ganhos): toda gravação passa pelo ProfileGuard, que devolve o que o
--     perfil gravado tinha a mais. Uma cópia de segurança (outro DataStore,
--     que só soma) é juntada ao perfil a cada carregamento.
--   * Perfil preso em outro servidor ou DataStore fora do ar: o jogo
--     continua tentando carregar enquanto o jogador estiver aqui (as
--     rodadas ficam guardadas) e nunca mostra um perfil vazio no lugar do
--     dele. Só o Studio sem acesso às APIs usa um perfil temporário.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ProfileConfig = require(script.Parent.Parent.config.ProfileConfig)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local ProfileGuard = require(script.Parent.Parent.data.ProfileGuard)
local DataStoreErrors = require(script.Parent.Parent.data.DataStoreErrors)
local PuffInventory = require(script.Parent.Parent.data.PuffInventory)
local RewardRules = require(script.Parent.Parent.data.RewardRules)
local DailyRules = require(script.Parent.Parent.data.DailyRules)
local OnboardingRules = require(script.Parent.Parent.data.OnboardingRules)
local SecretCatalog = require(ReplicatedStorage.Shared.config.SecretCatalog)
local BaronRoomsConfig = require(ReplicatedStorage.Shared.config.BaronRoomsConfig)
local MysteryConfig = require(ReplicatedStorage.Shared.config.MysteryConfig)
local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local LevelCurve = require(ReplicatedStorage.Shared.modules.LevelCurve)
local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local RewardConfig = require(ReplicatedStorage.Shared.config.RewardConfig)
local TelemetryService = require(script.Parent.TelemetryService)

type Profile = ProfileSchema.Profile
type RoundDelta = ProfileSchema.RoundDelta
type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type XpAward = ProfileTypes.XpAward
type XpLine = ProfileTypes.XpLine
type DailyReward = ProfileTypes.DailyReward
type SecretState = ProfileTypes.SecretState

-- O que aconteceu nesta atualização (o cliente comemora uma vez só).
export type Events = {
	newPuffs: { string }?,
	dailyReward: DailyReward?,
	completedChallenges: { string }?,
	newSecrets: { string }?,
	relicEvent: ProfileTypes.RelicEvent?,
}

-- XP calculado pelo RoundService para a rodada (ver XpCalculator).
export type RoundXp = {
	roundId: number,
	lines: { XpLine },
	total: number,
	won: boolean,
	-- Eliminado que ficou assistindo até o fim (ticket de torcida).
	stayedAsSpectator: boolean?,
	-- Partida com bots RoboPuff (BotRewardRules): vitória e top 3 que rendem
	-- ticket, e se os tickets da rodada entram no limite do dia (partida sem
	-- outro humano).
	tickets: { wins: number, top3: number, capped: boolean }?,
}

type Entry = {
	player: Player,
	key: string,
	-- Trava única deste carregamento (servidor + GUID): uma saída e volta
	-- rápida no mesmo servidor não confunde as duas sessões.
	lockId: string,
	profile: Profile,
	-- Falso: perfil desta sessão não é salvo (sem trava, versão futura ou
	-- DataStore indisponível).
	canSave: boolean,
	dirty: boolean,
	saving: boolean,
	released: boolean,
	lastSavedAt: number,
	-- Última atualização da cópia de segurança (os.clock).
	lastBackupAt: number,
	-- Subiu de nível na última rodada (telemetria de replay após level-up).
	leveledUpLastRound: boolean,
}

type PendingRound = {
	roundKey: string,
	delta: RoundDelta,
	xp: RoundXp,
}

export type ProfileListener = (player: Player, snapshot: ProfileSnapshot) -> ()
export type Updater = (profile: Profile, canSave: boolean) -> (Profile?, Events?)

local IS_STUDIO = RunService:IsStudio()
local STUDIO_PREFIX = "studio-"
local SESSION_ID = if game.JobId ~= "" then game.JobId else `{STUDIO_PREFIX}{HttpService:GenerateGUID(false)}`
local BIND_TO_CLOSE_TIMEOUT = 25
local REQUEST_COOLDOWN = 3
local MAX_ROUND_KEY_LENGTH = 80
-- Sem mudanças, o salvamento automático só renova a trava depois deste tempo.
local LOCK_REFRESH_INTERVAL = 300
local AUTOSAVE_STAGGER = 0.5
-- Liberação ao sair: novas tentativas se o DataStore falhar.
local RELEASE_RETRY_DELAY = 2
local RELEASE_RETRY_MAX_DELAY = 15
local RELEASE_RETRY_WINDOW = 90
-- Espalha as novas tentativas de carregar (depois de uma queda do
-- DataStore, nem todos os servidores tentam no mesmo instante).
local LOAD_RETRY_JITTER = 5
-- A cada tantas tentativas sem carregar, avisa de novo no log.
local LOAD_WARN_EVERY = 15
-- Teto de XP por rodada (defesa extra além dos limites do XpCalculator).
local MAX_ROUND_XP = 400

local PlayerDataService = {}

local store: DataStore? = nil
local backupStore: DataStore? = nil
-- Só no Studio: o DataStore real, lido (nunca gravado) para começar o
-- perfil de teste como cópia do perfil de verdade.
local liveStore: DataStore? = nil
-- Servidor fechando: para de tentar carregar perfis.
local closing = false
local entries: { [Player]: Entry } = {}
local loading: { [Player]: boolean } = {}
local snapshotRemote: RemoteEvent? = nil
local listeners: { ProfileListener } = {}
local started = false
local connections: { RBXScriptConnection } = {}
local lastRequest: { [Player]: number } = {}
-- Rodadas terminadas enquanto o perfil ainda carregava: aplicadas ao carregar.
local pendingRounds: { [Player]: { PendingRound } } = {}

local function now(): number
	return os.time()
end

local function keyFor(player: Player): string
	return `{ProfileConfig.KeyPrefix}{player.UserId}`
end

local function nonEmpty(list: { string }?): { string }?
	return if list ~= nil and #list > 0 then list else nil
end

local function snapshotOf(entry: Entry, award: XpAward?, events: Events?): ProfileSnapshot
	local profile = entry.profile
	local secrets: { SecretState } = {}
	for _, definition in ipairs(SecretCatalog.all()) do
		local obtainedAt = profile.secrets[definition.id]
		if obtainedAt ~= nil then
			table.insert(secrets, { id = definition.id, obtainedAt = obtainedAt })
		end
	end
	local relics: { ProfileTypes.RelicState } = {}
	for _, id in ipairs(RelicCatalog.everyId()) do
		local obtainedAt = profile.relics[id]
		if obtainedAt ~= nil then
			table.insert(relics, { id = id, obtainedAt = obtainedAt })
		end
	end
	local mysteries: { string } = {}
	for _, id in ipairs(MysteryConfig.Ids) do
		if profile.mysteries[id] ~= nil then
			table.insert(mysteries, id)
		end
	end
	local baronRooms: { string } = {}
	for _, id in ipairs(BaronRoomsConfig.Ids) do
		if profile.baronRooms[id] ~= nil then
			table.insert(baronRooms, id)
		end
	end
	local challenges = {}
	for _, state in ipairs(profile.challenges.list) do
		table.insert(challenges, table.clone(state))
	end
	return {
		stats = table.clone(profile.stats),
		xp = profile.xp,
		level = profile.level,
		prestige = profile.prestige,
		saved = entry.canSave,
		puffs = PuffInventory.toOwnedList(profile.puffs),
		equippedPuff = profile.equippedPuff,
		tickets = profile.tickets,
		machinePity = profile.machinePity,
		daily = table.clone(profile.daily),
		challenges = challenges,
		nextResetAt = DailyRules.nextResetAt(now()),
		secrets = secrets,
		relics = relics,
		dailyRelicDay = profile.dailyRelicDay,
		dailyRelicCount = profile.dailyRelicCount,
		mysteries = mysteries,
		baronRooms = baronRooms,
		award = award,
		newPuffs = if events ~= nil then nonEmpty(events.newPuffs) else nil,
		dailyReward = if events ~= nil then events.dailyReward else nil,
		completedChallenges = if events ~= nil then nonEmpty(events.completedChallenges) else nil,
		newSecrets = if events ~= nil then nonEmpty(events.newSecrets) else nil,
		relicEvent = if events ~= nil then events.relicEvent else nil,
	}
end

local function publish(entry: Entry, award: XpAward?, events: Events?)
	-- O Puff equipado vai num atributo do jogador: todos os clientes (e o
	-- PuffadorService, ao disparar) leem dali.
	if entry.player.Parent ~= nil and entry.player:GetAttribute(StateAttributeNames.PlayerEquippedPuff) ~= entry.profile.equippedPuff then
		entry.player:SetAttribute(StateAttributeNames.PlayerEquippedPuff, entry.profile.equippedPuff)
	end
	local snapshot = snapshotOf(entry, award, events)
	local remote = snapshotRemote
	if remote ~= nil and entry.player.Parent ~= nil then
		remote:FireClient(entry.player, snapshot)
	end
	for _, listener in ipairs(listeners) do
		task.spawn(listener, entry.player, snapshot)
	end
end

-- Chamada ao DataStore com algumas tentativas (rede e limites de uso).
local studioDenied = false

local function withRetries<T>(label: string, callback: () -> T): (boolean, T?)
	if studioDenied then
		return false, nil
	end
	local lastError: any = nil
	for attempt = 1, ProfileConfig.RequestRetries do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		-- Studio sem acesso às APIs: não adianta repetir; avisa uma vez só.
		if DataStoreErrors.isStudioAccessDenied(result) then
			studioDenied = true
			warn(string.format("[BlocoPuff] Profiles are not saved in this Studio session: %s", DataStoreErrors.StudioHint))
			return false, nil
		end
		if attempt < ProfileConfig.RequestRetries then
			task.wait(attempt)
		end
	end
	warn(string.format("[BlocoPuff] Profile %s failed: %s", label, tostring(lastError)))
	return false, nil
end

-- O guarda precisou devolver algo ao perfil: nunca deveria acontecer em
-- uso normal, então fica no log e na telemetria.
local function reportGuard(player: Player?, key: string, source: string, anomalies: { string })
	local detail = table.concat(anomalies, ",")
	warn(string.format("[BlocoPuff] Profile %s restored from %s: %s", key, source, detail))
	if player ~= nil then
		TelemetryService.lobbyEvent(player, "ProfileGuard", #anomalies, source, string.sub(detail, 1, 50))
	end
end

local function isNewerFormat(data: unknown): boolean
	if typeof(data) ~= "table" then
		return false
	end
	local version = (data :: { [string]: any }).version
	return typeof(version) == "number" and version > ProfileSchema.CurrentVersion
end

-- Perfil a partir do formato gravado, com a trava de `session`.
local function rebuild(data: { [string]: any }, session: ProfileSchema.Session?): Profile
	local profile = ProfileSchema.fromStored(data, now())
	profile.session = session
	return profile
end

-- O formato gravado como este servidor o entende (limpo por fromStored).
local function normalize(data: unknown): { [string]: any }?
	if typeof(data) ~= "table" then
		return nil
	end
	return ProfileSchema.toStored((ProfileSchema.fromStored(data, now())))
end

-- Cópia sem a carteira de tickets (para a cópia de segurança de uma sessão
-- que perdeu a trava: os itens valem, o saldo pode estar velho).
local function withoutWallet(data: { [string]: any }): { [string]: any }
	local copy = table.clone(data)
	for _, field in ipairs(ProfileGuard.WalletFields) do
		copy[field] = nil
	end
	return copy
end

-- Junta a cópia de segurança ao perfil recém-carregado: o que o principal
-- tiver perdido (dados corrompidos, bug) volta da cópia. Devolve o perfil
-- (o mesmo, se nada mudou) e se ele mudou.
local function healFromBackup(player: Player, key: string, profile: Profile): (Profile, boolean)
	local backup = backupStore
	if backup == nil then
		return profile, false
	end
	local ok, data = withRetries(`backup read {key}`, function()
		return backup:GetAsync(key)
	end)
	if not ok then
		warn(string.format("[BlocoPuff] Profile backup %s could not be read; loading without it", key))
		return profile, false
	end
	if typeof(data) ~= "table" or isNewerFormat(data) then
		return profile, false
	end
	local merged, anomalies = ProfileGuard.mergeForSave(normalize(data), ProfileSchema.toStored(profile))
	if #anomalies == 0 then
		return profile, false
	end
	reportGuard(player, key, "backup", anomalies)
	return rebuild(merged, profile.session), true
end

-- Atualiza a cópia de segurança com o que acabou de ser gravado. A cópia
-- só soma (o guarda nunca deixa nada sair dela).
local function writeBackup(key: string, written: { [string]: any })
	local backup = backupStore
	if backup == nil then
		return
	end
	local copy = table.clone(written)
	copy.session = nil
	withRetries(`backup {key}`, function()
		backup:UpdateAsync(key, function(old: any)
			if isNewerFormat(old) then
				return nil
			end
			local merged = ProfileGuard.mergeForSave(old, copy)
			return merged
		end)
		return true
	end)
end

-- Concede os Puffs que o perfil já merece e ainda não tem (nível e
-- façanhas). Devolve os ids novos para comemorar, mas só quando o perfil é
-- salvo: numa sessão sem salvar o Puff vale só agora e voltaria como
-- "novo" na próxima (o jogador veria o mesmo aviso de novo).
local function grantPuffs(entry: Entry): { string }
	local profile = entry.profile
	local timestamp = now()
	local inventory, granted = PuffInventory.grantUnlocks(profile.puffs, profile.stats :: any, profile.level, timestamp)
	if #granted == 0 then
		return granted
	end
	local updated = table.clone(profile)
	updated.puffs = inventory
	entry.profile = updated
	entry.dirty = true
	local owned = PuffInventory.countOwned(inventory)
	local total = #PuffCatalog.all()
	for _, id in ipairs(granted) do
		local definition = PuffCatalog.get(id)
		if definition ~= nil and entry.canSave then
			TelemetryService.lobbyEvent(entry.player, "PuffUnlocked", owned, id, `{definition.rarity}:{definition.origin}`)
		end
	end
	if not entry.canSave then
		return {}
	end
	TelemetryService.lobbyEvent(entry.player, "PuffCollection", owned, `Of{total}`)
	return granted
end

-- Soma tickets ao perfil atual (cópia nova).
local function addTickets(entry: Entry, tickets: number)
	if tickets <= 0 then
		return
	end
	entry.profile = ProfileSchema.withTickets(entry.profile, tickets)
	entry.dirty = true
end

-- Virada do dia: troca os desafios se o dia mudou e entrega o retorno
-- diário (uma vez por dia). Devolve a recompensa para comemorar (só com
-- perfil salvo, pelo mesmo motivo dos Puffs: senão ela voltaria amanhã
-- como se fosse nova).
local function refreshDay(entry: Entry): DailyReward?
	local profile = entry.profile
	local today = DailyRules.dayIndex(now())
	local challenges, replaced = DailyRules.ensureToday(profile.challenges, entry.player.UserId, today)
	local daily, reward = DailyRules.claimDaily(profile.daily, today)
	if not replaced and reward == nil then
		return nil
	end
	local updated = table.clone(profile)
	updated.challenges = challenges
	updated.daily = daily
	entry.profile = updated
	entry.dirty = true
	if replaced and entry.canSave then
		for _, state in ipairs(challenges.list) do
			TelemetryService.lobbyEvent(entry.player, "ChallengeAssigned", 1, state.id)
		end
	end
	if reward == nil then
		return nil
	end
	local ticketsBefore = entry.profile.tickets
	addTickets(entry, reward.tickets)
	if not entry.canSave then
		return nil
	end
	TelemetryService.lobbyEvent(entry.player, "DailyReturn", reward.streak, `Tickets{reward.tickets}`, `Best{daily.best}`)
	TelemetryService.ticketsEarned(entry.player, ticketsBefore, entry.profile.tickets, "Daily")
	return reward
end

-- Progresso dos desafios com a soma limpa da rodada. Só conta rodada
-- jogada de verdade (com XP). Devolve os desafios concluídos agora.
local function progressChallenges(entry: Entry, delta: RoundDelta, gainedXp: number): { string }
	if gainedXp <= 0 then
		return {}
	end
	local profile = entry.profile
	-- "Vença uma partida" também vale para vitória só contra bots.
	local progress = table.clone(delta) :: any
	progress.wins += delta.botWins
	local challenges, completed, tickets = DailyRules.applyRound(profile.challenges, progress)
	local updated = table.clone(profile)
	updated.challenges = challenges
	updated.challengesCompleted = profile.challengesCompleted + #completed
	entry.profile = updated
	entry.dirty = true
	local ticketsBefore = entry.profile.tickets
	addTickets(entry, tickets)
	for _, id in ipairs(completed) do
		TelemetryService.lobbyEvent(entry.player, "ChallengeCompleted", entry.profile.challengesCompleted, id)
	end
	if tickets > 0 then
		TelemetryService.ticketsEarned(entry.player, ticketsBefore, entry.profile.tickets, "Challenge")
	end
	return if entry.canSave then completed else {}
end

type LoadOutcome = "Loaded" | "Locked" | "Future" | "Error"

-- Studio: perfil de teste ainda vazio → cópia do perfil real, sem a trava
-- dele (só leitura do real; nada é gravado lá). Falso quando a leitura
-- falhou (tentar de novo: senão o perfil de teste nasceria vazio).
local function studioSeed(key: string): (boolean, { [string]: any }?)
	local dataStore = store
	local live = liveStore
	if dataStore == nil or live == nil then
		return true, nil
	end
	local ok, existing = withRetries(`studio check {key}`, function()
		return dataStore:GetAsync(key)
	end)
	if not ok then
		return false, nil
	end
	if existing ~= nil then
		return true, nil
	end
	local liveOk, stored = withRetries(`studio seed {key}`, function()
		return live:GetAsync(key)
	end)
	if not liveOk then
		return false, nil
	end
	if typeof(stored) ~= "table" then
		return true, nil
	end
	local seed = table.clone(stored :: { [string]: any })
	seed.session = nil
	seed.releasedBy = nil
	print(string.format("[BlocoPuff] Studio profile %s seeded from the live profile", key))
	return true, seed
end

-- Uma tentativa de carregar e travar o perfil. `seed` (só Studio) é usado
-- quando ainda não há nada gravado.
local function tryLoad(key: string, lockId: string, seed: { [string]: any }?): (LoadOutcome, Profile?)
	local dataStore = store
	if dataStore == nil then
		return "Error", nil
	end
	local outcome: LoadOutcome = "Error"
	local loaded: Profile? = nil
	local ok = withRetries(`load {key}`, function()
		dataStore:UpdateAsync(key, function(current: any)
			local stored = if current == nil then seed else current
			local profile, isFuture = ProfileSchema.fromStored(stored, now())
			if isFuture then
				outcome = "Future"
				loaded = profile
				return nil
			end
			local session = profile.session
			-- No Studio (save próprio), a trava de outra sessão do Studio é de
			-- um teste que parou sem liberar: assume na hora.
			local studioLeftover = IS_STUDIO and session ~= nil and string.sub(session.jobId, 1, #STUDIO_PREFIX) == STUDIO_PREFIX
			if session ~= nil and session.jobId ~= lockId and not studioLeftover and now() - session.lockedAt < ProfileConfig.SessionLockTimeout then
				outcome = "Locked"
				loaded = nil
				return nil
			end
			local lock = { jobId = lockId, lockedAt = now() }
			local toStore = ProfileSchema.toStored(profile)
			if typeof(stored) == "table" then
				-- A limpeza do formato (fromStored) pode descartar dados; o que
				-- está gravado continua (ProfileGuard) e a memória recebe o que
				-- a limpeza tinha tirado (a junção já está na versão atual).
				toStore = ProfileGuard.mergeForSave(stored, toStore)
				profile = rebuild(toStore, nil)
			end
			toStore.session = lock
			profile.session = lock
			outcome = "Loaded"
			loaded = profile
			return toStore
		end)
		return true
	end)
	if not ok then
		return "Error", nil
	end
	return outcome, loaded
end

-- Grava o perfil em memória, se este servidor ainda for o dono da trava.
-- `release` libera a trava (jogador saindo ou servidor fechando). Devolve
-- falso só quando o DataStore falhou (vale tentar de novo).
local function save(entry: Entry, release: boolean): boolean
	local dataStore = store
	if dataStore == nil or not entry.canSave or entry.released then
		return true
	end
	-- Uma gravação por vez por jogador; a próxima espera a anterior.
	while entry.saving do
		task.wait(0.1)
	end
	if entry.released or not entry.canSave then
		return true
	end
	entry.saving = true
	entry.dirty = false
	local timestamp = now()
	local profile = entry.profile
	local outgoing = ProfileSchema.toStored(profile)
	local lostLock = false
	local newer = false
	local alreadyReleased = false
	local written: { [string]: any }? = nil
	local anomalies: { string } = {}
	local ok = withRetries(`save {entry.key}`, function()
		dataStore:UpdateAsync(entry.key, function(stored: any)
			lostLock = false
			newer = false
			alreadyReleased = false
			written = nil
			anomalies = {}
			local session = ProfileSchema.storedSession(stored)
			if session == nil or session.jobId ~= entry.lockId then
				-- Esta liberação já foi gravada (resposta perdida e nova
				-- tentativa) ou outro servidor assumiu, mesmo que já tenha
				-- liberado depois.
				alreadyReleased = session == nil
					and release
					and typeof(stored) == "table"
					and stored.releasedBy == entry.lockId
				lostLock = not alreadyReleased
				return nil
			end
			if isNewerFormat(stored) then
				-- Gravado por uma versão mais nova do jogo: não mexe.
				newer = true
				return nil
			end
			-- Nada do que está gravado pode sumir (ver ProfileGuard). O que
			-- conta como correção é comparado com o gravado já limpo pelo
			-- formato: dados que a limpeza sempre descarta continuam gravados,
			-- mas não viram alerta a cada gravação.
			local toStore = ProfileGuard.mergeForSave(stored, outgoing)
			local _, found = ProfileGuard.mergeForSave(normalize(stored), outgoing)
			toStore.updatedAt = timestamp
			toStore.session = if release then nil else { jobId = entry.lockId, lockedAt = timestamp }
			toStore.releasedBy = if release then entry.lockId else nil
			written = toStore
			anomalies = found
			return toStore
		end)
		return true
	end)
	entry.saving = false
	entry.lastSavedAt = os.clock()
	if not ok then
		entry.dirty = true
		return false
	end
	if alreadyReleased then
		entry.released = true
		return true
	end
	if lostLock or newer then
		-- Outro servidor assumiu o perfil (esta sessão ficou para trás) ou
		-- uma versão mais nova do jogo gravou por cima. O que o jogador
		-- ganhou aqui vai para a cópia de segurança (sem a carteira, que o
		-- outro servidor pode ter gastado) e volta no próximo carregamento.
		entry.canSave = false
		warn(string.format("[BlocoPuff] Profile %s is owned by another server; stopped saving here", entry.key))
		TelemetryService.lobbyEvent(entry.player, "ProfileLockLost", 1, if newer then "Newer" else "Lock")
		writeBackup(entry.key, withoutWallet(ProfileSchema.toStored(entry.profile)))
		return true
	end
	local saved = written
	if saved ~= nil and #anomalies > 0 then
		reportGuard(entry.player, entry.key, "save", anomalies)
		if not release then
			-- A memória também recebe de volta o que faltava (junto com o que
			-- mudou durante a gravação).
			local combined = ProfileGuard.mergeForSave(saved, ProfileSchema.toStored(entry.profile))
			entry.profile = rebuild(combined, entry.profile.session)
			entry.dirty = true
			publish(entry)
		end
	end
	if release then
		entry.released = true
	end
	if saved ~= nil then
		if release then
			-- Ao sair, a cópia é gravada antes de terminar (o servidor pode
			-- estar fechando).
			entry.lastBackupAt = os.clock()
			writeBackup(entry.key, saved)
		elseif os.clock() - entry.lastBackupAt >= ProfileConfig.BackupInterval then
			entry.lastBackupAt = os.clock()
			task.spawn(writeBackup, entry.key, saved)
		end
	end
	return true
end

-- Libera o perfil de quem saiu. Se o DataStore falhar, tenta de novo por
-- um tempo; se não der, guarda o progresso na cópia de segurança (que volta
-- no próximo carregamento).
local function releaseWithRetries(entry: Entry)
	local delay = RELEASE_RETRY_DELAY
	local deadline = os.clock() + RELEASE_RETRY_WINDOW
	while not save(entry, true) do
		if closing or os.clock() >= deadline then
			warn(string.format("[BlocoPuff] Profile %s release failed; progress kept in the backup", entry.key))
			writeBackup(entry.key, ProfileSchema.toStored(entry.profile))
			return
		end
		task.wait(delay)
		delay = math.min(delay * 2, RELEASE_RETRY_MAX_DELAY)
	end
end

-- Espera `seconds`, mas volta antes se o jogador sair ou o servidor fechar.
local function waitWhilePresent(player: Player, seconds: number)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and player.Parent ~= nil and not closing do
		task.wait(0.5)
	end
end

local function load(player: Player)
	if loading[player] or entries[player] ~= nil then
		return
	end
	loading[player] = true
	local healedOnLoad = false
	local key = keyFor(player)
	local lockId = `{SESSION_ID}:{HttpService:GenerateGUID(false)}`
	local outcome: LoadOutcome = "Error"
	local profile: Profile? = nil
	local attempt = 0
	local seed: { [string]: any }? = nil
	local seedReady = liveStore == nil
	-- Preso em outro servidor ou DataStore com erro: o perfil existe (ou
	-- pode existir), então continua tentando enquanto o jogador estiver
	-- aqui. Um perfil vazio no lugar do dele pareceria que tudo sumiu.
	while store ~= nil and not studioDenied and not closing and player.Parent ~= nil do
		attempt += 1
		if not seedReady then
			local seedOk, seedData = studioSeed(key)
			seed = seedData
			seedReady = seedOk or studioDenied
		end
		if seedReady then
			outcome, profile = tryLoad(key, lockId, seed)
		else
			outcome, profile = "Error", nil
		end
		if outcome == "Loaded" or outcome == "Future" or studioDenied then
			break
		end
		if attempt == ProfileConfig.LoadLockedRetries or attempt % LOAD_WARN_EVERY == 0 then
			warn(string.format("[BlocoPuff] Profile for %s still not loaded after %d tries (%s); retrying", player.Name, attempt, outcome))
			TelemetryService.lobbyEvent(player, "ProfileLoadDelayed", attempt, outcome)
		end
		if attempt < ProfileConfig.LoadLockedRetries then
			waitWhilePresent(player, ProfileConfig.LoadRetryDelay)
		else
			waitWhilePresent(player, ProfileConfig.LoadRetryMaxDelay + (math.random() * LOAD_RETRY_JITTER))
		end
	end
	if outcome == "Loaded" and profile ~= nil and player.Parent ~= nil then
		local healed, changed = healFromBackup(player, key, profile)
		profile = healed
		healedOnLoad = changed
	end
	loading[player] = nil
	if outcome ~= "Loaded" and outcome ~= "Future" and not studioDenied and store ~= nil then
		-- Saiu ou o servidor está fechando antes de carregar: nada a gravar.
		pendingRounds[player] = nil
		return
	end
	if player.Parent == nil then
		-- Saiu enquanto carregava: libera a trava que acabou de pegar.
		if outcome == "Loaded" and profile ~= nil then
			releaseWithRetries({
				player = player,
				key = key,
				lockId = lockId,
				profile = profile,
				canSave = true,
				dirty = false,
				saving = false,
				released = false,
				lastSavedAt = os.clock(),
				lastBackupAt = -math.huge,
				leveledUpLastRound = false,
			})
		end
		pendingRounds[player] = nil
		return
	end

	local canSave = outcome == "Loaded"
	if not canSave then
		-- Só Studio sem acesso às APIs (perfil temporário) ou versão mais nova
		-- do jogo (perfil real, só leitura).
		warn(string.format("[BlocoPuff] Profile for %s not saved this session (%s)", player.Name, outcome))
	end
	local entry: Entry = {
		player = player,
		key = key,
		lockId = lockId,
		profile = profile or ProfileSchema.default(now()),
		canSave = canSave,
		dirty = false,
		saving = false,
		released = false,
		lastSavedAt = os.clock(),
		lastBackupAt = -math.huge,
		leveledUpLastRound = false,
	}
	entries[player] = entry
	-- Puffs já merecidos (inclusive por perfis antigos, sem Puffdex).
	-- Retenção (D1/D7/D28): dias desde a criação do perfil a cada sessão.
	if canSave then
		local days = math.max(0, math.floor((now() - entry.profile.createdAt) / 86400))
		local bucket = if days >= 28 then "D28+" elseif days >= 7 then "D7+" elseif days >= 1 then "D1+" else "D0"
		-- Tipo da primeira partida: retenção de quem começou com bots x só humanos.
		TelemetryService.lobbyEvent(player, "SessionStart", days, bucket, OnboardingRules.firstMatchLabel(entry.profile.firstMatchKind))
	end
	local newPuffs = grantPuffs(entry)
	-- Retorno diário e desafios de hoje.
	local dailyReward = refreshDay(entry)
	publish(entry, nil, { newPuffs = newPuffs, dailyReward = dailyReward })
	if healedOnLoad then
		entry.dirty = true
	end
	if entry.dirty then
		task.spawn(save, entry, false)
	end

	local pending = pendingRounds[player]
	pendingRounds[player] = nil
	if pending ~= nil then
		for _, round in ipairs(pending) do
			PlayerDataService.applyRound(player, round.roundKey, round.delta, round.xp)
		end
	end
end

local function unload(player: Player)
	-- `loading` fica: o próprio carregamento termina, vê que o jogador saiu
	-- e libera a trava (e o fechamento do servidor espera por ele).
	lastRequest[player] = nil
	local entry = entries[player]
	if entry == nil then
		return
	end
	pendingRounds[player] = nil
	entries[player] = nil
	releaseWithRetries(entry)
end

-- Tickets da rodada. Numa partida com bots, vitória e top 3 vêm de
-- BotRewardRules; numa partida sem outro humano, os tickets da rodada (menos
-- os de subir de nível) somam no máximo `SoloBotTicketsPerDay` por dia.
-- Devolve também o contador do dia atualizado.
local function roundTickets(profile: Profile, clean: RoundDelta, gained: number, levelsGained: number, roundXp: RoundXp): (number, { RewardRules.TicketLine }, number, number)
	local override = roundXp.tickets
	if override == nil then
		local tickets, lines = RewardRules.ticketsForRound(clean, gained, levelsGained, roundXp.stayedAsSpectator)
		return tickets, lines, profile.botTicketDay, profile.botTickets
	end
	local ticketDelta = table.clone(clean)
	ticketDelta.wins = math.clamp(override.wins, 0, 1)
	ticketDelta.top3 = math.clamp(override.top3, 0, 1)
	local tickets, lines = RewardRules.ticketsForRound(ticketDelta, gained, levelsGained, roundXp.stayedAsSpectator)
	local today = DailyRules.dayIndex(now())
	local usedToday = if profile.botTicketDay == today then profile.botTickets else 0
	if not override.capped then
		return tickets, lines, today, usedToday
	end
	local levelUp = 0
	for _, line in ipairs(lines) do
		if line.source == "LevelUp" then
			levelUp += line.tickets
		end
	end
	local budget = math.max(0, BotConfig.Rewards.SoloBotTicketsPerDay - usedToday)
	local granted = math.min(math.max(0, tickets - levelUp), budget)
	local kept: { RewardRules.TicketLine } = {}
	local remaining = granted
	for _, line in ipairs(lines) do
		if line.source == "LevelUp" then
			table.insert(kept, line)
		elseif remaining > 0 then
			local amount = math.min(line.tickets, remaining)
			remaining -= amount
			table.insert(kept, { source = line.source, tickets = amount })
		end
	end
	return math.min(tickets, granted + levelUp), kept, today, usedToday + granted
end

-- Soma a rodada ao perfil de um jogador presente. `roundKey` identifica a
-- rodada de forma única (servidor + rodada): repetir a chave não soma de novo.
function PlayerDataService.applyRound(player: Player, roundKey: string, delta: RoundDelta, roundXp: RoundXp): boolean
	local entry = entries[player]
	if entry == nil then
		if loading[player] then
			-- Perfil ainda carregando: guarda a rodada para somar ao carregar.
			local queue = pendingRounds[player] or {}
			if #queue >= ProfileConfig.MaxPendingRounds then
				local dropped = table.remove(queue, 1)
				warn(string.format("[BlocoPuff] Round %s dropped for %s: too many rounds while the profile loads", dropped.roundKey, player.Name))
				TelemetryService.lobbyEvent(player, "ProfileRoundDropped", #queue)
			end
			table.insert(queue, { roundKey = roundKey, delta = delta, xp = roundXp })
			pendingRounds[player] = queue
			return true
		end
		warn(string.format("[BlocoPuff] Round %s not applied to %s: profile not loaded", roundKey, player.Name))
		TelemetryService.event(player, "ProfileRoundSkipped")
		return false
	end
	local profile = entry.profile
	if table.find(profile.appliedRounds, roundKey) ~= nil then
		return false
	end
	local clean, anomalies = ProfileSchema.clampDelta(delta)
	if #anomalies > 0 then
		local detail = table.concat(anomalies, ",")
		warn(string.format("[BlocoPuff] Profile anomaly for %s in %s: %s", player.Name, roundKey, detail))
		TelemetryService.event(player, "ProfileAnomaly", #anomalies, string.sub(detail, 1, 50))
	end
	-- XP: limitado ao teto do prestígio atual; o nível sai do XP.
	local gained = math.clamp(math.floor(roundXp.total), 0, MAX_ROUND_XP)
	local newXp = math.min(LevelCurve.maxXp(), profile.xp + gained)
	local newLevel = LevelCurve.levelForXp(newXp)
	local timestamp = now()
	local tickets, ticketLines, botTicketDay, botTickets = roundTickets(profile, clean, gained, newLevel - profile.level, roundXp)
	local updated = ProfileSchema.withTickets(profile, tickets)
	updated.botTicketDay = botTicketDay
	updated.botTickets = botTickets
	updated.firstMatchKind = OnboardingRules.firstMatchKind(profile.firstMatchKind, profile.stats.matches, clean.matches, roundXp.tickets ~= nil)
	updated.stats = ProfileSchema.addStats(profile.stats, clean)
	updated.appliedRounds = ProfileSchema.withAppliedRound(profile.appliedRounds, roundKey, ProfileConfig.AppliedRoundsKept)
	updated.xp = newXp
	updated.level = newLevel
	if newLevel > profile.level then
		updated.levelReachedAt = timestamp
	end
	entry.profile = updated
	entry.leveledUpLastRound = newLevel > profile.level
	entry.dirty = true

	for _, line in ipairs(roundXp.lines) do
		TelemetryService.event(player, "XpGained", line.xp, line.source)
	end
	TelemetryService.event(player, "XpRound", gained, `Level{profile.level}`, if roundXp.won then "Win" else "NoWin")
	if newLevel > profile.level then
		TelemetryService.event(player, "LevelUp", timestamp - profile.levelReachedAt, `Level{newLevel}`, `From{profile.level}`)
	end
	-- Saldo depois de cada linha (o teto da carteira vale a cada soma).
	local balance = profile.tickets
	for _, line in ipairs(ticketLines) do
		local before = balance
		balance = math.min(RewardConfig.MaxTickets, balance + line.tickets)
		TelemetryService.ticketsEarned(player, before, balance, line.source)
	end

	-- Dia do jogo (pode ter virado com o jogador online) e desafios.
	local dailyReward = refreshDay(entry)
	local completed = progressChallenges(entry, clean, gained)
	local newPuffs = grantPuffs(entry)
	publish(entry, {
		roundId = roundXp.roundId,
		total = gained,
		lines = roundXp.lines,
		levelBefore = profile.level,
		levelAfter = newLevel,
		tickets = tickets,
	}, { newPuffs = newPuffs, dailyReward = dailyReward, completedChallenges = completed })
	-- Grava logo: o fim da rodada é o momento mais importante de não perder.
	task.spawn(save, entry, false)
	return true
end

function PlayerDataService.getSnapshot(player: Player): ProfileSnapshot?
	local entry = entries[player]
	return if entry ~= nil then snapshotOf(entry) else nil
end

function PlayerDataService.isLoaded(player: Player): boolean
	return entries[player] ~= nil
end

-- Avisado quando o perfil de alguém carrega ou muda.
function PlayerDataService.addListener(listener: ProfileListener)
	table.insert(listeners, listener)
end

-- Chamado no início de cada rodada: registra quem voltou a jogar logo
-- depois de subir de nível.
function PlayerDataService.roundStarted(players: { Player })
	for _, player in ipairs(players) do
		local entry = entries[player]
		if entry ~= nil and entry.leveledUpLastRound then
			entry.leveledUpLastRound = false
			TelemetryService.event(player, "RoundAfterLevelUp", entry.profile.level)
		end
	end
end

-- Prestígio (preparado; só funciona com ProgressionConfig.PrestigeEnabled):
-- no nível máximo, soma 1 de prestígio e recomeça do nível 1. Não dá força.
function PlayerDataService.prestige(player: Player): boolean
	local entry = entries[player]
	if not ProgressionConfig.PrestigeEnabled or entry == nil then
		return false
	end
	local profile = entry.profile
	if profile.level < ProgressionConfig.MaxLevel or profile.prestige >= ProgressionConfig.MaxPrestige then
		return false
	end
	local updated = table.clone(profile)
	updated.prestige = profile.prestige + 1
	updated.xp = 0
	updated.level = 1
	updated.levelReachedAt = now()
	entry.profile = updated
	entry.dirty = true
	print(string.format("[BlocoPuff] %s reached prestige %d", player.Name, updated.prestige))
	TelemetryService.event(player, "Prestige", updated.prestige)
	publish(entry)
	task.spawn(save, entry, false)
	return true
end

-- Atualização genérica e atômica do perfil, para os outros serviços
-- (Puffdex, Puff Machine, conquistas secretas). `updater` recebe o perfil
-- atual e se ele é salvo nesta sessão, e devolve o perfil NOVO (ou nil para
-- não mudar nada) e os eventos a comemorar. `updater` não pode pausar
-- (nada de wait/yield): é isso que garante que conferir e gravar acontecem
-- juntos. Com `saveNow`, grava logo em seguida.
function PlayerDataService.update(player: Player, updater: Updater, saveNow: boolean?): boolean
	local entry = entries[player]
	if entry == nil then
		return false
	end
	local updated, events = updater(entry.profile, entry.canSave)
	if updated == nil then
		return false
	end
	entry.profile = updated
	entry.dirty = true
	publish(entry, nil, events)
	if saveNow then
		task.spawn(save, entry, false)
	end
	return true
end

-- Chave única da rodada para `applyRound`.
function PlayerDataService.roundKey(roundId: number, startedAt: number): string
	return string.sub(`{SESSION_ID}:{roundId}:{startedAt}`, 1, MAX_ROUND_KEY_LENGTH)
end

local function autosaveLoop()
	while started do
		task.wait(ProfileConfig.AutosaveInterval)
		-- Só quem mudou (ou cuja trava precisa ser renovada), um de cada vez
		-- com um pequeno intervalo para não estourar o limite do DataStore.
		local due: { Entry } = {}
		for _, entry in pairs(entries) do
			if entry.dirty or os.clock() - entry.lastSavedAt >= LOCK_REFRESH_INTERVAL then
				table.insert(due, entry)
			end
		end
		for _, entry in ipairs(due) do
			if not entry.released then
				task.spawn(save, entry, false)
			end
			task.wait(AUTOSAVE_STAGGER)
		end
	end
end

local function saveAllOnClose()
	closing = true
	local deadline = os.clock() + BIND_TO_CLOSE_TIMEOUT
	-- Espera carregamentos em andamento terminarem (para liberar a trava).
	while next(loading) ~= nil and os.clock() < deadline - 10 do
		task.wait(0.2)
	end
	local pending = 0
	for player, entry in pairs(entries) do
		entries[player] = nil
		pending += 1
		task.spawn(function()
			-- Sem tempo para novas tentativas: se falhar, a cópia guarda.
			if not save(entry, true) then
				writeBackup(entry.key, ProfileSchema.toStored(entry.profile))
			end
			pending -= 1
		end)
	end
	while pending > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end

function PlayerDataService.start(remotesFolder: Folder?)
	if started then
		return
	end
	started = true

	local isStudio = RunService:IsStudio()
	local suffix = if isStudio then ProfileConfig.StudioSuffix else ""
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(ProfileConfig.StoreName .. suffix)
	end)
	if ok then
		store = result
	else
		warn(string.format("[BlocoPuff] Profiles will not be saved: %s", tostring(result)))
	end
	local backupOk, backupResult = pcall(function()
		return DataStoreService:GetDataStore(ProfileConfig.BackupStoreName .. suffix)
	end)
	if backupOk then
		backupStore = backupResult
	else
		warn(string.format("[BlocoPuff] Profile backups disabled: %s", tostring(backupResult)))
	end
	if isStudio then
		local liveOk, liveResult = pcall(function()
			return DataStoreService:GetDataStore(ProfileConfig.StoreName)
		end)
		if liveOk then
			liveStore = liveResult
		end
	end

	if remotesFolder ~= nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = PuffadorConstants.ProfileSnapshotRemoteName
		remote.Parent = remotesFolder
		snapshotRemote = remote
		-- O cliente pede a cópia ao iniciar (pode ter perdido o primeiro envio).
		table.insert(connections, remote.OnServerEvent:Connect(function(player: Player)
			local clock = os.clock()
			local last = lastRequest[player]
			if last ~= nil and clock - last < REQUEST_COOLDOWN then
				return
			end
			lastRequest[player] = clock
			local entry = entries[player]
			if entry ~= nil then
				remote:FireClient(player, snapshotOf(entry))
			end
		end))
	end

	table.insert(connections, Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(unload))
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	game:BindToClose(saveAllOnClose)
	task.spawn(autosaveLoop)
	if RunService:IsStudio() then
		print(string.format("[BlocoPuff] Profiles session %s", SESSION_ID))
	end
end

return table.freeze(PlayerDataService)
