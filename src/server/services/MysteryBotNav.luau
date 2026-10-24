--!strict

-- Navegação dos bots na Ala do Assassinato (Fase 5E.3): liga a planta
-- (MurderMansionPlan) e o grafo (NavGraph) ao mundo. Um bot com rota anda
-- de ponto em ponto pelas portas, escadas e passagem (MoveTo), e no fim vai
-- até um ponto final dentro do cômodo. Se não sai do lugar por um tempo,
-- pula e refaz a rota a partir de onde está.

local MurderMansionPlan = require(script.Parent.Parent.data.MurderMansionPlan)
local NavGraph = require(script.Parent.Parent.data.NavGraph)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local MurderMansionBuilder = require(script.Parent.MurderMansionBuilder)

type Combatant = CombatantRegistry.Combatant
type WingLayout = MurderMansionBuilder.WingLayout
type Graph = NavGraph.Graph

-- Chegou ao ponto: distância no plano e diferença de altura até o chão do
-- andar do ponto (a raiz fica uns 3 studs acima do chão).
local ARRIVED_DISTANCE = 2.5
local ARRIVED_HEIGHT = 5
local ROOT_HEIGHT = 3
local FINAL_DISTANCE = 3
-- Parado por esse tempo (s) com rota: pula e refaz a rota.
local UNSTICK_SECONDS = 2
local UNSTICK_MOVE = 1
-- Travou tantas vezes seguidas: desiste do destino.
local MAX_STUCK = 3

export type Route = {
	path: { string },
	index: number,
	-- Ponto final dentro do último cômodo (nil: para no último nó).
	final: Vector3?,
	-- Destino (para refazer a rota depois de travar).
	goal: string,
	stuckCount: number,
	-- Desistiu de vez depois de travar demais (telemetria MurderBotStuck).
	gaveUp: boolean,
	lastPosition: Vector3,
	lastMovedAt: number,
}

export type Nav = {
	layout: WingLayout,
	graph: Graph,
	roomIds: { string },
}

local MysteryBotNav = {}

function MysteryBotNav.new(layout: WingLayout): Nav
	local plan = layout.plan
	local roomIds: { string } = {}
	for _, room in ipairs(plan.rooms) do
		table.insert(roomIds, room.id)
	end
	return { layout = layout, graph = NavGraph.new(plan.nodes, plan.edges, plan.floorHeight), roomIds = roomIds }
end

-- Andar de uma posição do mundo (pela altura da raiz).
function MysteryBotNav.levelOf(nav: Nav, position: Vector3): number
	return if position.Y - nav.layout.floorY >= nav.layout.plan.floorHeight - 2 then 1 else 0
end

-- Cômodo da planta em que a posição está (nil: passagem ou escada).
function MysteryBotNav.roomOf(nav: Nav, position: Vector3): string?
	local center = nav.layout.center
	return MurderMansionPlan.roomAt(nav.layout.plan, position.X - center.X, position.Z - center.Z, MysteryBotNav.levelOf(nav, position))
end

-- Nó de onde sair: o do cômodo em que está, ou o mais perto no andar.
local function startNode(nav: Nav, position: Vector3): string?
	local room = MysteryBotNav.roomOf(nav, position)
	if room ~= nil then
		return room
	end
	local center = nav.layout.center
	return NavGraph.nearest(nav.graph, position.X - center.X, position.Z - center.Z, MysteryBotNav.levelOf(nav, position))
end

local function worldOf(nav: Nav, id: string): Vector3?
	local node = NavGraph.node(nav.graph, id)
	if node == nil then
		return nil
	end
	return nav.layout.toWorld(node.x, node.z, node.level)
end

-- Rota da posição até o nó `goal` (com um ponto final opcional).
function MysteryBotNav.plan(nav: Nav, position: Vector3, goal: string, final: Vector3?, now: number): Route?
	local from = startNode(nav, position)
	if from == nil then
		return nil
	end
	local path = NavGraph.path(nav.graph, from, goal)
	if path == nil then
		return nil
	end
	-- Já está no cômodo de saída: não precisa ir ao centro dele antes.
	local index = if #path > 1 and from == MysteryBotNav.roomOf(nav, position) then 2 else 1
	return { path = path, index = index, final = final, goal = goal, stuckCount = 0, gaveUp = false, lastPosition = position, lastMovedAt = now }
end

local function arrived(nav: Nav, position: Vector3, target: Vector3, distance: number): boolean
	local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z).Magnitude
	return flat <= distance and math.abs(position.Y - ROOT_HEIGHT - target.Y) <= ARRIVED_HEIGHT
end

-- Um passo da rota: anda até o ponto atual e avança quando chega. Devolve
-- false quando a rota acabou (ou não dá para seguir).
function MysteryBotNav.step(nav: Nav, bot: Combatant, route: Route, now: number): boolean
	local root = CombatantRegistry.getRoot(bot)
	local humanoid = CombatantRegistry.getHumanoid(bot)
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local position = root.Position
	if (position - route.lastPosition).Magnitude >= UNSTICK_MOVE then
		route.lastPosition = position
		route.lastMovedAt = now
		route.stuckCount = 0
	elseif now - route.lastMovedAt >= UNSTICK_SECONDS then
		-- Travou: pula e refaz a rota a partir de onde está.
		humanoid.Jump = true
		route.stuckCount += 1
		if route.stuckCount > MAX_STUCK then
			route.gaveUp = true
			return false
		end
		local fresh = MysteryBotNav.plan(nav, position, route.goal, route.final, now)
		if fresh == nil then
			return false
		end
		route.path = fresh.path
		route.index = fresh.index
		route.lastPosition = position
		route.lastMovedAt = now
	end

	while route.index <= #route.path do
		local target = worldOf(nav, route.path[route.index])
		if target == nil then
			return false
		end
		if not arrived(nav, position, target, ARRIVED_DISTANCE) then
			humanoid:MoveTo(target)
			return true
		end
		route.index += 1
	end
	local final = route.final
	if final ~= nil and not arrived(nav, position, final, FINAL_DISTANCE) then
		humanoid:MoveTo(final)
		return true
	end
	return false
end

return table.freeze(MysteryBotNav)
