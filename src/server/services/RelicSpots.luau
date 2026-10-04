--!strict

-- Onde as relíquias ficam (Fase 5C.2). Cada esconderijo é uma fração
-- (u, v) de um cômodo; aqui ela vira um ponto do mundo em cima do que
-- houver ali: o piso ou um móvel baixo (alcançável pelo prompt). Se o ponto
-- cair dentro de um móvel alto, de uma parede ou no vão de uma escada,
-- tenta pontos vizinhos.
--
-- A decoração quase toda não colide nem aparece em raios (CanQuery
-- desligado), então os raios do Roblox não a veem. Por isso o lugar é
-- calculado com um índice próprio das caixas das peças VISÍVEIS do
-- Casarão (montado uma vez, em grade).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)

type Rect = MansionLayout.Rect

export type Level = {
	rect: Rect,
	floorY: number,
}

type Box = {
	lo: Vector3,
	hi: Vector3,
}

export type Index = {
	cells: { [number]: { Box } },
}

-- Folga das paredes (as divisórias ficam na borda dos cômodos).
local INSET = 3.5
local EDGE_LIMIT = 2.2
-- Altura máxima de um móvel onde a relíquia pode ficar (o prompt alcança).
local PERCH_MAX = 5
-- Espaço livre que a relíquia precisa em cima da superfície.
local CLEARANCE = Vector3.new(1.2, 1.1, 1.2)
local CLEARANCE_LIFT = 0.08
local INVISIBLE = 0.9
local CELL = 8
-- Margem em volta do Casarão e da ala ao montar o índice.
local REGION_MARGIN = 6
-- Distância mínima entre duas relíquias (studs).
local MIN_SEPARATION = 2
-- Pontos vizinhos tentados quando o primeiro não serve (studs).
local OFFSETS: { Vector2 } = {
	Vector2.zero,
	Vector2.new(2, 0),
	Vector2.new(-2, 0),
	Vector2.new(0, 2),
	Vector2.new(0, -2),
	Vector2.new(3, 3),
	Vector2.new(-3, 3),
	Vector2.new(3, -3),
	Vector2.new(-3, -3),
	Vector2.new(5, 0),
	Vector2.new(-5, 0),
	Vector2.new(0, 5),
	Vector2.new(0, -5),
	Vector2.new(7, 7),
	Vector2.new(-7, -7),
	Vector2.new(7, -7),
	Vector2.new(-7, 7),
}

local RelicSpots = {}

-- Cômodo → retângulo e altura do piso. Sótão e Porão ocupam a ala inteira.
function RelicSpots.level(room: string): Level?
	local mansion = MansionLayout.get()
	local mansionRoom = mansion.rooms[room]
	if mansionRoom ~= nil then
		return { rect = mansionRoom, floorY = mansion.floorY }
	end
	local wing = MansionWingLayout.get()
	local wingRoom = wing.rooms[room]
	if wingRoom ~= nil then
		return { rect = wingRoom, floorY = wing.floorY }
	end
	local whole: Rect = { name = room, minX = wing.minX, maxX = wing.maxX, minZ = wing.minZ, maxZ = wing.maxZ }
	if room == "Attic" then
		return { rect = whole, floorY = wing.atticFloorY }
	elseif room == "Cellar" then
		return { rect = whole, floorY = wing.cellarFloorY }
	end
	return nil
end

-- Caixa alinhada aos eixos que contém a peça (girada ou não).
local function boxOf(part: BasePart): Box
	local cframe = part.CFrame
	local half = part.Size / 2
	local right, up, look = cframe.RightVector, cframe.UpVector, cframe.LookVector
	local extent = Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	)
	return { lo = cframe.Position - extent, hi = cframe.Position + extent }
end

local function cellKey(i: number, j: number): number
	return i * 100000 + j
end

