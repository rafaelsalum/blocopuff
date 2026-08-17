--!strict

-- Unifica clique, toque, botão dedicado e gatilho em um disparo central.
-- O cliente envia apenas o ponto visado; o servidor recalcula a direção a
-- partir da origem autoritativa e continua decidindo alcance e impacto.

local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local CombatCameraController = require(script.Parent.CombatCameraController)
local CrosshairView = require(script.Parent.Parent.ui.CrosshairView)
local FireButtonView = require(script.Parent.Parent.ui.FireButtonView)

type CrosshairViewHandle = CrosshairView.CrosshairViewHandle
type FireButtonViewHandle = FireButtonView.FireButtonViewHandle

local STATE_WAIT_TIMEOUT = 10
local MUZZLE_FLASH_LIFETIME = 0.12

local PuffadorController = {}

local started = false
local requestPuffRemote: RemoteEvent? = nil
local feedbackRemote: RemoteEvent? = nil
local connectedTools: { [Tool]: boolean } = {}
local lastLocalFireClock = 0
local equippedTool: Tool? = nil
local crosshair: CrosshairViewHandle? = nil
local fireButton: FireButtonViewHandle? = nil
local backpackWasEnabled: boolean? = nil
local targetingConnection: RBXScriptConnection? = nil

local function setCombatBackpackHidden(hidden: boolean)
	if hidden then
		if backpackWasEnabled == nil then
			local readOk, wasEnabled = pcall(function(): boolean
				return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
			end)
			if readOk then
				backpackWasEnabled = wasEnabled
			end
		end

		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		return
	end

	local restoreEnabled = if backpackWasEnabled ~= nil then backpackWasEnabled else true
	backpackWasEnabled = nil
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, restoreEnabled)
	end)
end

local function isFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteVector3(vector: Vector3): boolean
	return isFiniteNumber(vector.X) and isFiniteNumber(vector.Y) and isFiniteNumber(vector.Z)
end

