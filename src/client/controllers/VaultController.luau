--!strict

-- Reage aos eventos do Cofre do Barão enviados pelo servidor: faixas de
-- aviso, alarme sonoro para a partida inteira quando alguém invade o cofre
-- e a contagem de tiros do Super Puffador. Não decide nada; só apresenta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local VaultView = require(script.Parent.Parent.ui.VaultView)

type VaultViewHandle = VaultView.VaultViewHandle

local WAIT_TIMEOUT = 15
local CHIME_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local SUPER_SOUND = "rbxasset://sounds/button.wav"

local VaultController = {}

local started = false
local view: VaultViewHandle? = nil

local function playSound(soundId: string, speed: number, volume: number, delaySeconds: number?)
	task.delay(delaySeconds or 0, function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.PlaybackSpeed = speed
		sound.Volume = volume
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end)
end

-- Alarme curto de três toques alternados, audível em qualquer lugar do mapa.
local function playAlarm()
	local soundId = GameConfig.SecretRoom.AlertSoundId
	for index = 0, 5 do
		playSound(soundId, if index % 2 == 0 then 1.35 else 0.95, 0.8, index * 0.22)
	end
end

local function isLocalUser(userId: unknown): boolean
	local player = Players.LocalPlayer
	return player ~= nil and userId == player.UserId
end

local function asText(value: unknown): string
	return if typeof(value) == "string" then value else "Alguém"
end

local function onVaultEvent(kind: unknown, first: unknown, second: unknown)
	local current = view
	if current == nil then
		return
	end

	if kind == "Unlocked" then
		playSound(CHIME_SOUND, 1.6, 0.6)
		playSound(CHIME_SOUND, 2, 0.6, 0.18)
		current.showBanner("🔓", "O COFRE DESTRANCOU!", "Uma porta do andar de baixo está brilhando…", "Gold", 5)
	elseif kind == "Opened" then
		playAlarm()
		if isLocalUser(second) then
			current.showBanner("🗝️", "VOCÊ ACHOU O COFRE!", "Pegue o Super Puffador no pedestal. Cuidado: aqui um tiro elimina!", "Gold", 5)
		else
			current.showBanner("🚨", "COFRE INVADIDO!", `{asText(first)} abriu o cofre do Barão!`, "Danger", 5)
		end
	elseif kind == "SuperTaken" then
		playSound(SUPER_SOUND, 0.8, 0.8)
		if isLocalUser(second) then
			current.showBanner("⚡", "SUPER PUFFADOR!", "Cada tiro derruba 2 blocos. Todos veem seu brilho dourado!", "Gold", 4.5)
		else
			current.showBanner("⚡", "SUPER PUFFADOR!", `{asText(first)} pegou o Super Puffador. Derrube-o!`, "Gold", 4.5)
		end
	elseif kind == "ShotInVault" then
		current.showBanner("🎯", "PEGO NO COFRE!", `{asText(second)} acertou {asText(first)} dentro do cofre`, "Danger", 3.5)
	elseif kind == "Locked" then
		local subtitle = if first == true then "O cofre está atrás de outra porta!" else "O cofre do Barão ainda está trancado…"
		current.showBanner("🔒", "TRANCADA", subtitle, "Info", 2.2)
	elseif kind == "StayWarning" then
		local seconds = if typeof(first) == "number" then first else 5
		current.showBanner("⏳", "SAIA DO COFRE!", string.format("O Barão vai te expulsar em %d s", seconds), "Danger", 2.5)
	elseif kind == "Expelled" then
		current.showBanner("👢", "EXPULSO DO COFRE!", "Seu tempo no cofre acabou nesta rodada", "Info", 2.5)
	end
end

local function onPuffFeedback(kind: unknown, charges: unknown)
	local current = view
	if current == nil or kind ~= "Super" then
		return
	end
	local remaining = if typeof(charges) == "number" then charges else 0
	current.setSuperCharges(remaining)
	if remaining == 0 then
		current.showBanner("⚡", "SUPER ESGOTADO", "Seu Puffador voltou ao normal", "Info", 2)
	end
end

function VaultController.start()
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
		warn("[BlocoPuff] Vault controller not started: PlayerGui unavailable")
		return
	end
	view = VaultView.new(playerGui)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		if remotes == nil then
			warn("[BlocoPuff] Vault controller: remotes not found")
			return
		end
		local vaultRemote = remotes:WaitForChild(PuffadorConstants.VaultEventRemoteName, WAIT_TIMEOUT)
		if vaultRemote ~= nil and vaultRemote:IsA("RemoteEvent") then
			vaultRemote.OnClientEvent:Connect(onVaultEvent)
		end
		local feedbackRemote = remotes:WaitForChild(PuffadorConstants.PuffFeedbackRemoteName, WAIT_TIMEOUT)
		if feedbackRemote ~= nil and feedbackRemote:IsA("RemoteEvent") then
			feedbackRemote.OnClientEvent:Connect(onPuffFeedback)
		end
	end)

	-- Ao sair da rodada (eliminado ou fim), some a pílula do Super.
	local function hideSuperWhenOut()
		local competing = player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
			and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
		if not competing and view ~= nil then
			view.setSuperCharges(0)
		end
	end
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(hideSuperWhenOut)
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsEliminated):Connect(hideSuperWhenOut)
end

return table.freeze(VaultController)
