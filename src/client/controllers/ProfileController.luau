--!strict

-- Guarda a cópia do perfil persistente enviada pelo servidor (estatísticas,
-- XP, nível e prestígio) e avisa quem quiser mostrar. O cliente nunca muda o
-- perfil: só pede a cópia ao iniciar e recebe as atualizações.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local DailyConfig = require(ReplicatedStorage.Shared.config.DailyConfig)
local SecretCatalog = require(ReplicatedStorage.Shared.config.SecretCatalog)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type ProfileStats = ProfileTypes.ProfileStats
type XpAward = ProfileTypes.XpAward
type XpLine = ProfileTypes.XpLine
type OwnedPuff = PuffTypes.OwnedPuff
type ChallengeState = ProfileTypes.ChallengeState
type DailyState = ProfileTypes.DailyState
type DailyReward = ProfileTypes.DailyReward
type SecretState = ProfileTypes.SecretState

local WAIT_TIMEOUT = 15

local ProfileController = {}

local started = false
local current: ProfileSnapshot? = nil
local changed = Instance.new("BindableEvent")

local function readNumber(value: unknown): number
	if typeof(value) == "number" and value == value and value >= 0 and value < 1e12 then
		return math.floor(value)
	end
	return 0
end

local MAX_AWARD_LINES = 16

local function parseAward(raw: unknown): XpAward?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: any }
	local lines: { XpLine } = {}
	if typeof(data.lines) == "table" then
		for index, line in ipairs(data.lines :: { any }) do
			if index > MAX_AWARD_LINES then
				break
			end
			if typeof(line) == "table" and typeof(line.source) == "string" and #line.source <= 30 then
				table.insert(lines, { source = line.source, xp = readNumber(line.xp) })
			end
		end
	end
	return {
		roundId = readNumber(data.roundId),
		total = readNumber(data.total),
		lines = lines,
		levelBefore = math.max(1, readNumber(data.levelBefore)),
		levelAfter = math.max(1, readNumber(data.levelAfter)),
		tickets = readNumber(data.tickets),
	}
end

-- Só Puffs do catálogo, sem repetidos.
local function parsePuffs(raw: unknown): { OwnedPuff }
	local list: { OwnedPuff } = {}
	if typeof(raw) ~= "table" then
		return list
	end
	local seen: { [string]: boolean } = {}
	for index, item in ipairs(raw :: { any }) do
		if index > #PuffCatalog.all() then
			break
		end
		if typeof(item) == "table" then
			local definition = PuffCatalog.get(item.id)
			if definition ~= nil and not seen[definition.id] then
				seen[definition.id] = true
				local origin = if table.find(PuffTypes.Origins, item.origin) ~= nil then item.origin else definition.origin
				table.insert(list, {
					id = definition.id,
					obtainedAt = readNumber(item.obtainedAt),
					count = math.max(1, readNumber(item.count)),
					origin = origin,
				})
			end
		end
	end
	return list
end

local function parseNewPuffs(raw: unknown): { string }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local ids: { string } = {}
	for index, id in ipairs(raw :: { any }) do
		if index > #PuffCatalog.all() then
			break
		end
		local definition = PuffCatalog.get(id)
		if definition ~= nil then
			table.insert(ids, definition.id)
		end
	end
	return if #ids > 0 then ids else nil
end

local function isChallengeId(id: unknown): boolean
	for _, definition in ipairs(DailyConfig.Challenges) do
		if definition.id == id then
			return true
		end
	end
	return false
end

local function parseChallenges(raw: unknown): { ChallengeState }
	local list: { ChallengeState } = {}
	if typeof(raw) ~= "table" then
		return list
	end
	for index, item in ipairs(raw :: { any }) do
		if index > #DailyConfig.Tiers then
			break
		end
		if typeof(item) == "table" and isChallengeId(item.id) then
			table.insert(list, { id = item.id, progress = readNumber(item.progress), done = item.done == true })
		end
	end
	return list
end

