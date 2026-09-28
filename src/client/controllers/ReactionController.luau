--!strict

-- Reações do espectador (Fase 4.4): mostra a barra de emojis enquanto uma
-- partida acontece e o jogador local NÃO está competindo (eliminado ou
-- esperando), e mostra as reações que o servidor repassa. Quem está
-- jogando não vê nada (o servidor nem envia).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocialConfig = require(ReplicatedStorage.Shared.config.SocialConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ReactionView = require(script.Parent.Parent.ui.ReactionView)

local WAIT_TIMEOUT = 15
local MAX_NAME_LENGTH = 20

local ReactionController = {}

local started = false

function ReactionController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		warn("[BlocoPuff] Reaction controller not started: PlayerGui unavailable")
		return
	end

	local remote: RemoteEvent? = nil
	local lastSent = 0
	local view = ReactionView.new(playerGui, function(index: number)
		local clock = os.clock()
		local currentRemote = remote
		if currentRemote == nil or clock - lastSent < SocialConfig.ReactionCooldown then
			return
		end
		lastSent = clock
		currentRemote:FireServer("React", index)
	end)

	local function isCompeting(): boolean
		return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
			and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
	end

	task.spawn(function()
		local container = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, WAIT_TIMEOUT)
		if container == nil then
			return
		end
		local function refresh()
			local state = container:GetAttribute(StateAttributeNames.RoundState)
			local watching = state == RoundTypes.Active and not isCompeting()
			view.setBarVisible(watching)
			if isCompeting() then
				view.clear()
			end
		end
		container:GetAttributeChangedSignal(StateAttributeNames.RoundState):Connect(refresh)
		player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(refresh)
		player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsEliminated):Connect(refresh)
		refresh()
	end)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.ReactionRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Reaction controller: remote not found")
			return
		end
		remote = instance
		instance.OnClientEvent:Connect(function(kind: unknown, _userId: unknown, name: unknown, index: unknown)
			if kind ~= "React" or isCompeting() or typeof(index) ~= "number" then
				return
			end
			local emoji = SocialConfig.Reactions[math.floor(index)]
			if emoji == nil then
				return
			end
			local displayName = if typeof(name) == "string" then string.sub(name, 1, MAX_NAME_LENGTH) else "?"
			view.push(displayName, emoji)
		end)
	end)
end

return table.freeze(ReactionController)
