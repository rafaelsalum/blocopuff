--!strict

-- Traduz estado replicado em três camadas visuais independentes: rodada,
-- combate e anúncios. Não escreve atributos nem decide regras da partida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local EliminationTypes = require(ReplicatedStorage.Shared.types.EliminationTypes)
local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local HudView = require(script.Parent.Parent.ui.HudView)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local MatchQueueController = require(script.Parent.MatchQueueController)

local T = Lang.t

type RoundState = RoundTypes.RoundState
type HudViewHandle = HudView.HudViewHandle
type QueueStatus = HudView.QueueStatus
type Priority = NotificationManager.Priority

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
	finalChaos = false,
	hasSecondChance = false,
	inMatchQueue = false,
	queuePlace = "",
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

-- Para quem está na fila.
local function getQueueMessage(): string
	if cached.roundsUntilTurn >= 2 then
		return T("Sua vez chega em %d rodadas", cached.roundsUntilTurn)
	end
	return T("Você participa da próxima rodada")
end

-- Onde está a vaga do jogador (atributo "QueuePlace").
local function queueStatus(): QueueStatus
	if not cached.inMatchQueue then
		return "Out"
	end
	local place = cached.queuePlace
	if place == "Ticket" then
		return "Ticket"
	elseif place == "Party" then
		return "Party"
	end
	return "Mirante"
end

-- Etiqueta da fila (canto superior direito) na espera e na contagem.
local function renderQueue(currentView: HudViewHandle, counting: boolean)
	local count = math.max(0, math.floor(cached.participantCount))
	local minimum = math.max(1, math.floor(cached.minimumPlayers))
	local status = queueStatus()
	if status ~= "Out" then
		local roaming = status ~= "Mirante"
		local subtitle: string
		if cached.roundsUntilTurn >= 2 then
			subtitle = getQueueMessage()
		elseif counting then
			subtitle = if roaming then T("Partida em %d s · avisamos antes", math.max(0, math.floor(cached.timeRemaining))) else T("%d na fila · fique no mirante", count)
		elseif roaming then
			subtitle = T("Explore o Casarão: avisamos antes")
		else
			local missing = math.max(0, minimum - count)
			subtitle = if missing == 1 then T("Falta 1 jogador para começar") else T("Faltam %d jogadores para começar", missing)
		end
		local title: string
		if roaming then
			title = T("🎟 FICHA  %d/%d", count, minimum)
		else
			title = if counting then T("✅ VOCÊ ESTÁ NA FILA") else T("🏟 NA FILA  %d/%d", count, minimum)
		end
		currentView.setQueue(title, subtitle, status)
	else
		local title = if counting then T("🏟 %d NA FILA", count) else T("🏟 FILA  %d/%d", count, minimum)
		currentView.setQueue(title, T("Aperte JOGAR e explore enquanto espera"), status)
	end
end

local function clearAnnouncement(_currentView: HudViewHandle)
	if lastAnnouncementKey == "" then
		return
	end
	lastAnnouncementKey = ""
	NotificationManager.clear("Center")
end

-- Envia um anúncio central uma única vez por `key` (o render roda a cada
-- mudança de atributo). Fila, prioridade e sobreposição ficam com o
-- NotificationManager.
local function showAnnouncement(
	_currentView: HudViewHandle,
	key: string,
	title: string,
	subtitle: string,
	tone: "Info" | "Warning" | "Danger" | "Winner",
	duration: number,
	category: string,
	priority: Priority
)
	if key == lastAnnouncementKey then
		return
	end
	lastAnnouncementKey = key
	NotificationManager.notify({
		channel = "Center",
		category = category,
		priority = priority,
		key = key,
		title = title,
		subtitle = subtitle,
		tone = tone,
		duration = duration,
	})
end

local function renderWaiting(currentView: HudViewHandle)
	currentView.setRoundMode("Waiting")
	renderQueue(currentView, false)
	currentView.setCombatVisible(false)
	clearAnnouncement(currentView)
end

-- O cronômetro da contagem só aparece para quem está na fila; quem passeia
-- pelo Casarão vê apenas a etiqueta.
local function renderCountdown(currentView: HudViewHandle)
	if cached.inMatchQueue or cached.isParticipant then
		currentView.setRoundMode("Countdown")
		currentView.setCountdown(tostring(math.max(0, math.floor(cached.timeRemaining))))
	else
		currentView.setRoundMode("Waiting")
	end
	renderQueue(currentView, true)
	currentView.setCombatVisible(false)
	clearAnnouncement(currentView)
end

