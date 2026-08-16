--!strict

-- Quando o jogador local é eliminado durante uma rodada em andamento, a
-- câmera passa a seguir automaticamente um participante ainda ativo, em vez
-- de permanecer parada no personagem já eliminado no lobby. Não altera
-- nenhum estado autoritativo nem envia RemoteEvent: apenas lê atributos já
-- replicados (do Player local e dos demais) e ajusta CameraSubject.
--
-- CameraSubject é reafirmado a cada RenderStepped enquanto espectando, pois
-- o CameraModule padrão do Roblox também reage a CharacterAdded do jogador
-- local (ao respawnar no lobby) e tentaria reassumir o próprio personagem.
--
-- Alternância manual do alvo observado: setas do teclado, D-Pad do gamepad,
-- e botões na tela (mouse/toque) via SpectatorView. Todos os caminhos levam
-- à mesma função cycleTarget, então nenhum dispositivo tem lógica especial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local SpectatorView = require(script.Parent.Parent.ui.SpectatorView)

type RoundState = RoundTypes.RoundState
type SpectatorViewHandle = SpectatorView.SpectatorViewHandle

local STATE_WAIT_TIMEOUT = 10

local ATTR_ROUND_STATE = StateAttributeNames.RoundState
local ATTR_ROUND_ID = StateAttributeNames.RoundId
local ATTR_IS_PARTICIPANT = StateAttributeNames.PlayerIsParticipant
local ATTR_PARTICIPATING_ROUND_ID = StateAttributeNames.PlayerParticipatingRoundId
local ATTR_IS_ELIMINATED = StateAttributeNames.PlayerIsEliminated

local SpectatorController = {}

local started = false
local localPlayer: Player? = nil
local stateContainer: Instance? = nil
local view: SpectatorViewHandle? = nil
local connections: { RBXScriptConnection } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local currentTarget: Player? = nil
local spectating = false

local function readRoundState(instance: Instance): RoundState
	local value = instance:GetAttribute(ATTR_ROUND_STATE)
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

local function readBooleanAttribute(instance: Instance, name: string): boolean
	local value = instance:GetAttribute(name)
	if typeof(value) == "boolean" then
		return value
	end

	return false
end

local function isActiveParticipant(player: Player, roundId: number): boolean
	if readBooleanAttribute(player, ATTR_IS_PARTICIPANT) ~= true then
		return false
	end
	if readNumberAttribute(player, ATTR_PARTICIPATING_ROUND_ID) ~= roundId then
		return false
	end
	if readBooleanAttribute(player, ATTR_IS_ELIMINATED) ~= false then
		return false
	end

	return true
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function resetCameraToOwnCharacter()
	local player = localPlayer
	if player == nil then
		return
	end

	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	camera.CameraSubject = getHumanoid(player)
end

-- Lista estável (ordenada por UserId) dos participantes ainda ativos,
-- usada tanto para escolher o primeiro alvo automaticamente quanto para
-- alternar manualmente entre eles em ordem previsível.
local function getActiveParticipantList(roundId: number): { Player }
	local player = localPlayer
	local list: { Player } = {}

	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= player and isActiveParticipant(candidate, roundId) and getHumanoid(candidate) ~= nil then
			table.insert(list, candidate)
		end
	end

	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)

	return list
end

local function refreshSpectator()
	local player = localPlayer
	local container = stateContainer
	if player == nil or container == nil then
		return
	end

	local roundState = readRoundState(container)
	local roundId = readNumberAttribute(container, ATTR_ROUND_ID)

	local roundInProgress = roundState == RoundTypes.Active or roundState == RoundTypes.Ending
	local isEliminatedParticipant = roundInProgress
		and readBooleanAttribute(player, ATTR_IS_PARTICIPANT)
		and readNumberAttribute(player, ATTR_PARTICIPATING_ROUND_ID) == roundId
		and readBooleanAttribute(player, ATTR_IS_ELIMINATED)

	spectating = isEliminatedParticipant

	if not isEliminatedParticipant then
		if currentTarget ~= nil then
			currentTarget = nil
			resetCameraToOwnCharacter()
		end
		if view ~= nil then
			view.setVisible(false)
		end
		return
	end

	if currentTarget ~= nil and (not isActiveParticipant(currentTarget, roundId) or getHumanoid(currentTarget) == nil) then
		currentTarget = nil
	end

	if currentTarget == nil then
		currentTarget = getActiveParticipantList(roundId)[1]
	end

	if view ~= nil then
		if currentTarget ~= nil then
			view.setTargetName(currentTarget.Name)
			view.setVisible(true)
		else
			view.setVisible(false)
		end
	end