local function getAimResult(): (RaycastResult?, Vector3?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil, nil
	end

	local screenPoint = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local cameraRay = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	if cameraRay.Direction.Magnitude < 1e-4 then
		return nil, nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local localPlayer = Players.LocalPlayer
	local character = if localPlayer ~= nil then localPlayer.Character else nil
	local filterInstances: { Instance } = {}
	if character ~= nil then
		table.insert(filterInstances, character)
	end
	raycastParams.FilterDescendantsInstances = filterInstances
	raycastParams.IgnoreWater = true

	local direction = cameraRay.Direction.Unit * GameConfig.Puffador.MaximumRange
	local result = Workspace:Raycast(cameraRay.Origin, direction, raycastParams)
	local target = if result ~= nil then result.Position else cameraRay.Origin + direction
	if not isFiniteVector3(target) then
		return result, nil
	end

	return result, target
end

local function getAimTarget(): Vector3?
	local _, target = getAimResult()
	return target
end

local function isActiveArenaTarget(result: RaycastResult?): boolean
	if result == nil then
		return false
	end

	local instance = result.Instance
	return CollectionService:HasTag(instance, ArenaConstants.BlockTag)
		and instance:GetAttribute(ArenaConstants.IsDestroyedAttribute) ~= true
end

local function stopTargetingFeedback()
	if targetingConnection ~= nil then
		targetingConnection:Disconnect()
		targetingConnection = nil
	end

	if crosshair ~= nil then
		crosshair.setTargeting(false)
	end
end

local function startTargetingFeedback()
	stopTargetingFeedback()
	targetingConnection = RunService.RenderStepped:Connect(function()
		local result = getAimResult()
		if crosshair ~= nil then
			crosshair.setTargeting(isActiveArenaTarget(result))
		end
	end)
end

local function findToolSound(tool: Tool, soundName: string): Sound?
	local handle = tool:FindFirstChild(PuffadorConstants.HandleName)
	if handle == nil then
		return nil
	end

	local sound = handle:FindFirstChild(soundName)
	if sound ~= nil and sound:IsA("Sound") then
		return sound
	end

	return nil
end

local function playToolSound(tool: Tool, soundName: string)
	local sound = findToolSound(tool, soundName)
	if sound == nil then
		return
	end

	sound.TimePosition = 0
	sound:Play()
end

local function playMuzzleFlash(tool: Tool)
	local handle = tool:FindFirstChild(PuffadorConstants.HandleName)
	if handle == nil or not handle:IsA("BasePart") then
		return
	end

	local muzzle = handle:FindFirstChild(PuffadorConstants.MuzzleAttachmentName)
	if muzzle == nil or not muzzle:IsA("Attachment") then
		return
	end

	local flash = Instance.new("Part")
	flash.Name = "LocalPuffFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1.25, 1.25, 1.25)
	flash.Position = muzzle.WorldPosition
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 232, 116)
	flash.Transparency = 0.05
	flash.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Color = flash.Color
	light.Brightness = 2
	light.Range = 9
	light.Parent = flash

	TweenService:Create(flash, TweenInfo.new(MUZZLE_FLASH_LIFETIME, Enum.EasingStyle.Quad), {
		Size = Vector3.new(2.4, 2.4, 2.4),
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(MUZZLE_FLASH_LIFETIME), { Brightness = 0 }):Play()
	Debris:AddItem(flash, MUZZLE_FLASH_LIFETIME)
end

local function playLocalShotFeedback(tool: Tool)
	CombatCameraController.addRecoil()
	playMuzzleFlash(tool)
	playToolSound(tool, PuffadorConstants.ShotSoundName)

	if crosshair ~= nil then
		crosshair.playShot()
	end
	if fireButton ~= nil and UserInputService.TouchEnabled then
		fireButton.startCooldown(GameConfig.Puffador.FireCooldown)
	end
end

local function onToolActivated()
	local remote = requestPuffRemote
	local tool = equippedTool
	if remote == nil or tool == nil then
		return
	end

	local now = os.clock()
	if now - lastLocalFireClock < GameConfig.Puffador.FireCooldown then
		return
	end

	local aimTarget = getAimTarget()
	if aimTarget == nil then
		return
	end

	lastLocalFireClock = now
	playLocalShotFeedback(tool)
	remote:FireServer(aimTarget)
end

local function setToolEquipped(tool: Tool)
	equippedTool = tool
	lastLocalFireClock = 0
	setCombatBackpackHidden(true)
	CombatCameraController.enable()

	if crosshair ~= nil then
		crosshair.setCenteredOnScreen()
		crosshair.setVisible(true)
	end
	startTargetingFeedback()
	if fireButton ~= nil then
		fireButton.setVisible(UserInputService.TouchEnabled)
	end
end

local function clearToolEquipped(tool: Tool)
	if equippedTool ~= tool then
		return
	end

	equippedTool = nil
	stopTargetingFeedback()
	setCombatBackpackHidden(false)
	CombatCameraController.disable()
	if crosshair ~= nil then
		crosshair.setVisible(false)
	end
	if fireButton ~= nil then
		fireButton.setVisible(false)
	end
end

local function tryConnectTool(instance: Instance)
	if not instance:IsA("Tool") or instance.Name ~= PuffadorConstants.ToolName or connectedTools[instance] then
		return
	end

	local tool = instance
	connectedTools[tool] = true
	tool.Activated:Connect(onToolActivated)
	tool.Equipped:Connect(function()
		setToolEquipped(tool)
	end)
	tool.Unequipped:Connect(function()
		clearToolEquipped(tool)
	end)
	tool.Destroying:Connect(function()
		connectedTools[tool] = nil
		clearToolEquipped(tool)
	end)

	local localPlayer = Players.LocalPlayer
	if localPlayer ~= nil and localPlayer.Character ~= nil and tool.Parent == localPlayer.Character then
		setToolEquipped(tool)
	end
end

local function scanExistingChildren(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		tryConnectTool(child)
	end
end

local function connectRemotes(): boolean
	local remotesInstance = ReplicatedStorage:FindFirstChild(PuffadorConstants.RemotesContainerName)
	if remotesInstance == nil then
		remotesInstance = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, STATE_WAIT_TIMEOUT)
	end
	if remotesInstance == nil then
		return false
	end

	local requestInstance = remotesInstance:WaitForChild(PuffadorConstants.RequestPuffRemoteName, STATE_WAIT_TIMEOUT)
	local feedbackInstance = remotesInstance:WaitForChild(PuffadorConstants.PuffFeedbackRemoteName, STATE_WAIT_TIMEOUT)
	if requestInstance == nil or not requestInstance:IsA("RemoteEvent") then
		return false
	end
	if feedbackInstance == nil or not feedbackInstance:IsA("RemoteEvent") then
		return false
	end

	requestPuffRemote = requestInstance
	feedbackRemote = feedbackInstance
	feedbackInstance.OnClientEvent:Connect(function(feedbackType: unknown)
		if feedbackType ~= "Hit" then
			return
		end

		if crosshair ~= nil then
			crosshair.playHit()
		end
		local tool = equippedTool
		if tool ~= nil then
			playToolSound(tool, PuffadorConstants.HitSoundName)
		end
	end)

	return true
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

	local playerGuiInstance = localPlayer:WaitForChild("PlayerGui", STATE_WAIT_TIMEOUT)
	if playerGuiInstance ~= nil and playerGuiInstance:IsA("PlayerGui") then
		crosshair = CrosshairView.new(playerGuiInstance)
		fireButton = FireButtonView.new(playerGuiInstance, onToolActivated)
	else
		warn("[BlocoPuff] Puffador UI not started: PlayerGui unavailable")
	end

	if not connectRemotes() then
		warn("[BlocoPuff] Puffador controller not started: remotes unavailable")
		return
	end

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
		stopTargetingFeedback()
		setCombatBackpackHidden(false)
		CombatCameraController.disable()
		equippedTool = nil
		scanExistingChildren(character)
		character.ChildAdded:Connect(tryConnectTool)
	end)
end

return table.freeze(PuffadorController)
