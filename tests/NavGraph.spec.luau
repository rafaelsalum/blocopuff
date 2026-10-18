--!strict

-- Testes do grafo de navegação dos bots (Fase 5E.3)
-- (rodar com: lune run tests/NavGraph.spec.luau).

local NavGraph = require("../src/server/data/NavGraph")
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
local graph = NavGraph.new(plan.nodes, plan.edges, plan.floorHeight)

local function contains(path: { string }?, id: string): boolean
	if path == nil then
		return false
	end
	for _, step in ipairs(path) do
		if step == id then
			return true
		end
	end
	return false
end

-- Vizinhos passam pela porta.
local toDining = NavGraph.path(graph, "library", "dining")
check("neighbour path goes through the door", toDining ~= nil and #toDining == 3 and toDining[2] == "door:library:dining")
check("path starts and ends at the given nodes", toDining ~= nil and toDining[1] == "library" and toDining[#toDining] == "dining")

-- Andar de cima pela escada (e pelos pontos de aproximação).
local upstairs = NavGraph.path(graph, "hall", "music")
check("path to the upper floor uses a staircase", contains(upstairs, "stair1:bottom") or contains(upstairs, "stair2:bottom"))
check("stairs are taken through the approach points", contains(upstairs, "stair1:bottomApproach") or contains(upstairs, "stair2:bottomApproach"))

-- Caminho mais curto: Biblioteca → Cozinha pela passagem secreta é mais
-- curto que pelas portas? Pelo menos chega lá.
local secret = NavGraph.path(graph, "library", "kitchen")
check("library reaches the kitchen", secret ~= nil and secret[#secret] == "kitchen")

check("path to itself is just the node", (function()
	local path = NavGraph.path(graph, "hall", "hall")
	return path ~= nil and #path == 1 and path[1] == "hall"
end)())
check("unknown nodes have no path", NavGraph.path(graph, "hall", "nowhere") == nil)

-- Grafo desconectado não trava.
local island = NavGraph.new({ { id = "a", x = 0, z = 0, level = 0 }, { id = "b", x = 10, z = 0, level = 0 } }, {}, 15)
check("disconnected graph returns nil", NavGraph.path(island, "a", "b") == nil)

-- Ponto mais perto, no mesmo andar.
check("nearest node on the ground floor", NavGraph.nearest(graph, -32, -17, 0) == "library")
check("nearest node respects the floor", NavGraph.nearest(graph, -32, -17, 1) == "baronBedroom")

-- Cômodo em que um ponto está.
check("room at a point", MurderMansionPlan.roomAt(plan, -32, -17, 0) == "library")
check("room at a point upstairs", MurderMansionPlan.roomAt(plan, 32, 20, 1) == "greenhouse")
check("no room outside the mansion", MurderMansionPlan.roomAt(plan, 0, -39, 0) == nil)

-- Fuga: um cômodo longe da ameaça e fora do cômodo dela.
local rooms: { string } = {}
for _, room in ipairs(plan.rooms) do
	table.insert(rooms, room.id)
end
local fleeOk = true
for seed = 1, 20 do
	local value = seed / 21
	local target = NavGraph.fleeTarget(graph, rooms, -32, -18, 0, "library", function()
		return value
	end)
	local node = NavGraph.node(graph, target)
	local far = node ~= nil and (math.abs(node.x + 32) + math.abs(node.z + 18) >= 60 or node.level ~= 0)
	fleeOk = fleeOk and target ~= "library" and far
end
check("flee target is far from the threat", fleeOk)

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("NavGraph tests failed")
end
