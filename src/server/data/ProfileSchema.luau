--!strict

-- Formato salvo do perfil, versões e validação. Tudo que vem do DataStore
-- passa por `fromStored` (migra versões antigas e limpa valores inválidos) e
-- toda soma de rodada passa por `clampDelta` (valores impossíveis são
-- cortados e relatados).
--
-- Para mudar o formato: incremente CURRENT_VERSION e acrescente um passo em
-- MIGRATIONS que leva da versão anterior para a nova. Nunca remova passos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local LevelCurve = require(ReplicatedStorage.Shared.modules.LevelCurve)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local RewardConfig = require(ReplicatedStorage.Shared.config.RewardConfig)
local PuffInventory = require(script.Parent.PuffInventory)
local DailyRules = require(script.Parent.DailyRules)
local SecretCatalog = require(ReplicatedStorage.Shared.config.SecretCatalog)

type ProfileStats = ProfileTypes.ProfileStats
type Inventory = PuffInventory.Inventory
type Challenges = DailyRules.Challenges
type DailyState = ProfileTypes.DailyState

export type Session = {
	jobId: string,
	lockedAt: number,
}

export type Profile = {
	version: number,
	stats: ProfileStats,
	xp: number,
	level: number,
	prestige: number,
	-- os.time() em que chegou ao nível atual (telemetria de tempo por nível).
	levelReachedAt: number,
	-- Puffdex (4.1): Puffs do jogador e o equipado.
	puffs: Inventory,
	equippedPuff: string,
	-- Tickets e Puff Machine (4.2): saldo, totais e giros seguidos sem
	-- Épico ou melhor (garantia).
	tickets: number,
	ticketsEarned: number,
	ticketsSpent: number,
	machinePulls: number,
	machinePity: number,
	-- Retorno diário, desafios do dia e conquistas secretas (4.3).
	daily: DailyState,
	challenges: Challenges,
	challengesCompleted: number,
	secrets: { [string]: number },
	appliedRounds: { string },
	createdAt: number,
	updatedAt: number,
	session: Session?,
}

-- Soma de uma rodada para um jogador (mesmas chaves das estatísticas).
export type RoundDelta = ProfileStats

-- v1: estatísticas (3.1). v2: levelReachedAt (3.2). v3: Puffdex (4.1).
-- v4: tickets e Puff Machine (4.2). v5: desafios, retorno diário e
-- conquistas secretas (4.3).
local CURRENT_VERSION = 5
local MAX_STAT = 1e9
local MAX_ROUND_KEY_LENGTH = 80

local ProfileSchema = {}

ProfileSchema.CurrentVersion = CURRENT_VERSION

local function cleanNumber(value: unknown, fallback: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(math.floor(value), 0, MAX_STAT)
end

function ProfileSchema.emptyStats(): ProfileStats
	local stats = {} :: any
	for _, key in ipairs(ProfileTypes.StatKeys) do
		stats[key] = 0
	end
	return stats :: ProfileStats
end

function ProfileSchema.default(now: number): Profile
	return {
		version = CURRENT_VERSION,
		stats = ProfileSchema.emptyStats(),
		xp = 0,
		level = 1,
		prestige = 0,
		levelReachedAt = now,
		puffs = {},
		equippedPuff = PuffCatalog.DefaultId,
		tickets = 0,
		ticketsEarned = 0,
		ticketsSpent = 0,
		machinePulls = 0,
		machinePity = 0,
		daily = DailyRules.emptyDaily(),
		challenges = { day = 0, list = {} },
		challengesCompleted = 0,
		secrets = {},
		appliedRounds = {},
		createdAt = now,
		updatedAt = now,
		session = nil,
	}
end

-- Passos de migração: MIGRATIONS[n] recebe dados na versão n e devolve na n+1.
local MIGRATIONS: { [number]: (data: { [string]: any }) -> { [string]: any } } = {
	-- v1 → v2: data em que chegou ao nível atual (sem histórico: usa a última gravação).
	[1] = function(data)
		local migrated = table.clone(data)
		migrated.levelReachedAt = data.updatedAt or data.createdAt
		migrated.version = 2
		return migrated
	end,
	-- v2 → v3: inventário de Puffs vazio; os Puffs já merecidos (nível e
	-- façanhas) são concedidos pelo PlayerDataService ao carregar.
	[2] = function(data)
		local migrated = table.clone(data)
		migrated.puffs = {}
		migrated.equippedPuff = PuffCatalog.DefaultId
		migrated.version = 3
		return migrated
	end,
	-- v3 → v4: carteira de tickets zerada.
	[3] = function(data)
		local migrated = table.clone(data)
		migrated.tickets = 0
		migrated.ticketsEarned = 0
		migrated.ticketsSpent = 0
		migrated.machinePulls = 0
		migrated.machinePity = 0
		migrated.version = 4
		return migrated
	end,
	-- v4 → v5: sem desafios nem sequência ainda (começam no próximo login).
	[4] = function(data)
		local migrated = table.clone(data)
		migrated.daily = nil
		migrated.challenges = nil
		migrated.challengesCompleted = 0
		migrated.secrets = {}
		migrated.version = 5
		return migrated
	end,
}

local function readSecrets(raw: unknown, now: number): { [string]: number }
	local secrets: { [string]: number } = {}
	if typeof(raw) ~= "table" then
		return secrets
	end
	for id, value in pairs(raw :: { [unknown]: unknown }) do
		-- Ids desconhecidos são mantidos (conquista de uma versão futura).
		if typeof(id) == "string" and #id <= SecretCatalog.MaxIdLength then
			secrets[id] = if typeof(value) == "number" and value == value then math.max(0, math.floor(value)) else now
		end
	end
	return secrets
end

local function readStats(raw: unknown): ProfileStats
	local stats = ProfileSchema.emptyStats() :: any
	if typeof(raw) == "table" then
		local source = raw :: { [string]: unknown }
		for _, key in ipairs(ProfileTypes.StatKeys) do
			stats[key] = cleanNumber(source[key], 0)
		end
	end
	return stats :: ProfileStats
end

local function readSession(raw: unknown): Session?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: unknown }
	local jobId = data.jobId
	local lockedAt = data.lockedAt
	if typeof(jobId) ~= "string" or typeof(lockedAt) ~= "number" then
		return nil
	end
	return { jobId = jobId, lockedAt = lockedAt }
