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
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)

type ProfileStats = ProfileTypes.ProfileStats

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
	appliedRounds: { string },
	createdAt: number,
	updatedAt: number,
	session: Session?,
}

-- Soma de uma rodada para um jogador (mesmas chaves das estatísticas).
export type RoundDelta = ProfileStats

local CURRENT_VERSION = 1
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
		appliedRounds = {},
		createdAt = now,
		updatedAt = now,
		session = nil,
	}
end

-- Passos de migração: MIGRATIONS[n] recebe dados na versão n e devolve na n+1.
local MIGRATIONS: { [number]: (data: { [string]: any }) -> { [string]: any } } = {}

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

	return {
		version = CURRENT_VERSION,
		stats = readStats(data.stats),
		xp = cleanNumber(data.xp, 0),
		level = math.max(1, cleanNumber(data.level, 1)),
		prestige = cleanNumber(data.prestige, 0),
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
		appliedRounds = table.clone(profile.appliedRounds),
		createdAt = profile.createdAt,
		updatedAt = profile.updatedAt,
		session = if profile.session ~= nil then table.clone(profile.session) else nil,
	}
end

return table.freeze(ProfileSchema)
