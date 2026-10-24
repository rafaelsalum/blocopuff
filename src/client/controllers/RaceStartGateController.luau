--!strict

-- Portão mágico da largada da rampa da Torre do Relógio, no cliente. Quem
-- está no lobby passeia na ilha, mas o portão fecha a rampa (colide e
-- brilha); quem está correndo na Corrida passa direto e nem o vê. Quem já
-- está na rampa acima do portão (por exemplo, quando a Corrida acaba) nunca
-- fica preso: o portão só bloqueia quem está de fora. No servidor ele não
-- colide (os bots passam), então a colisão é só deste cliente.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local TowerAmbienceNames = require(ReplicatedStorage.Shared.modules.TowerAmbienceNames)
local TowerPathRules = require(ReplicatedStorage.Shared.modules.TowerPathRules)

local CHECK_INTERVAL = 0.25
local WAIT_TIMEOUT = 10
-- Transparência do portão fechado (o servidor monta com a mesma).
local CLOSED_TRANSPARENCY = 0.2

local RaceStartGateController = {}

local started = false

local function roundMode(): string?
	local container = ReplicatedStorage:FindFirstChild(StateAttributeNames.ContainerName)
	local value = if container ~= nil then container:GetAttribute(StateAttributeNames.RoundMode) else nil
	return if typeof(value) == "string" then value else nil
end

-- Já passou do portão (na rampa, à frente dele): o portão não segura quem
-- está lá.
local function beyond(gate: BasePart, position: Vector3): boolean
	local offset = gate.CFrame:PointToObjectSpace(position)
	return offset.Z < 0 and math.abs(offset.X) <= gate.Size.X / 2 and offset.Y >= -gate.Size.Y / 2
end

local function check(player: Player)
	local open = TowerPathRules.startGateOpen(
		player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true,
		player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == true,
		roundMode()
	)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	for _, instance in ipairs(CollectionService:GetTagged(TowerAmbienceNames.StartGateTag)) do
		if instance:IsA("BasePart") then
			local solid = not open and not (root ~= nil and root:IsA("BasePart") and beyond(instance, root.Position))
			if instance.CanCollide ~= solid then
				instance.CanCollide = solid
			end
			local transparency = if open then 1 else CLOSED_TRANSPARENCY
			if instance.Transparency ~= transparency then
				instance.Transparency = transparency
			end
		end
	end
end

function RaceStartGateController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	task.spawn(function()
		ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, WAIT_TIMEOUT)
		while true do
			local ok, failure = pcall(check, player)
			if not ok then
				warn(`[BlocoPuff] Race start gate check failed: {failure}`)
				task.wait(5)
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return table.freeze(RaceStartGateController)
