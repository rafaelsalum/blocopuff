--!strict

-- Lado de fora do Casarão: o Casarão, a ilha da Torre e a Ala do
-- Assassinato ficam assentados num chão de terreno no meio de uma floresta
-- de pinheiros, com morros, um lago a leste e montanhas em volta (nada mais
-- flutua no céu). O chão fica plano e com gramado em volta de cada
-- construção, com postes de lampião em volta do Casarão e nos portões da
-- Torre, e o poço da Arena (abaixo do chão) fica sem terreno. Do portão do
-- jardim da Torre sai um caminho de pedra iluminado até o lago, e quem está
-- no lobby passeia à vontade dentro da muralha invisível do limite do mapa
-- (troncos e postes são sólidos). Monta tudo em segundo plano: é só
-- cenário, a partida não espera por ele.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ForestAssets = require(script.Parent.ForestAssets)
local ForestPlan = require(script.Parent.Parent.data.ForestPlan)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local LampLayout = require(script.Parent.Parent.data.LampLayout)
local MurderMansionPlan = require(script.Parent.Parent.data.MurderMansionPlan)
local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local OutdoorBounds = require(script.Parent.OutdoorBounds)
local OutdoorConfig = require(ReplicatedStorage.Shared.config.OutdoorConfig)
local OutdoorLamps = require(script.Parent.OutdoorLamps)
local OutdoorTerrain = require(script.Parent.OutdoorTerrain)
local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local TerrainShape = require(script.Parent.Parent.data.TerrainShape)
local TowerAssets = require(script.Parent.TowerAssets)
local TowerHallLayout = require(ReplicatedStorage.Shared.modules.TowerHallLayout)

type Zone = TerrainShape.Zone
type Carve = TerrainShape.Carve
type Shape = TerrainShape.Shape
type Path = TerrainShape.Path

-- O que foi medido das construções para montar o lado de fora.
type Layout = {
	shape: Shape,
	homeMin: Vector3,
	homeMax: Vector3,
	wingMin: Vector3,
	wingMax: Vector3,
	-- Pontos do caminho do jardim, do portão da Torre até o lago.
	gardenPath: { Vector3 },
}

local FOLDER_NAME = "Outdoors"
local FOREST_NAME = "Forest"
local LAMPS_NAME = "Lamps"
local BOUNDS_NAME = "Bounds"
-- Distância em que o chão plano de cada construção volta ao natural.
local HOME_BLEND = 80
local ISLAND_BLEND = 60
local BRIDGE_BLEND = 30
local WING_BLEND = 220
-- Meia largura da faixa plana embaixo da ponte da Torre.
local BRIDGE_HALF_WIDTH = 8
-- O chão da ilha fica um pouco abaixo do gramado dela (que não flutua nem
-- some no terreno).
local ISLAND_SINK = 0.4
-- O terreno da Ala do Assassinato fica entre o fundo e o topo da laje do
-- térreo (2 studs de espessura).
local WING_SINK = 1.8
-- Quanto o pé da árvore afunda no chão (vezes a escala), para não flutuar
-- em encosta.
local TREE_SINK = 0.7
-- Árvores secas: alturas por unidade de escala e os modelos.
local DEAD_HEIGHT = 13
local DEAD_NAMES = { "BareTree", "TwistedTree" }
-- Árvores plantadas entre uma pausa e outra.
local TREES_PER_BATCH = 40
local SLOPE_STEP = 4
-- Nenhum poste no caminho da ponte da Torre (folga além da meia largura).
local BRIDGE_LAMP_CLEARANCE = 6
-- Postes do portão da Torre: afastamento para cada lado da ponte e para
-- fora da muralha.
local GATE_LAMP_SIDE = 9
local GATE_LAMP_OUT = 4
-- O caminho do jardim começa logo depois da muralha da ilha.
local GARDEN_PATH_START = 2
-- Tronco invisível e sólido de cada árvore (largura por unidade de escala).
local TRUNK_WIDTH = 0.6
local TRUNK_HEIGHT = 16
-- A cerca da Ala do Assassinato desce abaixo do chão do vale.
local WING_FENCE_DEPTH = 20

local OutdoorService = {}

local started = false

local function boxZone(minX: number, minZ: number, maxX: number, maxZ: number, y: number, blend: number): Zone
	return { kind = "Box", ax = minX, az = minZ, bx = maxX, bz = maxZ, radius = 0, y = y, blend = blend }