end

local function cycleTarget(direction: number)
	if not spectating then
		return
	end

	local container = stateContainer
	if container == nil then
		return
	end

	local roundId = readNumberAttribute(container, ATTR_ROUND_ID)
	local list = getActiveParticipantList(roundId)
	if #list == 0 then
		return
	end

	local currentIndex: number? = nil
	for index, candidate in ipairs(list) do
		if candidate == currentTarget then
			currentIndex = index
			break
		end
	end

	local nextIndex: number
	if currentIndex == nil then
		nextIndex = 1
	else
		nextIndex = ((currentIndex - 1 + direction) % #list) + 1
	end

	currentTarget = list[nextIndex]

	if view ~= nil and currentTarget ~= nil then
		view.setTargetName(currentTarget.Name)
	end
end

local function onRenderStep()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	if currentTarget == nil then
		return
	end

	local humanoid = getHumanoid(currentTarget)
	if humanoid == nil then
		refreshSpectator()
		return
	end

	camera.CameraSubject = humanoid
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then
		cycleTarget(-1)
	elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then
		cycleTarget(1)
	end
end

local function watchPlayer(player: Player)
	local playerConns = {
		player:GetAttributeChangedSignal(ATTR_IS_ELIMINATED):Connect(refreshSpectator),
		player:GetAttributeChangedSignal(ATTR_IS_PARTICIPANT):Connect(refreshSpectator),
		player:GetAttributeChangedSignal(ATTR_PARTICIPATING_ROUND_ID):Connect(refreshSpectator),
	}
	playerConnections[player] = playerConns
end

local function unwatchPlayer(player: Player)
	local playerConns = playerConnections[player]
	if playerConns == nil then
		return
	end

	for _, connection in ipairs(playerConns) do
		connection:Disconnect()
	end
	playerConnections[player] = nil

	if currentTarget == player then
		currentTarget = nil
		refreshSpectator()
	end
end

local function connectContainerAttribute(instance: Instance, attributeName: string)
	local connection = instance:GetAttributeChangedSignal(attributeName):Connect(refreshSpectator)
	table.insert(connections, connection)
end

function SpectatorController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	if player == nil then
		warn("[BlocoPuff] Spectator controller not started: LocalPlayer unavailable")
		return
	end
	localPlayer = player

	local playerGuiInstance = player:WaitForChild("PlayerGui", STATE_WAIT_TIMEOUT)
	if playerGuiInstance == nil or not playerGuiInstance:IsA("PlayerGui") then
		warn("[BlocoPuff] Spectator controller not started: PlayerGui unavailable")
		return
	end
	local playerGui: PlayerGui = playerGuiInstance

	local containerInstance = ReplicatedStorage:FindFirstChild(StateAttributeNames.ContainerName)
	if containerInstance == nil then
		containerInstance = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, STATE_WAIT_TIMEOUT)
	end
	if containerInstance == nil then
		warn("[BlocoPuff] Spectator controller not started: BlocoPuffState not found within timeout")
		return
	end
	stateContainer = containerInstance

	view = SpectatorView.new(playerGui, function()
		cycleTarget(-1)
	end, function()
		cycleTarget(1)
	end)

	connectContainerAttribute(containerInstance, ATTR_ROUND_STATE)
	connectContainerAttribute(containerInstance, ATTR_ROUND_ID)

	for _, existingPlayer in ipairs(Players:GetPlayers()) do
		watchPlayer(existingPlayer)
	end
	table.insert(connections, Players.PlayerAdded:Connect(watchPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(unwatchPlayer))

	table.insert(
		connections,
		player.CharacterAdded:Connect(function()
			refreshSpectator()
		end)
	)

	table.insert(connections, RunService.RenderStepped:Connect(onRenderStep))
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))

	refreshSpectator()
end

return table.freeze(SpectatorController)
