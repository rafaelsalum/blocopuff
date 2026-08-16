--!strict

-- Detecta o Puffador local e dispara RequestPuff com a direção de mira.
-- Não decide se o disparo é válido, não aplica efeitos e não calcula
-- origem: apenas envia a direção desejada para o servidor validar.
--
-- Disparo por dois caminhos que convergem na mesma função: Tool.Activated
-- (clique no mundo, toque no mundo ou gatilho de gamepad, já unificados pelo
-- Roblox) e o botão de disparo dedicado (FireButtonView), útil sobretudo em
-- toque, onde tocar o mundo também arrasta a câmera. A mira (CrosshairView)
-- acompanha o mesmo ponto de tela usado no cálculo da direção: a posição do
-- mouse quando há mouse, ou o centro da tela em toque/gamepad.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local CrosshairView = require(script.Parent.Parent.ui.CrosshairView)
local FireButtonView = require(script.Parent.Parent.ui.FireButtonView)

type CrosshairViewHandle = CrosshairView.CrosshairViewHandle
type FireButtonViewHandle = FireButtonView.FireButtonViewHandle

local STATE_WAIT_TIMEOUT = 10
local LOCAL_COOLDOWN_SLACK = 0.02

local PuffadorController = {}

local started = false
local requestPuffRemote: RemoteEvent? = nil
local connectedTools: { [Tool]: boolean } = {}
local lastLocalFireClock = 0
local crosshair: CrosshairViewHandle? = nil
local fireButton: FireButtonViewHandle? = nil
local crosshairRenderConnection: RBXScriptConnection? = nil

local function isFiniteVector3(vector: Vector3): boolean
	return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z
end

local function getAimScreenPoint(camera: Camera): Vector2
	if UserInputService.MouseEnabled then
		return UserInputService:GetMouseLocation()
	end

	-- Sem mouse (toque ou gamepad puro): mira pelo centro da tela, que segue
	-- a direção da câmera.
	return Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

local function computeAimDirection(): Vector3?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end

	local screenPoint = getAimScreenPoint(camera)
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	if ray.Direction.Magnitude < 1e-4 then
		return nil
	end

	local direction = ray.Direction.Unit
	if not isFiniteVector3(direction) then
		return nil
	end

	return direction
end

local function updateCrosshairPosition()
	local currentCrosshair = crosshair
	if currentCrosshair == nil then
		return
	end

	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	local screenPoint = getAimScreenPoint(camera)
	currentCrosshair.setPosition(screenPoint.X, screenPoint.Y)
end

local function startCrosshairTracking()
	if crosshairRenderConnection ~= nil then
		return
	end

	if not UserInputService.MouseEnabled then
		-- Toque/gamepad: a mira já é sempre pelo centro da câmera, então não
		-- há necessidade de recalcular a posição quadro a quadro.
		if crosshair ~= nil then
			crosshair.setCenteredOnScreen()
		end
		return
	end

	updateCrosshairPosition()
	crosshairRenderConnection = RunService.RenderStepped:Connect(updateCrosshairPosition)
end

local function stopCrosshairTracking()
	if crosshairRenderConnection ~= nil then
		crosshairRenderConnection:Disconnect()
		crosshairRenderConnection = nil
	end
end

local function onToolActivated()
	local remote = requestPuffRemote
	if remote == nil then
		return
	end

	-- Limite local apenas para sensação de resposta; o servidor aplica o
	-- rate limit real e nunca confia neste valor.
	local now = os.clock()
	if now - lastLocalFireClock < GameConfig.Puffador.FireCooldown - LOCAL_COOLDOWN_SLACK then
		return
	end

	local direction = computeAimDirection()
	if direction == nil then
		return
	end

	lastLocalFireClock = now
	remote:FireServer(direction)
end

local function tryConnectTool(instance: Instance)
	if not instance:IsA("Tool") then
		return
	end
	if instance.Name ~= PuffadorConstants.ToolName then
		return
	end
	if connectedTools[instance] then
		return
	end

	connectedTools[instance] = true
	instance.Activated:Connect(onToolActivated)
	instance.Equipped:Connect(function()
		if crosshair ~= nil then
			crosshair.setVisible(true)
		end
		if fireButton ~= nil then
			fireButton.setVisible(true)
		end
		startCrosshairTracking()
	end)
	instance.Unequipped:Connect(function()
		stopCrosshairTracking()
		if crosshair ~= nil then
			crosshair.setVisible(false)
		end
		if fireButton ~= nil then
			fireButton.setVisible(false)
		end
	end)
end

local function scanExistingChildren(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		tryConnectTool(child)
	end
end

function PuffadorController.start()
	if started then
		return
	end
	started = true

	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		warn("[BlocoPuff] Puffador controller not started: LocalPlayer unavailable")
		return
	end

	-- Mira e botão de disparo são só reforços de interface; se o PlayerGui
	-- não estiver disponível por algum motivo, o disparo continua
	-- funcionando normalmente via Tool.Activated sem eles.
	local playerGuiInstance = localPlayer:WaitForChild("PlayerGui", STATE_WAIT_TIMEOUT)
	if playerGuiInstance ~= nil and playerGuiInstance:IsA("PlayerGui") then
		crosshair = CrosshairView.new(playerGuiInstance)
		fireButton = FireButtonView.new(playerGuiInstance, onToolActivated)
	else
		warn("[BlocoPuff] Puffador crosshair/fire button not started: PlayerGui unavailable")
	end

	local remotesInstance = ReplicatedStorage:FindFirstChild(PuffadorConstants.RemotesContainerName)
	if remotesInstance == nil then
		remotesInstance = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, STATE_WAIT_TIMEOUT)
	end
	if remotesInstance == nil then
		warn("[BlocoPuff] Puffador controller not started: remotes container not found within timeout")
		return
	end

	local remoteInstance = remotesInstance:WaitForChild(PuffadorConstants.RequestPuffRemoteName, STATE_WAIT_TIMEOUT)
	if remoteInstance == nil or not remoteInstance:IsA("RemoteEvent") then
		warn("[BlocoPuff] Puffador controller not started: RequestPuff remote not found")
		return
	end
	requestPuffRemote = remoteInstance

	local backpack = localPlayer:WaitForChild("Backpack", STATE_WAIT_TIMEOUT)
	if backpack ~= nil then
		scanExistingChildren(backpack)
		backpack.ChildAdded:Connect(tryConnectTool)
	end

	local existingCharacter = localPlayer.Character
	if existingCharacter ~= nil then
		scanExistingChildren(existingCharacter)
		existingCharacter.ChildAdded:Connect(tryConnectTool)
	end

	localPlayer.CharacterAdded:Connect(function(character)
		scanExistingChildren(character)
		character.ChildAdded:Connect(tryConnectTool)
	end)
end

return table.freeze(PuffadorController)
