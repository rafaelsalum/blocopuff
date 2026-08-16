--!strict

-- Lê ReplicatedStorage/BlocoPuffState e os atributos do Player local, e
-- traduz esses valores replicados em chamadas ao HudView. Nunca escreve
-- nesses atributos nem toma decisão autoritativa sobre a partida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local EliminationTypes = require(ReplicatedStorage.Shared.types.EliminationTypes)
local HudView = require(script.Parent.Parent.ui.HudView)

type RoundState = RoundTypes.RoundState
type HudViewHandle = HudView.HudViewHandle

local STATE_WAIT_TIMEOUT = 10

local HudController = {}

local started = false
local view: HudViewHandle? = nil
local connections: { RBXScriptConnection } = {}

local cached = {
	roundState = RoundTypes.WaitingForPlayers :: RoundState,
	timeRemaining = 0,
	participantCount = 0,
	minimumPlayers = 0,
	winnerUserId = 0,
	winnerName = "",
	statusMessage = "",
	remainingBlockCount = 0,
	totalBlockCount = 0,
	isParticipant = false,
	isEliminated = false,
	eliminationReason = "",
}

local function readRoundState(instance: Instance): RoundState
	local value = instance:GetAttribute(StateAttributeNames.RoundState)
	if
		value == RoundTypes.WaitingForPlayers
		or value == RoundTypes.Countdown
		or value == RoundTypes.Active
		or value == RoundTypes.Ending
	then
		return value :: RoundState
	end

	return RoundTypes.WaitingForPlayers
end

local function readNumberAttribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end

	return 0
end

local function readStringAttribute(instance: Instance, name: string): string
	local value = instance:GetAttribute(name)
	if typeof(value) == "string" then
		return value
	end

	return ""
end

local function readBooleanAttribute(instance: Instance, name: string): boolean
	local value = instance:GetAttribute(name)
	if typeof(value) == "boolean" then
		return value
	end

	return false
end

local function formatMinutesSeconds(totalSeconds: number): string
	local clamped = math.max(0, math.floor(totalSeconds))
	local minutes = math.floor(clamped / 60)
	local seconds = clamped % 60
	return string.format("%02d:%02d", minutes, seconds)
end

local function render()
	local currentView = view
	if currentView == nil then
		return
	end

	currentView.setStatusText(cached.statusMessage)

	if cached.roundState == RoundTypes.WaitingForPlayers then
		currentView.setTimerVisible(false)
		currentView.setParticipantsText(
			string.format("%d/%d jogadores", cached.participantCount, cached.minimumPlayers)
		)
		currentView.setParticipantsVisible(true)
	elseif cached.roundState == RoundTypes.Countdown then
		currentView.setTimerText(tostring(math.max(0, math.floor(cached.timeRemaining))))
		currentView.setTimerVisible(true)
		currentView.setParticipantsText(string.format("%d jogadores", cached.participantCount))
		currentView.setParticipantsVisible(true)
	elseif cached.roundState == RoundTypes.Active then
		currentView.setTimerText(formatMinutesSeconds(cached.timeRemaining))
		currentView.setTimerVisible(true)
		currentView.setParticipantsText(string.format("%d participantes", cached.participantCount))
		currentView.setParticipantsVisible(true)
	else
		currentView.setTimerVisible(false)
		currentView.setParticipantsVisible(false)
	end

	local showBlockCount = cached.roundState == RoundTypes.Active or cached.roundState == RoundTypes.Ending
	if showBlockCount then
		currentView.setBlockCountText(string.format("Blocos: %d/%d", cached.remainingBlockCount, cached.totalBlockCount))
		currentView.setBlockCountVisible(true)
	else
		currentView.setBlockCountVisible(false)
	end

	local isRoundInProgress = cached.roundState == RoundTypes.Active or cached.roundState == RoundTypes.Ending
	if isRoundInProgress and not cached.isParticipant then
		currentView.setSubMessageText("Você participará da próxima rodada")
		currentView.setSubMessageVisible(true)
	elseif isRoundInProgress and cached.isParticipant and cached.isEliminated then
		if cached.eliminationReason == EliminationTypes.FellFromArena then
			currentView.setSubMessageText("VOCÊ CAIU DA ARENA\nAguarde a próxima rodada")
		elseif cached.eliminationReason == EliminationTypes.CharacterDied then
			currentView.setSubMessageText("VOCÊ FOI ELIMINADO\nAguarde a próxima rodada")
		else
			currentView.setSubMessageText("Você foi eliminado\nAguarde a próxima rodada")
		end
		currentView.setSubMessageVisible(true)
	else
		currentView.setSubMessageVisible(false)
	end

	currentView.setStatusHighlighted(
		cached.roundState == RoundTypes.Ending and cached.winnerUserId ~= 0 and cached.winnerName ~= ""
	)
