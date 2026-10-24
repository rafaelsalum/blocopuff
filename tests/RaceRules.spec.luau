--!strict

-- Testes das regras da Corrida da Torre do Relógio (Fase 5D.2)
-- (rodar com: lune run tests/RaceRules.spec.luau).

local RaceRules = require("../src/server/data/RaceRules")

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

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local SPIRAL: RaceRules.Spiral = {
	radius = 28,
	turns = 4,
	climbPerTurn = 24,
	baseY = 100,
}

-- Espiral: começa na base e sobe um andar por volta.
local x0, y0, z0 = RaceRules.spiralPoint(SPIRAL, 0)
check("spiral starts at the base", near(y0, 100) and near(x0, 28) and near(z0, 0))
local _, yHalf = RaceRules.spiralPoint(SPIRAL, 0.5)
check("half a turn climbs half a floor", near(yHalf, 112))
local x1, y1, z1 = RaceRules.spiralPoint(SPIRAL, 1)
check("one turn is back on the same side, one floor up", near(y1, 124) and near(x1, 28) and math.abs(z1) < 1e-6)
local _, yTop = RaceRules.spiralPoint(SPIRAL, 4)
check("top height", near(yTop, 196) and near(RaceRules.topY(SPIRAL), 196))
local _, yOver = RaceRules.spiralPoint(SPIRAL, 9)
check("spiral clamps past the top", near(yOver, 196))

