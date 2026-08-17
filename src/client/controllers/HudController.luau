--!strict

-- Traduz estado replicado em três camadas visuais independentes: rodada,
-- combate e anúncios. Não escreve atributos nem decide regras da partida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EliminationTypes = require(ReplicatedStorage.Shared.types.EliminationTypes)
local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local HudView = require(script.Parent.Parent.ui.HudView)

type RoundState = RoundTypes.RoundState
type HudViewHandle = HudView.HudViewHandle

local STATE_WAIT_TIMEOUT = 10

local HudController = {}

local started = false
local view: HudViewHandle? = nil
local connections: { RBXScriptConnection } = {}
local lastAnnouncementKey = ""

local cached = {
	roundState = RoundTypes.WaitingForPlayers :: RoundState,
	roundId = 0,
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
	roundsUntilTurn = 0,
	roundBlocksDestroyed = 0,
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

local function getQueueMessage(): string
	if cached.roundsUntilTurn >= 2 then
		return string.format("Sua vez chega em %d rodadas", cached.roundsUntilTurn)
	end
	return "Você participa da próxima rodada"
end

local function clearAnnouncement(currentView: HudViewHandle)
	if lastAnnouncementKey == "" then
		return
	end
	lastAnnouncementKey = ""
	currentView.hideAnnouncement()
end

local function showAnnouncement(
	currentView: HudViewHandle,
	key: string,
	title: string,
	subtitle: string,
	tone: "Info" | "Warning" | "Danger" | "Winner",
	duration: number?
)
	if key == lastAnnouncementKey then
		return
	end
	lastAnnouncementKey = key
	currentView.showAnnouncement(title, subtitle, tone, duration)
end

local function renderWaiting(currentView: HudViewHandle)
	currentView.setRoundMode("Waiting")
	currentView.setRoundStatus(if cached.statusMessage ~= "" then cached.statusMessage else "Aguardando jogadores")
	currentView.setRoundParticipants(
		string.format("%d DE %d JOGADORES", cached.participantCount, cached.minimumPlayers)
	)
	currentView.setQueueText(getQueueMessage())
	currentView.setQueueVisible(cached.roundsUntilTurn >= 2)
	currentView.setCombatVisible(false)
	clearAnnouncement(currentView)
end

local function renderCountdown(currentView: HudViewHandle)
	currentView.setRoundMode("Countdown")
	currentView.setCountdown(tostring(math.max(0, math.floor(cached.timeRemaining))))
	currentView.setQueueVisible(false)
	currentView.setCombatVisible(false)
	clearAnnouncement(currentView)
end

local function getPersonalScoreSummary(): string
	if not cached.isParticipant then
		return "A próxima rodada está chegando"
	end

	local safeScore = math.max(0, math.floor(cached.roundBlocksDestroyed))
	return string.format("Você derrubou %d %s", safeScore, if safeScore == 1 then "bloco" else "blocos")
end

local function renderActive(currentView: HudViewHandle)
	currentView.setRoundMode("Hidden")
	currentView.setQueueVisible(false)
	currentView.setCombatVisible(true)
	currentView.setCombatTimer(formatMinutesSeconds(cached.timeRemaining))
	currentView.setCombatParticipants(cached.participantCount)
	currentView.setArenaIntegrity(cached.remainingBlockCount, cached.totalBlockCount)
	currentView.setPersonalScore(cached.roundBlocksDestroyed, cached.isParticipant)

	if not cached.isParticipant then
		showAnnouncement(
			currentView,
			string.format("%d:waiting:%d", cached.roundId, cached.roundsUntilTurn),
			"AGUARDE SUA VEZ",
			getQueueMessage(),
			"Warning",
			3
		)
	elseif cached.isEliminated then
		local fell = cached.eliminationReason == EliminationTypes.FellFromArena
		showAnnouncement(
			currentView,
			string.format("%d:eliminated:%s", cached.roundId, cached.eliminationReason),
			if fell then "VOCÊ CAIU!" else "ELIMINADO!",
			string.format("%s • acompanhe os jogadores restantes", getPersonalScoreSummary()),
			"Danger",
			2.6
		)
	else
		showAnnouncement(
			currentView,
			string.format("%d:active", cached.roundId),
			"VALENDO!",
			"Mire nos blocos e continue na arena",
			"Info",
			1.5
		)
	end
end

local function renderEnding(currentView: HudViewHandle)
	currentView.setRoundMode("Hidden")
	currentView.setQueueVisible(false)
	currentView.setCombatVisible(false)

	local scoreSummary = getPersonalScoreSummary()
	if cached.winnerUserId ~= 0 and cached.winnerName ~= "" then
		local localPlayer = Players.LocalPlayer
		local localPlayerWon = localPlayer ~= nil and localPlayer.UserId == cached.winnerUserId
		showAnnouncement(
			currentView,
			string.format("%d:winner:%d", cached.roundId, cached.winnerUserId),
			if localPlayerWon then "VITÓRIA!" else "FIM DA RODADA",
			if localPlayerWon
				then string.format("Último na arena • %s", scoreSummary)
				else string.format("%s venceu • %s", cached.winnerName, scoreSummary),
			"Winner",
			4
		)
	else
		showAnnouncement(
			currentView,
			string.format("%d:no-winner", cached.roundId),
			"FIM DA RODADA",
			scoreSummary,
			"Info",
			3
		)
	end
end

local function render()
	local currentView = view
	if currentView == nil then
		return
	end

	if cached.roundState == RoundTypes.WaitingForPlayers then
		renderWaiting(currentView)
	elseif cached.roundState == RoundTypes.Countdown then
		renderCountdown(currentView)
	elseif cached.roundState == RoundTypes.Active then
		renderActive(currentView)
	else
		renderEnding(currentView)
	end
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

	local containerInstance = ReplicatedStorage:FindFirstChild(StateAttributeNames.ContainerName)
	if containerInstance == nil then
		containerInstance = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, STATE_WAIT_TIMEOUT)
	end
	if containerInstance == nil then
		warn("[BlocoPuff] HUD not started: BlocoPuffState not found within timeout")
		return
	end

	view = HudView.new(playerGuiInstance)

	local function refreshFromContainer()
		cached.roundState = readRoundState(containerInstance)
		cached.roundId = readNumberAttribute(containerInstance, StateAttributeNames.RoundId)
		cached.timeRemaining = readNumberAttribute(containerInstance, StateAttributeNames.TimeRemaining)
		cached.participantCount = readNumberAttribute(containerInstance, StateAttributeNames.ParticipantCount)
		cached.minimumPlayers = readNumberAttribute(containerInstance, StateAttributeNames.MinimumPlayers)
		cached.winnerUserId = readNumberAttribute(containerInstance, StateAttributeNames.WinnerUserId)
		cached.winnerName = readStringAttribute(containerInstance, StateAttributeNames.WinnerName)
		cached.statusMessage = readStringAttribute(containerInstance, StateAttributeNames.StatusMessage)
		cached.remainingBlockCount = readNumberAttribute(containerInstance, StateAttributeNames.RemainingBlockCount)
		cached.totalBlockCount = readNumberAttribute(containerInstance, StateAttributeNames.TotalBlockCount)
	end

	local function refreshFromPlayer()
		cached.isParticipant = readBooleanAttribute(localPlayer, StateAttributeNames.PlayerIsParticipant)
		cached.isEliminated = readBooleanAttribute(localPlayer, StateAttributeNames.PlayerIsEliminated)
		cached.eliminationReason = readStringAttribute(localPlayer, StateAttributeNames.PlayerEliminationReason)
		cached.roundsUntilTurn = readNumberAttribute(localPlayer, StateAttributeNames.PlayerRoundsUntilTurn)
		cached.roundBlocksDestroyed = readNumberAttribute(
			localPlayer,
			StateAttributeNames.PlayerRoundBlocksDestroyed
		)
	end

	refreshFromContainer()
	refreshFromPlayer()
	render()

	local containerAttributeNames = {
		StateAttributeNames.RoundState,
		StateAttributeNames.RoundId,
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
		connectAttribute(containerInstance, attributeName, function()
			refreshFromContainer()
			render()
		end)
	end

	local playerAttributeNames = {
		StateAttributeNames.PlayerIsParticipant,
		StateAttributeNames.PlayerIsEliminated,
		StateAttributeNames.PlayerEliminationReason,
		StateAttributeNames.PlayerRoundsUntilTurn,
		StateAttributeNames.PlayerRoundBlocksDestroyed,
	}
	for _, attributeName in ipairs(playerAttributeNames) do
		connectAttribute(localPlayer, attributeName, function()
			refreshFromPlayer()
			render()
		end)
	end
end

return table.freeze(HudController)
