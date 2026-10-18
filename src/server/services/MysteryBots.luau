--!strict

-- Bots RoboPuff no Assassinato no Casarão (Fase 5E.3). Na partida de verdade
-- os bots são só Inocentes e andam pelo grafo da planta (MysteryBotNav),
-- passando pelas portas, escadas e passagem secreta:
--   * passeiam de um cômodo para outro (pegando as moedas do caminho);
--   * fogem para um cômodo longe de quem estiver com a faca na mão perto
--     deles;
--   * quando a arma do Xerife cai, alguns vão até perto dela (não pegam:
--     só humanos viram Herói), o que ajuda o humano a achá-la;
--   * nunca blefam nem acusam ninguém.
-- No teste solo do Studio, um bot faz o Assassino: vai atrás de quem está
-- mais perto e golpeia quando alcança.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local NavGraph = require(script.Parent.Parent.data.NavGraph)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local MurderMansionBuilder = require(script.Parent.MurderMansionBuilder)
local MurderKnife = require(script.Parent.MurderKnife)
local MysteryBotNav = require(script.Parent.MysteryBotNav)

type Combatant = CombatantRegistry.Combatant
type WingLayout = MurderMansionBuilder.WingLayout
type Route = MysteryBotNav.Route
type Nav = MysteryBotNav.Nav

export type MurdererDriver = {
	murderer: Combatant,
	-- Quem o Assassino ainda pode eliminar.
	targets: () -> { Combatant },
	-- Tenta golpear quem estiver ao alcance (as regras ficam no modo).
	attack: () -> (),
}

export type Context = {
	-- O Assassino da partida (para os Inocentes fugirem da faca).
	murderer: () -> Combatant?,
	-- Onde está a arma caída (nil: com alguém ou sem Xerife).
	droppedGun: () -> Vector3?,
	-- Só no teste solo do Studio: o bot que faz o Assassino.
	driver: MurdererDriver?,
}

type Mode = "Wander" | "Flee" | "Gun"

type BotState = {
	mode: Mode,
	route: Route?,
	-- Quando a fuga atual começou (refaz se a ameaça continuar perto).
	since: number,
	-- Arma caída que este bot já decidiu (ir ou não) olhar.
	gunSeen: Vector3?,
}

local TICK_SECONDS = 0.25
local SPEED_FACTOR = 0.85
-- Foge de quem está com a faca na mão até essa distância (studs), no mesmo
-- andar; refaz a fuga a cada FLEE_REPLAN segundos se a ameaça seguir perto.
local FLEE_DISTANCE = 25
local FLEE_HEIGHT = 8
local FLEE_REPLAN = 4
local FLEE_TRIES = 3
-- Chance de um bot ir olhar a arma caída, e a que distância dela para.
local GUN_CHANCE = 0.5
local GUN_STOP = 6
-- A arma conta como nova (novo sorteio) se mudou mais que isso de lugar.
local GUN_MOVED = 4
-- Bot Assassino (Studio): persegue direto quando o alvo está perto.
local CHASE_DIRECT = 18
local CHASE_REPLAN = 1.5

local MysteryBots = {}

local random = Random.new()
local running = false
local generation = 0

local function threatFor(context: Context, bot: Combatant, root: BasePart): BasePart?
	local murderer = context.murderer()
	if murderer == nil or murderer == bot or not MurderKnife.isEquipped(murderer) then
		return nil
	end
	local threatRoot = CombatantRegistry.getRoot(murderer)
	if threatRoot == nil then
		return nil
	end
	local offset = threatRoot.Position - root.Position
	if math.abs(offset.Y) > FLEE_HEIGHT or Vector3.new(offset.X, 0, offset.Z).Magnitude > FLEE_DISTANCE then
		return nil
	end
	return threatRoot
end

