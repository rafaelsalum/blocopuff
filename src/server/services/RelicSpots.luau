--!strict

-- Onde as relíquias ficam (Fase 5C.2). Cada relíquia diz o móvel onde fica
-- escondida (âncora); aqui procuramos, em volta e embaixo dele, o ponto
-- mais escondido: com mais direções tapadas por móveis e paredes e, de
-- preferência, com algo por cima (debaixo de mesa, lençol, sofá). Sem a
-- âncora, vale a fração (u, v) do cômodo, como reserva.
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
	part: BasePart,
}

export type Index = {
	cells: { [number]: { Box } },
	boxes: { Box },
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
	return { lo = cframe.Position - extent, hi = cframe.Position + extent, part = part }
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
	local boxes: { Box } = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < INVISIBLE and (skip == nil or not descendant:IsDescendantOf(skip)) then
			local box = boxOf(descendant)
			if box.hi.X >= minX and box.lo.X <= maxX and box.hi.Z >= minZ and box.lo.Z <= maxZ then
				table.insert(boxes, box)
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
	return { cells = cells, boxes = boxes }
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

-- Esconderijo junto a um móvel ------------------------------------------

-- Distância de fora do móvel onde ficam os pontos em volta dele.
local RING_GAP = 0.9
local RING_STEP = 1
-- Teto de pontos testados por móvel (móveis grandes testam menos pontos).
local MAX_CANDIDATES = 160
local CLUSTER_MARGIN = 0.3
-- Direções horizontais testadas para ver o quanto o ponto fica tapado.
local DIRECTIONS = 8
local SIGHT_RANGE = 3.2
local SIGHT_STEP = 0.4
local COVER_FROM = 1.3
local COVER_TO = 5
local COVER_BONUS = 3
-- Pontos perdidos por stud acima do piso.
local HEIGHT_PENALTY = 1.5
-- Até esta altura conta como "no chão" (tapetes, degrau baixo).
local FLOOR_LIFT = 0.6
-- Altura máxima do móvel-âncora acima do piso (estantes passam disso, mas
-- só o pé delas importa).
local ANCHOR_HEIGHT = 16

-- O nome da peça é a âncora ou começa com ela seguida de algo que não é
-- dígito ("HallSofa1Back" é do "HallSofa1", mas "Pedestal10" não é do
-- "Pedestal1").
local function matchesAnchor(instance: Instance, anchor: string): boolean
	local name = instance.Name
	if name == anchor then
		return true
	end
	if #name <= #anchor or string.sub(name, 1, #anchor) ~= anchor then
		return false
	end
	return string.match(string.sub(name, #anchor + 1, #anchor + 1), "%d") == nil
end

local function belongsToAnchor(part: BasePart, anchor: string): boolean
	local current: Instance? = part
	while current ~= nil and not current:IsA("Workspace") do
		if matchesAnchor(current, anchor) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function insideLevel(box: Box, level: Level): boolean
	local rect = level.rect
	local center = (box.lo + box.hi) / 2
	return center.X >= rect.minX
		and center.X <= rect.maxX
		and center.Z >= rect.minZ
		and center.Z <= rect.maxZ
		and box.lo.Y <= level.floorY + ANCHOR_HEIGHT
		and box.hi.Y >= level.floorY - 1
end

local function overlaps(a: Box, b: Box, margin: number): boolean
	return a.lo.X - margin < b.hi.X
		and a.hi.X + margin > b.lo.X
		and a.lo.Y - margin < b.hi.Y
		and a.hi.Y + margin > b.lo.Y
		and a.lo.Z - margin < b.hi.Z
		and a.hi.Z + margin > b.lo.Z
end

-- Junta à peça `base` as peças que encostam nela (e nas já juntadas).
local function cluster(matches: { Box }, base: Box): (Vector3, Vector3)
	local lo, hi = base.lo, base.hi
	local taken: { [Box]: boolean } = { [base] = true }
	local grew = true
	while grew do
		grew = false
		local bounds: Box = { lo = lo, hi = hi, part = base.part }
		for _, box in ipairs(matches) do
			if not taken[box] and overlaps(box, bounds, CLUSTER_MARGIN) then
				taken[box] = true
				lo = lo:Min(box.lo)
				hi = hi:Max(box.hi)
				grew = true
			end
		end
	end
	return lo, hi
end

-- Caixa do móvel-âncora no cômodo. Com `nth`, escolhe entre móveis
-- repetidos (peças com o nome exato, em ordem de X e depois de Z) e junta
-- as peças vizinhas do mesmo móvel (tampa, cintas).
function RelicSpots.anchorBox(index: Index, level: Level, anchor: string, nth: number?): (Vector3?, Vector3?)
	local matches: { Box } = {}
	for _, box in ipairs(index.boxes) do
		if insideLevel(box, level) and belongsToAnchor(box.part, anchor) then
			table.insert(matches, box)
		end
	end
	if #matches == 0 then
		return nil, nil
	end
	if nth == nil then
		-- Só o móvel em volta da maior peça (peças soltas de mesmo nome em
		-- outro canto não esticam a caixa).
		local largest = matches[1]
		for _, box in ipairs(matches) do
			if (box.hi - box.lo).Magnitude > (largest.hi - largest.lo).Magnitude then
				largest = box
			end
		end
		return cluster(matches, largest)
	end
	local bases: { Box } = {}
	for _, box in ipairs(matches) do
		if box.part.Name == anchor then
			table.insert(bases, box)
		end
	end
	table.sort(bases, function(a: Box, b: Box): boolean
		local ax, bx = a.lo.X + a.hi.X, b.lo.X + b.hi.X
		if math.abs(ax - bx) > 0.01 then
			return ax < bx
		end
		return a.lo.Z + a.hi.Z < b.lo.Z + b.hi.Z
	end)
	local base = bases[nth]
	if base == nil then
		return nil, nil
	end
	return cluster(matches, base)
end

-- Chamado muitas vezes por candidato: lê a célula direto, sem criar tabelas.
local function pointInside(index: Index, point: Vector3): boolean
	local cell = index.cells[cellKey(math.floor(point.X / CELL), math.floor(point.Z / CELL))]
	if cell == nil then
		return false
	end
	for _, box in ipairs(cell) do
		if point.X > box.lo.X and point.X < box.hi.X and point.Y > box.lo.Y and point.Y < box.hi.Y and point.Z > box.lo.Z and point.Z < box.hi.Z then
			return true
		end
	end
	return false
end

-- Nota do esconderijo: direções tapadas por perto e se há algo por cima.
local function concealment(index: Index, position: Vector3): number
	local eye = position + Vector3.new(0, 0.5, 0)
	local blocked = 0
	for step = 0, DIRECTIONS - 1 do
		local angle = step * (2 * math.pi / DIRECTIONS)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local distance = SIGHT_STEP
		while distance <= SIGHT_RANGE do
			if pointInside(index, eye + direction * distance) then
				blocked += 1
				break
			end
			distance += SIGHT_STEP
		end
	end
	local covered = false
	local height = COVER_FROM
	while height <= COVER_TO do
		if pointInside(index, position + Vector3.new(0, height, 0)) then
			covered = true
			break
		end
		height += 0.5
	end
	return blocked + (if covered then COVER_BONUS else 0)
end

-- Superfícies (piso, tapete, móvel baixo) em (x, z), da mais baixa à mais alta.
local function surfacesAt(index: Index, x: number, z: number, level: Level): { number }
	local tops: { number } = {}
	for _, box in ipairs(boxesNear(index, x, x, z, z)) do
		local top = box.hi.Y
		if x >= box.lo.X and x <= box.hi.X and z >= box.lo.Z and z <= box.hi.Z and top >= level.floorY - 1 and top <= level.floorY + PERCH_MAX then
			table.insert(tops, top)
		end
	end
	table.sort(tops)
	return tops
end

-- Todos os pontos em volta (anel) e embaixo (grade) do móvel.
local function allCandidates(lo: Vector3, hi: Vector3): { Vector2 }
	local points: { Vector2 } = {}
	local x0, x1 = lo.X - RING_GAP, hi.X + RING_GAP
	local z0, z1 = lo.Z - RING_GAP, hi.Z + RING_GAP
	local x = x0
	while x <= x1 + 0.01 do
		table.insert(points, Vector2.new(x, z0))
		table.insert(points, Vector2.new(x, z1))
		x += RING_STEP
	end
	local z = z0 + RING_STEP
	while z <= z1 - RING_STEP + 0.01 do
		table.insert(points, Vector2.new(x0, z))
		table.insert(points, Vector2.new(x1, z))
		z += RING_STEP
	end
	local gx = lo.X + 0.5
	while gx <= hi.X - 0.5 do
		local gz = lo.Z + 0.5
		while gz <= hi.Z - 0.5 do
			table.insert(points, Vector2.new(gx, gz))
			gz += RING_STEP
		end
		gx += RING_STEP
	end
	return points
end

-- Pontos em volta (anel) e embaixo (grade) do móvel, no máximo
-- MAX_CANDIDATES (pulando pontos de forma uniforme).
local function candidatesAround(lo: Vector3, hi: Vector3): { Vector2 }
	local all = allCandidates(lo, hi)
	if #all <= MAX_CANDIDATES then
		return all
	end
	local points: { Vector2 } = {}
	local stride = #all / MAX_CANDIDATES
	local position = 1
	while position <= #all do
		table.insert(points, all[math.floor(position)])
		position += stride
	end
	return points
end

-- Melhor ponto junto ao móvel: o melhor no chão (até FLOOR_LIFT) e o
-- melhor em qualquer altura, numa passada só.
local function bestAround(index: Index, level: Level, lo: Vector3, hi: Vector3, occupied: { Vector3 }): (Vector3?, Vector3?)
	local rect = level.rect
	local center = (lo + hi) / 2
	local bestFloor: Vector3? = nil
	local bestFloorScore = -math.huge
	local bestAny: Vector3? = nil
	local bestAnyScore = -math.huge
	for _, point in ipairs(candidatesAround(lo, hi)) do
		local insideRoom = point.X >= rect.minX + EDGE_LIMIT
			and point.X <= rect.maxX - EDGE_LIMIT
			and point.Y >= rect.minZ + EDGE_LIMIT
			and point.Y <= rect.maxZ - EDGE_LIMIT
		if insideRoom then
			for _, y in ipairs(surfacesAt(index, point.X, point.Y, level)) do
				local position = Vector3.new(point.X, y, point.Y)
				if farFrom(position, occupied) and isClear(index, position) then
					-- Mais tapado ganha; mais alto fica mais à vista; no
					-- empate, mais perto do móvel.
					local score = concealment(index, position)
						- (Vector2.new(point.X - center.X, point.Y - center.Z).Magnitude * 0.01)
						- ((y - level.floorY) * HEIGHT_PENALTY)
					if y <= level.floorY + FLOOR_LIFT and score > bestFloorScore then
						bestFloorScore = score
						bestFloor = position
					end
					if score > bestAnyScore then
						bestAnyScore = score
						bestAny = position
					end
				end
			end
		end
	end
	return bestFloor, bestAny
end

-- O ponto mais escondido junto ao móvel `anchor`: de preferência no chão
-- (atrás, ao lado ou debaixo dele); só em cima do móvel se não houver
-- lugar no chão. nil se o móvel não existir ou não houver lugar livre.
function RelicSpots.hide(index: Index, level: Level, anchor: string, nth: number?, occupied: { Vector3 }): Vector3?
	local lo, hi = RelicSpots.anchorBox(index, level, anchor, nth)
	if lo == nil or hi == nil then
		return nil
	end
	local onFloor, anywhere = bestAround(index, level, lo, hi, occupied)
	return onFloor or anywhere
end

-- Centro do cômodo, no piso (para virar a frente das relíquias para ele).
function RelicSpots.center(level: Level): Vector3
	local rect = level.rect
	return Vector3.new((rect.minX + rect.maxX) / 2, level.floorY, (rect.minZ + rect.maxZ) / 2)
end

return table.freeze(RelicSpots)
