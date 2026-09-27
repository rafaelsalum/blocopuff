--!strict

-- Geometria pura do prédio fechado onde a partida acontece. Centraliza as
-- contas de pisos, paredes, galeria e zona de eliminação para que Arena,
-- Building e Lobby usem exatamente as mesmas medidas, sem duplicação.
-- Convenção: piso 1 é o mais baixo; o piso ArenaConfig.FloorCount é o topo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

type ArenaConfig = GameConfig.ArenaConfig
type BuildingConfig = GameConfig.BuildingConfig

export type RoomBounds = {
	center: Vector3,
	halfWidth: number,
	halfDepth: number,
	bottomY: number,
	ceilingY: number,
}

-- Porta secreta do andar mais baixo. `center` fica na face interna da
-- parede, no nível do piso; `inward` aponta para dentro da sala e `along`
-- corre ao longo da parede. A sala secreta fica do lado de fora (-inward).
export type SecretDoor = {
	name: string,
	center: Vector3,
	inward: Vector3,
	along: Vector3,
}

-- Corredor secreto do lado de fora de uma parede externa, ligando o andar de
-- baixo ao de cima por uma rampa. `wallCenter` fica no centro da face interna
-- da parede (Y = 0); `inward` aponta para a arena e `along` corre ao longo da
-- parede. As entradas ficam em `lowerAlong` (andar 1) e `upperAlong` (andar
-- de cima), sempre existentes mesmo antes de serem reveladas.
export type Corridor = {
	name: string,
	wallCenter: Vector3,
	inward: Vector3,
	along: Vector3,
	lowerY: number,
	upperY: number,
	lowerAlong: number,
	upperAlong: number,
}

export type GalleryLayout = {
	floorY: number,
	center: Vector3,
	size: Vector3,
	innerX: number,
}

local SPAWN_HEIGHT_OFFSET = 5
local SPAWN_EDGE_BLOCKS = 1
local SPREAD_TOLERANCE = 0.9
local GALLERY_SPAWN_INSET = 4
local GALLERY_SPAWN_COLUMNS = 3

local BuildingLayout = {}

-- Vão da porta (largura, altura) e interior da sala (largura ao longo da
-- parede, altura, profundidade para fora do prédio).
BuildingLayout.SecretDoorSize = Vector2.new(5, 8.8)
BuildingLayout.SecretRoomSize = Vector3.new(14, 11, 12)

-- Corredores secretos: largura interna, meio comprimento (ao longo da
-- parede), meio comprimento da rampa, posição das entradas e pé-direito
-- acima do andar de cima.
BuildingLayout.CorridorWidth = 7
BuildingLayout.CorridorHalfLength = 40
BuildingLayout.CorridorRampHalfLength = 26
BuildingLayout.CorridorEntranceAlong = 32
BuildingLayout.CorridorHeadroom = 11

function BuildingLayout.getFloorSize(arena: ArenaConfig): (number, number)
	local width = (arena.Columns * arena.BlockSize.X) + ((arena.Columns - 1) * arena.BlockGap)
	local depth = (arena.Rows * arena.BlockSize.Z) + ((arena.Rows - 1) * arena.BlockGap)
	return width, depth
end

function BuildingLayout.getFloorY(arena: ArenaConfig, floorIndex: number): number
	return arena.Position.Y + ((floorIndex - 1) * arena.FloorSpacing)
end

function BuildingLayout.getTopFloorY(arena: ArenaConfig): number
	return BuildingLayout.getFloorY(arena, arena.FloorCount)
end

function BuildingLayout.getFloorSurfaceY(arena: ArenaConfig, floorIndex: number): number
	return BuildingLayout.getFloorY(arena, floorIndex) + (arena.BlockSize.Y / 2)
end

function BuildingLayout.getEliminationY(arena: ArenaConfig, depthBelowLowestFloor: number): number
	return BuildingLayout.getFloorY(arena, 1) - depthBelowLowestFloor
end

function BuildingLayout.getRoomBounds(arena: ArenaConfig, building: BuildingConfig): RoomBounds
	local width, depth = BuildingLayout.getFloorSize(arena)
	return {
		center = Vector3.new(arena.Position.X, 0, arena.Position.Z),
		halfWidth = width / 2,
		halfDepth = depth / 2,
		bottomY = BuildingLayout.getFloorY(arena, 1) - building.PitDepth,
		ceilingY = BuildingLayout.getTopFloorY(arena) + building.CeilingClearance,
	}
end

-- A galeria fica encostada na parede +X, um pouco acima do piso de cima e
-- separada da arena por vidro: quem espera ou foi eliminado assiste de
-- dentro do prédio sem conseguir interferir na partida.
function BuildingLayout.getGallery(arena: ArenaConfig, building: BuildingConfig): GalleryLayout
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local floorY = BuildingLayout.getFloorSurfaceY(arena, arena.FloorCount) + building.GalleryRise
	local innerX = bounds.center.X + bounds.halfWidth
	return {
		floorY = floorY,
		center = Vector3.new(innerX + (building.GalleryDepth / 2), floorY, bounds.center.Z),
		size = Vector3.new(building.GalleryDepth, 0, bounds.halfDepth * 2),
		innerX = innerX,
	}