end

local function modelBox(model: Instance?): (CFrame?, Vector3?)
	if model == nil or not model:IsA("Model") then
		return nil, nil
	end
	return model:GetBoundingBox()
end

-- Pontos do caminho do jardim: do portão da Torre até a margem do lago.
local function gardenPathPoints(): { Vector3 }
	local tower = RaceConfig.Tower
	local angle = math.rad(tower.GardenGateDegrees)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local points = { tower.Center + outward * (tower.IslandRadius + GARDEN_PATH_START) }
	for _, waypoint in ipairs(OutdoorConfig.GardenPath.Waypoints) do
		table.insert(points, Vector3.new(waypoint[1], tower.Center.Y, waypoint[2]))
	end
	return points
end

-- Chão plano em volta de tudo que já está construído.
local function buildLayout(world: Instance): Layout
	local terrain = OutdoorConfig.Terrain
	local groundY = terrain.GroundY
	local zones: { Zone } = {}
	local carves: { Carve } = {}
	local homeMin, homeMax = Vector3.one * math.huge, -Vector3.one * math.huge

	for _, name in ipairs({ "Building", "Mansion" }) do
		local center, size = modelBox(world:FindFirstChild(name))
		if center ~= nil and size ~= nil then
			local low, high = center.Position - size / 2, center.Position + size / 2
			table.insert(zones, boxZone(low.X, low.Z, high.X, high.Z, groundY, HOME_BLEND))
			homeMin, homeMax = homeMin:Min(low), homeMax:Max(high)
			-- A Arena vai abaixo do chão (o poço): por dentro das paredes do
			-- prédio não entra terreno.
			if name == "Building" then
				local wall = GameConfig.Building.WallThickness
				table.insert(carves, { minX = low.X + wall, maxX = high.X - wall, minZ = low.Z + wall, maxZ = high.Z - wall })
			end
		end
	end

	local hall = TowerHallLayout.get()
	table.insert(zones, boxZone(hall.room.minX, hall.room.minZ, hall.room.maxX, hall.room.maxZ, groundY, HOME_BLEND))
	table.insert(zones, {
		kind = "Segment",
		ax = hall.bridgeFrom.X,
		az = hall.bridgeFrom.Z,
		bx = hall.bridgeTo.X,
		bz = hall.bridgeTo.Z,
		radius = BRIDGE_HALF_WIDTH,
		y = groundY,
		blend = BRIDGE_BLEND,
	})

	local tower = RaceConfig.Tower
	table.insert(zones, {
		kind = "Circle",
		ax = tower.Center.X,
		az = tower.Center.Z,
		bx = 0,
		bz = 0,
		radius = tower.IslandRadius,
		y = tower.Center.Y - ISLAND_SINK,
		blend = ISLAND_BLEND,
	})

	local wing = MysteryModeConfig.Wing.Center
	local plan = MurderMansionPlan.get()
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, room in ipairs(plan.rooms) do
		minX, maxX = math.min(minX, room.minX), math.max(maxX, room.maxX)
		minZ, maxZ = math.min(minZ, room.minZ), math.max(maxZ, room.maxZ)
	end
	table.insert(zones, boxZone(wing.X + minX, wing.Z + minZ, wing.X + maxX, wing.Z + maxZ, wing.Y - WING_SINK, WING_BLEND))

	local garden = gardenPathPoints()
	local paths: { Path } = {}
	for index = 1, #garden - 1 do
		local a, b = garden[index], garden[index + 1]
		table.insert(paths, { ax = a.X, az = a.Z, bx = b.X, bz = b.Z, halfWidth = OutdoorConfig.GardenPath.HalfWidth })
	end

	if homeMin.X == math.huge then
		homeMin, homeMax = tower.Center, tower.Center
	end
	return {
		shape = TerrainShape.new(terrain, zones, carves, paths),
		homeMin = homeMin,
		homeMax = homeMax,
		wingMin = Vector3.new(wing.X + minX, wing.Y, wing.Z + minZ),
		wingMax = Vector3.new(wing.X + maxX, wing.Y, wing.Z + maxZ),
		gardenPath = garden,
	}
end

-- Distância do ponto (no chão) até o segmento de `a` a `b`.
local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local flatPoint = Vector3.new(point.X, 0, point.Z)
	local along = flatB - flatA
	local t = if along.Magnitude > 0 then math.clamp((flatPoint - flatA):Dot(along) / along:Dot(along), 0, 1) else 0
	return (flatPoint - (flatA + along * t)).Magnitude