-- Índice das peças visíveis dentro do Casarão e da ala (fora `skip`, a
-- pasta das próprias relíquias).
function RelicSpots.index(root: Instance, skip: Instance?): Index
	local mansion = MansionLayout.get()
	local wing = MansionWingLayout.get()
	local minX = mansion.minX - REGION_MARGIN
	local maxX = math.max(mansion.maxX, wing.maxX) + REGION_MARGIN
	local minZ = math.min(mansion.minZ, wing.minZ) - REGION_MARGIN
	local maxZ = math.max(mansion.maxZ, wing.maxZ) + REGION_MARGIN
	local cells: { [number]: { Box } } = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < INVISIBLE and (skip == nil or not descendant:IsDescendantOf(skip)) then
			local box = boxOf(descendant)
			if box.hi.X >= minX and box.lo.X <= maxX and box.hi.Z >= minZ and box.lo.Z <= maxZ then
				for i = math.floor(box.lo.X / CELL), math.floor(box.hi.X / CELL) do
					for j = math.floor(box.lo.Z / CELL), math.floor(box.hi.Z / CELL) do
						local key = cellKey(i, j)
						local list = cells[key]
						if list == nil then
							list = {}
							cells[key] = list
						end
						table.insert(list, box)
					end
				end
			end
		end
	end
	return { cells = cells }
end

-- Caixas que tocam o retângulo (x0..x1, z0..z1), sem repetir.
local function boxesNear(index: Index, x0: number, x1: number, z0: number, z1: number): { Box }
	local seen: { [Box]: boolean } = {}
	local found: { Box } = {}
	for i = math.floor(x0 / CELL), math.floor(x1 / CELL) do
		for j = math.floor(z0 / CELL), math.floor(z1 / CELL) do
			for _, box in ipairs(index.cells[cellKey(i, j)] or {}) do
				if not seen[box] then
					seen[box] = true
					table.insert(found, box)
				end
			end
		end
	end
	return found
end

-- Topo mais alto embaixo de (x, z) entre o piso do cômodo e PERCH_MAX.
local function surfaceAt(index: Index, x: number, z: number, level: Level): number?
	local best: number? = nil
	for _, box in ipairs(boxesNear(index, x, x, z, z)) do
		local top = box.hi.Y
		if x >= box.lo.X and x <= box.hi.X and z >= box.lo.Z and z <= box.hi.Z and top >= level.floorY - 1 and top <= level.floorY + PERCH_MAX then
			if best == nil or top > best then
				best = top
			end
		end
	end
	return best
end

-- Verdadeiro se nenhuma peça visível ocupa o espaço da relíquia.
local function isClear(index: Index, position: Vector3): boolean
	local half = CLEARANCE / 2
	local lo = Vector3.new(position.X - half.X, position.Y + CLEARANCE_LIFT, position.Z - half.Z)
	local hi = Vector3.new(position.X + half.X, position.Y + CLEARANCE_LIFT + CLEARANCE.Y, position.Z + half.Z)
	for _, box in ipairs(boxesNear(index, lo.X, hi.X, lo.Z, hi.Z)) do
		if box.lo.X < hi.X and box.hi.X > lo.X and box.lo.Y < hi.Y and box.hi.Y > lo.Y and box.lo.Z < hi.Z and box.hi.Z > lo.Z then
			return false
		end
	end
	return true
end

local function farFrom(position: Vector3, occupied: { Vector3 }): boolean
	for _, other in ipairs(occupied) do
		if (other - position).Magnitude < MIN_SEPARATION then
			return false
		end
	end
	return true
end

-- Ponto do mundo para o esconderijo (u, v) do nível, ou nil se nenhum
-- vizinho serve. `occupied`: onde já há relíquias.
function RelicSpots.find(index: Index, level: Level, u: number, v: number, occupied: { Vector3 }): Vector3?
	local rect = level.rect
	local baseX = rect.minX + INSET + u * math.max(0, rect.maxX - rect.minX - INSET * 2)
	local baseZ = rect.minZ + INSET + v * math.max(0, rect.maxZ - rect.minZ - INSET * 2)
	for _, offset in ipairs(OFFSETS) do
		local x = math.clamp(baseX + offset.X, rect.minX + EDGE_LIMIT, rect.maxX - EDGE_LIMIT)
		local z = math.clamp(baseZ + offset.Y, rect.minZ + EDGE_LIMIT, rect.maxZ - EDGE_LIMIT)
		local y = surfaceAt(index, x, z, level)
		if y ~= nil then
			local position = Vector3.new(x, y, z)
			if farFrom(position, occupied) and isClear(index, position) then
				return position
			end
		end
	end
	return nil
end

-- Centro do cômodo, no piso (para virar a frente das relíquias para ele).
function RelicSpots.center(level: Level): Vector3
	local rect = level.rect
	return Vector3.new((rect.minX + rect.maxX) / 2, level.floorY, (rect.minZ + rect.maxZ) / 2)
end

return table.freeze(RelicSpots)
