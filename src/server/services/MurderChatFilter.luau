--!strict

-- Chat no Assassinato no Casarão (Fase 5E.4): durante a partida, o que um
-- participante eliminado escreve não chega a quem ainda está vivo nela (não
-- dá para entregar o Assassino depois de sair). Quem está no lobby e os
-- outros eliminados continuam lendo. Vale em todos os canais do
-- TextChatService (geral, equipe e sussurro).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

local MODE_ID = "Mystery"
local WAIT_TIMEOUT = 15

local MurderChatFilter = {}

local started = false

local function inMurderMatch(): boolean
	local container = ReplicatedStorage:FindFirstChild(StateAttributeNames.ContainerName)
	return container ~= nil
		and container:GetAttribute(StateAttributeNames.RoundState) == "Active"
		and container:GetAttribute(StateAttributeNames.RoundMode) == MODE_ID
end

local function isParticipant(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
end

local function isEliminated(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == true
end

-- Entrega a mensagem a `target`?
local function shouldDeliver(message: TextChatMessage, target: TextSource): boolean
	local source = message.TextSource
	if source == nil or not inMurderMatch() then
		return true
	end
	local sender = Players:GetPlayerByUserId(source.UserId)
	local receiver = Players:GetPlayerByUserId(target.UserId)
	if sender == nil or receiver == nil or sender == receiver then
		return true
	end
	local senderOut = isParticipant(sender) and isEliminated(sender)
	local receiverAlive = isParticipant(receiver) and not isEliminated(receiver)
	return not (senderOut and receiverAlive)
end

local function hook(channel: Instance)
	if channel:IsA("TextChannel") then
		channel.ShouldDeliverCallback = shouldDeliver
	end
end

function MurderChatFilter.start()
	if started then
		return
	end
	started = true
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn("[BlocoPuff] MurderChatFilter: legacy chat in use, eliminated chat is not filtered")
		return
	end
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", WAIT_TIMEOUT)
		if channels == nil then
			warn("[BlocoPuff] MurderChatFilter: TextChannels not found")
			return
		end
		channels.ChildAdded:Connect(hook)
		for _, channel in ipairs(channels:GetChildren()) do
			hook(channel)
		end
	end)
end

return table.freeze(MurderChatFilter)
