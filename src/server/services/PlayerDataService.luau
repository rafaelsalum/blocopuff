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
--   * Puffdex: os Puffs merecidos (nível e façanhas) são concedidos pelo
--     servidor ao carregar e depois de cada rodada. O inventário é indexado
--     pelo id do Puff: nada duplica ao reconectar.

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
local DataStoreErrors = require(script.Parent.Parent.data.DataStoreErrors)
local PuffInventory = require(script.Parent.Parent.data.PuffInventory)
local RewardRules = require(script.Parent.Parent.data.RewardRules)
local RewardConfig = require(ReplicatedStorage.Shared.config.RewardConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local LevelCurve = require(ReplicatedStorage.Shared.modules.LevelCurve)
local TelemetryService = require(script.Parent.TelemetryService)

type Profile = ProfileSchema.Profile
type RoundDelta = ProfileSchema.RoundDelta
type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type XpAward = ProfileTypes.XpAward
type XpLine = ProfileTypes.XpLine

-- XP calculado pelo RoundService para a rodada (ver XpCalculator).
export type RoundXp = {
	roundId: number,
	lines: { XpLine },
	total: number,
	won: boolean,
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
	-- Subiu de nível na última rodada (telemetria de replay após level-up).
	leveledUpLastRound: boolean,
}

type PendingRound = {
	roundKey: string,
	delta: RoundDelta,
	xp: RoundXp,
}

export type ProfileListener = (player: Player, snapshot: ProfileSnapshot) -> ()

-- Resultado de um giro da Puff Machine.
export type MachineResult = {
	puffId: string,
	duplicate: boolean,
	refund: number,
	tickets: number,
	pity: number,
}

-- Motivos de falha do giro (o PuffMachineService ainda usa "Cooldown" e
-- "Competing", decididos antes de chegar aqui).
export type MachineFailure = "NotLoaded" | "NotSaved" | "NoTickets" | "Empty"

local SESSION_ID = if game.JobId ~= "" then game.JobId else `studio-{HttpService:GenerateGUID(false)}`
local BIND_TO_CLOSE_TIMEOUT = 25
local REQUEST_COOLDOWN = 3
local MAX_ROUND_KEY_LENGTH = 80
-- Sem mudanças, o salvamento automático só renova a trava depois deste tempo.
local LOCK_REFRESH_INTERVAL = 300
local AUTOSAVE_STAGGER = 0.5
-- Teto de XP por rodada (defesa extra além dos limites do XpCalculator).
local MAX_ROUND_XP = 400

local PlayerDataService = {}

local store: DataStore? = nil
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

local function snapshotOf(entry: Entry, award: XpAward?, newPuffs: { string }?): ProfileSnapshot
	local profile = entry.profile
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
		award = award,
		newPuffs = if newPuffs ~= nil and #newPuffs > 0 then newPuffs else nil,
	}
end

local function publish(entry: Entry, award: XpAward?, newPuffs: { string }?)
	-- O Puff equipado vai num atributo do jogador: todos os clientes (e o
	-- PuffadorService, ao disparar) leem dali.
	if entry.player.Parent ~= nil and entry.player:GetAttribute(StateAttributeNames.PlayerEquippedPuff) ~= entry.profile.equippedPuff then
		entry.player:SetAttribute(StateAttributeNames.PlayerEquippedPuff, entry.profile.equippedPuff)
	end
	local snapshot = snapshotOf(entry, award, newPuffs)
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

type LoadOutcome = "Loaded" | "Locked" | "Future" | "Error"

-- Uma tentativa de carregar e travar o perfil.
local function tryLoad(key: string, lockId: string): (LoadOutcome, Profile?)
	local dataStore = store
	if dataStore == nil then
		return "Error", nil
	end
	local outcome: LoadOutcome = "Error"
	local loaded: Profile? = nil
	local ok = withRetries(`load {key}`, function()
		dataStore:UpdateAsync(key, function(stored: any)
			local profile, isFuture = ProfileSchema.fromStored(stored, now())
			if isFuture then
				outcome = "Future"
				loaded = profile
				return nil
			end
			local session = profile.session
			if session ~= nil and session.jobId ~= lockId and now() - session.lockedAt < ProfileConfig.SessionLockTimeout then
				outcome = "Locked"
				loaded = nil
				return nil
			end
			profile.session = { jobId = lockId, lockedAt = now() }
			outcome = "Loaded"
			loaded = profile
			return ProfileSchema.toStored(profile)
		end)
		return true
	end)
	if not ok then
		return "Error", nil
	end
	return outcome, loaded
