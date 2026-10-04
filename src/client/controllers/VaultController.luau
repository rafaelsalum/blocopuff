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
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local SuperChargeView = require(script.Parent.Parent.ui.SuperChargeView)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

type SuperChargeViewHandle = SuperChargeView.SuperChargeViewHandle
type Priority = NotificationManager.Priority
type Tone = NotificationManager.Tone

local T = Lang.t
local WAIT_TIMEOUT = 15
local CHIME_SOUND = "rbxassetid://123582256549202"
local ALARM_SECONDS = 2.5
local SUPER_SOUND = "rbxassetid://84872960927850"

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

-- Alarme curto (campainha de emergência), audível em qualquer lugar do
-- mapa: o som é longo, então para depois de ALARM_SECONDS.
local function playAlarm()
	local sound = Instance.new("Sound")
	sound.SoundId = GameConfig.SecretRoom.AlertSoundId
	sound.Volume = 0.7
	sound.Parent = SoundService
	sound:Play()
	task.delay(ALARM_SECONDS, function()
		sound:Destroy()
	end)
end

local function isLocalUser(userId: unknown): boolean
	local player = Players.LocalPlayer
	return player ~= nil and userId == player.UserId
end

local function asText(value: unknown): string
	return if typeof(value) == "string" then value else T("Alguém")
end

local function onVaultEvent(kind: unknown, first: unknown, second: unknown)
	local current = view
	if current == nil then
		return
	end

	if kind == "Unlocked" then
		playSound(CHIME_SOUND, 1, 0.6)
		playSound(CHIME_SOUND, 1.25, 0.6, 0.18)
		banner("🐶", T("O BARÃO ACORDOU!"), T("E o cofre destrancou: porta dourada no andar de baixo"), "Gold", 5, "Critical", "vault-unlocked")
	elseif kind == "Opened" then
		playAlarm()
		if isLocalUser(second) then
			banner("🗝️", T("VOCÊ ABRIU O COFRE!"), T("Pegue o Puffador do Cofre no pedestal. O Barão ficou bravo!"), "Gold", 5, "Critical", "vault-opened")
		else
			banner("🚨", T("COFRE ABERTO!"), T("%s abriu o cofre. O Barão ficou bravo!", asText(first)), "Danger", 5, "Critical", "vault-opened")
		end
	elseif kind == "SuperTaken" then
		playSound(SUPER_SOUND, 1, 0.8)
		if isLocalUser(second) then
			banner("⚡", T("COFRE CONQUISTADO!"), T("Puffador do Cofre: 2 blocos por Puff. Q, Y ou 🧱 troca para Construir"), "Gold", 5, "High", "vault-super")
		else
			banner("⚡", T("COFRE CONQUISTADO!"), T("%s pegou o Puffador do Cofre. Derrube-o!", asText(first)), "Gold", 4.5, "High", "vault-super")
		end
	elseif kind == "Locked" then
		local subtitle = if first == true then T("O cofre está atrás de outra porta!") else T("O cofre abre quando o Barão acordar…")
		banner("🔒", T("TRANCADA"), subtitle, "Info", 2.2, "Low", "vault-locked")
	elseif kind == "StayWarning" then
		local seconds = if typeof(first) == "number" then first else 5
		banner("⏳", T("SAIA DO COFRE!"), T("O Barão vai te expulsar em %d s", seconds), "Danger", 2.5, "High", "vault-stay")
	elseif kind == "Expelled" then
		banner("👢", T("EXPULSO DO COFRE!"), T("Seu tempo no cofre acabou nesta rodada"), "Info", 2.5, "Normal")
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
		banner("⚡", T("PUFFADOR DO COFRE ESGOTADO"), T("Seu Puffador voltou ao normal"), "Info", 2, "Normal")
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
