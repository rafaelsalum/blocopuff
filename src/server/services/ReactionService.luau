--!strict

-- Espectador social (Fase 4.4). Pedidos do cliente (remote "Reaction"):
--   "React", índice → um emoji fixo de SocialConfig.Reactions;
--   "Spectating"    → telemetria de uso do espectador (troca de câmera).
-- Só quem NÃO está competindo reage, e a reação só chega a quem também não
-- está competindo: nada aparece na tela de quem está jogando.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocialConfig = require(ReplicatedStorage.Shared.config.SocialConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local TelemetryService = require(script.Parent.TelemetryService)

local SPECTATING_COOLDOWN = 10

local ReactionService = {}

local started = false
local lastReaction: { [Player]: number } = {}
local lastSpectating: { [Player]: number } = {}

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function throttled(map: { [Player]: number }, player: Player, cooldown: number): boolean
	local clock = os.clock()
	local last = map[player]
	if last ~= nil and clock - last < cooldown then
		return true
	end
	map[player] = clock
	return false
end

local function onRequest(remote: RemoteEvent, player: Player, action: unknown, value: unknown)
	if action == "React" then
		if typeof(value) ~= "number" or value ~= value or isCompeting(player) then
			return
		end
		local index = math.floor(value)
		if SocialConfig.Reactions[index] == nil or throttled(lastReaction, player, SocialConfig.ReactionCooldown) then
			return
		end
		for _, viewer in ipairs(Players:GetPlayers()) do
			if not isCompeting(viewer) then
				remote:FireClient(viewer, "React", player.UserId, player.DisplayName, index)
			end
		end
		TelemetryService.lobbyEvent(player, "Reaction", index)
	elseif action == "Spectating" then
		if throttled(lastSpectating, player, SPECTATING_COOLDOWN) then
			return
		end
		TelemetryService.lobbyEvent(player, "SpectatorSwitch", 1)
	end
end

function ReactionService.start(remotesFolder: Folder)
	if started then
		return
	end
	started = true
	local remote = Instance.new("RemoteEvent")
	remote.Name = PuffadorConstants.ReactionRemoteName
	remote.Parent = remotesFolder
	remote.OnServerEvent:Connect(function(player: Player, action: unknown, value: unknown)
		onRequest(remote, player, action, value)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastReaction[player] = nil
		lastSpectating[player] = nil
	end)
end

return table.freeze(ReactionService)