end

local function readAppliedRounds(raw: unknown): { string }
	local rounds: { string } = {}
	if typeof(raw) == "table" then
		for _, value in ipairs(raw :: { unknown }) do
			if typeof(value) == "string" and #value <= MAX_ROUND_KEY_LENGTH then
				table.insert(rounds, value)
			end
		end
	end
	return rounds
end

-- Só a trava de sessão do que está salvo (checagem leve dentro do
-- UpdateAsync ao salvar, sem reconstruir o perfil inteiro).
function ProfileSchema.storedSession(raw: unknown): Session?
	if typeof(raw) ~= "table" then
		return nil
	end
	return readSession((raw :: { [string]: unknown }).session)
end

-- Converte o que veio do DataStore num perfil válido da versão atual.
-- Segundo retorno: verdadeiro se os dados são de uma versão MAIS NOVA que
-- este servidor conhece (atualização em andamento). Nesse caso o perfil não
-- deve ser salvo por este servidor, para não perder campos novos.
function ProfileSchema.fromStored(raw: unknown, now: number): (Profile, boolean)
	if typeof(raw) ~= "table" then
		return ProfileSchema.default(now), false
	end
	local data = table.clone(raw :: { [string]: any })
	local version = cleanNumber(data.version, 1)
	if version > CURRENT_VERSION then
		local profile = ProfileSchema.default(now)
		profile.stats = readStats(data.stats)
		profile.puffs = PuffInventory.fromStored(data.puffs, now)
		profile.equippedPuff = PuffInventory.validEquipped(profile.puffs, data.equippedPuff)
		profile.daily = DailyRules.readDaily(data.daily)
		profile.challenges = DailyRules.readChallenges(data.challenges)
		profile.secrets = readSecrets(data.secrets, now)
		profile.session = readSession(data.session)
		return profile, true
	end
	while version < CURRENT_VERSION do
		local step = MIGRATIONS[version]
		if step == nil then
			break
		end
		data = step(data)
		version += 1
	end

	-- O nível sai sempre do XP (determinístico); o salvo é só informativo.
	local xp = math.min(cleanNumber(data.xp, 0), LevelCurve.maxXp())
	local puffs = PuffInventory.fromStored(data.puffs, now)
	return {
		version = CURRENT_VERSION,
		stats = readStats(data.stats),
		xp = xp,
		level = LevelCurve.levelForXp(xp),
		prestige = cleanNumber(data.prestige, 0),
		levelReachedAt = cleanNumber(data.levelReachedAt, now),
		puffs = puffs,
		equippedPuff = PuffInventory.validEquipped(puffs, data.equippedPuff),
		tickets = math.min(cleanNumber(data.tickets, 0), RewardConfig.MaxTickets),
		ticketsEarned = cleanNumber(data.ticketsEarned, 0),
		ticketsSpent = cleanNumber(data.ticketsSpent, 0),
		machinePulls = cleanNumber(data.machinePulls, 0),
		machinePity = math.min(cleanNumber(data.machinePity, 0), RewardConfig.PityThreshold),
		daily = DailyRules.readDaily(data.daily),
		challenges = DailyRules.readChallenges(data.challenges),
		challengesCompleted = cleanNumber(data.challengesCompleted, 0),
		secrets = readSecrets(data.secrets, now),
		appliedRounds = readAppliedRounds(data.appliedRounds),
		createdAt = cleanNumber(data.createdAt, now),
		updatedAt = cleanNumber(data.updatedAt, now),
		session = readSession(data.session),
	}, false