end

-- Grava o perfil em memória, se este servidor ainda for o dono da trava.
-- `release` libera a trava (jogador saindo ou servidor fechando).
local function save(entry: Entry, release: boolean)
	local dataStore = store
	if dataStore == nil or not entry.canSave or entry.released then
		return
	end
	-- Uma gravação por vez por jogador; a próxima espera a anterior.
	while entry.saving do
		task.wait(0.1)
	end
	if entry.released or not entry.canSave then
		return
	end
	entry.saving = true
	entry.dirty = false
	local timestamp = now()
	local profile = entry.profile
	local lostLock = false
	local ok = withRetries(`save {entry.key}`, function()
		dataStore:UpdateAsync(entry.key, function(stored: any)
			local session = ProfileSchema.storedSession(stored)
			if session ~= nil and session.jobId ~= entry.lockId then
				lostLock = true
				return nil
			end
			local toStore = ProfileSchema.toStored(profile)
			toStore.updatedAt = timestamp
			toStore.session = if release then nil else { jobId = entry.lockId, lockedAt = timestamp }
			return toStore
		end)
		return true
	end)
	entry.saving = false
	entry.lastSavedAt = os.clock()
	if not ok then
		entry.dirty = true
		return
	end
	if lostLock then
		-- Outro servidor assumiu o perfil (esta sessão ficou para trás).
		entry.canSave = false
		warn(string.format("[BlocoPuff] Profile %s is owned by another server; stopped saving here", entry.key))
		return
	end
	if release then
		entry.released = true
	end
end

local function load(player: Player)
	if loading[player] or entries[player] ~= nil then
		return
	end
	loading[player] = true
	local key = keyFor(player)
	local lockId = `{SESSION_ID}:{HttpService:GenerateGUID(false)}`
	local outcome: LoadOutcome = "Error"
	local profile: Profile? = nil
	if store ~= nil then
		for attempt = 1, ProfileConfig.LoadLockedRetries do
			outcome, profile = tryLoad(key, lockId)
			if outcome ~= "Locked" or player.Parent == nil then
				break
			end
			if attempt < ProfileConfig.LoadLockedRetries then
				task.wait(ProfileConfig.LoadRetryDelay)
			end
		end
	end
	loading[player] = nil
	if player.Parent == nil then
		-- Saiu enquanto carregava: libera a trava que acabou de pegar.
		if outcome == "Loaded" and profile ~= nil then
			save({
				player = player,
				key = key,
				lockId = lockId,
				profile = profile,
				canSave = true,
				dirty = false,
				saving = false,
				released = false,
				lastSavedAt = os.clock(),
				leveledUpLastRound = false,
			}, true)
		end
		pendingRounds[player] = nil
		return
	end

	local canSave = outcome == "Loaded"
	if not canSave then
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
		leveledUpLastRound = false,
	}
	entries[player] = entry
	-- Puffs já merecidos (inclusive por perfis antigos, sem Puffdex).
	local newPuffs = grantPuffs(entry)
	publish(entry, nil, newPuffs)
	if #newPuffs > 0 then
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
	loading[player] = nil
	lastRequest[player] = nil
	pendingRounds[player] = nil
	local entry = entries[player]
	if entry == nil then
		return
	end
	entries[player] = nil
	save(entry, true)
end

