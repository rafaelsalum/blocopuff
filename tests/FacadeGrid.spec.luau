--!strict

-- Testes da grade de fachada (rodar com: lune run tests/FacadeGrid.spec.luau).

local FacadeGrid = require("../src/server/data/FacadeGrid")

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

-- Parede de 10 x 6 com uma janela nas colunas 4..5, linhas 2..3, e as
-- colunas 9..10 mais para dentro (profundidade 2).
local function sample(col: number, row: number): number
	if col >= 4 and col <= 5 and row >= 2 and row <= 3 then
		return 0
	end
	return if col >= 9 then 2 else 1
end
local grid = FacadeGrid.new(10, 6, sample)

-- Os retângulos cobrem toda parede e nenhuma abertura, sem sobrepor.
local covered: { [string]: number } = {}
for _, rect in ipairs(FacadeGrid.rects(grid)) do
	for row = rect.row0, rect.row1 do
		for col = rect.col0, rect.col1 do
			local cell = `{col},{row}`
			covered[cell] = (covered[cell] or 0) + 1
		end
	end
end
local missing, overlap, onHole, wrongKey = 0, 0, 0, 0
for row = 1, 6 do
	for col = 1, 10 do
		local count = covered[`{col},{row}`] or 0
		local key = sample(col, row)
		if key == 0 and count > 0 then
			onHole += 1
		elseif key ~= 0 and count == 0 then
			missing += 1
		elseif count > 1 then
			overlap += 1
		end
	end
end
for _, rect in ipairs(FacadeGrid.rects(grid)) do
	for row = rect.row0, rect.row1 do
		for col = rect.col0, rect.col1 do
			if sample(col, row) ~= rect.key then
				wrongKey += 1
			end
		end
	end
end
check("every wall cell is covered", missing == 0)
check("no opening is covered", onHole == 0)
check("no cell is covered twice", overlap == 0)
check("each rect keeps one depth", wrongKey == 0)
check("merging keeps the part count low", #FacadeGrid.rects(grid) <= 6)

-- Parede cheia: sem a janela, numa profundidade só.
check("solid block left of the window", FacadeGrid.solid(grid, 1, 3, 1, 6))
check("block over the window is not solid", not FacadeGrid.solid(grid, 3, 4, 1, 6))
check("block across two depths is not solid", not FacadeGrid.solid(grid, 7, 9, 1, 6))
check("block outside the grid is not solid", not FacadeGrid.solid(grid, 9, 11, 1, 2))

-- Lugares para enfeites: pula a janela e a quina de profundidade.
local spots = FacadeGrid.spots(grid, 2, 1, 6, 2, 1)
local hitWindow = false
for _, col in ipairs(spots) do
	if col == 3 or col == 5 or col == 4 then
		hitWindow = true
	end
end
check("spots avoid the window", not hitWindow)
check("spots find the solid stretches", table.find(spots, 1) ~= nil and table.find(spots, 9) ~= nil)
local everyColumn = FacadeGrid.spots(grid, 2, 1, 6, 1, 1)
check("spots skip a block across depths", table.find(everyColumn, 8) == nil and table.find(everyColumn, 7) ~= nil)

-- Grade vazia não gera nada.
local empty = FacadeGrid.new(4, 4, function()
	return 0
end)
check("empty facade has no rects", #FacadeGrid.rects(empty) == 0)
check("empty facade has no spots", #FacadeGrid.spots(empty, 1, 1, 4, 1, 1) == 0)

print(`FacadeGrid: {passed} passed, {failures} failed`)
if failures > 0 then
	error("FacadeGrid tests failed")
end