local function parseDaily(raw: unknown): DailyState
	if typeof(raw) ~= "table" then
		return { lastDay = 0, streak = 0, best = 0 }
	end
	local data = raw :: { [string]: any }
	return { lastDay = readNumber(data.lastDay), streak = readNumber(data.streak), best = readNumber(data.best) }
end

local function parseDailyReward(raw: unknown): DailyReward?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: any }
	local streak = readNumber(data.streak)
	if streak <= 0 then
		return nil
	end
	return { streak = streak, tickets = readNumber(data.tickets) }
end

local function parseSecrets(raw: unknown): { SecretState }
	local list: { SecretState } = {}
	if typeof(raw) ~= "table" then
		return list
	end
	for index, item in ipairs(raw :: { any }) do
		if index > #SecretCatalog.all() then
			break
		end
		if typeof(item) == "table" and SecretCatalog.get(item.id) ~= nil then
			table.insert(list, { id = item.id, obtainedAt = readNumber(item.obtainedAt) })
		end
	end
	return list
end

-- Lista de ids válidos (desafios ou segredos) para os eventos.
local function parseIds(raw: unknown, isValid: (id: unknown) -> boolean, limit: number): { string }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local ids: { string } = {}
	for index, id in ipairs(raw :: { any }) do
		if index > limit then
			break
		end
		if typeof(id) == "string" and isValid(id) then
			table.insert(ids, id)
		end
	end
	return if #ids > 0 then ids else nil
end

local function parse(raw: unknown): ProfileSnapshot?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: any }
	if typeof(data.stats) ~= "table" then
		return nil
	end
	local stats = {} :: any
	for _, key in ipairs(ProfileTypes.StatKeys) do
		stats[key] = readNumber(data.stats[key])
	end
	return {
		stats = stats :: ProfileStats,
		xp = readNumber(data.xp),
		level = math.max(1, readNumber(data.level)),
		prestige = readNumber(data.prestige),
		saved = data.saved == true,
		puffs = parsePuffs(data.puffs),
		equippedPuff = if PuffCatalog.get(data.equippedPuff) ~= nil then data.equippedPuff else PuffCatalog.DefaultId,
		tickets = readNumber(data.tickets),
		machinePity = readNumber(data.machinePity),
		daily = parseDaily(data.daily),
		challenges = parseChallenges(data.challenges),
		nextResetAt = readNumber(data.nextResetAt),
		secrets = parseSecrets(data.secrets),
		dailyReward = parseDailyReward(data.dailyReward),
		completedChallenges = parseIds(data.completedChallenges, isChallengeId, #DailyConfig.Tiers),
		newSecrets = parseIds(data.newSecrets, function(id)
			return SecretCatalog.get(id) ~= nil
		end, #SecretCatalog.all()),
		award = parseAward(data.award),
		newPuffs = parseNewPuffs(data.newPuffs),
	}
end

function ProfileController.get(): ProfileSnapshot?
	return current
end

-- Evento disparado com o novo ProfileSnapshot sempre que ele muda.
ProfileController.Changed = changed.Event

function ProfileController.start()
	if started then
		return
	end
	started = true
	if Players.LocalPlayer == nil then
		return
	end

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local remote = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.ProfileSnapshotRemoteName, WAIT_TIMEOUT) else nil
		if remote == nil or not remote:IsA("RemoteEvent") then
			warn("[BlocoPuff] Profile controller: remote not found")
			return
		end
		remote.OnClientEvent:Connect(function(raw: unknown)
			local snapshot = parse(raw)
			if snapshot == nil then
				warn("[BlocoPuff] Ignoring malformed profile snapshot")
				return
			end
			current = snapshot
			if RunService:IsStudio() then
				print(string.format("[BlocoPuff] Profile: %d matches, %d wins, saved=%s", snapshot.stats.matches, snapshot.stats.wins, tostring(snapshot.saved)))
			end
			changed:Fire(snapshot)
		end)
		remote:FireServer()
	end)
end

return table.freeze(ProfileController)
