-- Testes da leitura da grade da arena pelos bots RoboPuff (Fase 5B).
-- Rodar: lune run tests/BotGrid.spec

local BotGrid = require("../src/server/data/BotGrid")

local failures = 0
local passed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

-- Grade 5x5, passo 6, célula (1,1) centrada em (0, 0). Coluna = X, linha = Z.
local grid = { originX = 0, originZ = 0, step = 6, rows = 5, columns = 5 }

local function fullFloor(floor: number): { [number]: boolean }
	local intact: { [number]: boolean } = {}
	for row = 1, 5 do
		for column = 1, 5 do
			intact[BotGrid.key(floor, row, column)] = true
		end
	end
	return intact
end

local function noRandom(): number
	return 0
end

-- Posição → célula.
local row, column = BotGrid.cellOf(grid, 0.4, -0.4)
check("origin is cell 1,1", row == 1 and column == 1)
row, column = BotGrid.cellOf(grid, 12.2, 6.1)
check("x picks the column and z the row", row == 2 and column == 3)
check("outside the grid is not inside", not BotGrid.isInside(grid, 0, 3))
check("cell 5,5 is inside", BotGrid.isInside(grid, 5, 5))
local x, z = BotGrid.center(grid, 2, 3)
check("center of cell 2,3", x == 12 and z == 6)

-- Vizinhos inteiros.
local intact = fullFloor(1)
check("middle cell is fully safe", BotGrid.safety(intact, 1, 3, 3) == 4)
check("corner cell has two neighbors", BotGrid.safety(intact, 1, 1, 1) == 2)
intact[BotGrid.key(1, 3, 4)] = nil
check("a hole lowers the safety", BotGrid.safety(intact, 1, 3, 3) == 3)
check("another floor is separate", BotGrid.safety(intact, 2, 3, 3) == 0)

-- Caminho reto sem buraco.
check("clear path on a full row", BotGrid.isPathClear(grid, fullFloor(1), 1, 0, 0, 24, 0))
local holed = fullFloor(1)
holed[BotGrid.key(1, 1, 3)] = nil
check("hole blocks the straight path", not BotGrid.isPathClear(grid, holed, 1, 0, 0, 24, 0))
check("path around the hole is clear", BotGrid.isPathClear(grid, holed, 1, 0, 6, 24, 6))
check("path leaving the grid is not clear", not BotGrid.isPathClear(grid, fullFloor(1), 1, 0, 0, -12, 0))

-- Escolha do destino.
local goalRow, goalColumn = BotGrid.chooseGoal(grid, fullFloor(1), 1, 0, 0, {
	maxDistance = 30,
	avoid = {},
	random = noRandom,
})
check("goal exists on a full floor", goalRow ~= nil and goalColumn ~= nil)
check("goal prefers fully safe cells", goalRow ~= nil and goalColumn ~= nil and BotGrid.safety(fullFloor(1), 1, goalRow, goalColumn) == 4)

local towardRow, towardColumn = BotGrid.chooseGoal(grid, fullFloor(1), 1, 12, 12, {
	maxDistance = 30,
	avoid = {},
	random = noRandom,
	prefer = { x = 18, z = 18 },
	preferWeight = 1,
})
check("goal moves toward the preferred point", towardRow == 4 and towardColumn == 4)

local avoid: { [number]: boolean } = {}
for r = 1, 5 do
	for c = 1, 5 do
		if not (r == 5 and c == 5) then
			avoid[BotGrid.key(1, r, c)] = true
		end
	end
end
local safeRow, safeColumn = BotGrid.chooseGoal(grid, fullFloor(1), 1, 24, 24, { maxDistance = 30, avoid = avoid, random = noRandom })
check("avoided cells are never chosen", safeRow == 5 and safeColumn == 5)

local island: { [number]: boolean } = { [BotGrid.key(1, 1, 1)] = true, [BotGrid.key(1, 1, 3)] = true }
local islandRow, islandColumn = BotGrid.chooseGoal(grid, island, 1, 0, 0, { maxDistance = 30, avoid = {}, random = noRandom })
check("unreachable cells are skipped", islandRow == 1 and islandColumn == 1)
check("no intact cells gives nil", BotGrid.chooseGoal(grid, {}, 1, 0, 0, { maxDistance = 30, avoid = {}, random = noRandom }) == nil)

print(`BotGrid: {passed} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} BotGrid checks failed`)
end
