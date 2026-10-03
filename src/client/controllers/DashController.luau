--!strict

-- Impulso do próprio personagem: tecla F (o E é dos prompts de interação), botão B do controle ou o botão
-- ao lado do pulo no celular. O personagem é simulado por este cliente,
-- então a arrancada acontece aqui na hora (sem esperar a rede); o servidor
-- é avisado para conferir o intervalo e mostrar o efeito aos outros.
-- Regras em DashRules, valores em DashConfig.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DashConfig = require(ReplicatedStorage.Shared.config.DashConfig)
local DashRules = require(ReplicatedStorage.Shared.modules.DashRules)
local CharacterImpulse = require(ReplicatedStorage.Shared.modules.CharacterImpulse)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local DashButtonView = require(script.Parent.Parent.ui.DashButtonView)
local DashFx = require(script.Parent.Parent.effects.DashFx)

type DashButtonViewHandle = DashButtonView.DashButtonViewHandle

local ACTION_NAME = "BlocoPuffDash"
local WAIT_TIMEOUT = 15
local MIN_MOVE = 0.1

local DashController = {}

local started = false
local state = DashRules.new()
local remote: RemoteEvent? = nil
local button: DashButtonViewHandle? = nil
local floorConnection: RBXScriptConnection? = nil

local function aliveCharacter(): (Model?, BasePart?, Humanoid?)
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	if character == nil then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, root, humanoid
end

-- Para onde arrancar: para onde está andando; parado, para a frente.
local function dashDirection(root: BasePart, humanoid: Humanoid): Vector3
	local moving = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	if moving.Magnitude > MIN_MOVE then
		return moving.Unit
	end
	local look = root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z)
end

function DashController.dash()
	local character, root, humanoid = aliveCharacter()
	if character == nil or root == nil or humanoid == nil then
		return
	end
	if CharacterImpulse.isBeingPushed(root) or humanoid.Sit then
		return
	end
	local now = os.clock()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if grounded then
		state = DashRules.landed(state)
	end
	if not DashRules.canDash(state, now, grounded, DashConfig) then
		return
	end
	CharacterImpulse.dash(root, dashDirection(root, humanoid), DashConfig.Speed, DashConfig.Duration)
	state = DashRules.afterDash(state, now, grounded, DashConfig)
	DashFx.play(character)
	local currentButton = button
	if currentButton ~= nil then
		currentButton.startCooldown(DashConfig.Cooldown)
	end
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireServer()
	end
end

-- Tocar o chão devolve o impulso no ar.
local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", WAIT_TIMEOUT)
	-- Respawn rápido: só o personagem atual fica sendo observado.
	local player = Players.LocalPlayer
	if humanoid == nil or not humanoid:IsA("Humanoid") or player == nil or player.Character ~= character then
		return
	end
	if floorConnection ~= nil then
		floorConnection:Disconnect()
	end
	state = DashRules.landed(state)
	floorConnection = humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			state = DashRules.landed(state)
		end
	end)
end

function DashController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	DashFx.start()

	ContextActionService:BindAction(ACTION_NAME, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			DashController.dash()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonB)

	if UserInputService.TouchEnabled then
		local playerGui = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
		if playerGui ~= nil and playerGui:IsA("PlayerGui") then
			button = DashButtonView.new(playerGui, DashController.dash)
		end
	end

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character ~= nil then
		task.spawn(watchCharacter, player.Character)
	end

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.DashRemoteName, WAIT_TIMEOUT) else nil
		if instance ~= nil and instance:IsA("RemoteEvent") then
			remote = instance
		else
			warn("[BlocoPuff] Dash remote not found: dashes are not shown to others")
		end
	end)
end

return table.freeze(DashController)