end

local function connectAttribute(instance: Instance, attributeName: string, handler: () -> ())
	local connection = instance:GetAttributeChangedSignal(attributeName):Connect(handler)
	table.insert(connections, connection)
end

function HudController.start()
	if started then
		return
	end
	started = true

	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		warn("[BlocoPuff] HUD not started: LocalPlayer unavailable")
		return
	end

	local playerGuiInstance = localPlayer:WaitForChild("PlayerGui", STATE_WAIT_TIMEOUT)
	if playerGuiInstance == nil or not playerGuiInstance:IsA("PlayerGui") then
		warn("[BlocoPuff] HUD not started: PlayerGui unavailable")
		return
	end
	local playerGui: PlayerGui = playerGuiInstance

	local containerInstance = ReplicatedStorage:FindFirstChild(StateAttributeNames.ContainerName)
	if containerInstance == nil then
		containerInstance = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, STATE_WAIT_TIMEOUT)
	end
	if containerInstance == nil then
		warn("[BlocoPuff] HUD not started: BlocoPuffState not found within timeout")
		return
	end
	local stateContainer: Instance = containerInstance

	view = HudView.new(playerGui)

	local function refreshFromContainer()
		cached.roundState = readRoundState(stateContainer)
		cached.timeRemaining = readNumberAttribute(stateContainer, StateAttributeNames.TimeRemaining)
		cached.participantCount = readNumberAttribute(stateContainer, StateAttributeNames.ParticipantCount)
		cached.minimumPlayers = readNumberAttribute(stateContainer, StateAttributeNames.MinimumPlayers)
		cached.winnerUserId = readNumberAttribute(stateContainer, StateAttributeNames.WinnerUserId)
		cached.winnerName = readStringAttribute(stateContainer, StateAttributeNames.WinnerName)
		cached.statusMessage = readStringAttribute(stateContainer, StateAttributeNames.StatusMessage)
		cached.remainingBlockCount = readNumberAttribute(stateContainer, StateAttributeNames.RemainingBlockCount)
		cached.totalBlockCount = readNumberAttribute(stateContainer, StateAttributeNames.TotalBlockCount)
	end

	local function refreshFromPlayer()
		cached.isParticipant = readBooleanAttribute(localPlayer, StateAttributeNames.PlayerIsParticipant)
		cached.isEliminated = readBooleanAttribute(localPlayer, StateAttributeNames.PlayerIsEliminated)
		cached.eliminationReason = readStringAttribute(localPlayer, StateAttributeNames.PlayerEliminationReason)
	end

	refreshFromContainer()
	refreshFromPlayer()
	render()

	local containerAttributeNames = {
		StateAttributeNames.RoundState,
		StateAttributeNames.TimeRemaining,
		StateAttributeNames.ParticipantCount,
		StateAttributeNames.MinimumPlayers,
		StateAttributeNames.WinnerUserId,
		StateAttributeNames.WinnerName,
		StateAttributeNames.StatusMessage,
		StateAttributeNames.RemainingBlockCount,
		StateAttributeNames.TotalBlockCount,
	}
	for _, attributeName in ipairs(containerAttributeNames) do
		connectAttribute(stateContainer, attributeName, function()
			refreshFromContainer()
			render()
		end)
	end

	local playerAttributeNames = {
		StateAttributeNames.PlayerIsParticipant,
		StateAttributeNames.PlayerIsEliminated,
		StateAttributeNames.PlayerEliminationReason,
	}
	for _, attributeName in ipairs(playerAttributeNames) do
		connectAttribute(localPlayer, attributeName, function()
			refreshFromPlayer()
			render()
		end)
	end
end

return table.freeze(HudController)
