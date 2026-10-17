--!strict

-- Modos de partida no cliente (Fase 5D): confirma o voto ao entrar no
-- mirante por uma das portas, avisa qual será a próxima partida quando não
-- for a Arena, abre a partida com o nome e o objetivo do modo e,
-- na Corrida da Torre, mostra o checkpoint e a posição ao vivo. Na Arena
-- nada muda: o HUD de combate de sempre cuida de tudo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local UiTheme = require(script.Parent.Parent.ui.UiTheme)
local ResponsiveScale = require(script.Parent.Parent.ui.ResponsiveScale)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local T = Lang.t
local WAIT_TIMEOUT = 15
local CATEGORY = "Mode"
local GUI_NAME = "BlocoPuffModeHud"
local DISPLAY_ORDER = 6
local PANEL_SIZE = Vector2.new(260, 48)

type ModeInfo = {
	icon: string,
	title: string,
	goal: string,
}

-- Textos de cada modo novo (a Arena não aparece aqui).
local function modeInfo(mode: string): ModeInfo?
	if mode == "Race" then
		return {
			icon = "🕰",
			title = T("CORRIDA DA TORRE"),
			goal = T("Chegue ao topo primeiro! Desvie do que o Barão joga"),
		}
	elseif mode == "Mystery" then
		return {
			icon = "👻",
			title = T("MISTÉRIO NO CASARÃO"),
			goal = T("Um Fantasma está entre vocês · descubra quem é"),
		}
	end
	return nil
end

-- Nome do modo no aviso de voto (a Arena também).
local function voteTitle(mode: string): (string, string)
	local info = modeInfo(mode)
	if info ~= nil then
		return info.icon, info.title
	end
	return "🏟", T("DERRUBE SEUS AMIGOS")
end

local ModeController = {}

local started = false

type Panel = {
	gui: ScreenGui,
	label: TextLabel,
}

local function createPanel(playerGui: PlayerGui): Panel
	local gui = UiTheme.createScreenGui(GUI_NAME, playerGui, DISPLAY_ORDER)
	gui.Enabled = false
	local root = Instance.new("Frame")
	root.Name = "RaceProgress"
	root.Position = UDim2.fromOffset(18, 16)
	root.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	root.Parent = gui
	UiTheme.stylePanel(root, { accent = UiTheme.Colors.Gold, radius = 14 })
	ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.7, 1.05)
	local label = UiTheme.createLabel(root, "Progress", "", Enum.Font.GothamBold, 18)
	label.Size = UDim2.fromScale(1, 1)
	UiTheme.addPadding(label, 12, 4)
	UiTheme.addTextOutline(label, 1.5)
	return { gui = gui, label = label }
end

local function readNumber(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function readString(instance: Instance, name: string): string
	local value = instance:GetAttribute(name)
	return if typeof(value) == "string" then value else ""
end

local function progressText(checkpoint: number, position: number, finishOrder: number): string
	if finishOrder > 0 then
		return T("🏁 Você chegou em %s!", Lang.ordinal(finishOrder))
	end
	local checkpoints = T("🚩 Checkpoint %d/%d", checkpoint, RaceConfig.CheckpointCount)
	if position > 0 then
		return T("%s · %s lugar", checkpoints, Lang.ordinal(position))
	end
	return checkpoints
end

local function run(container: Instance, panel: Panel)
	local localPlayer = Players.LocalPlayer
	local lastNextMode = ""
	local lastVote = readString(localPlayer, StateAttributeNames.PlayerModeVote)
	local introRound = 0
	local lastCheckpoint = 0
	local announcedFinish = 0

	local function refresh()
		local state = readString(container, StateAttributeNames.RoundState)
		local roundMode = readString(container, StateAttributeNames.RoundMode)
		local nextMode = readString(container, StateAttributeNames.NextRoundMode)
		local roundId = readNumber(container, StateAttributeNames.RoundId)
		local participant = localPlayer:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true

		-- Voto novo pela porta do mirante.
		local vote = readString(localPlayer, StateAttributeNames.PlayerModeVote)
		if vote ~= lastVote then
			lastVote = vote
			if vote ~= "" then
				local icon, title = voteTitle(vote)
				NotificationManager.notify({
					channel = "Banner",
					category = CATEGORY,
					priority = "Normal",
					key = "mode-vote",
					icon = icon,
					title = T("SEU VOTO: %s", title),
					subtitle = T("O modo mais votado da fila é o da próxima partida"),
					tone = "Gold",
					duration = 3,
				})
			end
		end

		-- Próxima partida diferente da Arena: um aviso por mudança.
		local waiting = state == "WaitingForPlayers" or state == "Countdown"
		if waiting and nextMode ~= lastNextMode then
			lastNextMode = nextMode
			local info = modeInfo(nextMode)
			if info ~= nil then
				NotificationManager.notify({
					channel = "Banner",
					category = CATEGORY,
					priority = "Normal",
					key = "next-mode",
					icon = info.icon,
					title = T("PRÓXIMA PARTIDA"),
					subtitle = info.title,
					tone = "Gold",
					duration = 4,
				})
			end
		end

		local racing = state == "Active" and participant and roundMode == "Race"
		local info = modeInfo(roundMode)
		if state == "Active" and participant and info ~= nil and introRound ~= roundId then
			introRound = roundId
			lastCheckpoint = 0
			announcedFinish = 0
			NotificationManager.notify({
				channel = "Center",
				category = CATEGORY,
				priority = "High",
				key = "mode-intro",
				icon = info.icon,
				title = info.title,
				subtitle = info.goal,
				tone = "Gold",
				duration = 3,
			})
		end

		panel.gui.Enabled = racing
		if not racing then
			return
		end
		local checkpoint = readNumber(localPlayer, StateAttributeNames.PlayerRaceCheckpoint)
		local position = readNumber(localPlayer, StateAttributeNames.PlayerRacePosition)
		local finishOrder = readNumber(localPlayer, StateAttributeNames.PlayerRaceFinishOrder)
		panel.label.Text = progressText(checkpoint, position, finishOrder)

		if checkpoint > lastCheckpoint then
			lastCheckpoint = checkpoint
			NotificationManager.notify({
				channel = "Banner",
				category = CATEGORY,
				priority = "Low",
				key = "race-checkpoint",
				icon = "🚩",
				title = T("CHECKPOINT %d/%d", checkpoint, RaceConfig.CheckpointCount),
				subtitle = T("Se cair, você volta para cá"),
				tone = "Info",
				duration = 2,
			})
		end
		if finishOrder > 0 and announcedFinish ~= roundId then
			announcedFinish = roundId
			NotificationManager.notify({
				channel = "Center",
				category = CATEGORY,
				priority = "High",
				key = "race-finish",
				icon = "🏁",
				title = T("VOCÊ CHEGOU EM %s!", string.upper(Lang.ordinal(finishOrder))),
				subtitle = T("Aguarde o fim da corrida no topo"),
				tone = "Winner",
				duration = 3,
			})
		end
	end

	container.AttributeChanged:Connect(refresh)
	localPlayer.AttributeChanged:Connect(refresh)
	refresh()
end

function ModeController.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local localPlayer = Players.LocalPlayer
		local playerGui = localPlayer:WaitForChild("PlayerGui", WAIT_TIMEOUT)
		local container = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, WAIT_TIMEOUT)
		if playerGui == nil or container == nil or not playerGui:IsA("PlayerGui") then
			warn("[BlocoPuff] ModeController: state container or PlayerGui not found")
			return
		end
		run(container, createPanel(playerGui))
	end)
end

return table.freeze(ModeController)
