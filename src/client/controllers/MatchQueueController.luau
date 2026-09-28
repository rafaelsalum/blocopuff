--!strict

-- Fila da partida no cliente: o botão JOGAR do HUD pede ao servidor para
-- ir ao mirante, e o aviso de "sozinho na fila" vira uma faixa sugerindo
-- chamar amigos. Quem está na fila é decidido no servidor
-- (MatchQueueService, atributo "InMatchQueue").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local WAIT_TIMEOUT = 15

local MatchQueueController = {}

local started = false
local remote: RemoteEvent? = nil

local function onMessage(kind: unknown)
	if kind ~= "Lonely" then
		return
	end
	NotificationManager.notify({
		channel = "Banner",
		category = "Lobby",
		priority = "Low",
		key = "queue-lonely",
		icon = "👥",
		title = "CHAME UM AMIGO",
		subtitle = "A partida começa com 2 no mirante. Convide pela Party!",
		tone = "Info",
		duration = 5,
		maxWait = 8,
	})
end

-- Botão JOGAR: o servidor valida (fora da partida, vivo) e leva ao mirante.
function MatchQueueController.join()
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireServer("Join")
	end
end

function MatchQueueController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if playerGui ~= nil and playerGui:IsA("PlayerGui") then
		NotificationManager.init(playerGui)
	end
	-- Espera o remote sem travar o início dos outros controllers.
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.MatchQueueRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Match queue remote not found")
			return
		end
		remote = instance
		instance.OnClientEvent:Connect(onMessage)
	end)
end

return table.freeze(MatchQueueController)