-- Soma a rodada ao perfil de um jogador presente. `roundKey` identifica a
-- rodada de forma única (servidor + rodada): repetir a chave não soma de novo.
function PlayerDataService.applyRound(player: Player, roundKey: string, delta: RoundDelta, roundXp: RoundXp): boolean
	local entry = entries[player]
	if entry == nil then
		if loading[player] then
			-- Perfil ainda carregando: guarda a rodada para somar ao carregar.
			local queue = pendingRounds[player] or {}
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
	local tickets, ticketLines = RewardRules.ticketsForRound(clean, gained, newLevel - profile.level)
	local updated = table.clone(profile)
	updated.tickets = math.min(RewardConfig.MaxTickets, profile.tickets + tickets)
	updated.ticketsEarned = profile.ticketsEarned + tickets
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
	for _, line in ipairs(ticketLines) do
		TelemetryService.lobbyEvent(player, "TicketsEarned", line.tickets, line.source)
	end

	local newPuffs = grantPuffs(entry)
	publish(entry, {
		roundId = roundXp.roundId,
		total = gained,
		lines = roundXp.lines,
		levelBefore = profile.level,
		levelAfter = newLevel,
		tickets = tickets,
	}, newPuffs)
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

-- Equipa um Puff que o jogador tem (só visual). Falso se não tiver.
function PlayerDataService.equipPuff(player: Player, puffId: string): boolean
	local entry = entries[player]
	if entry == nil or not PuffInventory.owns(entry.profile.puffs, puffId) then
		return false
	end
	if entry.profile.equippedPuff == puffId then
		return true
	end
	local updated = table.clone(entry.profile)
	updated.equippedPuff = puffId
	entry.profile = updated
	entry.dirty = true
	local definition = PuffCatalog.get(puffId)
	TelemetryService.lobbyEvent(player, "PuffEquipped", 1, puffId, if definition ~= nil then definition.rarity else nil)
	publish(entry)
	return true
end

-- Um giro da Puff Machine: confere o saldo, gasta, sorteia e guarda o Puff
-- numa única atualização (nada aqui pausa, então dois pedidos seguidos
-- nunca gastam o mesmo saldo). Só com perfil salvo: um Puff que sumisse na
-- próxima sessão pareceria roubo. Salva logo em seguida.
function PlayerDataService.machinePull(player: Player, rng: Random): (MachineResult?, MachineFailure?)
	local entry = entries[player]
	if entry == nil then
		return nil, "NotLoaded"
	end
	if not entry.canSave then
		return nil, "NotSaved"
	end
	local profile = entry.profile
	if profile.tickets < RewardConfig.MachineCost then
		return nil, "NoTickets"
	end
	local picked, nextPity = RewardRules.rollMachine(rng, profile.machinePity)
	if picked == nil then
		return nil, "Empty"
	end
	local timestamp = now()
	local puffs, duplicate = PuffInventory.addPuff(profile.puffs, picked.id, "Machine", timestamp)
	local refund = if duplicate then RewardConfig.DuplicateRefund else 0
	local updated = table.clone(profile)
	updated.puffs = puffs
	updated.tickets = math.min(RewardConfig.MaxTickets, profile.tickets - RewardConfig.MachineCost + refund)
	updated.ticketsSpent = profile.ticketsSpent + RewardConfig.MachineCost - refund
	updated.machinePulls = profile.machinePulls + 1
	updated.machinePity = nextPity
	entry.profile = updated
	entry.dirty = true

	TelemetryService.lobbyEvent(player, "TicketsSpent", RewardConfig.MachineCost, "PuffMachine")
	TelemetryService.lobbyEvent(player, "PuffMachinePull", updated.machinePulls, picked.id, `{picked.rarity}:{if duplicate then "Duplicate" else "New"}`)
	if duplicate then
		TelemetryService.lobbyEvent(player, "TicketsEarned", refund, "DuplicateRefund")
	else
		TelemetryService.lobbyEvent(player, "PuffUnlocked", PuffInventory.countOwned(puffs), picked.id, `{picked.rarity}:Machine`)
		TelemetryService.lobbyEvent(player, "PuffCollection", PuffInventory.countOwned(puffs), `Of{#PuffCatalog.all()}`)
	end

	-- Sem `newPuffs`: a própria máquina faz a revelação.
	publish(entry)
	task.spawn(save, entry, false)
	return {
		puffId = picked.id,
		duplicate = duplicate,
		refund = refund,
		tickets = updated.tickets,
		pity = nextPity,
	}, nil
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
			save(entry, true)
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

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(ProfileConfig.StoreName)
	end)
	if ok then
		store = result
	else
		warn(string.format("[BlocoPuff] Profiles will not be saved: %s", tostring(result)))
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