local function wanderGoal(nav: Nav, state: BotState, position: Vector3, now: number)
	local current = MysteryBotNav.roomOf(nav, position)
	local goal = nav.roomIds[random:NextInteger(1, #nav.roomIds)]
	if goal == current then
		goal = nav.roomIds[(table.find(nav.roomIds, goal) or 0) % #nav.roomIds + 1]
	end
	state.mode = "Wander"
	state.route = MysteryBotNav.plan(nav, position, goal, nav.layout.randomPointIn(goal, random), now)
end

local function flee(nav: Nav, state: BotState, position: Vector3, threat: Vector3, now: number)
	local center = nav.layout.center
	local level = MysteryBotNav.levelOf(nav, threat)
	local threatRoom = MysteryBotNav.roomOf(nav, threat)
	-- Sorteia algumas vezes para não fugir passando pelo cômodo da ameaça.
	for _ = 1, FLEE_TRIES do
		local goal = NavGraph.fleeTarget(nav.graph, nav.roomIds, threat.X - center.X, threat.Z - center.Z, level, threatRoom, function()
			return random:NextNumber()
		end)
		if goal == nil then
			return
		end
		local route = MysteryBotNav.plan(nav, position, goal, nav.layout.randomPointIn(goal, random), now)
		if route ~= nil and (threatRoom == nil or not table.find(route.path, threatRoom, route.index)) then
			state.mode = "Flee"
			state.since = now
			state.route = route
			return
		end
	end
end

-- Vai até perto da arma caída (sem pegar).
local function lookAtGun(nav: Nav, state: BotState, position: Vector3, gun: Vector3, now: number)
	local room = MysteryBotNav.roomOf(nav, gun)
	if room == nil then
		return
	end
	local away = Vector3.new(position.X - gun.X, 0, position.Z - gun.Z)
	local stop = if away.Magnitude > 1e-3 then gun + away.Unit * GUN_STOP else gun
	if MysteryBotNav.roomOf(nav, stop) ~= room then
		-- Ponto de parada atrás de uma parede: para no centro do cômodo.
		local node = NavGraph.node(nav.graph, room)
		stop = if node ~= nil then nav.layout.toWorld(node.x, node.z, node.level) else gun
	end
	state.mode = "Gun"
	state.route = MysteryBotNav.plan(nav, position, room, Vector3.new(stop.X, nav.layout.floorAt(gun), stop.Z), now)
end

local function innocentTick(nav: Nav, context: Context, bot: Combatant, state: BotState, now: number)
	local root = CombatantRegistry.getRoot(bot)
	local humanoid = CombatantRegistry.getHumanoid(bot)
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local position = root.Position
	local threat = threatFor(context, bot, root)
	if threat ~= nil and (state.mode ~= "Flee" or now - state.since >= FLEE_REPLAN) then
		flee(nav, state, position, threat.Position, now)
	end
	local gun = context.droppedGun()
	local seen = state.gunSeen
	if gun ~= nil and state.mode == "Wander" and (seen == nil or (seen - gun).Magnitude > GUN_MOVED) then
		state.gunSeen = gun
		if random:NextNumber() < GUN_CHANCE then
			lookAtGun(nav, state, position, gun, now)
		end
	end
	local route = state.route
	if route == nil or not MysteryBotNav.step(nav, bot, route, now) then
		wanderGoal(nav, state, position, now)
	end
end

-- Bot Assassino (só no teste solo do Studio): rota até o cômodo do alvo
-- mais perto; perto e no mesmo andar, vai direto e golpeia.
local function murdererTick(nav: Nav, driver: MurdererDriver, state: BotState, now: number)
	local root = CombatantRegistry.getRoot(driver.murderer)
	local humanoid = CombatantRegistry.getHumanoid(driver.murderer)
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
	local target = nearest
	if target == nil then
		return
	end
	local targetRoom = MysteryBotNav.roomOf(nav, target.Position)
	local sameRoom = targetRoom ~= nil and targetRoom == MysteryBotNav.roomOf(nav, root.Position)
	if sameRoom and nearestDistance <= CHASE_DIRECT then
		humanoid:MoveTo(target.Position)
		-- Olha para o alvo: o golpe só vale à frente.
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
		driver.attack()
		return
	end
	-- Refaz a rota quando o alvo muda de cômodo ou a rota acaba (refazer
	-- sempre zeraria o destravamento).
	local route = state.route
	if route == nil or (targetRoom ~= nil and route.goal ~= targetRoom and now - state.since >= CHASE_REPLAN) then
		state.since = now
		state.route = if targetRoom ~= nil then MysteryBotNav.plan(nav, root.Position, targetRoom, target.Position, now) else nil
		route = state.route
	end
	if route ~= nil and not MysteryBotNav.step(nav, driver.murderer, route, now) then
		state.route = nil
	end
end

function MysteryBots.begin(layout: WingLayout, bots: { Combatant }, context: Context)
	MysteryBots.stop()
	if #bots == 0 then
		return
	end
	local nav = MysteryBotNav.new(layout)
	local speed = BotConfig.Levels.Normal.WalkSpeed * SPEED_FACTOR
	local states: { [Combatant]: BotState } = {}
	for _, bot in ipairs(bots) do
		local humanoid = CombatantRegistry.getHumanoid(bot)
		if humanoid ~= nil then
			humanoid.WalkSpeed = speed
		end
		states[bot] = { mode = "Wander", route = nil, since = 0, gunSeen = nil }
	end
	running = true
	generation += 1
	local current = generation
	task.spawn(function()
		while running and generation == current do
			local now = os.clock()
			for _, bot in ipairs(bots) do
				if CombatantRegistry.isPresent(bot) then
					local driver = context.driver
					local ok, problem = pcall(function()
						if driver ~= nil and driver.murderer == bot then
							murdererTick(nav, driver, states[bot], now)
						else
							innocentTick(nav, context, bot, states[bot], now)
						end
					end)
					if not ok then
						warn(`[BlocoPuff] bot do Assassinato: {problem}`)
						states[bot].route = nil
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
