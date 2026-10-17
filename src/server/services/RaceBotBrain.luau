--!strict

-- Cérebro dos bots RoboPuff na Corrida da Torre do Relógio (Fase 5D.2):
-- sobem pelo caminho da rampa, pulam quando um barril chega perto (às vezes
-- tarde demais) e param no topo. Não atiram: na Corrida o desafio é subir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local TowerBuilder = require(script.Parent.TowerBuilder)
local RaceHazards = require(script.Parent.RaceHazards)

type Combatant = CombatantRegistry.Combatant
type TowerLayout = TowerBuilder.TowerLayout

local TICK_SECONDS = 0.25
-- Quantos pontos do caminho à frente o bot mira (corta a curva de leve).
local LOOKAHEAD = 2
local BARREL_ALERT_DISTANCE = 10
local BARREL_ALERT_HEIGHT = 5
-- Chance, por tique, de o bot notar o barril e pular a tempo.
local DODGE_CHANCE = 0.7
local RANDOM_JUMP_CHANCE = 0.02
-- Bots um pouco mais lentos que o normal, cada um no seu ritmo.
local SPEED_MIN = 0.8
local SPEED_MAX = 0.95

local RaceBotBrain = {}

local random = Random.new()
local running = false
local generation = 0

local function nearestIndex(tower: TowerLayout, position: Vector3): number
	local bestIndex = 1
	local bestDistance = math.huge
	for index, point in ipairs(tower.path) do
		local distance = (point - position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestIndex = index
		end
	end
	return bestIndex
end

local function barrelNear(position: Vector3): boolean
	for _, barrel in ipairs(RaceHazards.barrelPositions()) do
		local offset = barrel - position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < BARREL_ALERT_DISTANCE and math.abs(offset.Y) < BARREL_ALERT_HEIGHT then
			return true
		end
	end
	return false
end

local function step(tower: TowerLayout, bot: Combatant)
	local root = CombatantRegistry.getRoot(bot)
	local humanoid = CombatantRegistry.getHumanoid(bot)
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if CombatantRegistry.readCount(bot, StateAttributeNames.PlayerRaceFinishOrder) > 0 then
		humanoid:MoveTo(root.Position)
		return
	end
	local index = math.min(#tower.path, nearestIndex(tower, root.Position) + LOOKAHEAD)
	humanoid:MoveTo(tower.path[index])
	if (barrelNear(root.Position) and random:NextNumber() < DODGE_CHANCE) or random:NextNumber() < RANDOM_JUMP_CHANCE then
		humanoid.Jump = true
	end
end

function RaceBotBrain.begin(tower: TowerLayout, bots: { Combatant })
	RaceBotBrain.stop()
	if #bots == 0 then
		return
	end
	local baseSpeed = BotConfig.Levels.Normal.WalkSpeed
	for _, bot in ipairs(bots) do
		local humanoid = CombatantRegistry.getHumanoid(bot)
		if humanoid ~= nil then
			humanoid.WalkSpeed = baseSpeed * random:NextNumber(SPEED_MIN, SPEED_MAX)
		end
	end
	running = true
	generation += 1
	local current = generation
	task.spawn(function()
		while running and generation == current do
			for _, bot in ipairs(bots) do
				if CombatantRegistry.isPresent(bot) then
					step(tower, bot)
				end
			end
			task.wait(TICK_SECONDS)
		end
	end)
end

function RaceBotBrain.stop()
	running = false
	generation += 1
end

return table.freeze(RaceBotBrain)
