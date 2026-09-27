--!strict

-- Avisos das passagens secretas: faixa no topo e som quando alguém revela
-- as entradas de um andar, e um aviso curto para quem acerta o quadro errado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local WAIT_TIMEOUT = 15
local CHIME = "rbxasset://sounds/electronicpingshort.wav"

local SecretPassageController = {}

local started = false

local function floorName(floor: unknown): string
	if floor == 1 then
		return "no andar de baixo"
	elseif floor == GameConfig.Arena.FloorCount then
		return "no andar de cima"
	end
	return "na mansão"
end

local function playChime()
	for index, speed in ipairs({ 1.2, 1.5, 1.8 }) do
		task.delay((index - 1) * 0.12, function()
			local sound = Instance.new("Sound")
			sound.SoundId = CHIME
			sound.PlaybackSpeed = speed
			sound.Volume = 0.55
			sound.Parent = SoundService
			sound.Ended:Once(function()
				sound:Destroy()
			end)
			sound:Play()
		end)
	end
end

local function onEvent(kind: unknown, floor: unknown, name: unknown, userId: unknown)
	if kind == "Revealed" then
		playChime()
		local localPlayer = Players.LocalPlayer
		local isMe = localPlayer ~= nil and userId == localPlayer.UserId
		local who = if typeof(name) == "string" then name else "Alguém"
		NotificationManager.notify({
			channel = "Banner",
			category = "Secret",
			priority = "High",
			key = `secret-{tostring(floor)}`,
			icon = "🗝️",
			title = "PASSAGEM SECRETA!",
			subtitle = if isMe
				then `Você revelou as passagens {floorName(floor)}`
				else `{who} revelou as passagens {floorName(floor)}`,
			tone = "Gold",
			duration = 4,
		})
	elseif kind == "WrongPainting" then
		NotificationManager.notify({
			channel = "Banner",
			category = "Secret",
			priority = "Low",
			key = "secret-wrong",
			icon = "🖼️",
			title = "NÃO ERA ESSE QUADRO",
			subtitle = `Algum quadro {floorName(floor)} esconde um segredo…`,
			tone = "Info",
			duration = 1.8,
		})
	end
end

function SecretPassageController.start()
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

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local remote = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.SecretEventRemoteName, WAIT_TIMEOUT) else nil
		if remote ~= nil and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(onEvent)
		else
			warn("[BlocoPuff] Secret passage controller: remote not found")
		end
	end)
end

return table.freeze(SecretPassageController)