end

local function distributeOnGrid(count: number, minX: number, minZ: number, spanX: number, spanZ: number, y: number): { CFrame }
	local gridColumns = math.max(1, math.ceil(math.sqrt(count)))
	local gridRows = math.max(1, math.ceil(count / gridColumns))

	local cframes: { CFrame } = {}
	for index = 1, count do
		local zeroBased = index - 1
		local gridRow = math.floor(zeroBased / gridColumns)
		local gridColumn = zeroBased % gridColumns
		local xRatio = if gridColumns > 1 then gridColumn / (gridColumns - 1) else 0.5
		local zRatio = if gridRows > 1 then gridRow / (gridRows - 1) else 0.5
		table.insert(cframes, CFrame.new(minX + (xRatio * spanX), y, minZ + (zRatio * spanZ)))
	end

	return cframes
end

local function getSpawnCandidates(arena: ArenaConfig, floorIndex: number): { Vector3 }
	local width, depth = BuildingLayout.getFloorSize(arena)
	local stepX = arena.BlockSize.X + arena.BlockGap
	local stepZ = arena.BlockSize.Z + arena.BlockGap
	local startX = arena.Position.X - (width / 2) + (arena.BlockSize.X / 2)
	local startZ = arena.Position.Z - (depth / 2) + (arena.BlockSize.Z / 2)
	local y = BuildingLayout.getFloorSurfaceY(arena, floorIndex) + SPAWN_HEIGHT_OFFSET
	-- Evita nascer colado à parede, onde a câmera fica apertada.
	local edge = if arena.Rows > 2 and arena.Columns > 2 then SPAWN_EDGE_BLOCKS else 0

	local candidates: { Vector3 } = {}
	for row = 1 + edge, arena.Rows - edge do
		for column = 1 + edge, arena.Columns - edge do
			table.insert(candidates, Vector3.new(startX + ((column - 1) * stepX), y, startZ + ((row - 1) * stepZ)))
		end
	end
	return candidates
end

local function getMinimumDistance(point: Vector3, chosen: { Vector3 }): number
	local minimum = math.huge
	for _, other in ipairs(chosen) do
		minimum = math.min(minimum, (point - other).Magnitude)
	end
	return minimum
end

