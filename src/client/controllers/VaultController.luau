--!strict

-- Reage aos eventos do Cofre do Barão enviados pelo servidor: faixas de
-- aviso, alarme sonoro para a partida inteira quando alguém abre o cofre
-- e a contagem de Puffs e construções do Puffador do Cofre. Não decide
-- nada; só apresenta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local SuperChargeView = require(script.Parent.Parent.ui.SuperChargeView)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

type SuperChargeViewHandle = SuperChargeView.SuperChargeViewHandle
type Priority = NotificationManager.Priority
type Tone = NotificationManager.Tone

local WAIT_TIMEOUT = 15
local CHIME_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local SUPER_SOUND = "rbxasset://sounds/button.wav"

local VaultController = {}

local started = false
local view: SuperChargeViewHandle? = nil
local puffs = 0
local builds = 0

-- Faixa do topo, via NotificationManager (fila e prioridade compartilhadas
-- com os avisos de administrador).
local function banner(icon: string, title: string, subtitle: string, tone: Tone, duration: number, priority: Priority, key: string?)
	NotificationManager.notify({
		channel = "Banner",
		category = "Vault",
		priority = priority,
		key = key,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = tone,
		duration = duration,
	})
end

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
		banner("🐶", "O BARÃO ACORDOU!", "E o cofre destrancou: porta dourada no andar de baixo", "Gold", 5, "High", "vault-unlocked")
	elseif kind == "Opened" then
		playAlarm()
		if isLocalUser(second) then
			banner("🗝️", "VOCÊ ABRIU O COFRE!", "Pegue o Puffador do Cofre no pedestal. O Barão ficou bravo!", "Gold", 5, "Critical", "vault-opened")
		else
			banner("🚨", "COFRE ABERTO!", `{asText(first)} abriu o cofre. O Barão ficou bravo!`, "Danger", 5, "Critical", "vault-opened")
		end
	elseif kind == "SuperTaken" then
		playSound(SUPER_SOUND, 0.8, 0.8)
		if isLocalUser(second) then
			banner("⚡", "PUFFADOR DO COFRE!", "2 blocos por Puff. Q, Y ou 🧱 troca para Construir", "Gold", 5, "High", "vault-super")
		else
			banner("⚡", "PUFFADOR DO COFRE!", `{asText(first)} pegou o Puffador do Cofre. Derrube-o!`, "Gold", 4.5, "High", "vault-super")
		end
	elseif kind == "Locked" then
		local subtitle = if first == true then "O cofre está atrás de outra porta!" else "O cofre abre quando o Barão acordar…"
		banner("🔒", "TRANCADA", subtitle, "Info", 2.2, "Low", "vault-locked")
	elseif kind == "StayWarning" then
		local seconds = if typeof(first) == "number" then first else 5
		banner("⏳", "SAIA DO COFRE!", string.format("O Barão vai te expulsar em %d s", seconds), "Danger", 2.5, "High", "vault-stay")
	elseif kind == "Expelled" then
		banner("👢", "EXPULSO DO COFRE!", "Seu tempo no cofre acabou nesta rodada", "Info", 2.5, "Normal")
	end
end

local function onPuffFeedback(kind: unknown, value: unknown)
	local current = view
	if current == nil or (kind ~= "Super" and kind ~= "Builds") then
		return
	end
	local remaining = if typeof(value) == "number" and value == value then math.max(0, math.floor(value)) else 0
	if kind == "Builds" then
		builds = remaining
		current.setCharges(puffs, builds)
		return
	end
	local hadSuper = puffs > 0
	puffs = remaining
	current.setCharges(puffs, builds)
	if remaining == 0 and hadSuper then
		banner("⚡", "PUFFADOR DO COFRE ESGOTADO", "Seu Puffador voltou ao normal", "Info", 2, "Normal")
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
	NotificationManager.init(playerGui)
	view = SuperChargeView.new(playerGui)

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
			puffs = 0
			builds = 0
			view.setCharges(0, 0)
		end
	end
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(hideSuperWhenOut)
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsEliminated):Connect(hideSuperWhenOut)
end

return table.freeze(VaultController)
