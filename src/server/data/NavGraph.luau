--!strict

-- Grafo de navegação dos bots (Fase 5E.3), sem Roblox: caminho mais curto
-- (A*) entre pontos da planta, ponto mais perto de uma posição no mesmo
-- andar e o cômodo para onde fugir de uma ameaça. Os nós vêm da planta
-- (MurderMansionPlan). Os testes rodam no Lune (tests/NavGraph.spec.luau).

export type Node = {
	id: string,
	x: number,
	z: number,
	level: number,
}

export type Graph = {
	nodes: { [string]: Node },
	order: { Node },
	neighbors: { [string]: { string } },
	floorHeight: number,
}

-- Fugir: entre os cômodos mais longe da ameaça (outro andar já conta a
-- altura dele na distância), sorteia um destes primeiros.
local FLEE_CHOICES = 3

local NavGraph = {}

function NavGraph.new(nodes: { Node }, edges: { { string } }, floorHeight: number): Graph
	local byId: { [string]: Node } = {}
	local order: { Node } = {}
	local neighbors: { [string]: { string } } = {}
	for _, node in ipairs(nodes) do
		local copy = { id = node.id, x = node.x, z = node.z, level = node.level }
		byId[node.id] = copy
		table.insert(order, copy)
		neighbors[node.id] = {}
	end
	for _, edge in ipairs(edges) do
		local a, b = edge[1], edge[2]
		if byId[a] ~= nil and byId[b] ~= nil then
			table.insert(neighbors[a], b)
			table.insert(neighbors[b], a)
		end
	end
	return { nodes = byId, order = order, neighbors = neighbors, floorHeight = floorHeight }
end

function NavGraph.node(graph: Graph, id: string): Node?
	return graph.nodes[id]
end

-- Distância entre dois nós (subir ou descer um andar conta a altura dele).
local function distance(graph: Graph, a: Node, b: Node): number
	local dx, dz = a.x - b.x, a.z - b.z
	local dy = (a.level - b.level) * graph.floorHeight
	return math.sqrt(dx * dx + dz * dz + dy * dy)
end

-- Caminho mais curto de `fromId` até `toId` (inclusive os dois), ou nil.
function NavGraph.path(graph: Graph, fromId: string, toId: string): { string }?
	local start, goal = graph.nodes[fromId], graph.nodes[toId]
	if start == nil or goal == nil then
		return nil
	end
	local open: { [string]: boolean } = { [fromId] = true }
	local cost: { [string]: number } = { [fromId] = 0 }
	local estimate: { [string]: number } = { [fromId] = distance(graph, start, goal) }
	local cameFrom: { [string]: string } = {}
	while next(open) ~= nil do
		local current: string? = nil
		local best = math.huge
		for id in pairs(open) do
			if estimate[id] < best then
				best = estimate[id]
				current = id
			end
		end
		local currentId = current :: string
		if currentId == toId then
			local path = { currentId }
			while cameFrom[path[1]] ~= nil do
				table.insert(path, 1, cameFrom[path[1]])
			end
			return path
		end
		open[currentId] = nil
		local currentNode = graph.nodes[currentId]
		for _, otherId in ipairs(graph.neighbors[currentId]) do
			local tentative = cost[currentId] + distance(graph, currentNode, graph.nodes[otherId])
			if cost[otherId] == nil or tentative < cost[otherId] then
				cameFrom[otherId] = currentId
				cost[otherId] = tentative
				estimate[otherId] = tentative + distance(graph, graph.nodes[otherId], goal)
				open[otherId] = true
			end
		end
	end
	return nil
end

-- Nó mais perto de (x, z) no andar `level` (nil sem nós nesse andar).
function NavGraph.nearest(graph: Graph, x: number, z: number, level: number): string?
	local bestId: string? = nil
	local best = math.huge
	for _, node in ipairs(graph.order) do
		if node.level == level then
			local dx, dz = node.x - x, node.z - z
			local gap = dx * dx + dz * dz
			if gap < best then
				best = gap
				bestId = node.id
			end
		end
	end
	return bestId
end

-- Cômodo para fugir de uma ameaça em (x, z, level): entre os de `rooms`
-- (fora o cômodo da ameaça), um dos mais longe, sorteado com `random`.
function NavGraph.fleeTarget(graph: Graph, rooms: { string }, x: number, z: number, level: number, threatRoom: string?, random: () -> number): string?
	local threat: Node = { id = "", x = x, z = z, level = level }
	local candidates: { { id: string, gap: number } } = {}
	for _, id in ipairs(rooms) do
		local node = graph.nodes[id]
		if node ~= nil and id ~= threatRoom then
			table.insert(candidates, { id = id, gap = distance(graph, node, threat) })
		end
	end
	if #candidates == 0 then
		return nil
	end
	table.sort(candidates, function(a, b)
		return a.gap > b.gap
	end)
	local choices = math.min(FLEE_CHOICES, #candidates)
	local index = math.clamp(math.floor(random() * choices) + 1, 1, choices)
	return candidates[index].id
end

return table.freeze(NavGraph)
