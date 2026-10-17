--!strict

-- Modo Corrida da Torre do Relógio (Fase 5D.2): o primeiro a chegar ao topo
-- vence. Ninguém é eliminado: quem é derrubado cai para a volta de baixo, e
-- quem cai muito abaixo do último checkpoint volta para ele. A corrida acaba
-- quando o pódio enche ou o tempo acaba; quem não chegou fica pela altura.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local CharacterImpulse = require(ReplicatedStorage.Shared.modules.CharacterImpulse)
local RoundModeTypes = require(script.Parent.RoundModeTypes)
local RaceRules = require(script.Parent.Parent.data.RaceRules)
local services = script.Parent.Parent.services
local CombatantRegistry = require(services.CombatantRegistry)
local KnockbackService = require(services.KnockbackService)
local PuffadorService = require(services.PuffadorService)
local TelemetryService = require(services.TelemetryService)
local TowerBuilder = require(services.TowerBuilder)
local RaceHazards = require(services.RaceHazards)
local RaceBotBrain = require(services.RaceBotBrain)

type BeginContext = RoundModeTypes.BeginContext
type TickContext = RoundModeTypes.TickContext
type Outcome = RoundModeTypes.Outcome
type Combatant = CombatantRegistry.Combatant
type TowerLayout = TowerBuilder.TowerLayout

type Racer = {
	checkpoint: number,
	bestHeight: number,
	-- Altura na última checagem aceita (para barrar teletransporte).
	lastHeight: number,
	-- Até quando (os.clock) a subida não é conferida: largada e volta ao
	-- checkpoint, enquanto a posição nova ainda chega do cliente.
	graceUntil: number,
	finishOrder: number?,
}

local ATTR_CHECKPOINT = StateAttributeNames.PlayerRaceCheckpoint
local ATTR_POSITION = StateAttributeNames.PlayerRacePosition
local ATTR_FINISH_ORDER = StateAttributeNames.PlayerRaceFinishOrder
-- Folga da conferência de subida depois de um teleporte do próprio jogo.
local TELEPORT_GRACE = 1
-- Quem chegou fica protegido de empurrões até o fim da corrida.
local FINISHED_PROTECTION = 600
-- A posição ao vivo é recalculada a cada tantos tiques.
local POSITION_EVERY_TICKS = 5

local tower: TowerLayout? = nil
local racers: { [Combatant]: Racer } = {}
local order: { Combatant } = {}
local finishers: { Combatant } = {}
local running = false
local generation = 0
local startedAt = 0

local function requireTower(): TowerLayout
	local current = tower
	if current == nil then
		current = TowerBuilder.build()
		tower = current
	end
	return current
end

-- Corredores presentes que ainda não chegaram ao topo.
local function climbing(): { Combatant }
	local list: { Combatant } = {}
	for _, combatant in ipairs(order) do
		local racer = racers[combatant]
		if racer ~= nil and racer.finishOrder == nil and CombatantRegistry.isPresent(combatant) then
			table.insert(list, combatant)
		end
	end
	return list
end

local function presentCount(): number
	local count = 0
	for _, combatant in ipairs(order) do
		if CombatantRegistry.isPresent(combatant) then
			count += 1
		end
	end
	return count
end

-- Quem chegou e ainda está no servidor, na ordem de chegada (quem saiu não
-- ocupa posição no pódio).
local function presentFinishers(): { Combatant }
	local list: { Combatant } = {}
	for _, combatant in ipairs(finishers) do
		if CombatantRegistry.isPresent(combatant) then
			table.insert(list, combatant)
		end
	end
	return list
end

local function rankPositions(): { [Combatant]: number }
	local entries: { RaceRules.RankEntry } = {}
	local byId: { [number]: Combatant } = {}
	local finishOrder: { [Combatant]: number } = {}
	for index, combatant in ipairs(presentFinishers()) do
		finishOrder[combatant] = index
	end
	for _, combatant in ipairs(order) do
		local racer = racers[combatant]
		if racer ~= nil and CombatantRegistry.isPresent(combatant) then
			table.insert(entries, { id = combatant.id, finishOrder = finishOrder[combatant], bestHeight = math.floor(racer.bestHeight) })
			byId[combatant.id] = combatant
		end
	end
	local positions: { [Combatant]: number } = {}
	for id, position in pairs(RaceRules.rank(entries)) do
		local combatant = byId[id]
		if combatant ~= nil then
			positions[combatant] = position
		end
	end
	return positions
