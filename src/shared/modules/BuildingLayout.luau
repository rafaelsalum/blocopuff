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

local BuildingLayout = {}

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

function BuildingLayout.getGallerySpawnCFrames(arena: ArenaConfig, building: BuildingConfig, count: number): { CFrame }
	local gallery = BuildingLayout.getGallery(arena, building)
	local spanZ = math.max(0, gallery.size.Z - (GALLERY_SPAWN_INSET * 2))
	local spanX = math.max(0, gallery.size.X - (GALLERY_SPAWN_INSET * 2))

	return distributeOnGrid(
		count,
		gallery.center.X - (spanX / 2),
		gallery.center.Z - (spanZ / 2),
		spanX,
		spanZ,
		gallery.floorY + SPAWN_HEIGHT_OFFSET
	)
end

return table.freeze(BuildingLayout)
