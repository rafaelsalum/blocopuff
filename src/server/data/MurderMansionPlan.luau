--!strict

-- Planta da Ala do Assassinato (Fase 5E.2), sem Roblox: dois andares com
-- seis cômodos cada (grade 3 x 2), portas entre todos os vizinhos, duas
-- escadas em lados opostos (Salão de Baile → Sala de Música e Sala de Estar
-- → Estufa) e uma passagem secreta atrás das estantes, da Biblioteca até a
-- Cozinha. Também os pontos de navegação dos bots (centro de cada cômodo,
-- cada porta, os pés e o alto das escadas e a passagem).
--
-- Coordenadas locais em studs: x de oeste (−) para leste (+), z de norte
-- (−) para sul (+), centradas no meio da Ala; `level` 0 é o térreo e 1 o
-- andar de cima. O construtor (MurderMansionBuilder) põe tudo no mundo. Os
-- testes rodam no Lune (tests/MurderMansionPlan.spec.luau).

export type Room = {
	id: string,
	-- Nome mostrado (placas) e tema dos móveis.
	name: string,
	level: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

export type Door = {
	from: string,
	to: string,
	level: number,
	-- "Z": parede em x constante (a porta corre ao longo de z); "X": parede
	-- em z constante.
	axis: "X" | "Z",
	x: number,
	z: number,
}

export type Stair = {
	lowerRoom: string,
	upperRoom: string,
	-- Faixa da escada junto à parede (centro em x e largura).
	x: number,
	width: number,
	-- Começa embaixo em bottomZ e chega em cima em topZ.
	bottomZ: number,
	topZ: number,
}

export type Passage = {
	fromRoom: string,
	toRoom: string,
	-- Aberturas na parede norte (z = wallZ) atrás das estantes.
	fromX: number,
	toX: number,
	wallZ: number,
	gapWidth: number,
	-- Corredor escondido do lado de fora da parede.
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

export type Node = {
	id: string,
	x: number,
	z: number,
	level: number,
	-- Cômodo do nó (nil: no vão de porta ou na passagem).
	room: string?,
}

export type Area = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

export type Plan = {
	floorHeight: number,
	wallHeight: number,
	doorWidth: number,
	doorHeight: number,
	rooms: { Room },
	doors: { Door },
	stairs: { Stair },
	passages: { Passage },
	nodes: { Node },
	edges: { { string } },
}

-- Andar: 14 de parede + 1 de laje.
local FLOOR_HEIGHT = 15
local WALL_HEIGHT = 14
local DOOR_WIDTH = 8
local DOOR_HEIGHT = 10
-- Grade de cômodos.
local COLUMNS = { -48, -16, 16, 48 }
local ROWS = { -36, 0, 36 }
-- Escadas junto às paredes de oeste e de leste.
local STAIR_WIDTH = 6
local STAIR_BOTTOM_Z = 32
local STAIR_TOP_Z = 6
-- Distância da faixa da escada até o ponto de aproximação.
local STAIR_APPROACH = 3
-- Folga das paredes (e da escada) para nascer, moedas e móveis no meio.
local OPEN_MARGIN = 9

local NAMES: { { string } } = {
	-- Térreo: norte (oeste, meio, leste), depois sul.
	{ "library", "Biblioteca" },
	{ "dining", "Sala de Jantar" },
	{ "kitchen", "Cozinha" },
	{ "ballroom", "Salão de Baile" },
	{ "hall", "Hall de Entrada" },
	{ "lounge", "Sala de Estar" },
	-- Andar de cima.
	{ "baronBedroom", "Quarto do Barão" },
	{ "portraits", "Corredor dos Retratos" },
	{ "guestBedroom", "Quarto de Hóspedes" },
	{ "music", "Sala de Música" },
	{ "games", "Sala de Jogos" },
	{ "greenhouse", "Estufa" },
}

local MurderMansionPlan = {}

local function buildRooms(): { Room }
	local rooms: { Room } = {}
	for index, entry in ipairs(NAMES) do
		local slot = (index - 1) % 6
		local column = (slot % 3) + 1
		local row = math.floor(slot / 3) + 1
		table.insert(rooms, {
			id = entry[1],
			name = entry[2],
			level = if index <= 6 then 0 else 1,
			minX = COLUMNS[column],
			maxX = COLUMNS[column + 1],
			minZ = ROWS[row],
			maxZ = ROWS[row + 1],
		})
	end
	return rooms
end

-- Portas entre todos os vizinhos de cada andar (laços para fugir).
local function buildDoors(rooms: { Room }): { Door }
	local doors: { Door } = {}
	for level = 0, 1 do
		local grid: { Room } = {}
		for _, room in ipairs(rooms) do
			if room.level == level then
				table.insert(grid, room)
			end
		end
		for slot, room in ipairs(grid) do
			local column = ((slot - 1) % 3) + 1
			local east = grid[slot + 1]
			if column < 3 and east ~= nil then
				table.insert(doors, { from = room.id, to = east.id, level = level, axis = "Z", x = room.maxX, z = (room.minZ + room.maxZ) / 2 })
			end
			local south = grid[slot + 3]
			if south ~= nil then
				table.insert(doors, { from = room.id, to = south.id, level = level, axis = "X", x = (room.minX + room.maxX) / 2, z = room.maxZ })
			end
		end
	end
	return doors
end

local function buildStairs(): { Stair }
	return {
		{ lowerRoom = "ballroom", upperRoom = "music", x = COLUMNS[1] + STAIR_WIDTH / 2, width = STAIR_WIDTH, bottomZ = STAIR_BOTTOM_Z, topZ = STAIR_TOP_Z },
		{ lowerRoom = "lounge", upperRoom = "greenhouse", x = COLUMNS[4] - STAIR_WIDTH / 2, width = STAIR_WIDTH, bottomZ = STAIR_BOTTOM_Z, topZ = STAIR_TOP_Z },
	}
end

local function buildPassages(): { Passage }
	return {
		{
			fromRoom = "library",
			toRoom = "kitchen",
			fromX = -32,
			toX = 32,
			wallZ = ROWS[1],
			gapWidth = 4,
			minX = -36,
			maxX = 36,
			minZ = ROWS[1] - 6,
			maxZ = ROWS[1],
		},
	}
end

local function buildGraph(rooms: { Room }, doors: { Door }, stairs: { Stair }, passages: { Passage }): ({ Node }, { { string } })
	local nodes: { Node } = {}
	local edges: { { string } } = {}
	local byId: { [string]: Room } = {}
	for _, room in ipairs(rooms) do
		byId[room.id] = room
		table.insert(nodes, { id = room.id, x = (room.minX + room.maxX) / 2, z = (room.minZ + room.maxZ) / 2, level = room.level, room = room.id })
	end
	for _, door in ipairs(doors) do
		local id = `door:{door.from}:{door.to}`
		table.insert(nodes, { id = id, x = door.x, z = door.z, level = door.level, room = nil })
		table.insert(edges, { door.from, id })
		table.insert(edges, { id, door.to })
	end
	for index, stair in ipairs(stairs) do
		local bottom = `stair{index}:bottom`
		local top = `stair{index}:top`
		local lower = byId[stair.lowerRoom]
		local upper = byId[stair.upperRoom]
		-- Pé da escada logo antes do começo da rampa; alto logo depois do fim.
		local step = if stair.topZ < stair.bottomZ then 2 else -2
		local bottomZ = stair.bottomZ + step
		local topZ = stair.topZ - step * 1.5
		-- Aproximação: fora da faixa da escada, na mesma linha do pé e do alto,
		-- para ninguém chegar em diagonal (bateria nos degraus ou cairia no
		-- vão do andar de cima).
		local roomMiddle = (lower.minX + lower.maxX) / 2
		local inward = if roomMiddle > stair.x then 1 else -1
		local approachX = stair.x + inward * (stair.width / 2 + STAIR_APPROACH)
		local bottomApproach = `stair{index}:bottomApproach`
		local topApproach = `stair{index}:topApproach`
		table.insert(nodes, { id = bottomApproach, x = approachX, z = bottomZ, level = lower.level, room = lower.id })
		table.insert(nodes, { id = bottom, x = stair.x, z = bottomZ, level = lower.level, room = lower.id })
		table.insert(nodes, { id = top, x = stair.x, z = topZ, level = upper.level, room = upper.id })
		table.insert(nodes, { id = topApproach, x = approachX, z = topZ, level = upper.level, room = upper.id })
		table.insert(edges, { lower.id, bottomApproach })
		table.insert(edges, { bottomApproach, bottom })
		table.insert(edges, { bottom, top })
		table.insert(edges, { top, topApproach })
		table.insert(edges, { topApproach, upper.id })
	end
	for index, passage in ipairs(passages) do
		local corridorZ = (passage.minZ + passage.maxZ) / 2
		local fromInside = `passage{index}:from`
		local fromCorridor = `passage{index}:fromCorridor`
		local toCorridor = `passage{index}:toCorridor`
		local toInside = `passage{index}:to`
		table.insert(nodes, { id = fromInside, x = passage.fromX, z = passage.wallZ + 3, level = 0, room = passage.fromRoom })
		table.insert(nodes, { id = fromCorridor, x = passage.fromX, z = corridorZ, level = 0, room = nil })
		table.insert(nodes, { id = toCorridor, x = passage.toX, z = corridorZ, level = 0, room = nil })
		table.insert(nodes, { id = toInside, x = passage.toX, z = passage.wallZ + 3, level = 0, room = passage.toRoom })
		table.insert(edges, { passage.fromRoom, fromInside })
		table.insert(edges, { fromInside, fromCorridor })
		table.insert(edges, { fromCorridor, toCorridor })
		table.insert(edges, { toCorridor, toInside })
		table.insert(edges, { toInside, passage.toRoom })
	end
	return nodes, edges
end

local cached: Plan? = nil

function MurderMansionPlan.get(): Plan
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local rooms = buildRooms()
	local doors = buildDoors(rooms)
	local stairs = buildStairs()
	local passages = buildPassages()
	local nodes, edges = buildGraph(rooms, doors, stairs, passages)
	local plan: Plan = {
		floorHeight = FLOOR_HEIGHT,
		wallHeight = WALL_HEIGHT,
		doorWidth = DOOR_WIDTH,
		doorHeight = DOOR_HEIGHT,
		rooms = rooms,
		doors = doors,
		stairs = stairs,
		passages = passages,
		nodes = nodes,
		edges = edges,
	}
	cached = plan
	return plan
end

-- Miolo livre do cômodo (longe das paredes, dos móveis e da escada): onde
-- se nasce e onde caem as moedas.
function MurderMansionPlan.openArea(room: Room): Area
	return {
		minX = room.minX + OPEN_MARGIN,
		maxX = room.maxX - OPEN_MARGIN,
		minZ = room.minZ + OPEN_MARGIN,
		maxZ = room.maxZ - OPEN_MARGIN,
	}
end

-- Cômodo em que o ponto (x, z) do andar `level` está, ou nil (escada no
-- meio do caminho conta como o cômodo dela; a passagem secreta, não).
function MurderMansionPlan.roomAt(plan: Plan, x: number, z: number, level: number): string?
	for _, room in ipairs(plan.rooms) do
		if room.level == level and x >= room.minX and x <= room.maxX and z >= room.minZ and z <= room.maxZ then
			return room.id
		end
	end
	return nil
end

-- Nós alcançáveis a partir de `start` seguindo as arestas.
function MurderMansionPlan.reachableFrom(plan: Plan, start: string): { [string]: boolean }
	local neighbors: { [string]: { string } } = {}
	for _, edge in ipairs(plan.edges) do
		local a, b = edge[1], edge[2]
		neighbors[a] = neighbors[a] or {}
		neighbors[b] = neighbors[b] or {}
		table.insert(neighbors[a], b)
		table.insert(neighbors[b], a)
	end
	local seen: { [string]: boolean } = { [start] = true }
	local queue = { start }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, other in ipairs(neighbors[current] or {}) do
			if not seen[other] then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	return seen
end

return table.freeze(MurderMansionPlan)
