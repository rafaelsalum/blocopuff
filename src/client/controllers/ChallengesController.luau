--!strict

-- Desafios, retorno diário e conquistas secretas no cliente (Fase 4.3):
-- abre o painel pelo botão 📋 do cartão de perfil e comemora com avisos o
-- que o servidor avisou no perfil (recompensa do dia, desafio concluído,
-- conquista secreta). O cliente não concede nada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyConfig = require(ReplicatedStorage.Shared.config.DailyConfig)
local SecretCatalog = require(ReplicatedStorage.Shared.config.SecretCatalog)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local ChallengesView = require(script.Parent.Parent.ui.ChallengesView)
local ProfileController = require(script.Parent.ProfileController)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type ChallengesViewHandle = ChallengesView.ChallengesViewHandle

local WAIT_TIMEOUT = 15

local ChallengesController = {}

local started = false
local view: ChallengesViewHandle? = nil

local function challengeTitle(id: string): string
	for _, definition in ipairs(DailyConfig.Challenges) do
		if definition.id == id then
			return definition.title
		end
	end
	return id
end

local function challengeTickets(id: string): number
	for _, definition in ipairs(DailyConfig.Challenges) do
		if definition.id == id then
			return definition.tickets
		end
	end
	return 0
end

local function celebrate(snapshot: ProfileSnapshot)
	local reward = snapshot.dailyReward
	if reward ~= nil then
		NotificationManager.notify({
			channel = "Banner",
			category = "Progression",
			priority = "Normal",
			key = "daily-return",
			icon = "🌞",
			title = string.format("RETORNO DIÁRIO · DIA %d", reward.streak),
			subtitle = string.format("+%d 🎟 para a Puff Machine", reward.tickets),
			tone = "Winner",
			duration = 4,
			maxWait = 30,
		})
	end
	for _, id in ipairs(snapshot.completedChallenges or {}) do
		NotificationManager.notify({
			channel = "Banner",
			category = "Progression",
			priority = "Normal",
			key = `challenge-{id}`,
			icon = "📋",
			title = "DESAFIO CONCLUÍDO!",
			subtitle = string.format("%s · +%d 🎟", challengeTitle(id), challengeTickets(id)),
			tone = "Winner",
			duration = 4,
			maxWait = 30,
		})
	end
	for _, id in ipairs(snapshot.newSecrets or {}) do
		local definition = SecretCatalog.get(id)
		if definition ~= nil then
			NotificationManager.notify({
				channel = "Banner",
				category = "Progression",
				priority = "High",
				key = `secret-{id}`,
				icon = "🔍",
				title = "CONQUISTA SECRETA!",
				subtitle = string.format("%s · +%d 🎟", definition.name, definition.tickets),
				tone = "Winner",
				duration = 4.5,
				maxWait = 30,
			})
		end
	end
end

function ChallengesController.open()
	local current = view
	if current == nil then
		return
	end
	if current.isOpen() then
		current.close()
	else
		current.open()
	end
end

function ChallengesController.start()
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
		warn("[BlocoPuff] Challenges controller not started: PlayerGui unavailable")
		return
	end
	NotificationManager.init(playerGui)

	-- Abrir o painel só vira telemetria (pelo remote do Puffdex, que já
	-- limita a frequência).
	local newView = ChallengesView.new(playerGui, function()
		local remotes = ReplicatedStorage:FindFirstChild(PuffadorConstants.RemotesContainerName)
		local remote = if remotes ~= nil then remotes:FindFirstChild(PuffadorConstants.PuffdexRemoteName) else nil
		if remote ~= nil and remote:IsA("RemoteEvent") then
			remote:FireServer("ChallengesOpened")
		end
	end)
	view = newView

	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			newView.close()
		end
	end)

	ProfileController.Changed:Connect(function(snapshot: ProfileSnapshot)
		newView.setProfile(snapshot)
		celebrate(snapshot)
	end)
	local current = ProfileController.get()
	if current ~= nil then
		newView.setProfile(current)
	end
end

return table.freeze(ChallengesController)