-- Partida em andamento para quem não está nela (lobby): nada da partida
-- (HUD de combate, avisos, cronômetro); só a etiqueta da fila da próxima.
local function renderLobbyDuringMatch(currentView: HudViewHandle)
	currentView.setRoundMode("Waiting")
	currentView.setQueue(
		T("⚔️ PARTIDA EM ANDAMENTO"),
		if cached.inMatchQueue then T("Você está na fila da próxima") else T("Aperte JOGAR para a próxima"),
		queueStatus()
	)
	currentView.setCombatVisible(false)
	currentView.setTimerDanger(false)
	clearAnnouncement(currentView)
end

local function getPersonalScoreSummary(): string
	if not cached.isParticipant then
		return T("A próxima rodada está chegando")
	end

	local safeScore = math.max(0, math.floor(cached.roundBlocksDestroyed))
	return T("Você derrubou %d %s", safeScore, if safeScore == 1 then T("bloco") else T("blocos"))
end

local function renderActive(currentView: HudViewHandle)
	if not cached.isParticipant then
		renderLobbyDuringMatch(currentView)
		return
	end
	currentView.setRoundMode("Hidden")
	currentView.setCombatVisible(true)
	currentView.setCombatTimer(formatMinutesSeconds(cached.timeRemaining))
	currentView.setCombatParticipants(cached.participantCount)
	currentView.setArenaIntegrity(cached.remainingBlockCount, cached.totalBlockCount)
	currentView.setPersonalScore(cached.roundBlocksDestroyed, cached.isParticipant)
	currentView.setTimerDanger(cached.finalChaos)

	local competing = cached.isParticipant and not cached.isEliminated
	local secondChanceUsed = competing and GameConfig.SecondChance.Enabled and not cached.hasSecondChance
	if not competing then
		currentView.setLives("Hidden")
	elseif cached.finalChaos then
		currentView.setLives("Chaos")
	elseif cached.hasSecondChance then
		currentView.setLives("SecondChance")
	else
		currentView.setLives("LastLife")
	end

	if cached.isEliminated then
		local reason = cached.eliminationReason
		local title = if reason == EliminationTypes.FellFromArena then T("VOCÊ CAIU!") else T("ELIMINADO!")
		showAnnouncement(
			currentView,
			string.format("%d:eliminated:%s", cached.roundId, reason),
			title,
			T("%s · acompanhe os jogadores restantes", getPersonalScoreSummary()),
			"Danger",
			2.6,
			"Elimination",
			"Critical"
		)
	elseif cached.finalChaos then
		showAnnouncement(
			currentView,
			string.format("%d:chaos", cached.roundId),
			T("CAOS FINAL!"),
			T("Sem Segunda Chance · blocos vermelhos vão cair"),
			"Danger",
			3,
			"Chaos",
			"Critical"
		)
	elseif secondChanceUsed then
		showAnnouncement(
			currentView,
			string.format("%d:second-chance", cached.roundId),
			T("SEGUNDA CHANCE!"),
			T("Você voltou para a arena · agora é sua última vida"),
			"Warning",
			2.6,
			"Lives",
			"High"
		)
	else
		showAnnouncement(
			currentView,
			string.format("%d:active", cached.roundId),
			T("VALENDO!"),
			T("Empurre os rivais e derrube os blocos embaixo deles"),
			"Info",
			1.5,
			"Round",
			"Normal"
		)
	end
end

local function renderEnding(currentView: HudViewHandle)
	if not cached.isParticipant then
		renderLobbyDuringMatch(currentView)
		return
	end
	currentView.setRoundMode("Hidden")
	currentView.setCombatVisible(false)
	currentView.setTimerDanger(false)

	-- O resultado aparece no painel de pós-partida (ResultsController), no
	-- centro da tela; nenhum anúncio central pode ficar por cima dele.
	lastAnnouncementKey = ""
	NotificationManager.clear("Center")
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

	NotificationManager.init(playerGuiInstance)
	view = HudView.new(playerGuiInstance, MatchQueueController.join, MatchQueueController.leave)

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
		cached.finalChaos = readBooleanAttribute(containerInstance, StateAttributeNames.FinalChaos)
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
		cached.hasSecondChance = readBooleanAttribute(localPlayer, StateAttributeNames.PlayerHasSecondChance)
		cached.inMatchQueue = readBooleanAttribute(localPlayer, StateAttributeNames.PlayerInMatchQueue)
		cached.queuePlace = readStringAttribute(localPlayer, StateAttributeNames.PlayerQueuePlace)
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
		StateAttributeNames.FinalChaos,
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
		StateAttributeNames.PlayerHasSecondChance,
		StateAttributeNames.PlayerInMatchQueue,
		StateAttributeNames.PlayerQueuePlace,
	}
	for _, attributeName in ipairs(playerAttributeNames) do
		connectAttribute(localPlayer, attributeName, function()
			refreshFromPlayer()
			render()
		end)
	end
end

return table.freeze(HudController)
