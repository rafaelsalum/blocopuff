--!strict

-- Estações do lobby (Fase 4.5): o ProximityPrompt de cada estação física
-- abre a tela correspondente (Puff Machine, Puffdex, Desafios, Party). A loja só
-- avisa que chega em breve. O carinho no Barão é tratado no servidor.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local ChallengesController = require(script.Parent.ChallengesController)
local PartyController = require(script.Parent.PartyController)
local PuffdexController = require(script.Parent.PuffdexController)
local PuffMachineController = require(script.Parent.PuffMachineController)

local STATION_ATTRIBUTE = "LobbyStation"
local WAIT_TIMEOUT = 15

local LobbyStationsController = {}

local started = false

local function openStation(station: unknown)
	if station == "PuffMachine" then
		PuffMachineController.show()
	elseif station == "Puffdex" then
		PuffdexController.show()
	elseif station == "Challenges" then
		ChallengesController.show()
	elseif station == "Party" then
		PartyController.show()
	elseif station == "Shop" then
		NotificationManager.notify({
			channel = "Banner",
			category = "Lobby",
			priority = "Normal",
			key = "shop-soon",
			icon = "🛍",
			title = Lang.t("LOJA EM BREVE"),
			subtitle = Lang.t("Ainda não tem nada à venda. Puffs saem jogando!"),
			tone = "Info",
			duration = 3.5,
			maxWait = 5,
		})
	end
end

function LobbyStationsController.start()
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
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeredBy: Player)
		if triggeredBy ~= player then
			return
		end
		openStation(prompt:GetAttribute(STATION_ATTRIBUTE))
	end)
end

return table.freeze(LobbyStationsController)
