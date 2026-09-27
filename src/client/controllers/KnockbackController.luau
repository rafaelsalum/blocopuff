--!strict

-- Aplica ao próprio personagem os efeitos físicos decididos pelo servidor:
-- o empurrão do Puffador e a parada da queda ao usar a Segunda Chance. O
-- personagem é simulado por este cliente, então é aqui que a velocidade
-- precisa ser escrita. Valores recebidos são validados e limitados.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)

local WAIT_TIMEOUT = 15
local MAX_SPEED = 200
local PUSH_NAME = "BlocoPuffKnockback"

local KnockbackController = {}

local started = false

local function isFiniteVector(vector: Vector3): boolean
	for _, value in ipairs({ vector.X, vector.Y, vector.Z }) do
		if value ~= value or value == math.huge or value == -math.huge then
			return false
		end
	end
	return true
end

local function getRoot(): (BasePart?, Humanoid?)
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

-- Um LinearVelocity curto garante o empurrão mesmo com o Humanoid no chão
-- (ele anularia uma velocidade horizontal escrita diretamente). Ao terminar,
-- o personagem segue com o impulso e cai normalmente.
local function applyKnockback(velocity: Vector3)
	local root, humanoid = getRoot()
	if root == nil or humanoid == nil then
		return
	end
	if velocity.Magnitude > MAX_SPEED then
		velocity = velocity.Unit * MAX_SPEED
	end

	local existing = root:FindFirstChild(PUSH_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = PUSH_NAME
	attachment.Parent = root

	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = attachment

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	task.delay(GameConfig.Knockback.Duration, function()
		if attachment.Parent ~= nil then
			attachment:Destroy()
		end
	end)
end

local function stopFalling(cframe: CFrame)
	local root = getRoot()
	if root == nil then
		return
	end
	local existing = root:FindFirstChild(PUSH_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	-- Garante a posição do respawn caso o teleporte do servidor chegue depois.
	if (root.Position - cframe.Position).Magnitude > 8 then
		local character = root.Parent
		if character ~= nil and character:IsA("Model") then
			character:PivotTo(cframe)
		end
	end
end

local function onFeedback(kind: unknown, value: unknown)
	if kind == "Knockback" and typeof(value) == "Vector3" and isFiniteVector(value) then
		applyKnockback(value)
	elseif kind == "Respawn" and typeof(value) == "CFrame" and isFiniteVector(value.Position) then
		stopFalling(value)
	end
end

function KnockbackController.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		if remotes == nil then
			warn("[BlocoPuff] Knockback controller: remotes not found")
			return
		end
		local feedback = remotes:WaitForChild(PuffadorConstants.PuffFeedbackRemoteName, WAIT_TIMEOUT)
		if feedback ~= nil and feedback:IsA("RemoteEvent") then
			feedback.OnClientEvent:Connect(onFeedback)
		end
	end)
end

return table.freeze(KnockbackController)
