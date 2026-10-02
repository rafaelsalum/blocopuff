--!strict

-- Leitura da grade da arena pelos bots RoboPuff (Fase 5B), sem Roblox: em
-- que célula está uma posição, quão segura é uma célula (vizinhos inteiros),
-- se dá para andar em linha reta sem pisar num buraco e qual bloco escolher
-- como destino. Os testes rodam no Lune (tests/BotGrid.spec.luau).
--
-- Coluna anda em X e linha em Z, como no ArenaService. `intact` marca as
-- células inteiras pela chave `key(floor, row, column)`.

export type Grid = {
	-- Centro da célula (1, 1).
	originX: number,
	originZ: number,
	-- Distância entre centros de células vizinhas (bloco + fresta).
	step: number,
	rows: number,
	columns: number,
}

export type GoalOptions = {
	maxDistance: number,
	-- Células que não servem de destino (piscando antes de cair, por exemplo).
	avoid: { [number]: boolean },
	-- Sorteio entre 0 e 1 (desempata e deixa o bot menos previsível).
	random: () -> number,
	-- Ponto para onde o bot quer ir (um alvo), e quanto isso pesa.
	prefer: { x: number, z: number }?,
	preferWeight: number?,
}

local NEIGHBORS = table.freeze({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
-- Amostras por célula ao conferir um caminho reto.
local SAMPLES_PER_CELL = 3
local SAFETY_WEIGHT = 2
local RANDOM_WEIGHT = 1.5

local BotGrid = {}

function BotGrid.key(floor: number, row: number, column: number): number
	return (floor * 1000000) + (row * 1000) + column
end

function BotGrid.cellOf(grid: Grid, x: number, z: number): (number, number)
	local row = math.floor(((z - grid.originZ) / grid.step) + 0.5) + 1
	local column = math.floor(((x - grid.originX) / grid.step) + 0.5) + 1
	return row, column
end

function BotGrid.center(grid: Grid, row: number, column: number): (number, number)
	return grid.originX + ((column - 1) * grid.step), grid.originZ + ((row - 1) * grid.step)
end

function BotGrid.isInside(grid: Grid, row: number, column: number): boolean
	return row >= 1 and row <= grid.rows and column >= 1 and column <= grid.columns
end

-- Vizinhos inteiros (0 a 4): quanto mais, menor a chance de cair logo.
function BotGrid.safety(intact: { [number]: boolean }, floor: number, row: number, column: number): number
	local count = 0
	for _, offset in ipairs(NEIGHBORS) do
		if intact[BotGrid.key(floor, row + offset[1], column + offset[2])] then
			count += 1
		end
	end
	return count
end

-- Dá para ir em linha reta de um ponto a outro sem passar por buraco?
function BotGrid.isPathClear(grid: Grid, intact: { [number]: boolean }, floor: number, fromX: number, fromZ: number, toX: number, toZ: number): boolean
	local dx = toX - fromX
	local dz = toZ - fromZ
	local distance = math.sqrt((dx * dx) + (dz * dz))
	local samples = math.max(1, math.ceil(distance / (grid.step / SAMPLES_PER_CELL)))
	for index = 0, samples do
		local t = index / samples
		local row, column = BotGrid.cellOf(grid, fromX + (dx * t), fromZ + (dz * t))
		if not BotGrid.isInside(grid, row, column) or not intact[BotGrid.key(floor, row, column)] then
			return false
		end
	end
	return true
end

-- Melhor bloco inteiro e alcançável em linha reta, até `maxDistance`:
-- prefere os mais seguros, perto de `prefer` (se houver), com um pouco de
-- sorteio. nil se não houver nenhum.
function BotGrid.chooseGoal(grid: Grid, intact: { [number]: boolean }, floor: number, fromX: number, fromZ: number, options: GoalOptions): (number?, number?)
	local bestRow: number? = nil
	local bestColumn: number? = nil
	local bestScore = -math.huge
	local prefer = options.prefer
	local preferWeight = options.preferWeight or 0
	for row = 1, grid.rows do
		for column = 1, grid.columns do
			local cellKey = BotGrid.key(floor, row, column)
			if intact[cellKey] and not options.avoid[cellKey] then
				local x, z = BotGrid.center(grid, row, column)
				local distance = math.sqrt(((x - fromX) ^ 2) + ((z - fromZ) ^ 2))
				if distance <= options.maxDistance and BotGrid.isPathClear(grid, intact, floor, fromX, fromZ, x, z) then
					local score = (BotGrid.safety(intact, floor, row, column) * SAFETY_WEIGHT) + (options.random() * RANDOM_WEIGHT)
					if prefer ~= nil then
						local away = math.sqrt(((x - prefer.x) ^ 2) + ((z - prefer.z) ^ 2))
						score -= preferWeight * (away / grid.step)
					end
					if score > bestScore then
						bestScore = score
						bestRow = row
						bestColumn = column
					end
				end
			end
		end
	end
	return bestRow, bestColumn
end

return table.freeze(BotGrid)
