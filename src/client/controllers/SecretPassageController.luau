--!strict

-- Avisos das passagens secretas: faixa no topo e som quando alguém revela
-- as entradas de um andar, e um aviso curto para quem acerta o quadro errado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local WAIT_TIMEOUT = 15
local CHIME = "rbxassetid://118315466257318"

local SecretPassageController = {}

local started = false

local T = Lang.t

local function floorName(floor: unknown): string
	if floor == 1 then
		return T("no andar de baixo")
	elseif floor == GameConfig.Arena.FloorCount then
		return T("no andar de cima")
	end
	return T("na mansão")
end

local function playChime()
	local sound = Instance.new("Sound")
	sound.SoundId = CHIME
	sound.Volume = 0.55
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function onEvent(kind: unknown, floor: unknown, name: unknown, userId: unknown)
	if kind == "Revealed" then
		playChime()
		local localPlayer = Players.LocalPlayer
		local isMe = localPlayer ~= nil and userId == localPlayer.UserId
		local who = if typeof(name) == "string" then name else T("Alguém")
		local subtitle: string
		if isMe then
			subtitle = T("Você revelou as passagens %s", floorName(floor))
		else
			subtitle = T("%s revelou as passagens %s", who, floorName(floor))
		end
		NotificationManager.notify({
			channel = "Banner",
			category = "Secret",
			priority = "High",
			key = `secret-{tostring(floor)}`,
			icon = "🗝️",
			title = T("PASSAGEM SECRETA!"),
			subtitle = subtitle,
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
			title = T("NÃO ERA ESSE QUADRO"),
			subtitle = T("Algum quadro %s esconde um segredo…", floorName(floor)),
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