-- Pontos do caminho: começo e fim certos, sempre subindo.
local path = RaceRules.pathTurns(SPIRAL, 16)
check("path has turns * segments + 1 points", #path == 65)
check("path starts at 0 and ends at the top", near(path[1], 0) and near(path[#path], 4))
local increasing = true
for index = 2, #path do
	increasing = increasing and path[index] > path[index - 1]
end
check("path always climbs", increasing)

-- Checkpoints no fim de cada volta, menos a última (é a chegada).
local checkpoints = RaceRules.checkpointHeights(SPIRAL, 3)
check("three checkpoints", #checkpoints == 3)
check("checkpoints at the end of turns 1..3", near(checkpoints[1], 124) and near(checkpoints[2], 148) and near(checkpoints[3], 172))
check("no checkpoint below the first", RaceRules.checkpointFor(110, checkpoints, 2) == 0)
check("checkpoint reached at its height", RaceRules.checkpointFor(123, checkpoints, 2) == 1)
check("highest checkpoint reached", RaceRules.checkpointFor(175, checkpoints, 2) == 3)
local fewer = RaceRules.checkpointHeights(SPIRAL, 9)
check("checkpoints never pass turns - 1", #fewer == 3)

-- Queda: volta ao checkpoint só se caiu bem abaixo dele.
check("small drop keeps going", not RaceRules.shouldReturn(140, 148, 10))
check("big drop returns to checkpoint", RaceRules.shouldReturn(130, 148, 10))
check("no checkpoint never returns above the floor", not RaceRules.shouldReturn(90, nil, 10))
check("falling off the base returns to start", RaceRules.shouldReturn(70, nil, 10, 100))

-- Classificação: chegada primeiro (por ordem), depois altura.
local ranked = RaceRules.rank({
	{ id = 1, finishOrder = nil, bestHeight = 150 },
	{ id = 2, finishOrder = 2, bestHeight = 196 },
	{ id = 3, finishOrder = 1, bestHeight = 196 },
	{ id = 4, finishOrder = nil, bestHeight = 170 },
	{ id = 5, finishOrder = nil, bestHeight = 150 },
})
check("finishers first in order", ranked[3] == 1 and ranked[2] == 2)
check("then by height", ranked[4] == 3)
check("same height ties", ranked[1] == 4 and ranked[5] == 4)

-- Subida possível: andar, pular e ser empurrado passam; teletransporte não.
check("normal climb is plausible", RaceRules.plausibleRise(120, 125, 0.2, 60))
check("falling is always plausible", RaceRules.plausibleRise(150, 110, 0.2, 60))
check("teleport to the top is not", not RaceRules.plausibleRise(110, 196, 0.2, 60))
check("rise limit scales with time", RaceRules.plausibleRise(110, 130, 0.5, 60))

-- Checkpoints em ordem: não dá para pular um.
check("next checkpoint in order", RaceRules.nextCheckpoint(0, 1) == 1)
check("cannot skip checkpoints", RaceRules.nextCheckpoint(0, 3) == 1)
check("never goes back", RaceRules.nextCheckpoint(2, 1) == 2)

-- Fim da corrida.
check("ends when the podium is full", RaceRules.isOver(3, 6, 3))
check("not over with two finishers of six", not RaceRules.isOver(2, 6, 3))
check("small race ends when everyone finished", RaceRules.isOver(2, 2, 3))
check("never over with nobody racing", not RaceRules.isOver(0, 0, 3))

-- Ritmo dos obstáculos: começa calmo e acelera até o mínimo.
check("hazards start slow", near(RaceRules.hazardInterval(0, 3, 1.2), 3))
check("hazards end fast", near(RaceRules.hazardInterval(1, 3, 1.2), 1.2))
check("hazards halfway", near(RaceRules.hazardInterval(0.5, 3, 1.2), 2.1))
check("hazard progress is clamped", near(RaceRules.hazardInterval(5, 3, 1.2), 1.2))

-- Barril: acerta quem está perto e não pulou por cima.
check("barrel hits close", RaceRules.barrelHits(1, 0, 3, 2.5, 4))
check("barrel misses far", not RaceRules.barrelHits(6, 0, 3, 2.5, 4))
check("jumping over the barrel dodges", not RaceRules.barrelHits(1, 5, 3, 2.5, 4))

-- Mureta e barreira da torre (Fase 5F).
check("parapet sits on the outer edge", near(RaceRules.parapetRadius(42, 24, 2), 55))
check("barrier stops below the next turn", near(RaceRules.barrierHeight(30, 2, 3.5, 1), 23.5))
check("barrier never negative", near(RaceRules.barrierHeight(4, 2, 3.5, 1), 0))
check("arc contains its middle", RaceRules.inArc(0.2, 0, 1))
check("arc excludes outside", not RaceRules.inArc(1.5, 0, 1))
check("arc wraps around zero", RaceRules.inArc(0.05, -0.7, 0.14) and RaceRules.inArc(2 * math.pi - 0.3, -0.7, 0.14))
check("wrapped arc excludes the far side", not RaceRules.inArc(math.pi, -0.7, 0.14))

-- Obstáculos novos (Fase 5F.3).
check("band hits inside", RaceRules.bandHits(2, 1, 0, 5.5, 2, 6))
check("band misses beside", not RaceRules.bandHits(7, 1, 0, 5.5, 2, 6))
check("band misses ahead", not RaceRules.bandHits(2, 3, 0, 5.5, 2, 6))
check("jumping over the books dodges", not RaceRules.bandHits(0, 0, 6.5, 5.5, 2, 6))
check("band ignores the turn below", not RaceRules.bandHits(0, 0, -25, 5.5, 2, 6))
check("hand hits a racer on the floor in its path", RaceRules.handSweeps(0.1, 0.2, 0.15, 40, 30, 54, 3, 4.8))
check("hand misses a jumping racer", not RaceRules.handSweeps(0.1, 0.2, 0.15, 40, 30, 54, 5.5, 4.8))
check("hand misses outside its sweep", not RaceRules.handSweeps(0.1, 0.2, 0.4, 40, 30, 54, 3, 4.8))
check("hand misses beyond its length", not RaceRules.handSweeps(0.1, 0.2, 0.15, 58, 30, 54, 3, 4.8))
check("hand sweeps back the other way", RaceRules.handSweeps(0.2, 0.1, 0.15, 40, 30, 54, 3, 4.8))
check("hand sweeps across zero", RaceRules.handSweeps(-0.05, 0.05, 2 * math.pi - 0.01, 40, 30, 54, 3, 4.8))
do
	local x, y, z = RaceRules.downhillPush(0, 1, 36, 14)
	check("push goes against the climb", near(x, 0) and near(z, -36))
	check("push lifts a little", near(y, 14))
	local px, _, pz = RaceRules.downhillPush(3, 4, 10, 0)
	check("push keeps the downhill speed", near(math.sqrt(px * px + pz * pz), 10))
	local ox, oy, oz = RaceRules.downhillPush(0, 0, 10, 5)
	check("push without tangent only lifts", near(ox, 0) and near(oy, 5) and near(oz, 0))
end

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("RaceRules tests failed")
end
