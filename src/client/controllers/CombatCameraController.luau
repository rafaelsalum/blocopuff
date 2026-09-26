--!strict

-- Ativa uma câmera de combate sobre o ombro enquanto o Puffador está
-- equipado. A mira permanece centralizada, o zoom fica fixo como em jogos de
-- tiro em terceira pessoa e o personagem acompanha a direção horizontal da
-- câmera. O deslocamento de ombro encolhe perto de paredes: sem isso o foco
-- da câmera atravessaria a parede e revelaria o lado de fora do prédio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

local RENDER_STEP_NAME = "BlocoPuffCombatCamera"
-- Roda antes do módulo de câmera padrão, que usa CameraOffset e o Popper
-- (oclusão) no mesmo quadro.
local CAMERA_RENDER_PRIORITY = Enum.RenderPriority.Camera.Value - 1
local HEAD_HEIGHT = 1.5
-- Folga mantida entre o foco da câmera e qualquer superfície sólida.
local WALL_CLEARANCE = 1

local CombatCameraController = {}

local enabled = false
local recoilDistance = 0
local previousMouseBehavior = Enum.MouseBehavior.Default
local previousMouseIconEnabled = true
local previousCameraOffset = Vector3.zero
local previousAutoRotate = true
local previousMinZoom: number? = nil
local previousMaxZoom: number? = nil
local shoulderParams = RaycastParams.new()
shoulderParams.FilterType = Enum.RaycastFilterType.Exclude
shoulderParams.IgnoreWater = true

local function getCharacterParts(): (Humanoid?, BasePart?)
	local localPlayer = Players.LocalPlayer
	local character = if localPlayer ~= nil then localPlayer.Character else nil
	if character == nil then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return humanoid, nil
	end

	return humanoid, rootPart
end

local function updateCharacterFacing(rootPart: BasePart, camera: Camera)
	local lookVector = camera.CFrame.LookVector
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude < 1e-4 then
		return
	end

	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook.Unit)
end

-- Encolhe o deslocamento lateral/vertical quando há uma superfície sólida
-- entre a cabeça e o ponto de foco desejado.
local function getSafeShoulderOffset(rootPart: BasePart, character: Model, desired: Vector3): Vector3
	local worldOffset = rootPart.CFrame:VectorToWorldSpace(desired)
	local distance = worldOffset.Magnitude
	if distance < 1e-3 then
		return desired
	end

	shoulderParams.FilterDescendantsInstances = { character }
	local headPosition = rootPart.Position + Vector3.new(0, HEAD_HEIGHT, 0)
	local probe = worldOffset.Unit * (distance + WALL_CLEARANCE)
	local hit = Workspace:Raycast(headPosition, probe, shoulderParams)
	if hit == nil then
		return desired
	end

	local allowed = math.max(0, (hit.Position - headPosition).Magnitude - WALL_CLEARANCE)
	return desired * math.clamp(allowed / distance, 0, 1)
end

local function lockZoom(player: Player)
	previousMinZoom = player.CameraMinZoomDistance
	previousMaxZoom = player.CameraMaxZoomDistance
	local zoom = GameConfig.Puffador.CombatCameraZoom
	-- Ordem que nunca deixa Min acima de Max durante a troca.
	player.CameraMinZoomDistance = math.min(player.CameraMinZoomDistance, zoom)
	player.CameraMaxZoomDistance = zoom
	player.CameraMinZoomDistance = zoom
end

local function restoreZoom(player: Player)
	local minZoom = previousMinZoom
	local maxZoom = previousMaxZoom
	previousMinZoom = nil
	previousMaxZoom = nil
	if minZoom == nil or maxZoom == nil then
		return
	end
	player.CameraMaxZoomDistance = math.max(maxZoom, player.CameraMaxZoomDistance)
	player.CameraMinZoomDistance = minZoom
	player.CameraMaxZoomDistance = maxZoom
end

local function onRenderStep(deltaTime: number)
	if not enabled then
		return
	end

	local camera = Workspace.CurrentCamera
	local humanoid, rootPart = getCharacterParts()
	if camera == nil or humanoid == nil or rootPart == nil or humanoid.Health <= 0 then
		return
	end

	updateCharacterFacing(rootPart, camera)
	local character = rootPart.Parent
	local desiredOffset = GameConfig.Puffador.CameraShoulderOffset
	if character ~= nil and character:IsA("Model") then
		desiredOffset = getSafeShoulderOffset(rootPart, character, desiredOffset)
	end
	humanoid.CameraOffset = desiredOffset + Vector3.new(0, 0, recoilDistance)

	if recoilDistance > 0.001 then
		recoilDistance *= math.exp(-GameConfig.Puffador.CameraRecoilRecovery * deltaTime)
	else
		recoilDistance = 0
	end
end

function CombatCameraController.enable()
	if enabled then
		return
	end

	enabled = true
	previousMouseBehavior = UserInputService.MouseBehavior
	previousMouseIconEnabled = UserInputService.MouseIconEnabled

	local humanoid = getCharacterParts()
	if humanoid ~= nil then
		previousCameraOffset = humanoid.CameraOffset
		previousAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
		humanoid.CameraOffset = GameConfig.Puffador.CameraShoulderOffset
	end

	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end

	local localPlayer = Players.LocalPlayer
	if localPlayer ~= nil then
		lockZoom(localPlayer)
	end

	RunService:BindToRenderStep(RENDER_STEP_NAME, CAMERA_RENDER_PRIORITY, onRenderStep)
end

function CombatCameraController.disable()
	if not enabled then
		return
	end

	enabled = false
	recoilDistance = 0
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)

	local humanoid = getCharacterParts()
	if humanoid ~= nil then
		humanoid.CameraOffset = previousCameraOffset
		humanoid.AutoRotate = previousAutoRotate
	end

	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = previousMouseBehavior
		UserInputService.MouseIconEnabled = previousMouseIconEnabled
	end

	local localPlayer = Players.LocalPlayer
	if localPlayer ~= nil then
		restoreZoom(localPlayer)
	end
end

function CombatCameraController.addRecoil()
	if not enabled then
		return
	end

	recoilDistance = math.min(
		recoilDistance + GameConfig.Puffador.CameraRecoilDistance,
		GameConfig.Puffador.CameraRecoilDistance * 1.5
	)
end

function CombatCameraController.isEnabled(): boolean
	return enabled
end

return table.freeze(CombatCameraController)
