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
--
-- Party (4.4): o primeiro alvo é alguém da própria Party ainda na partida
-- (marcado com 👥). Trocar de alvo avisa o servidor só para telemetria.
--
-- Bots RoboPuff (5B) também podem ser assistidos: o alvo é o Player ou o
-- Model do bot (tag BotTag), que guarda os mesmos atributos da rodada.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
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
-- Player ou Model de um bot RoboPuff.
local currentTarget: Instance? = nil
local spectating = false
-- Verdadeiro enquanto a câmera segue o personagem de outro jogador. É o que
-- decide se é preciso devolver a câmera, e não currentTarget: o alvo pode
-- ser apagado antes (ex.: o servidor limpa os atributos do jogador assistido
-- no fim da rodada, ou ele sai do jogo) e a câmera ficaria presa nele.
local cameraOverridden = false

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

local function isActiveParticipant(target: Instance, roundId: number): boolean
	if readBooleanAttribute(target, ATTR_IS_PARTICIPANT) ~= true then
		return false
	end
	if readNumberAttribute(target, ATTR_PARTICIPATING_ROUND_ID) ~= roundId then
		return false
	end
	if readBooleanAttribute(target, ATTR_IS_ELIMINATED) ~= false then
		return false
	end

	return true
end

local function getHumanoid(target: Instance): Humanoid?
	local character: Instance? = if target:IsA("Player") then target.Character else target
	if character == nil or character.Parent == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return if humanoid ~= nil and humanoid.Health > 0 then humanoid else nil
end

-- Jogadores pelo UserId; bots (id negativo) depois deles.
local function sortKey(target: Instance): number
	if target:IsA("Player") then
		return target.UserId
	end
	return math.huge - readNumberAttribute(target, StateAttributeNames.BotId)
end

-- Devolve a câmera ao próprio personagem. Se ele ainda não existir (está
-- renascendo), mantém a marcação para tentar de novo no próximo quadro.
local function resetCameraToOwnCharacter()
	local player = localPlayer
	local camera = Workspace.CurrentCamera
	if player == nil or camera == nil then
		return
	end

	local ownHumanoid = getHumanoid(player)
	if ownHumanoid == nil then
		return
	end

	camera.CameraSubject = ownHumanoid
	cameraOverridden = false
end

-- Lista estável (jogadores por UserId, depois os bots) dos participantes
-- ainda ativos, usada tanto para escolher o primeiro alvo automaticamente
-- quanto para alternar manualmente entre eles em ordem previsível.
local function getActiveParticipantList(roundId: number): { Instance }
	local player = localPlayer
	local list: { Instance } = {}

	local candidates: { Instance } = Players:GetPlayers()
	for _, bot in ipairs(CollectionService:GetTagged(StateAttributeNames.BotTag)) do
		if bot:IsA("Model") then
			table.insert(candidates, bot)
		end
	end
	for _, candidate in ipairs(candidates) do
		if candidate ~= player and isActiveParticipant(candidate, roundId) and getHumanoid(candidate) ~= nil then
			table.insert(list, candidate)
		end
	end

	table.sort(list, function(a, b)
		return sortKey(a) < sortKey(b)
	end)

	return list
end

local function isPartyMate(candidate: Instance): boolean
	local player = localPlayer
	local partyId = if player ~= nil then player:GetAttribute(StateAttributeNames.PlayerPartyId) else nil
	return candidate:IsA("Player") and typeof(partyId) == "string" and candidate:GetAttribute(StateAttributeNames.PlayerPartyId) == partyId
end

local function targetLabel(target: Instance): string
	if not target:IsA("Player") then
		local humanoid = getHumanoid(target)
		return if humanoid ~= nil then humanoid.DisplayName else target.Name
	end
	return if isPartyMate(target) then `👥 {target.Name}` else target.Name
end

local function reportSpectating()
	local remotes = ReplicatedStorage:FindFirstChild(PuffadorConstants.RemotesContainerName)
	local remote = if remotes ~= nil then remotes:FindFirstChild(PuffadorConstants.ReactionRemoteName) else nil
	if remote ~= nil and remote:IsA("RemoteEvent") then
		remote:FireServer("Spectating")
	end
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
		currentTarget = nil
		if cameraOverridden then
			resetCameraToOwnCharacter()
		end
		if view ~= nil then
			view.setVisible(false)
		end
		return
	end

	local list = getActiveParticipantList(roundId)

	if currentTarget ~= nil and (not isActiveParticipant(currentTarget, roundId) or getHumanoid(currentTarget) == nil) then
		currentTarget = nil
	end

	if currentTarget == nil then
		-- Primeiro alguém da Party, se ainda estiver na partida.
		for _, candidate in ipairs(list) do
			if isPartyMate(candidate) then
				currentTarget = candidate
				break
			end
		end
		if currentTarget == nil then
			currentTarget = list[1]
		end
	end

	if view ~= nil then
		if currentTarget ~= nil then
			view.setTargetInfo(targetLabel(currentTarget), #list)
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
	reportSpectating()

	if view ~= nil and currentTarget ~= nil then
		view.setTargetInfo(targetLabel(currentTarget), #list)
	end
end

local function onRenderStep()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	-- Fora do modo espectador, garante que a câmera volte ao próprio
	-- personagem, mesmo que o alvo já tenha sido apagado.
	if not spectating then
		if cameraOverridden then
			resetCameraToOwnCharacter()
		end
		return
	end

	local target = currentTarget
	if target == nil then
		return
	end

	-- Bots não disparam os sinais de Player: a eliminação deles é notada aqui.
	local humanoid = getHumanoid(target)
	local container = stateContainer
	local stillActive = container == nil or isActiveParticipant(target, readNumberAttribute(container, ATTR_ROUND_ID))
	if humanoid == nil or not stillActive then
		refreshSpectator()
		return
	end

	camera.CameraSubject = humanoid
	cameraOverridden = true
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
