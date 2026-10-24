--!strict

-- Lado de fora do Casarão: o Casarão, a ilha da Torre e a Ala do
-- Assassinato ficam assentados num chão de terreno no meio de uma floresta
-- de pinheiros, com morros, um lago a leste e montanhas em volta (nada mais
-- flutua no céu). O chão fica plano e com gramado em volta de cada
-- construção, com postes de lampião em volta do Casarão e no portão da
-- Torre, e o poço da Arena (abaixo do chão) fica sem terreno. Monta
-- tudo em segundo plano: é só cenário, a partida não espera por ele.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ForestAssets = require(script.Parent.ForestAssets)
local ForestPlan = require(script.Parent.Parent.data.ForestPlan)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local LampLayout = require(script.Parent.Parent.data.LampLayout)
local MurderMansionPlan = require(script.Parent.Parent.data.MurderMansionPlan)
local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
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

local FOLDER_NAME = "Outdoors"
local FOREST_NAME = "Forest"
local LAMPS_NAME = "Lamps"
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

-- Chão plano em volta de tudo que já está construído.
local function buildShape(world: Instance): (Shape, Vector3, Vector3)
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

	if homeMin.X == math.huge then
		homeMin, homeMax = tower.Center, tower.Center
	end
	return TerrainShape.new(terrain, zones, carves), homeMin, homeMax
end

-- Distância do ponto (no chão) até o segmento de `a` a `b`.
local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local flatPoint = Vector3.new(point.X, 0, point.Z)
	local along = flatB - flatA
	local t = if along.Magnitude > 0 then math.clamp((flatPoint - flatA):Dot(along) / along:Dot(along), 0, 1) else 0
	return (flatPoint - (flatA + along * t)).Magnitude
end

-- Pés dos postes: em volta do Casarão e da Arena (menos no caminho da ponte)
-- e um de cada lado do portão da Torre.
local function lampFeet(shape: Shape, homeMin: Vector3, homeMax: Vector3): { Vector3 }
	local settings = OutdoorConfig.Lamps
	local hall = TowerHallLayout.get()
	local feet: { Vector3 } = {}
	for _, spot in ipairs(LampLayout.around(homeMin.X, homeMin.Z, homeMax.X, homeMax.Z, settings.WallOffset, settings.Spacing)) do
		local foot = Vector3.new(spot.x, TerrainShape.heightAt(shape, spot.x, spot.z), spot.z)
		if distanceToSegment(foot, hall.bridgeFrom, hall.bridgeTo) > BRIDGE_HALF_WIDTH + BRIDGE_LAMP_CLEARANCE then
			table.insert(feet, foot)
		end
	end
	local toward = Vector3.new(hall.bridgeFrom.X - hall.bridgeTo.X, 0, hall.bridgeFrom.Z - hall.bridgeTo.Z).Unit
	local side = Vector3.new(-toward.Z, 0, toward.X)
	for _, sign in ipairs({ -1, 1 }) do
		local spot = hall.bridgeTo + toward * GATE_LAMP_OUT + side * (sign * GATE_LAMP_SIDE)
		table.insert(feet, Vector3.new(spot.X, TerrainShape.heightAt(shape, spot.X, spot.Z), spot.Z))
	end
	return feet
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
			wet = TerrainShape.inLake(shape, x, z) and height < terrain.Lake.WaterY + 1,
			inside = TerrainShape.inBounds(shape, x, z) and not TerrainShape.isCarved(shape, x, z, 0),
		}
	end, ForestAssets.VARIANT_COUNT)

	ForestAssets.preload()
	local folder = Instance.new("Folder")
	folder.Name = FOREST_NAME
	folder.Parent = parent
	for index, tree in ipairs(trees) do
		local foot = Vector3.new(tree.x, tree.y - TREE_SINK * tree.scale, tree.z)
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
	local shape, homeMin, homeMax = buildShape(world)
	local home = (homeMin + homeMax) / 2
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = world
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
			OutdoorLamps.place(lampsFolder, lampFeet(shape, homeMin, homeMax))
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
