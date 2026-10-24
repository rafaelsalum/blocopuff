--!strict

-- Testes do chão do lado de fora (rodar com: lune run tests/TerrainShape.spec.luau).

local TerrainShape = require("../src/server/data/TerrainShape")

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

local TERRAIN: TerrainShape.Terrain = {
	GroundY = 100,
	HalfExtent = 1000,
	HillAmplitude = 8,
	HillScale = 200,
	Mountains = { CenterX = 0, CenterZ = 0, InnerRadius = 600, OuterRadius = 900, PeakHeight = 300 },
	Lake = { X = 400, Z = 0, Radius = 100, WaterY = 96, Depth = 15, ShoreWobble = 0.1 },
}

local HOME: TerrainShape.Zone = { kind = "Box", ax = -50, az = -50, bx = 50, bz = 50, radius = 0, y = 120, blend = 60 }
local ISLAND: TerrainShape.Zone = { kind = "Circle", ax = 0, az = -300, bx = 0, bz = 0, radius = 40, y = 130, blend = 40 }
local BRIDGE: TerrainShape.Zone = { kind = "Segment", ax = 0, az = -50, bx = 0, bz = -260, radius = 6, y = 125, blend = 20 }
local PIT: TerrainShape.Carve = { minX = -30, maxX = 30, minZ = -30, maxZ = 30 }

local shape = TerrainShape.new(TERRAIN, { HOME, ISLAND, BRIDGE }, { PIT })

-- Em cima das construções o chão é plano na altura delas.
check("ground is flat under the home", TerrainShape.heightAt(shape, 10, 40) == 120)
check("ground is flat under the island", TerrainShape.heightAt(shape, 20, -300) == 130)
check("ground follows the bridge strip", TerrainShape.heightAt(shape, 3, -150) == 125)

-- Longe delas volta ao chão natural; no meio do caminho fica entre os dois.
local natural = TerrainShape.naturalHeight(shape, 200, 200)
check("far from buildings ground is natural", TerrainShape.heightAt(shape, 200, 200) == natural)
local edge = TerrainShape.heightAt(shape, 80, 0)
local edgeNatural = TerrainShape.naturalHeight(shape, 80, 0)
check("blend sits between natural and flat", edge > math.min(edgeNatural, 120) and edge < math.max(edgeNatural, 120))

-- Morros suaves perto do centro, montanhas no anel de fora.
check("hills stay gentle near the center", math.abs(TerrainShape.naturalHeight(shape, 150, -120) - 100) <= 12)
check("mountains rise past the outer radius", TerrainShape.naturalHeight(shape, 950, 0) >= 100 + 0.55 * 300 - 12)
check("mountains are taller than the hills", TerrainShape.naturalHeight(shape, 0, 950) > TerrainShape.naturalHeight(shape, 0, 500) + 100)

-- O lago: fundo abaixo da água no meio, margem logo acima dela.
check("lake bottom is under the water", TerrainShape.heightAt(shape, 400, 0) < 96 - 10)
check("lake center counts as lake", TerrainShape.inLake(shape, 400, 0))
check("far from the lake is not lake", not TerrainShape.inLake(shape, 0, 400))
check("lake bed is mud", TerrainShape.materialAt(shape, 400, 0, 85, 0.1) == "Mud")

-- O poço da Arena fica sem terreno; a coluna que encosta nele também.
check("pit is carved", TerrainShape.isCarved(shape, 0, 0, 2))
check("column touching the pit is carved", TerrainShape.isCarved(shape, 31, 0, 2))
check("outside the pit is not carved", not TerrainShape.isCarved(shape, 40, 0, 2))

-- Distância até a construção mais perto.
check("clearance is zero on a building", TerrainShape.clearance(shape, 0, 0) == 0)
check("clearance grows away from buildings", TerrainShape.clearance(shape, 100, 0) > 40)

-- Dentro do quadrado do terreno.
check("center is inside the terrain", TerrainShape.inBounds(shape, 0, 0))
check("beyond the extent is outside", not TerrainShape.inBounds(shape, 1100, 0))

-- Materiais: pedra nas encostas íngremes e no alto, grama no plano.
check("steep slope is rock", TerrainShape.materialAt(shape, 200, 200, 110, 1.5) == "Rock")
check("medium slope is slate", TerrainShape.materialAt(shape, 200, 200, 110, 0.8) == "Slate")
check("summit is rock", TerrainShape.materialAt(shape, 200, 200, 100 + 260, 0.2) == "Rock")
local flat = TerrainShape.materialAt(shape, 200, 200, 101, 0.1)
check("flat ground is grassy", flat == "Grass" or flat == "LeafyGrass" or flat == "Ground")
check("flat slope is measured as gentle", TerrainShape.slopeAt(shape, 10, 10, 4) < 0.05)

print(`TerrainShape: {passed} passed, {failures} failed`)
if failures > 0 then
	error("TerrainShape tests failed")
end
