--!strict

-- Obstáculos da Corrida da Torre do Relógio (Fase 5D.2, renovados na Fase
-- 5F.3), sempre com aviso:
--   * barris e caldeirões de poção que rolam rampa abaixo (vê-se descendo);
--   * engrenagens que caem do mecanismo do relógio (sombra antes, HazardGears);
--   * bandos de livros que cruzam a rampa (brilho na coluna antes, HazardBooks);
--   * o ponteiro gigante que varre um trecho da terceira volta (sai devagar
--     da coluna antes, HazardClockHand).
-- Os tipos saem de um saco embaralhado (todos aparecem na mesma corrida) e
-- o ritmo acelera conforme a corrida passa. Quem é atingido é empurrado
-- rampa abaixo e fica tonto um instante; ninguém é eliminado.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local RaceRules = require(script.Parent.Parent.data.RaceRules)
local TowerBuilder = require(script.Parent.TowerBuilder)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local KnockbackService = require(script.Parent.KnockbackService)
local HazardBooks = require(script.Parent.HazardBooks)
local HazardClockHand = require(script.Parent.HazardClockHand)
local HazardContext = require(script.Parent.HazardContext)
local HazardGears = require(script.Parent.HazardGears)
local HazardProps = require(script.Parent.HazardProps)
local RaceDizzy = require(script.Parent.RaceDizzy)

type Combatant = CombatantRegistry.Combatant
type TowerLayout = TowerBuilder.TowerLayout
type Context = HazardContext.Context

-- Barril ou caldeirão descendo a rampa.
type Roller = {
	model: Model,
	t: number,
	roll: number,
	radius: number,
	secondsPerTurn: number,
	hitRadius: number,
	clearHeight: number,
}

local ROLL_SPEED = 6

local RaceHazards = {}

local random = Random.new()
local running = false
local generation = 0
local layout: TowerLayout? = nil
local getRacers: (() -> { Combatant })? = nil
local rollers: { Roller } = {}
local heartbeat: RBXScriptConnection? = nil
local spawned: { Instance } = {}
local bag: { string } = {}

