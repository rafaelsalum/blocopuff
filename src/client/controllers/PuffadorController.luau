--!strict

-- Detecta o Puffador local e dispara RequestPuff com a direção de mira.
-- Não decide se o disparo é válido, não aplica efeitos e não calcula
-- origem: apenas envia a direção desejada para o servidor validar.
--
-- Entrada unificada via Tool.Activated, que o Roblox já aciona a partir de:
-- clique do mouse, botão de ativação padrão em toque, e gatilho de gamepad.
-- Por isso este controlador não precisa de botões próprios nem de lógica
-- de entrada separada por dispositivo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)

local STATE_WAIT_TIMEOUT = 10
local LOCAL_COOLDOWN_SLACK = 0.02

local PuffadorController = {}

local started = false
local requestPuffRemote: RemoteEvent? = nil
local connectedTools: { [Tool]: boolean } = {}
local lastLocalFireClock = 0

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
