--!strict

-- Mostra a progressão do jogador: o cartão de perfil no lobby (nível, XP e
-- estatísticas) e a comemoração de subida de nível (o XP de cada rodada fica
-- no painel de pós-partida). Tudo vem do servidor pelo ProfileController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local ProfileCardView = require(script.Parent.Parent.ui.ProfileCardView)
local ProfileController = require(script.Parent.ProfileController)
local LeaderboardController = require(script.Parent.LeaderboardController)
local PuffdexController = require(script.Parent.PuffdexController)
local PuffMachineController = require(script.Parent.PuffMachineController)
local ChallengesController = require(script.Parent.ChallengesController)
local PartyController = require(script.Parent.PartyController)
local InviteController = require(script.Parent.InviteController)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type XpAward = ProfileTypes.XpAward

local WAIT_TIMEOUT = 15
local LEVEL_UP_SOUND = "rbxassetid://112485797063762"

local ProgressionController = {}

local started = false

local function playLevelUp()
	local sound = Instance.new("Sound")
	sound.SoundId = LEVEL_UP_SOUND
	sound.Volume = 0.6
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- O XP da rodada aparece no painel de pós-partida; aqui fica só a
-- comemoração de subida de nível.
local function announce(award: XpAward)
	if award.levelAfter <= award.levelBefore then
		return
	end
	playLevelUp()
	NotificationManager.notify({
		channel = "Banner",
		category = "Progression",
		priority = "High",
		key = "level-up",
		icon = "⭐",
		title = Lang.t("NÍVEL %d!", award.levelAfter),
		subtitle = Lang.t("Você subiu de nível no BlocoPuff"),
		tone = "Winner",
		duration = 4,
		maxWait = 10,
	})
end

function ProgressionController.start()
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
		warn("[BlocoPuff] Progression controller not started: PlayerGui unavailable")
		return
	end
	NotificationManager.init(playerGui)
	local card = ProfileCardView.new(playerGui, LeaderboardController.open, PuffdexController.open, PuffMachineController.open, ChallengesController.open, PartyController.open, InviteController.invite)
	PartyController.SizeChanged:Connect(card.setPartySize)

	-- Cartão só no lobby: some enquanto o jogador está competindo.
	local hasProfile = false
	local function refreshVisibility()
		local competing = player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
			and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
		card.setVisible(hasProfile and not competing)
	end
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(refreshVisibility)
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsEliminated):Connect(refreshVisibility)

	local function onProfile(snapshot: ProfileSnapshot)
		hasProfile = true
		card.setProfile(snapshot)
		refreshVisibility()
		local award = snapshot.award
		if award ~= nil then
			announce(award)
			if award.levelAfter > award.levelBefore then
				card.celebrateLevel()
			end
		end
	end
	ProfileController.Changed:Connect(onProfile)
	local current = ProfileController.get()
	if current ~= nil then
		onProfile(current)
	end
end

return table.freeze(ProgressionController)