-- Volta (t) do ponto do caminho mais perto de `position`.
function RaceHazards.turnsAt(tower: TowerLayout, position: Vector3): number
	local bestIndex = 1
	local bestDistance = math.huge
	for index, point in ipairs(tower.path) do
		local distance = (point - position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestIndex = index
		end
	end
	return tower.pathTurns[bestIndex]
end

-- Empurra rampa abaixo e deixa tonto (se o empurrão valeu).
local function hit(tower: TowerLayout, combatant: Combatant, t: number)
	local hazards = RaceConfig.Hazards
	local tangent = tower.tangentAt(t)
	local x, y, z = RaceRules.downhillPush(tangent.X, tangent.Z, hazards.PushDownhill, hazards.PushVertical)
	if KnockbackService.push(nil, combatant, Vector3.new(x, y, z)) then
		KnockbackService.protect(combatant, hazards.HitProtection)
		RaceDizzy.apply(combatant, hazards.DizzySeconds, hazards.DizzyWalkSpeed)
	end
end

local function racers(): { Combatant }
	local provider = getRacers
	return if provider ~= nil then provider() else {}
end

local function contextFor(tower: TowerLayout, current: number): Context
	return {
		tower = tower,
		folder = tower.folder,
		random = random,
		isLive = function()
			return running and generation == current
		end,
		racers = racers,
		hit = function(combatant: Combatant, t: number)
			hit(tower, combatant, t)
		end,
		turnsAt = function(position: Vector3)
			return RaceHazards.turnsAt(tower, position)
		end,
		track = function(instance: Instance)
			table.insert(spawned, instance)
		end,
	}
end

local function rollerCFrame(tower: TowerLayout, roller: Roller): CFrame
	local position = tower.pointAt(roller.t) + Vector3.new(0, roller.radius, 0)
	local tangent = tower.tangentAt(roller.t)
	-- O eixo (X) fica atravessado na rampa; o rolo gira nele.
	return CFrame.lookAt(position, position - tangent) * CFrame.Angles(roller.roll, 0, 0)
end

local function spawnRoller(tower: TowerLayout, cauldron: boolean)
	local hazards = RaceConfig.Hazards
	local radius = if cauldron then hazards.CauldronRadius else hazards.BarrelRadius
	local model = if cauldron then HazardProps.cauldron(radius) else HazardProps.barrel(radius)
	local roller: Roller = {
		model = model,
		t = tower.spiral.turns,
		roll = 0,
		radius = radius,
		secondsPerTurn = if cauldron then hazards.CauldronSecondsPerTurn else hazards.BarrelSecondsPerTurn,
		hitRadius = if cauldron then hazards.CauldronHitRadius else hazards.BarrelHitRadius,
		clearHeight = if cauldron then hazards.CauldronClearHeight else hazards.BarrelClearHeight,
	}
	model:PivotTo(rollerCFrame(tower, roller))
	model.Parent = tower.folder
	table.insert(rollers, roller)
	table.insert(spawned, model)
end

local function stepRollers(dt: number)
	local tower = layout
	if tower == nil then
		return
	end
	local current = racers()
	for index = #rollers, 1, -1 do
		local roller = rollers[index]
		roller.t -= dt / roller.secondsPerTurn
		roller.roll += dt * ROLL_SPEED * RaceConfig.Hazards.BarrelRadius / roller.radius
		if roller.t <= 0 then
			roller.model:Destroy()
			table.remove(rollers, index)
			continue
		end
		local cframe = rollerCFrame(tower, roller)
		roller.model:PivotTo(cframe)
		for _, combatant in ipairs(current) do
			local root = CombatantRegistry.getRoot(combatant)
			if root ~= nil then
				local offset = root.Position - cframe.Position
				local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if RaceRules.barrelHits(horizontal, offset.Y, roller.hitRadius, roller.radius, roller.clearHeight) then
					hit(tower, combatant, roller.t)
				end
			end
		end
	end
end

-- Próximo tipo do saco (embaralha um saco novo quando esvazia).
local function nextKind(): string
	if #bag == 0 then
		for _, kind in ipairs(RaceConfig.Hazards.Bag) do
			table.insert(bag, kind)
		end
		for index = #bag, 2, -1 do
			local other = random:NextInteger(1, index)
			bag[index], bag[other] = bag[other], bag[index]
		end
	end
	return table.remove(bag) :: string
end

local function launch(tower: TowerLayout, context: Context)
	local kind = nextKind()
	if kind == "Barrel" or kind == "Cauldron" then
		spawnRoller(tower, kind == "Cauldron")
		return
	end
	local candidates = racers()
	if #candidates == 0 then
		return
	end
	local target = candidates[random:NextInteger(1, #candidates)]
	if kind == "Books" then
		HazardBooks.launch(context, target)
	else
		HazardGears.drop(context, target)
	end
end

-- Liga os obstáculos. `provider` devolve quem ainda está correndo (sem quem
-- já chegou ao topo).
function RaceHazards.start(tower: TowerLayout, provider: () -> { Combatant }, duration: number)
	RaceHazards.stop()
	running = true
	generation += 1
	local current = generation
	layout = tower
	getRacers = provider
	heartbeat = RunService.Heartbeat:Connect(stepRollers)
	local context = contextFor(tower, current)
	HazardClockHand.start(context)
	local hazards = RaceConfig.Hazards
	task.spawn(function()
		local startedAt = os.clock()
		-- Um respiro na largada antes do primeiro obstáculo.
		task.wait(hazards.SlowInterval)
		while running and generation == current do
			launch(tower, context)
			local progress = if duration > 0 then (os.clock() - startedAt) / duration else 1
			task.wait(RaceRules.hazardInterval(progress, hazards.SlowInterval, hazards.FastInterval))
		end
	end)
end

-- Posições dos barris e caldeirões descendo (os bots pulam quando um chega
-- perto).
function RaceHazards.barrelPositions(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, roller in ipairs(rollers) do
		table.insert(positions, roller.model:GetPivot().Position)
	end
	return positions
end

function RaceHazards.stop()
	running = false
	generation += 1
	if heartbeat ~= nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for _, instance in ipairs(spawned) do
		instance:Destroy()
	end
	table.clear(spawned)
	table.clear(rollers)
	table.clear(bag)
	RaceDizzy.clear()
	layout = nil
	getRacers = nil
end

return table.freeze(RaceHazards)
