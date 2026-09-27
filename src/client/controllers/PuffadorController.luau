--!strict

-- Unifica clique, toque, botão dedicado e gatilho em um disparo central.
-- O cliente envia o ponto sob a mira e a origem do raio da câmera; o
-- servidor valida essa origem e continua decidindo alcance e impacto.

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
local ControlHintView = require(script.Parent.Parent.ui.ControlHintView)
local FireButtonView = require(script.Parent.Parent.ui.FireButtonView)
local FeedbackView = require(script.Parent.Parent.ui.FeedbackView)

type CrosshairViewHandle = CrosshairView.CrosshairViewHandle
type ControlHintViewHandle = ControlHintView.ControlHintViewHandle
type FireButtonViewHandle = FireButtonView.FireButtonViewHandle
type FeedbackViewHandle = FeedbackView.FeedbackViewHandle

local STATE_WAIT_TIMEOUT = 10
local MUZZLE_FLASH_LIFETIME = 0.12
-- Marcos de blocos derrubados na rodada que merecem uma notificação.
local SCORE_MILESTONES: { [number]: string } = {
	[10] = "10 blocos derrubados! 🔥",
	[25] = "25 blocos! Você está dominando a arena",
	[50] = "50 blocos! Demolidor oficial 🏆",
}

local PuffadorController = {}

local started = false
local requestPuffRemote: RemoteEvent? = nil
local feedbackRemote: RemoteEvent? = nil
local connectedTools: { [Tool]: boolean } = {}
local lastLocalFireClock = 0
local equippedTool: Tool? = nil
local crosshair: CrosshairViewHandle? = nil
local fireButton: FireButtonViewHandle? = nil
local controlHint: ControlHintViewHandle? = nil
local feedback: FeedbackViewHandle? = nil
-- Acertos com a ferramenta atual; cada rodada entrega uma ferramenta nova.
local equipHits = 0
local scoredTool: Tool? = nil
local backpackWasEnabled: boolean? = nil
local targetingConnection: RBXScriptConnection? = nil
local hasShownControlHint = false
-- Disparo contínuo enquanto o botão (toque, mouse ou gatilho) está segurado.
local holdingFire = false
local holdSequence = 0
local HOLD_POLL = 0.05

local function getControlHintText(): string
	local inputName = UserInputService:GetLastInputType().Name
	if
		string.find(inputName, "Gamepad") ~= nil
		or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled)
	then
		return "SEGURE O GATILHO DIREITO (R2) PARA ATIRAR"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "SEGURE O BOTÃO PUFF PARA ATIRAR"
	end
	return "SEGURE O CLIQUE PARA ATIRAR"
end

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

local function getAimResult(): (RaycastResult?, Vector3?, Vector3?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil, nil, nil
	end

	local screenPoint = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local cameraRay = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	if cameraRay.Direction.Magnitude < 1e-4 then
		return nil, nil, nil
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
	if not isFiniteVector3(target) or not isFiniteVector3(cameraRay.Origin) then
		return result, nil, nil
	end

	return result, target, cameraRay.Origin
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

	local _, aimTarget, aimOrigin = getAimResult()
	if aimTarget == nil or aimOrigin == nil then
		return
	end

	lastLocalFireClock = now
	if controlHint ~= nil then
		controlHint.hide()
	end
	playLocalShotFeedback(tool)
	remote:FireServer(aimTarget, aimOrigin)
end

local function stopFiring()
	holdingFire = false
	holdSequence += 1
end

-- Enquanto segurado, tenta disparar; a cadência (FireCooldown) continua
-- sendo aplicada por onToolActivated e revalidada no servidor.
local function startFiring()
	if holdingFire then
		return
	end
	holdingFire = true
	holdSequence += 1
	local sequence = holdSequence
	task.spawn(function()
		while holdingFire and holdSequence == sequence and equippedTool ~= nil do
			onToolActivated()
			task.wait(HOLD_POLL)
		end
	end)
end

-- No toque, a Tool dispara em qualquer toque na tela, inclusive ao girar a
-- câmera. Lá o disparo vem só do botão PUFF.
local function isTouchInput(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

local function setToolEquipped(tool: Tool)
	equippedTool = tool
	lastLocalFireClock = 0
	if scoredTool ~= tool then
		scoredTool = tool
		equipHits = 0
	end
	setCombatBackpackHidden(true)
	CombatCameraController.enable()

	if crosshair ~= nil then
		crosshair.setCenteredOnScreen()
		crosshair.setVisible(true)
	end
	startTargetingFeedback()
	if controlHint ~= nil and not hasShownControlHint then
		hasShownControlHint = true
		controlHint.show(getControlHintText(), 7)
	end
	if fireButton ~= nil then
		fireButton.setVisible(UserInputService.TouchEnabled)
	end
end

local function clearToolEquipped(tool: Tool)
	if equippedTool ~= tool then
		return
	end

	equippedTool = nil
	stopFiring()
	stopTargetingFeedback()
	if feedback ~= nil then
		feedback.resetCombo()
	end
	if controlHint ~= nil then
		controlHint.hide()
	end
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
	tool.Activated:Connect(function()
		if not isTouchInput() then
			startFiring()
		end
	end)
	tool.Deactivated:Connect(stopFiring)
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
		if feedbackType == "PlayerHit" then
			-- Acertou outro jogador: marcador rosa na mira e som, sem somar bloco.
			if crosshair ~= nil then
				crosshair.playPlayerHit()
			end
			local hitTool = equippedTool
			if hitTool ~= nil then
				playToolSound(hitTool, PuffadorConstants.HitSoundName)
			end
			return
		end
		if feedbackType ~= "Hit" then
			return
		end

		if crosshair ~= nil then
			crosshair.playHit()
		end
		if feedback ~= nil then
			feedback.playBlockHit()
			equipHits += 1
			local milestone = SCORE_MILESTONES[equipHits]
			if milestone ~= nil then
				feedback.showToast(milestone, "Success")
			end
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
		fireButton = FireButtonView.new(playerGuiInstance, startFiring, stopFiring)
		controlHint = ControlHintView.new(playerGuiInstance)
		feedback = FeedbackView.new(playerGuiInstance)
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
		stopFiring()
		if controlHint ~= nil then
			controlHint.hide()
		end
		setCombatBackpackHidden(false)
		CombatCameraController.disable()
		equippedTool = nil
		scanExistingChildren(character)
		character.ChildAdded:Connect(tryConnectTool)
	end)
end

return table.freeze(PuffadorController)
