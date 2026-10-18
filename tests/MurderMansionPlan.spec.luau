--!strict

-- Testes da planta da Ala do Assassinato (Fase 5E.2)
-- (rodar com: lune run tests/MurderMansionPlan.spec.luau).

local MurderMansionPlan = require("../src/server/data/MurderMansionPlan")

local passed = 0
local failures = 0
local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

local plan = MurderMansionPlan.get()

local roomsById: { [string]: MurderMansionPlan.Room } = {}
local perLevel: { [number]: number } = {}
for _, room in ipairs(plan.rooms) do
	roomsById[room.id] = room
	perLevel[room.level] = (perLevel[room.level] or 0) + 1
end
check("two floors with six rooms each", perLevel[0] == 6 and perLevel[1] == 6)

-- Cômodos do mesmo andar não se sobrepõem.
local overlap = false
for i, a in ipairs(plan.rooms) do
	for j, b in ipairs(plan.rooms) do
		if i < j and a.level == b.level and a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ then
			overlap = true
		end
	end
end
check("rooms on the same floor never overlap", not overlap)

-- Cada porta fica na parede comum entre os dois cômodos que liga.
local function onSharedWall(door: MurderMansionPlan.Door): boolean
	local a, b = roomsById[door.from], roomsById[door.to]
	if a == nil or b == nil or a.level ~= b.level or door.level ~= a.level then
		return false
	end
	local half = plan.doorWidth / 2
	if door.axis == "Z" then
		-- Parede em x constante, porta ao longo de z.
		local sharesX = a.maxX == door.x and b.minX == door.x or b.maxX == door.x and a.minX == door.x
		local inside = door.z - half >= math.max(a.minZ, b.minZ) and door.z + half <= math.min(a.maxZ, b.maxZ)
		return sharesX and inside
	end
	local sharesZ = a.maxZ == door.z and b.minZ == door.z or b.maxZ == door.z and a.minZ == door.z
	local inside = door.x - half >= math.max(a.minX, b.minX) and door.x + half <= math.min(a.maxX, b.maxX)
	return sharesZ and inside
end
local doorsOk = #plan.doors > 0
for _, door in ipairs(plan.doors) do
	doorsOk = doorsOk and onSharedWall(door)
end
check("every door sits on the wall shared by its rooms", doorsOk)

-- Duas escadas, em lados opostos, ligando o térreo ao andar de cima.
check("two staircases", #plan.stairs == 2)
local opposite = #plan.stairs == 2 and plan.stairs[1].x * plan.stairs[2].x < 0
check("staircases on opposite sides", opposite)
local stairsOk = true
for _, stair in ipairs(plan.stairs) do
	local lower, upper = roomsById[stair.lowerRoom], roomsById[stair.upperRoom]
	stairsOk = stairsOk
		and lower ~= nil
		and upper ~= nil
		and lower.level == 0
		and upper.level == 1
		and stair.x - stair.width / 2 >= lower.minX
		and stair.x + stair.width / 2 <= lower.maxX
		and math.min(stair.bottomZ, stair.topZ) >= lower.minZ
		and math.max(stair.bottomZ, stair.topZ) <= lower.maxZ
end
check("staircases go from the ground floor to the upper floor inside their rooms", stairsOk)
local gentle = true
for _, stair in ipairs(plan.stairs) do
	local run = math.abs(stair.topZ - stair.bottomZ)
	gentle = gentle and math.deg(math.atan(plan.floorHeight / run)) <= 35
end
check("stairs are gentle enough to walk", gentle)

check("one secret passage", #plan.passages == 1)

-- Navegação: tudo alcançável a partir de qualquer cômodo.
local nodeIds: { [string]: boolean } = {}
for _, node in ipairs(plan.nodes) do
	nodeIds[node.id] = true
end
local edgesOk = true
for _, edge in ipairs(plan.edges) do
	edgesOk = edgesOk and nodeIds[edge[1]] == true and nodeIds[edge[2]] == true
end
check("edges only join existing nodes", edgesOk)
local reachable = MurderMansionPlan.reachableFrom(plan, plan.rooms[1].id)
local allReached = true
for _, node in ipairs(plan.nodes) do
	allReached = allReached and reachable[node.id] == true
end
check("every node is reachable", allReached)

-- Rotas de fuga: todo cômodo tem pelo menos duas saídas.
local exits: { [string]: number } = {}
for _, door in ipairs(plan.doors) do
	exits[door.from] = (exits[door.from] or 0) + 1
	exits[door.to] = (exits[door.to] or 0) + 1
end
for _, stair in ipairs(plan.stairs) do
	exits[stair.lowerRoom] = (exits[stair.lowerRoom] or 0) + 1
	exits[stair.upperRoom] = (exits[stair.upperRoom] or 0) + 1
end
local twoExits = true
for _, room in ipairs(plan.rooms) do
	twoExits = twoExits and (exits[room.id] or 0) >= 2
end
check("every room has at least two exits", twoExits)

-- Nós de cômodo e da escada ficam dentro do cômodo certo, longe das paredes.
local inside = true
for _, node in ipairs(plan.nodes) do
	local room = if node.room ~= nil then roomsById[node.room] else nil
	if room ~= nil then
		inside = inside
			and node.level == room.level
			and node.x > room.minX + 1
			and node.x < room.maxX - 1
			and node.z > room.minZ + 1
			and node.z < room.maxZ - 1
	end
end
check("room nodes are inside their rooms", inside)

-- Ninguém chega à escada em diagonal (cairia pelo vão ou bateria nos
-- degraus): o cômodo liga a um ponto de aproximação fora da faixa da escada,
-- e só ele liga ao pé ou ao alto.
local nodeById: { [string]: MurderMansionPlan.Node } = {}
for _, node in ipairs(plan.nodes) do
	nodeById[node.id] = node
end
local approachesOk = true
for index, stair in ipairs(plan.stairs) do
	for _, ending in ipairs({ "bottom", "top" }) do
		local approach = nodeById[`stair{index}:{ending}Approach`]
		local stairEnd = nodeById[`stair{index}:{ending}`]
		local outside = approach ~= nil and math.abs(approach.x - stair.x) > stair.width / 2 + 1
		local aligned = approach ~= nil and stairEnd ~= nil and approach.z == stairEnd.z
		approachesOk = approachesOk and outside and aligned
		for _, edge in ipairs(plan.edges) do
			local touchesEnd = edge[1] == `stair{index}:{ending}` or edge[2] == `stair{index}:{ending}`
			local other = if edge[1] == `stair{index}:{ending}` then edge[2] else edge[1]
			if touchesEnd and roomsById[other] ~= nil then
				approachesOk = false
			end
		end
	end
end
check("stairs are reached straight from an approach point", approachesOk)

-- Área livre para nascer e para moedas: dentro do cômodo, sem a escada.
local clear = true
for _, room in ipairs(plan.rooms) do
	local area = MurderMansionPlan.openArea(room)
	clear = clear and area.minX > room.minX and area.maxX < room.maxX and area.minZ > room.minZ and area.maxZ < room.maxZ
	for _, stair in ipairs(plan.stairs) do
		if stair.lowerRoom == room.id or stair.upperRoom == room.id then
			local stairMin, stairMax = stair.x - stair.width / 2, stair.x + stair.width / 2
			clear = clear and (area.maxX <= stairMin or area.minX >= stairMax)
		end
	end
end
check("open areas avoid walls and stairs", clear)

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("MurderMansionPlan tests failed")
end