end

local function returnTo(combatant: Combatant, cframe: CFrame)
	local character = CombatantRegistry.getCharacter(combatant)
	local root = CombatantRegistry.getRoot(combatant)
	if character == nil or root == nil then
		return
	end
	local moved = pcall(function()
		character:PivotTo(cframe)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
	if not moved then
		return
	end
	KnockbackService.forget(combatant)
	local racer = racers[combatant]
	if racer ~= nil then
		racer.lastHeight = cframe.Position.Y
		racer.graceUntil = os.clock() + TELEPORT_GRACE
	end
	local player = combatant.player
	if player ~= nil then
		-- A física do personagem é do cliente: ele zera a própria queda.
		PuffadorService.sendFeedback(player, "Respawn", cframe)
		TelemetryService.event(player, "RaceReturn", racers[combatant].checkpoint)
	else
		CharacterImpulse.stopFalling(root, cframe)
	end
end

local function finishRacer(layout: TowerLayout, combatant: Combatant, racer: Racer)
	table.insert(finishers, combatant)
	racer.finishOrder = #finishers
	racer.bestHeight = layout.topY
	CombatantRegistry.setAttribute(combatant, ATTR_FINISH_ORDER, #finishers)
	KnockbackService.protect(combatant, FINISHED_PROTECTION)
	local player = combatant.player
	if player ~= nil then
		TelemetryService.event(player, "RaceFinish", math.floor(os.clock() - startedAt), tostring(#finishers))
	end
	print(string.format("[BlocoPuff] %s reached the top of the tower (#%d)", combatant.name, #finishers))
end

local function updateRacer(layout: TowerLayout, combatant: Combatant, racer: Racer)
	local root = CombatantRegistry.getRoot(combatant)
	if root == nil or racer.finishOrder ~= nil then
		return
	end
	local position = root.Position
	local height = position.Y
	local checkpointCFrame = if racer.checkpoint > 0 then layout.checkpointCFrames[racer.checkpoint] else TowerBuilder.startCFrames(layout, 1)[1]
	-- A posição do jogador vem do cliente: subida impossível não conta e
	-- devolve o corredor ao último checkpoint.
	local checked = os.clock() >= racer.graceUntil
	if checked and not RaceRules.plausibleRise(racer.lastHeight, height, RaceConfig.TickSeconds, RaceConfig.MaxRiseSpeed) then
		returnTo(combatant, checkpointCFrame)
		return
	end
	racer.lastHeight = height
	racer.bestHeight = math.max(racer.bestHeight, height)

	local reached = RaceRules.nextCheckpoint(racer.checkpoint, RaceRules.checkpointFor(height, layout.checkpointHeights, RaceConfig.ReachTolerance))
	if reached > racer.checkpoint then
		racer.checkpoint = reached
		CombatantRegistry.setAttribute(combatant, ATTR_CHECKPOINT, reached)
		local player = combatant.player
		if player ~= nil then
			TelemetryService.event(player, "RaceCheckpoint", reached)
		end
	end

	local horizontal = Vector3.new(position.X - layout.center.X, 0, position.Z - layout.center.Z).Magnitude
	local allCheckpoints = racer.checkpoint >= #layout.checkpointHeights
	if allCheckpoints and height >= layout.topY - RaceConfig.ReachTolerance and horizontal <= RaceConfig.Tower.TopRadius then
		finishRacer(layout, combatant, racer)
		return
	end

	local checkpointY = if racer.checkpoint > 0 then layout.checkpointHeights[racer.checkpoint] else nil
	if RaceRules.shouldReturn(height, checkpointY, RaceConfig.ReturnTolerance, layout.center.Y) then
		local cframe = if racer.checkpoint > 0 then layout.checkpointCFrames[racer.checkpoint] else TowerBuilder.startCFrames(layout, 1)[1]
		returnTo(combatant, cframe)
	end
end

local function publishPositions()
	for combatant, position in pairs(rankPositions()) do
		CombatantRegistry.setAttribute(combatant, ATTR_POSITION, position)
	end
end

local function canRun(humans: number): boolean
	return humans >= 1
end

local function prepare(_roundId: number)
	requireTower()
	table.clear(racers)
	table.clear(order)
	table.clear(finishers)
end

local function getSpawnCFrames(count: number): { CFrame }
	return TowerBuilder.startCFrames(requireTower(), count)
end

local function getRoundDuration(default: number): number
	return math.min(default, RaceConfig.Duration)
end

local function begin(context: BeginContext)
	local layout = requireTower()
	for _, combatant in ipairs(context.combatants) do
		local root = CombatantRegistry.getRoot(combatant)
		local startHeight = if root ~= nil then root.Position.Y else layout.center.Y
		racers[combatant] = { checkpoint = 0, bestHeight = layout.center.Y, lastHeight = startHeight, graceUntil = os.clock() + TELEPORT_GRACE, finishOrder = nil }
		table.insert(order, combatant)
		CombatantRegistry.setAttribute(combatant, ATTR_CHECKPOINT, 0)
		CombatantRegistry.setAttribute(combatant, ATTR_POSITION, 0)
		CombatantRegistry.setAttribute(combatant, ATTR_FINISH_ORDER, 0)
	end
	KnockbackService.setShotForce(RaceConfig.PuffadorForce)
	RaceHazards.start(layout, climbing, context.roundDuration)

	running = true
	generation += 1
	startedAt = os.clock()
	local current = generation
	task.spawn(function()
		local ticks = 0
		while running and generation == current do
			for _, combatant in ipairs(order) do
				local racer = racers[combatant]
				if racer ~= nil and CombatantRegistry.isPresent(combatant) then
					updateRacer(layout, combatant, racer)
				end
			end
			ticks += 1
			if ticks % POSITION_EVERY_TICKS == 0 then
				publishPositions()
			end
			task.wait(RaceConfig.TickSeconds)
		end
	end)
end

local function getClimaxDuration(_roundDuration: number): number
	return 0
end

local function isInClimax(): boolean
	return false
end

local function tick(_context: TickContext) end

-- Vence o primeiro a chegar, quando o pódio enche ou o tempo acaba.
local function evaluate(timeUp: boolean): Outcome?
	if not timeUp and not RaceRules.isOver(#presentFinishers(), presentCount(), RaceConfig.PodiumSize) then
		return nil
	end
	return { winner = presentFinishers()[1] }
end

local function getRanking(): { [Combatant]: number }?
	return rankPositions()
end

local function beginBots(bots: { Combatant }, _humans: { Player })
	RaceBotBrain.begin(requireTower(), bots)
end

local function endBots()
	RaceBotBrain.stop()
end

-- Na Corrida não há Segunda Chance: a volta ao checkpoint já cuida das quedas.
local function getRespawnCFrame(): CFrame?
	return nil
end

local function getRemainingFloorRatio(): number
	return 1
end

-- Para tudo, mas guarda chegadas e alturas para o resultado.
local function finish()
	running = false
	generation += 1
	RaceHazards.stop()
	publishPositions()
end

local function cleanup()
	for _, combatant in ipairs(order) do
		CombatantRegistry.setAttribute(combatant, ATTR_CHECKPOINT, 0)
		CombatantRegistry.setAttribute(combatant, ATTR_POSITION, 0)
		CombatantRegistry.setAttribute(combatant, ATTR_FINISH_ORDER, 0)
	end
	table.clear(racers)
	table.clear(order)
	table.clear(finishers)
end

local function stop()
	finish()
	RaceBotBrain.stop()
end

local RaceMode: RoundModeTypes.RoundMode = {
	id = "Race",
	canRun = canRun,
	prepare = prepare,
	getSpawnCFrames = getSpawnCFrames,
	getRoundDuration = getRoundDuration,
	begin = begin,
	getClimaxDuration = getClimaxDuration,
	isInClimax = isInClimax,
	tick = tick,
	lastStanding = false,
	evaluate = evaluate,
	getRanking = getRanking,
	beginBots = beginBots,
	endBots = endBots,
	getRespawnCFrame = getRespawnCFrame,
	getRemainingFloorRatio = getRemainingFloorRatio,
	finish = finish,
	cleanup = cleanup,
	stop = stop,
}

return table.freeze(RaceMode)
