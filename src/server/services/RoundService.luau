--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local RoundMessages = require(ReplicatedStorage.Shared.modules.RoundMessages)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ArenaService = require(script.Parent.ArenaService)
local LobbyService = require(script.Parent.LobbyService)
local ReplicatedState = require(script.Parent.ReplicatedStateService)
local PuffadorService = require(script.Parent.PuffadorService)

type RoundState = RoundTypes.RoundState
type RoundTimings = GameConfig.RoundTimings

type Participant = {
	player: Player,
	alive: boolean,
}

type Winner = {
	userId: number,
	name: string,
}

local POLL_INTERVAL = 1
local TICK_INTERVAL = 1

-- Atributos autoritativos escritos pelo servidor em cada Player, usados pelo
-- cliente para saber se participa da rodada atual sem inferir pela posição.
-- IsRoundParticipant: true enquanto o jogador integra a rodada em andamento.
-- ParticipatingRoundId: RoundId da rodada em que participa (0 = nenhuma).
-- IsEliminated: true se o Humanoid do participante morreu durante Active.
local ATTR_IS_PARTICIPANT = StateAttributeNames.PlayerIsParticipant
local ATTR_PARTICIPATING_ROUND_ID = StateAttributeNames.PlayerParticipatingRoundId
local ATTR_IS_ELIMINATED = StateAttributeNames.PlayerIsEliminated

local RoundService = {}

local isRunning = false
local currentState: RoundState = RoundTypes.WaitingForPlayers
local currentRoundId = 0

local participants: { [Player]: Participant } = {}
local participantOrder: { Player } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local playerRemovingConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local winner: Winner? = nil

local function countConnectedPlayers(): number
	return #Players:GetPlayers()
end

local function setState(newState: RoundState)
	if currentState == newState then
		return
	end

	currentState = newState
	ReplicatedState.setRoundState(newState)
	print(string.format("[BlocoPuff] Round state: %s", newState))
end

