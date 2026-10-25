--!strict

-- Testes da floresta do lado de fora (rodar com: lune run tests/ForestPlan.spec.luau).

local ForestPlan = require("../src/server/data/ForestPlan")

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

local SETTINGS: ForestPlan.Settings = {
	Seed = 42,
	CellSize = 20,
	NearChance = 0.9,
	FarChance = 0.2,
	FarRadius = 300,
	ClearingMargin = 30,
	PathMargin = 6,
	MinScale = 1.5,
	MaxScale = 2.5,
	MaxSlope = 0.7,
	TreeLine = 150,
	DeadChance = 0.1,
	ShadowRadius = 150,
	CenterX = 0,
	CenterZ = 0,
	HalfExtent = 400,
	GroundY = 100,
	HomeX = 0,
	HomeZ = 0,
}

-- Uma casa de raio 50 no meio, um lago a leste (x > 250), uma encosta
-- íngreme ao norte (z < -250), montanha alta no sul (z > 300) e um caminho
-- de pedra em x = -150 (meia largura 3).
local function sample(x: number, z: number): ForestPlan.Sample
	local fromHome = math.sqrt(x * x + z * z)
	return {
		height = if z > 300 then 100 + 200 else 100,
		slope = if z < -250 then 1.2 else 0.1,
		clearance = math.max(0, fromHome - 50),
		path = math.max(0, math.abs(x + 150) - 3),
		wet = x > 250,
		inside = true,
	}
end

local trees = ForestPlan.plan(SETTINGS, sample, 5)
check("forest has trees", #trees > 50)

local inClearing, wet, steep, high, badVariant, badScale, dead, onPath = 0, 0, 0, 0, 0, 0, 0, 0
for _, tree in ipairs(trees) do
	if math.sqrt(tree.x * tree.x + tree.z * tree.z) < 50 + 30 then
		inClearing += 1
	end
	if tree.x > 250 then
		wet += 1
	end
	if tree.z < -250 then
		steep += 1
	end
	if tree.z > 300 then
		high += 1
	end
	local count = if tree.kind == "Dead" then 2 else 5
	if tree.variant < 1 or tree.variant > count then
		badVariant += 1
	end
	if tree.scale < 1.5 or tree.scale > 2.5 then
		badScale += 1
	end
	if tree.kind == "Dead" then
		dead += 1
	end
	if math.abs(tree.x + 150) < 3 + 6 then
		onPath += 1
	end
end
check("no tree on the home lawn", inClearing == 0)
check("no tree in the water", wet == 0)
check("no tree on steep slopes", steep == 0)
check("no tree above the tree line", high == 0)
check("no tree on or beside the stone path", onPath == 0)
check("variants stay in range", badVariant == 0)
check("scales stay in range", badScale == 0)
check("a few trees are dead", dead > 0 and dead < #trees / 4)

-- Sombras só perto da casa.
local farShadow = 0
for _, tree in ipairs(trees) do
	if tree.shadow and math.sqrt(tree.x * tree.x + tree.z * tree.z) > 150 then
		farShadow += 1
	end
end
check("only nearby trees cast shadows", farShadow == 0)

-- Mesma semente, mesma floresta; outra semente, outra floresta.
local again = ForestPlan.plan(SETTINGS, sample, 5)
check("same seed plants the same forest", #again == #trees and again[1].x == trees[1].x and again[#again].z == trees[#trees].z)
local other = table.clone(SETTINGS)
other.Seed = 7
local different = ForestPlan.plan(other, sample, 5)
check("another seed plants another forest", different[1].x ~= trees[1].x)

-- Mais rala longe do centro.
local near, far = 0, 0
for _, tree in ipairs(trees) do
	local distance = math.sqrt(tree.x * tree.x + tree.z * tree.z)
	if distance < 250 then
		near += 1
	elseif distance > 300 and math.abs(tree.z) <= 250 and tree.x <= 250 then
		far += 1
	end
end
check("forest is denser near the center", near > far)

-- Fora do terreno não nasce nada.
local outside = ForestPlan.plan(SETTINGS, function(_x: number, _z: number): ForestPlan.Sample
	return { height = 100, slope = 0, clearance = 1000, path = 1000, wet = false, inside = false }
end, 5)
check("nothing grows outside the terrain", #outside == 0)

print(`ForestPlan: {passed} passed, {failures} failed`)
if failures > 0 then
	error("ForestPlan tests failed")
end
