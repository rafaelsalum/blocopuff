--!strict

-- Bots RoboPuff no Mistério no Casarão (Fase 5D.3). Na partida de verdade os
-- bots são só Moradores: andam de um cômodo para outro (pegando as moedas
-- que estiverem no caminho), sem nunca blefar nem acusar ninguém. No teste
-- solo do Studio, um bot faz o Fantasma: vai atrás de quem está perto e
-- assusta quando alcança.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local MysteryWingBuilder = require(script.Parent.MysteryWingBuilder)

type Combatant = CombatantRegistry.Combatant
type WingLayout = MysteryWingBuilder.WingLayout

export type GhostDriver = {
	ghost: Combatant,
	-- Quem o Fantasma ainda pode assustar.
	targets: () -> { Combatant },
	-- Tenta assustar quem estiver ao alcance (as regras ficam no modo).
	scare: () -> (),
}

local TICK_SECONDS = 0.4
-- Chegou perto do destino: escolhe outro.
local ARRIVED_DISTANCE = 4
-- Anda no mesmo destino no máximo isso (s), para não ficar preso num móvel.
local GOAL_TIMEOUT = 6
local SPEED_FACTOR = 0.85

type Goal = {
	position: Vector3,
	since: number,
}

local MysteryBots = {}

local random = Random.new()
local running = false
local generation = 0

local function wander(layout: WingLayout, bot: Combatant, goals: { [Combatant]: Goal }, now: number)
	local root = CombatantRegistry.getRoot(bot)
	local humanoid = CombatantRegistry.getHumanoid(bot)
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local goal = goals[bot]
	local flat = if goal ~= nil then Vector3.new(goal.position.X - root.Position.X, 0, goal.position.Z - root.Position.Z) else Vector3.zero
	if goal == nil or flat.Magnitude < ARRIVED_DISTANCE or now - goal.since > GOAL_TIMEOUT then
		goal = { position = layout.randomPoint(random), since = now }
		goals[bot] = goal
	end
	humanoid:MoveTo((goal :: Goal).position)
end

local function chase(driver: GhostDriver)
	local root = CombatantRegistry.getRoot(driver.ghost)
	local humanoid = CombatantRegistry.getHumanoid(driver.ghost)
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local nearest: BasePart? = nil
	local nearestDistance = math.huge
	for _, target in ipairs(driver.targets()) do
		local targetRoot = CombatantRegistry.getRoot(target)
		if targetRoot ~= nil then
			local distance = (targetRoot.Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearest = targetRoot
				nearestDistance = distance
			end
		end
	end
	if nearest ~= nil then
		humanoid:MoveTo(nearest.Position)
	end
	driver.scare()
end

function MysteryBots.begin(layout: WingLayout, bots: { Combatant }, ghostDriver: GhostDriver?)
	MysteryBots.stop()
	if #bots == 0 then
		return
	end
	local speed = BotConfig.Levels.Normal.WalkSpeed * SPEED_FACTOR
	for _, bot in ipairs(bots) do
		local humanoid = CombatantRegistry.getHumanoid(bot)
		if humanoid ~= nil then
			humanoid.WalkSpeed = speed
		end
	end
	running = true
	generation += 1
	local current = generation
	local goals: { [Combatant]: Goal } = {}
	task.spawn(function()
		while running and generation == current do
			local now = os.clock()
			for _, bot in ipairs(bots) do
				if CombatantRegistry.isPresent(bot) then
					if ghostDriver ~= nil and ghostDriver.ghost == bot then
						chase(ghostDriver)
					else
						wander(layout, bot, goals, now)
					end
				end
			end
			task.wait(TICK_SECONDS)
		end
	end)
end

function MysteryBots.stop()
	running = false
	generation += 1
end

return table.freeze(MysteryBots)
