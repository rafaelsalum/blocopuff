--!strict

-- Avisos do Barão e das Tocas Seguras para o próprio jogador: quando entra
-- numa Toca (e por quanto tempo ela protege), o aviso de que o tempo está
-- acabando, a expulsão por tempo esgotado e o empurrão do Barão. A posição
-- do Barão nunca é mostrada: a pista dele é só o som.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local WAIT_TIMEOUT = 15
local CATEGORY_TOCA = "Toca"
local CATEGORY_BARAO = "Barao"

local BaraoController = {}

local started = false

local function seconds(value: unknown, fallback: number): number
	if typeof(value) == "number" and value == value and value >= 0 and value <= 60 then
		return math.ceil(value)
	end
	return fallback
end

local function onFeedback(kind: unknown, value: unknown)
	if kind == "TocaEnter" then
		NotificationManager.notify({
			channel = "Banner",
			category = CATEGORY_TOCA,
			priority = "Low",
			key = "toca",
			icon = "🐾",
			title = "TOCA SEGURA",
			subtitle = `O Barão não te pega aqui por {seconds(value, GameConfig.Toca.MaxStay)} s`,
			tone = "Info",
			duration = 2.5,
		})
	elseif kind == "TocaWarning" then
		NotificationManager.notify({
			channel = "Banner",
			category = CATEGORY_TOCA,
			priority = "Normal",
			key = "toca",
			icon = "⏳",
			title = "SAIA DA TOCA",
			subtitle = `A proteção acaba em {seconds(value, GameConfig.Toca.WarningAt)} s`,
			tone = "Warning",
			duration = 2,
		})
	elseif kind == "TocaEject" then
		NotificationManager.notify({
			channel = "Banner",
			category = CATEGORY_TOCA,
			priority = "Normal",
			key = "toca",
			icon = "🚪",
			title = "TEMPO ESGOTADO NA TOCA",
			subtitle = `Tocas bloqueadas para você por {seconds(value, GameConfig.Toca.Cooldown)} s`,
			tone = "Warning",
			duration = 2.5,
		})
	elseif kind == "TocaLeave" then
		NotificationManager.clear("Banner", CATEGORY_TOCA)
	elseif kind == "BaraoContact" then
		NotificationManager.notify({
			channel = "Banner",
			category = CATEGORY_BARAO,
			priority = "Normal",
			key = "barao-contact",
			icon = "🐶",
			title = "AU AU!",
			subtitle = "O Barão te expulsou do corredor",
			tone = "Warning",
			duration = 1.8,
		})
	end
end

function BaraoController.start()
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
		local feedback = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.PuffFeedbackRemoteName, WAIT_TIMEOUT) else nil
		if feedback ~= nil and feedback:IsA("RemoteEvent") then
			feedback.OnClientEvent:Connect(onFeedback)
		else
			warn("[BlocoPuff] Barao controller: feedback remote not found")
		end
	end)
end

return table.freeze(BaraoController)