local function getHumanoidRootPart(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function moveCharacterTo(character: Model, cframe: CFrame): boolean
	local rootPart = getHumanoidRootPart(character)
	if rootPart == nil then
		return false
	end

	local ok = pcall(function()
		character:PivotTo(cframe)
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end)

	return ok
end

local function selectParticipants(): { Player }
	local selected: { Player } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if #selected >= GameConfig.MaximumPlayers then
			break
		end
		table.insert(selected, player)
	end

	return selected
end

local function teleportParticipantsToArena(players: { Player })
	local spawnCFrames = ArenaService.getPlayerSpawnCFrames()

	for index, player in ipairs(players) do
		local cframe = spawnCFrames[index]
		if cframe == nil then
			break
		end

		local character = player.Character
		if character == nil then
			warn(string.format("[BlocoPuff] Skipping arena teleport for %s: character not found", player.Name))
			continue
		end

		if not moveCharacterTo(character, cframe) then
			warn(string.format("[BlocoPuff] Failed to move %s into the arena", player.Name))
		end
	end
end

local function returnParticipantsToLobby(players: { Player })
	local returnCFrame = LobbyService.getReturnCFrame()
	if returnCFrame == nil then
		warn("[BlocoPuff] Lobby return position unavailable; skipping return teleport")
		return
	end

	for index, player in ipairs(players) do
		local character = player.Character
		if character == nil then
			continue
		end

		local offset = Vector3.new((((index - 1) % 5) - 2) * 4, 0, math.floor((index - 1) / 5) * 4)
		if not moveCharacterTo(character, returnCFrame + offset) then
			warn(string.format("[BlocoPuff] Failed to return %s to the lobby", player.Name))
		end
	end
end

local function resetParticipantAttributes(player: Player)
	player:SetAttribute(ATTR_IS_PARTICIPANT, false)
	player:SetAttribute(ATTR_PARTICIPATING_ROUND_ID, 0)
	player:SetAttribute(ATTR_IS_ELIMINATED, false)
end

local function markParticipantAttributes(player: Player, roundId: number)
	player:SetAttribute(ATTR_IS_PARTICIPANT, true)
	player:SetAttribute(ATTR_PARTICIPATING_ROUND_ID, roundId)
	player:SetAttribute(ATTR_IS_ELIMINATED, false)
end

local function markEliminated(player: Player)
	player:SetAttribute(ATTR_IS_ELIMINATED, true)
end

local function onPlayerAdded(player: Player)
	resetParticipantAttributes(player)
end

local function onParticipantDied(player: Player)
	local participant = participants[player]
	if participant == nil then
		return
	end

	participant.alive = false
	markEliminated(player)
	PuffadorService.revokeFrom(player)
end

local function connectParticipantDeathHandlers(players: { Player })
	for _, player in ipairs(players) do
		local character = player.Character
		if character == nil then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			continue
		end

		deathConnections[player] = humanoid.Died:Connect(function()
			onParticipantDied(player)
		end)
	end
end

local function disconnectParticipantDeathHandlers()
	for _, connection in pairs(deathConnections) do
		connection:Disconnect()
	end
	table.clear(deathConnections)
end

local function clearRoundParticipants()
	table.clear(participants)
	table.clear(participantOrder)
end

local function evaluateActiveParticipants(): (number, Participant?)
	local aliveCount = 0
	local soleActive: Participant? = nil

	for _, player in ipairs(participantOrder) do
		local participant = participants[player]
		if participant ~= nil and participant.alive then
			aliveCount += 1
			soleActive = participant
		end
	end

	if aliveCount == 1 then
		return 1, soleActive
	end

	return aliveCount, nil
end

local function onPlayerRemoving(player: Player)
	if participants[player] ~= nil then
		participants[player] = nil
		for index, participantPlayer in ipairs(participantOrder) do
			if participantPlayer == player then
				table.remove(participantOrder, index)
				break
			end
		end
	end

	local connection = deathConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		deathConnections[player] = nil
	end

	PuffadorService.revokeFrom(player)
end

local function runWaitingForPlayers()
	setState(RoundTypes.WaitingForPlayers)
	ReplicatedState.setTimeRemaining(0)
	ReplicatedState.clearWinner()
	ReplicatedState.setStatusMessage(RoundMessages.WaitingForPlayers)
	ReplicatedState.setParticipantCount(countConnectedPlayers())

	while isRunning and countConnectedPlayers() < GameConfig.MinimumPlayers do
		task.wait(POLL_INTERVAL)
		ReplicatedState.setParticipantCount(countConnectedPlayers())
	end
end

local function runCountdown(timings: RoundTimings): boolean
	setState(RoundTypes.Countdown)

	local remaining = timings.LobbyCountdown
	ReplicatedState.setTimeRemaining(remaining)
	ReplicatedState.setStatusMessage(RoundMessages.countdown(remaining))
	ReplicatedState.setParticipantCount(countConnectedPlayers())

	while isRunning and remaining > 0 do
		task.wait(TICK_INTERVAL)

		if not isRunning then
			return false
		end

		if countConnectedPlayers() < GameConfig.MinimumPlayers then
			return false
		end

		remaining -= 1
		ReplicatedState.setTimeRemaining(remaining)
		ReplicatedState.setStatusMessage(RoundMessages.countdown(remaining))
		ReplicatedState.setParticipantCount(countConnectedPlayers())
	end

	return isRunning
end

local function beginRound(timings: RoundTimings)
	currentRoundId += 1

	-- A arena precisa estar totalmente restaurada e com a destruição
	-- habilitada para a nova rodada antes que qualquer jogador chegue nela.
	ArenaService.restoreAllBlocks()
	ArenaService.beginRound(currentRoundId)

	local selected = selectParticipants()
	clearRoundParticipants()
	for _, player in ipairs(selected) do
		participants[player] = { player = player, alive = true }
		table.insert(participantOrder, player)
		markParticipantAttributes(player, currentRoundId)
	end

	teleportParticipantsToArena(participantOrder)
	connectParticipantDeathHandlers(participantOrder)
	PuffadorService.beginRound(participantOrder, currentRoundId)

	setState(RoundTypes.Active)
	ReplicatedState.setRoundId(currentRoundId)
	ReplicatedState.setParticipantCount(#participantOrder)
	ReplicatedState.setTimeRemaining(timings.RoundDuration)
	ReplicatedState.setStatusMessage(RoundMessages.Active)

	print(string.format("[BlocoPuff] Round %d started with %d participants", currentRoundId, #participantOrder))
end

local function runActive(timings: RoundTimings)
	local remaining = timings.RoundDuration

	while isRunning do
		local aliveCount, soleActive = evaluateActiveParticipants()

		if aliveCount == 0 then
			winner = nil
			break
		elseif aliveCount == 1 then
			winner = if soleActive ~= nil
				then { userId = soleActive.player.UserId, name = soleActive.player.Name }
				else nil
			break
		end

		if remaining <= 0 then
			winner = nil
			break
		end

		task.wait(TICK_INTERVAL)
		remaining -= 1
		ReplicatedState.setTimeRemaining(remaining)
	end
end

local function runEnding(timings: RoundTimings)
	setState(RoundTypes.Ending)
	ArenaService.endRound()
	PuffadorService.endRound()
	disconnectParticipantDeathHandlers()

	if winner ~= nil then
		ReplicatedState.setWinner(winner.userId, winner.name)
		ReplicatedState.setStatusMessage(RoundMessages.winner(winner.name))
		print(string.format("[BlocoPuff] Round %d ended with winner %s", currentRoundId, winner.name))
	else
		ReplicatedState.clearWinner()
		ReplicatedState.setStatusMessage(RoundMessages.EndedNoWinner)
		print(string.format("[BlocoPuff] Round %d ended without a winner", currentRoundId))
	end

	local remaining = timings.IntermissionDuration
	ReplicatedState.setTimeRemaining(remaining)

	while isRunning and remaining > 0 do
		task.wait(TICK_INTERVAL)
		remaining -= 1
		ReplicatedState.setTimeRemaining(remaining)
	end

	returnParticipantsToLobby(participantOrder)
	-- Restaura depois que os jogadores já saíram da arena, evitando que um
	-- bloco reapareça dentro de um personagem.
	ArenaService.restoreAllBlocks()
	for _, player in ipairs(participantOrder) do
		resetParticipantAttributes(player)
	end
	clearRoundParticipants()
	winner = nil
end

local function runRoundLifecycle()
	while isRunning do
		runWaitingForPlayers()
		if not isRunning then
			break
		end

		local timings = GameConfig.getRoundTimings()
		local countdownCompleted = runCountdown(timings)
		if not countdownCompleted then
			continue
		end

		beginRound(timings)
		runActive(timings)
		if not isRunning then
			break
		end
		runEnding(timings)
	end
end

function RoundService.start()
	if isRunning then
		return
	end

	isRunning = true
	playerRemovingConnection = Players.PlayerRemoving:Connect(onPlayerRemoving)
	playerAddedConnection = Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	task.spawn(runRoundLifecycle)
end

function RoundService.stop()
	isRunning = false

	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end

	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end

	disconnectParticipantDeathHandlers()
	ArenaService.endRound()
	PuffadorService.stop()
	ArenaService.restoreAllBlocks()
	for _, player in ipairs(participantOrder) do
		resetParticipantAttributes(player)
	end
	clearRoundParticipants()
	winner = nil
end

function RoundService.getState(): RoundState
	return currentState
end

function RoundService.getParticipants(): { Player }
	local copy: { Player } = {}
	for _, player in ipairs(participantOrder) do
		table.insert(copy, player)
	end

	return copy
end

return table.freeze(RoundService)