end

local function onGround(shape: Shape, point: Vector3): Vector3
	return Vector3.new(point.X, TerrainShape.heightAt(shape, point.X, point.Z), point.Z)
end

-- Um poste de cada lado de um portão em `gate`, para fora na direção
-- `outward` (no chão).
local function gateLamps(feet: { Vector3 }, shape: Shape, gate: Vector3, outward: Vector3)
	local side = Vector3.new(-outward.Z, 0, outward.X)
	for _, sign in ipairs({ -1, 1 }) do
		table.insert(feet, onGround(shape, gate + outward * GATE_LAMP_OUT + side * (sign * GATE_LAMP_SIDE)))
	end
end

-- Pés dos postes: em volta do Casarão e da Arena (menos no caminho da
-- ponte), dos dois lados dos portões da Torre e ao longo do caminho do
-- jardim, alternando os lados.
local function lampFeet(layout: Layout): { Vector3 }
	local settings = OutdoorConfig.Lamps
	local shape = layout.shape
	local hall = TowerHallLayout.get()
	local feet: { Vector3 } = {}
	for _, spot in ipairs(LampLayout.around(layout.homeMin.X, layout.homeMin.Z, layout.homeMax.X, layout.homeMax.Z, settings.WallOffset, settings.Spacing)) do
		local foot = onGround(shape, Vector3.new(spot.x, 0, spot.z))
		if distanceToSegment(foot, hall.bridgeFrom, hall.bridgeTo) > BRIDGE_HALF_WIDTH + BRIDGE_LAMP_CLEARANCE then
			table.insert(feet, foot)
		end
	end
	local towardHall = Vector3.new(hall.bridgeFrom.X - hall.bridgeTo.X, 0, hall.bridgeFrom.Z - hall.bridgeTo.Z).Unit
	gateLamps(feet, shape, hall.bridgeTo, towardHall)

	local path = layout.gardenPath
	local garden = OutdoorConfig.GardenPath
	local tower = RaceConfig.Tower
	local outward = Vector3.new(path[1].X - tower.Center.X, 0, path[1].Z - tower.Center.Z).Unit
	gateLamps(feet, shape, path[1] - outward * GARDEN_PATH_START, outward)
	local travelled, nextLamp, sign = 0, garden.LampSpacing, 1
	for index = 1, #path - 1 do
		local a, b = path[index], path[index + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		local direction = flat.Unit
		local side = Vector3.new(-direction.Z, 0, direction.X)
		while nextLamp <= travelled + length do
			local along = Vector3.new(a.X, 0, a.Z) + direction * (nextLamp - travelled)
			table.insert(feet, onGround(shape, along + side * (sign * garden.LampOffset)))
			sign = -sign
			nextLamp += garden.LampSpacing
		end
		travelled += length
	end
	return feet
end

-- Tronco sólido (invisível) da árvore com o pé em `foot`.
local function trunk(parent: Instance, foot: Vector3, scale: number)
	local collider = Instance.new("Part")
	collider.Name = "Trunk"
	collider.Size = Vector3.new(TRUNK_WIDTH * scale, TRUNK_HEIGHT, TRUNK_WIDTH * scale)
	collider.CFrame = CFrame.new(foot + Vector3.new(0, TRUNK_HEIGHT / 2, 0))
	collider.Anchored = true
	collider.CanQuery = false
	collider.CanTouch = false
	collider.Transparency = 1
	collider.CastShadow = false
	collider.Parent = parent
end

local function plantForest(parent: Instance, shape: Shape, home: Vector3): number
	local forest = OutdoorConfig.Forest
	local terrain = OutdoorConfig.Terrain
	local settings: ForestPlan.Settings = {
		Seed = forest.Seed,
		CellSize = forest.CellSize,
		NearChance = forest.NearChance,
		FarChance = forest.FarChance,
		FarRadius = forest.FarRadius,
		ClearingMargin = forest.ClearingMargin,
		PathMargin = forest.PathMargin,
		MinScale = forest.MinScale,
		MaxScale = forest.MaxScale,
		MaxSlope = forest.MaxSlope,
		TreeLine = forest.TreeLine,
		DeadChance = forest.DeadChance,
		ShadowRadius = forest.ShadowRadius,
		CenterX = terrain.Mountains.CenterX,
		CenterZ = terrain.Mountains.CenterZ,
		HalfExtent = terrain.HalfExtent,
		GroundY = terrain.GroundY,
		HomeX = home.X,
		HomeZ = home.Z,
	}
	local trees = ForestPlan.plan(settings, function(x: number, z: number): ForestPlan.Sample
		local height = TerrainShape.heightAt(shape, x, z)
		return {
			height = height,
			slope = TerrainShape.slopeAt(shape, x, z, SLOPE_STEP),
			clearance = TerrainShape.clearance(shape, x, z),
			path = TerrainShape.pathDistance(shape, x, z),
			wet = TerrainShape.inLake(shape, x, z) and height < terrain.Lake.WaterY + 1,
			inside = TerrainShape.inBounds(shape, x, z) and not TerrainShape.isCarved(shape, x, z, 0),
		}
	end, ForestAssets.VARIANT_COUNT)

	ForestAssets.preload()
	local folder = Instance.new("Folder")
	folder.Name = FOREST_NAME
	folder.Parent = parent
	local bounds = OutdoorConfig.Bounds
	for index, tree in ipairs(trees) do
		local foot = Vector3.new(tree.x, tree.y - TREE_SINK * tree.scale, tree.z)
		-- Só dá para esbarrar nas árvores de dentro do limite do mapa.
		local fromCenter = Vector2.new(tree.x - settings.CenterX, tree.z - settings.CenterZ).Magnitude
		if fromCenter <= bounds.Radius then
			trunk(folder, foot, tree.scale)
		end
		if tree.kind == "Dead" then
			local facing = Vector3.new(math.cos(tree.yaw), 0, math.sin(tree.yaw))
			TowerAssets.place(folder, DEAD_NAMES[tree.variant], DEAD_HEIGHT * tree.scale, foot, facing)
		else
			ForestAssets.place(folder, tree.variant, CFrame.new(foot) * CFrame.Angles(0, tree.yaw, 0), tree.scale, tree.shadow)
		end
		if index % TREES_PER_BATCH == 0 then
			task.wait()
		end
	end
	return #trees
end

-- Monta o lado de fora em segundo plano. Precisa do prédio, do Casarão e da
-- Torre já construídos (assenta o chão em volta deles).
function OutdoorService.start(world: Instance)
	if started then
		return
	end
	started = true
	local layout = buildLayout(world)
	local shape = layout.shape
	local home = (layout.homeMin + layout.homeMax) / 2
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = world

	local bounds = OutdoorConfig.Bounds
	local terrain = OutdoorConfig.Terrain
	local boundsFolder = Instance.new("Folder")
	boundsFolder.Name = BOUNDS_NAME
	boundsFolder.Parent = folder
	OutdoorBounds.ring(boundsFolder, terrain.Mountains.CenterX, terrain.Mountains.CenterZ, bounds.Radius, bounds.Segments, terrain.GroundY - bounds.Depth, terrain.GroundY + bounds.Height)
	local margin = bounds.WingMargin
	local wingFloor = layout.wingMin.Y
	OutdoorBounds.box(boundsFolder, layout.wingMin.X - margin, layout.wingMin.Z - margin, layout.wingMax.X + margin, layout.wingMax.Z + margin, wingFloor - WING_FENCE_DEPTH, wingFloor + bounds.WingFenceHeight)
	task.spawn(function()
		local clock = os.clock()
		local ok, failure = pcall(OutdoorTerrain.build, shape, OutdoorConfig.Terrain)
		if not ok then
			warn(`[BlocoPuff] Outdoor terrain failed: {failure}`)
			return
		end
		local terrainSeconds = os.clock() - clock
		local lampsFolder = Instance.new("Folder")
		lampsFolder.Name = LAMPS_NAME
		lampsFolder.Parent = folder
		local lit, lampFailure = pcall(function()
			OutdoorLamps.place(lampsFolder, lampFeet(layout))
		end)
		if not lit then
			warn(`[BlocoPuff] Outdoor lamps failed: {lampFailure}`)
		end
		local planted, trees = pcall(plantForest, folder, shape, home)
		if not planted then
			warn(`[BlocoPuff] Forest failed: {trees}`)
			return
		end
		print(string.format("[BlocoPuff] Outdoors ready: terrain %.1fs, %d trees in %.1fs", terrainSeconds, trees, os.clock() - clock - terrainSeconds))
	end)
end

return table.freeze(OutdoorService)