end

-- Máximo possível por rodada para cada estatística.
local function roundLimits(): { [string]: number }
	local arena = GameConfig.Arena
	local totalBlocks = arena.Rows * arena.Columns * arena.FloorCount
	return {
		matches = 1,
		wins = 1,
		top3 = 1,
		knockouts = GameConfig.MaximumPlayers - 1,
		blocksDestroyed = totalBlocks + (GameConfig.SecretRoom.BuildCharges * 2),
		vaultsOpened = 1,
		vaultsConquered = 1,
		baraoEscapes = 10,
		secretsFound = arena.FloorCount,
		blocksBuilt = GameConfig.SecretRoom.BuildCharges,
		comebacks = 1,
	}
end

-- Corta valores impossíveis de uma rodada. Devolve a soma limpa e a lista
-- das estatísticas que precisaram de corte (para log e telemetria).
function ProfileSchema.clampDelta(delta: RoundDelta): (RoundDelta, { string })
	local limits = roundLimits()
	local clean = ProfileSchema.emptyStats() :: any
	local anomalies: { string } = {}
	local source = delta :: any
	for _, key in ipairs(ProfileTypes.StatKeys) do
		local raw = source[key]
		local value = cleanNumber(raw, 0)
		local limit = limits[key] or 0
		if value > limit then
			table.insert(anomalies, `{key}={tostring(raw)}>{limit}`)
			value = limit
		elseif raw ~= nil and raw ~= value then
			table.insert(anomalies, `{key}={tostring(raw)}`)
		end
		clean[key] = value
	end
	return clean :: RoundDelta, anomalies
end

-- Nova tabela de estatísticas com a rodada somada (não altera `stats`).
function ProfileSchema.addStats(stats: ProfileStats, delta: RoundDelta): ProfileStats
	local result = {} :: any
	local current = stats :: any
	local extra = delta :: any
	for _, key in ipairs(ProfileTypes.StatKeys) do
		result[key] = math.min(MAX_STAT, (current[key] or 0) + (extra[key] or 0))
	end
	return result :: ProfileStats
end

-- Cópia do perfil com tickets somados (respeita o teto de saldo).
function ProfileSchema.withTickets(profile: Profile, tickets: number): Profile
	local updated = table.clone(profile)
	local amount = math.max(0, math.floor(tickets))
	updated.tickets = math.min(RewardConfig.MaxTickets, profile.tickets + amount)
	updated.ticketsEarned = profile.ticketsEarned + amount
	return updated
end

-- Guarda a chave da rodada aplicada, mantendo só as `keep` mais recentes.
function ProfileSchema.withAppliedRound(rounds: { string }, roundKey: string, keep: number): { string }
	local result = table.clone(rounds)
	table.insert(result, string.sub(roundKey, 1, MAX_ROUND_KEY_LENGTH))
	while #result > keep do
		table.remove(result, 1)
	end
	return result
end

-- Formato gravado no DataStore (tabela simples, sem metatables).
function ProfileSchema.toStored(profile: Profile): { [string]: any }
	return {
		version = profile.version,
		stats = table.clone(profile.stats),
		xp = profile.xp,
		level = profile.level,
		prestige = profile.prestige,
		levelReachedAt = profile.levelReachedAt,
		puffs = PuffInventory.toStored(profile.puffs),
		equippedPuff = profile.equippedPuff,
		tickets = profile.tickets,
		ticketsEarned = profile.ticketsEarned,
		ticketsSpent = profile.ticketsSpent,
		machinePulls = profile.machinePulls,
		machinePity = profile.machinePity,
		daily = table.clone(profile.daily),
		challenges = DailyRules.toStoredChallenges(profile.challenges),
		challengesCompleted = profile.challengesCompleted,
		secrets = table.clone(profile.secrets),
		appliedRounds = table.clone(profile.appliedRounds),
		createdAt = profile.createdAt,
		updatedAt = profile.updatedAt,
		session = if profile.session ~= nil then table.clone(profile.session) else nil,
	}
end

return table.freeze(ProfileSchema)