-- Amostragem do ponto mais distante: o primeiro jogador nasce em um bloco
-- aleatório e cada próximo no bloco mais afastado de todos os já escolhidos.
-- Sortear entre os candidatos quase tão bons mantém as partidas variadas.
function BuildingLayout.getSpreadSpawnCFrames(arena: ArenaConfig, floorIndex: number, count: number, rng: Random): { CFrame }
	local candidates = getSpawnCandidates(arena, floorIndex)
	local center = Vector3.new(arena.Position.X, 0, arena.Position.Z)
	local chosen: { Vector3 } = {}
	if #candidates == 0 then
		return {}
	end

	table.insert(chosen, candidates[rng:NextInteger(1, #candidates)])
	while #chosen < count do
		local bestDistance = 0
		local distances: { number } = {}
		for index, candidate in ipairs(candidates) do
			distances[index] = getMinimumDistance(candidate, chosen)
			bestDistance = math.max(bestDistance, distances[index])
		end

		local nearlyBest: { Vector3 } = {}
		for index, candidate in ipairs(candidates) do
			if bestDistance > 0 and distances[index] >= bestDistance * SPREAD_TOLERANCE then
				table.insert(nearlyBest, candidate)
			end
		end
		if #nearlyBest == 0 then
			-- Mais jogadores que blocos livres: reaproveita posições.
			table.insert(chosen, candidates[rng:NextInteger(1, #candidates)])
		else
			table.insert(chosen, nearlyBest[rng:NextInteger(1, #nearlyBest)])
		end
	end

	local cframes: { CFrame } = {}
	for _, position in ipairs(chosen) do
		local lookTarget = Vector3.new(center.X, position.Y, center.Z)
		if (lookTarget - position).Magnitude < 1e-3 then
			table.insert(cframes, CFrame.new(position))
		else
			table.insert(cframes, CFrame.lookAt(position, lookTarget))
		end
	end
	return cframes
end

-- Grade de posições no piso da galeria (lobby): poucas colunas na largura e
-- muitas linhas no comprimento, acompanhando o formato comprido da galeria.
-- Todos olham para o vidro, de frente para a arena.
function BuildingLayout.getGallerySpawnCFrames(arena: ArenaConfig, building: BuildingConfig, count: number): { CFrame }
	local gallery = BuildingLayout.getGallery(arena, building)
	local spanZ = math.max(0, gallery.size.Z - (GALLERY_SPAWN_INSET * 2))
	local spanX = math.max(0, gallery.size.X - (GALLERY_SPAWN_INSET * 2))
	local columns = math.max(1, math.min(GALLERY_SPAWN_COLUMNS, count))
	local rows = math.max(1, math.ceil(count / columns))
	local minX = gallery.center.X - (spanX / 2)
	local minZ = gallery.center.Z - (spanZ / 2)
	local y = gallery.floorY + SPAWN_HEIGHT_OFFSET
	local facing = Vector3.new(-1, 0, 0)

	local cframes: { CFrame } = {}
	for index = 1, count do
		local zeroBased = index - 1
		local column = zeroBased % columns
		local row = math.floor(zeroBased / columns)
		local xRatio = if columns > 1 then column / (columns - 1) else 0.5
		local zRatio = if rows > 1 then row / (rows - 1) else 0.5
		local position = Vector3.new(minX + (xRatio * spanX), y, minZ + (zRatio * spanZ))
		table.insert(cframes, CFrame.lookAt(position, position + facing))
	end
	return cframes
end

-- Referencial de uma parede vista de dentro: X ao longo, Y para cima e Z para
-- fora do prédio (fromMatrix(along, up) deixa +Z = -inward).
function BuildingLayout.getWallFrame(center: Vector3, along: Vector3): CFrame
	return CFrame.fromMatrix(center, along, Vector3.yAxis)
end

-- Corredores secretos nas paredes norte e sul (a oeste fica o cofre).
function BuildingLayout.getCorridors(arena: ArenaConfig, building: BuildingConfig): { Corridor }
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local center = bounds.center
	local definitions = {
		{ name = "North", point = Vector3.new(center.X, 0, center.Z - bounds.halfDepth), inward = Vector3.new(0, 0, 1) },
		{ name = "South", point = Vector3.new(center.X, 0, center.Z + bounds.halfDepth), inward = Vector3.new(0, 0, -1) },
	}
	local corridors: { Corridor } = {}
	for _, definition in ipairs(definitions) do
		table.insert(corridors, {
			name = definition.name,
			wallCenter = definition.point,
			inward = definition.inward,
			along = definition.inward:Cross(Vector3.yAxis),
			lowerY = BuildingLayout.getFloorSurfaceY(arena, 1),
			upperY = BuildingLayout.getFloorSurfaceY(arena, arena.FloorCount),
			lowerAlong = -BuildingLayout.CorridorEntranceAlong,
			upperAlong = BuildingLayout.CorridorEntranceAlong,
		})
	end
	return corridors
end

-- Verdadeiro se a posição está dentro do corredor (incluindo os vãos das
-- entradas na espessura da parede). Usado pelo Barão e pela telemetria dos
-- corredores (entrega 2.2).
function BuildingLayout.isInsideCorridor(corridor: Corridor, building: BuildingConfig, position: Vector3): boolean
	local relative = position - corridor.wallCenter
	local outward = -relative:Dot(corridor.inward)
	local sideways = relative:Dot(corridor.along)
	return outward >= 0.3
		and outward <= building.WallThickness + BuildingLayout.CorridorWidth
		and math.abs(sideways) <= BuildingLayout.CorridorHalfLength
		and position.Y >= corridor.lowerY - 2
		and position.Y <= corridor.upperY + BuildingLayout.CorridorHeadroom
end

-- Porta do cofre: centro da parede oeste, no andar mais baixo. Norte e sul
-- têm os corredores secretos; a leste fica o bloco da galeria.
function BuildingLayout.getSecretDoors(arena: ArenaConfig, building: BuildingConfig): { SecretDoor }
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local floorY = BuildingLayout.getFloorSurfaceY(arena, 1)
	local center = bounds.center
	local definitions = {
		{ name = "West", point = Vector3.new(center.X - bounds.halfWidth, floorY, center.Z), inward = Vector3.new(1, 0, 0) },
	}

	local doors: { SecretDoor } = {}
	for _, definition in ipairs(definitions) do
		table.insert(doors, {
			name = definition.name,
			center = definition.point,
			inward = definition.inward,
			along = definition.inward:Cross(Vector3.yAxis),
		})
	end
	return doors
end

-- Verdadeiro se a posição está dentro da sala secreta (incluindo o vão da
-- porta na espessura da parede).
function BuildingLayout.isInsideSecretRoom(door: SecretDoor, building: BuildingConfig, position: Vector3): boolean
	local room = BuildingLayout.SecretRoomSize
	local relative = position - door.center
	local outward = -relative:Dot(door.inward)
	local sideways = math.abs(relative:Dot(door.along))
	local height = relative.Y
	return outward >= 0.3
		and outward <= building.WallThickness + room.Z
		and sideways <= room.X / 2
		and height >= -2
		and height <= room.Y
end

return table.freeze(BuildingLayout)
