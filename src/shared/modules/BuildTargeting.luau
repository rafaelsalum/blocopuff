--!strict

-- Alvo do modo Construir do Puffador do Cofre. Só é possível reconstruir
-- blocos derrubados da própria grade da arena (nada de blocos soltos no ar
-- ou paredes): o raio da mira é cruzado com o plano de cada andar e o
-- primeiro buraco que ele atravessa, antes de bater em algo, é o alvo.
-- Usado pelo servidor (validação) e pelo cliente (prévia), cada um com a
-- sua fonte do estado dos blocos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)

type ArenaConfig = GameConfig.ArenaConfig

export type CellState = "Destroyed" | "Intact"
export type Cell = {
	floor: number,
	row: number,
	column: number,
	center: Vector3,
}
export type StateLookup = (floor: number, row: number, column: number) -> CellState?

local MIN_VERTICAL = 1e-3

local BuildTargeting = {}

local function gridOrigin(arena: ArenaConfig): (number, number, number, number)
	local width, depth = BuildingLayout.getFloorSize(arena)
	local startX = arena.Position.X - (width / 2) + (arena.BlockSize.X / 2)
	local startZ = arena.Position.Z - (depth / 2) + (arena.BlockSize.Z / 2)
	return startX, startZ, arena.BlockSize.X + arena.BlockGap, arena.BlockSize.Z + arena.BlockGap
end

function BuildTargeting.cellCenter(arena: ArenaConfig, floor: number, row: number, column: number): Vector3
	local startX, startZ, stepX, stepZ = gridOrigin(arena)
	return Vector3.new(startX + ((column - 1) * stepX), BuildingLayout.getFloorY(arena, floor), startZ + ((row - 1) * stepZ))
end

-- Linha e coluna da célula sob uma posição (X/Z), ou nil fora da grade.
function BuildTargeting.cellAt(arena: ArenaConfig, position: Vector3): (number?, number?)
	local startX, startZ, stepX, stepZ = gridOrigin(arena)
	local column = math.floor(((position.X - startX) / stepX) + 0.5) + 1
	local row = math.floor(((position.Z - startZ) / stepZ) + 0.5) + 1
	if row < 1 or row > arena.Rows or column < 1 or column > arena.Columns then
		return nil, nil
	end
	return row, column
end

-- Primeiro bloco derrubado que o raio atravessa. `stopDistance` é a
-- distância até o que a mira acertou: o raio não passa através de paredes
-- nem de blocos inteiros. `maxDistance` limita o alcance da construção.
function BuildTargeting.findTarget(
	arena: ArenaConfig,
	origin: Vector3,
	direction: Vector3,
	maxDistance: number,
	stopDistance: number,
	getState: StateLookup
): Cell?
	if direction.Magnitude < 1e-4 or math.abs(direction.Unit.Y) < MIN_VERTICAL then
		return nil
	end
	local unit = direction.Unit
	local limit = math.min(maxDistance, stopDistance + (arena.BlockSize.Y / 2))
	local best: Cell? = nil
	local bestDistance = math.huge
	for floor = 1, arena.FloorCount do
		local planeY = BuildingLayout.getFloorY(arena, floor)
		local distance = (planeY - origin.Y) / unit.Y
		if distance > 0 and distance <= limit and distance < bestDistance then
			local point = origin + (unit * distance)
			local row, column = BuildTargeting.cellAt(arena, point)
			if row ~= nil and column ~= nil and getState(floor, row, column) == "Destroyed" then
				best = { floor = floor, row = row, column = column, center = BuildTargeting.cellCenter(arena, floor, row, column) }
				bestDistance = distance
			end
		end
	end
	return best
end

return table.freeze(BuildTargeting)
