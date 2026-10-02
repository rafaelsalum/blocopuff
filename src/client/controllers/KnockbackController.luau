--!strict

-- Aplica ao próprio personagem os efeitos físicos decididos pelo servidor:
-- o empurrão do Puffador e a parada da queda ao usar a Segunda Chance. O
-- personagem é simulado por este cliente, então é aqui que a velocidade
-- precisa ser escrita. Valores recebidos são validados e limitados.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local CharacterImpulse = require(ReplicatedStorage.Shared.modules.CharacterImpulse)

local WAIT_TIMEOUT = 15
local MIN_SLIDE_DURATION = 0.05
local MAX_SLIDE_DURATION = 1

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

local function applyKnockback(velocity: Vector3)
	local root, humanoid = getRoot()
	if root ~= nil and humanoid ~= nil then
		CharacterImpulse.knockback(root, humanoid, velocity)
	end
end

local function applySlide(velocity: Vector3, duration: number)
	local root = getRoot()
	if root ~= nil then
		CharacterImpulse.slide(root, velocity, duration)
	end
end

-- Garante a posição do respawn caso o teleporte do servidor chegue depois.
local function stopFalling(cframe: CFrame)
	local root = getRoot()
	if root ~= nil then
		CharacterImpulse.stopFalling(root, cframe)
	end
end

local function onFeedback(kind: unknown, value: unknown)
	if kind == "Knockback" and typeof(value) == "Vector3" and isFiniteVector(value) then
		applyKnockback(value)
	elseif kind == "Slide" and typeof(value) == "table" then
		local data = value :: { [string]: unknown }
		local velocity = data.velocity
		local duration = data.duration
		if typeof(velocity) == "Vector3" and isFiniteVector(velocity) and typeof(duration) == "number" and duration == duration then
			applySlide(velocity, math.clamp(duration, MIN_SLIDE_DURATION, MAX_SLIDE_DURATION))
		end
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
