--!strict

-- Efeito do impulso (só no cliente): uma lufada de fumaça branca saindo
-- de trás de quem arrancou e um "fru" curto. O próprio jogador vê na hora;
-- os outros (jogadores e bots RoboPuff) quando o servidor aceita o impulso
-- (atributo LastDashAt).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local TrapFxUtil = require(script.Parent.TrapFxUtil)

local PUFF_COUNT = 14
local LIFETIME = 0.6
local SOUND_ID = "rbxassetid://127183292018512"

local DashFx = {}

local started = false

function DashFx.play(character: Model?)
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "BlocoPuffDashFx"
	attachment.Position = Vector3.new(0, -1.5, 0.8)
	attachment.Parent = root

	local puff = TrapFxUtil.newEmitter(attachment, TrapFxUtil.SmokeTexture, Color3.new(1, 1, 1))
	puff.LightEmission = 0.1
	puff.Lifetime = NumberRange.new(0.3, LIFETIME)
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 2.2),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Speed = NumberRange.new(4, 9)
	puff.SpreadAngle = Vector2.new(35, 35)
	puff.EmissionDirection = Enum.NormalId.Back
	puff:Emit(PUFF_COUNT)

	local sound = TrapFxUtil.newSound(root, SOUND_ID, 1, 0.5)
	sound:Play()
	Debris:AddItem(attachment, LIFETIME + 0.2)
	Debris:AddItem(sound, 1)
end

-- Outro jogador ou bot: efeito quando o servidor marca o impulso.
local function watch(holder: Instance, getCharacter: () -> Model?)
	holder:GetAttributeChangedSignal(StateAttributeNames.LastDashAt):Connect(function()
		DashFx.play(getCharacter())
	end)
end

local function watchPlayer(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	watch(player, function()
		return player.Character
	end)
end

local function watchBot(instance: Instance)
	if instance:IsA("Model") then
		local model = instance
		watch(model, function()
			return model
		end)
	end
end

function DashFx.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	CollectionService:GetInstanceAddedSignal(StateAttributeNames.BotTag):Connect(watchBot)
	for _, instance in ipairs(CollectionService:GetTagged(StateAttributeNames.BotTag)) do
		watchBot(instance)
	end
end

return table.freeze(DashFx)
