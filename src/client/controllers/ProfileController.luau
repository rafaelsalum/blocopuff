--!strict

-- Guarda a cópia do perfil persistente enviada pelo servidor (estatísticas,
-- XP, nível e prestígio) e avisa quem quiser mostrar. O cliente nunca muda o
-- perfil: só pede a cópia ao iniciar e recebe as atualizações.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type ProfileStats = ProfileTypes.ProfileStats

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
