--!strict

-- Mostra a progressão do jogador: o cartão de perfil no lobby (nível, XP e
-- estatísticas), o XP ganho em cada rodada e a comemoração de subida de
-- nível. Tudo vem do servidor pelo ProfileController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local ProfileCardView = require(script.Parent.Parent.ui.ProfileCardView)
local ProfileController = require(script.Parent.ProfileController)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type XpAward = ProfileTypes.XpAward

local WAIT_TIMEOUT = 15
local LEVEL_UP_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local SUMMARY_LINES = 3

local SOURCE_NAMES: { [string]: string } = {
	Participation = "Partida",
	Placement = "Colocação",
	Win = "Vitória",
	Knockouts = "Derrubadas",
	Blocks = "Blocos",
	Secrets = "Segredos",
	VaultOpened = "Cofre aberto",
	VaultConquered = "Cofre conquistado",
	BaraoEscapes = "Fugas do Barão",
	Comeback = "Volta por Cima",
	BlocksBuilt = "Construções",
}

local ProgressionController = {}

local started = false

local function playLevelUp()
	for index, speed in ipairs({ 1, 1.25, 1.5, 2 }) do
		task.delay((index - 1) * 0.1, function()
			local sound = Instance.new("Sound")
			sound.SoundId = LEVEL_UP_SOUND
			sound.PlaybackSpeed = speed
			sound.Volume = 0.6
			sound.Parent = SoundService
			sound.Ended:Once(function()
				sound:Destroy()
			end)
			sound:Play()
		end)
	end
end

-- "Vitória +40 · Derrubadas +16 · Partida +20" com as maiores fontes.
local function summarize(award: XpAward): string
	local lines = table.clone(award.lines)
	table.sort(lines, function(a, b)
		return a.xp > b.xp
	end)
	local parts: { string } = {}
	for index = 1, math.min(SUMMARY_LINES, #lines) do
		local line = lines[index]
		table.insert(parts, string.format("%s +%d", SOURCE_NAMES[line.source] or line.source, line.xp))
	end
	return if #parts > 0 then table.concat(parts, " · ") else "Dispare para ganhar XP na próxima"
end

local function announce(award: XpAward)
	NotificationManager.notify({
		channel = "Banner",
		category = "Progression",
		priority = "Normal",
		key = "xp-award",
		icon = "✨",
		title = string.format("+%d XP", award.total),
		subtitle = summarize(award),
		tone = "Gold",
		duration = 3.5,
		maxWait = 8,
	})
	if award.levelAfter > award.levelBefore then
		playLevelUp()
		NotificationManager.notify({
			channel = "Banner",
			category = "Progression",
			priority = "High",
			key = "level-up",
			icon = "⭐",
			title = string.format("NÍVEL %d!", award.levelAfter),
			subtitle = "Você subiu de nível no BlocoPuff",
			tone = "Winner",
			duration = 4,
			maxWait = 10,
		})
	end
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
	local card = ProfileCardView.new(playerGui)

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
