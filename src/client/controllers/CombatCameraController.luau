--!strict

-- Ativa uma câmera de combate sobre o ombro enquanto o Puffador está
-- equipado. A mira permanece centralizada e o personagem acompanha a
-- direção horizontal da câmera, reproduzindo um shift-lock consistente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

local RENDER_STEP_NAME = "BlocoPuffCombatCamera"
local CAMERA_RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1

local CombatCameraController = {}

local enabled = false
local recoilDegrees = 0
local previousMouseBehavior = Enum.MouseBehavior.Default
local previousMouseIconEnabled = true
local previousCameraOffset = Vector3.zero
local previousAutoRotate = true

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

local function onRenderStep(deltaTime: number)
	if not enabled then
		return
	end

	local camera = Workspace.CurrentCamera
	local humanoid, rootPart = getCharacterParts()
	if camera == nil or humanoid == nil or rootPart == nil or humanoid.Health <= 0 then
		return
	end

	humanoid.CameraOffset = GameConfig.Puffador.CameraShoulderOffset
	updateCharacterFacing(rootPart, camera)

	if recoilDegrees > 0.01 then
		camera.CFrame *= CFrame.Angles(-math.rad(recoilDegrees), 0, 0)
		recoilDegrees *= math.exp(-GameConfig.Puffador.CameraRecoilRecovery * deltaTime)
	else
		recoilDegrees = 0
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

	RunService:BindToRenderStep(RENDER_STEP_NAME, CAMERA_RENDER_PRIORITY, onRenderStep)
end

function CombatCameraController.disable()
	if not enabled then
		return
	end

	enabled = false
	recoilDegrees = 0
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
end

function CombatCameraController.addRecoil()
	if not enabled then
		return
	end

	recoilDegrees = math.min(
		recoilDegrees + GameConfig.Puffador.CameraRecoilDegrees,
		GameConfig.Puffador.CameraRecoilDegrees * 2
	)
end

function CombatCameraController.isEnabled(): boolean
	return enabled
end

return table.freeze(CombatCameraController)
