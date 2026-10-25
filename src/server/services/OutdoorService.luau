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

local CastleEntrance = require(script.Parent.CastleEntrance)
local CastleExterior = require(script.Parent.CastleExterior)
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
	frontPath: { Vector3 },
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
-- Salas do prédio da Arena fora das paredes principais (abaixo do chão).
local BUILDING_SIDE_ROOMS = { "SecretCorridorNorth", "SecretCorridorSouth", "SecretRoomWest" }
-- Terra mínima por cima de um nicho enterrado.
local BURIED_ROOF = 4
-- Calçada de pedra em volta das salas do prédio que saem do chão: o terreno
-- é escavado em células de 4 studs e deixava um vão sem fundo encostado na
-- parede delas. Largura, espessura e quanto fica acima do chão.
local APRON_WIDTH = 4.5
local APRON_DEPTH = 2.3
local APRON_RISE = 0.3
local APRON_COLOR = Color3.fromRGB(128, 124, 116)
local APRONS_NAME = "BuildingAprons"
-- Distância mínima entre um lampião e uma torre ou a escadaria do castelo.
local TOWER_LAMP_CLEARANCE = 3
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

-- Pontos do caminho da frente: do pé da escadaria da porta principal até a
-- margem do lago.
local function frontPathPoints(groundY: number): { Vector3 }
	local foot = CastleEntrance.plan(groundY).foot
	local points = { Vector3.new(foot.x, groundY, foot.z) }
	for _, waypoint in ipairs(OutdoorConfig.FrontPath.Waypoints) do
		table.insert(points, Vector3.new(waypoint[1], groundY, waypoint[2]))
	end
	return points
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

-- Salas do prédio da Arena que descem abaixo do chão: o corpo principal
-- (por dentro das paredes, pelo teto) e os corredores secretos (pelo teto
-- deles) ficam sem terreno; os nichos enterrados dos corredores e a sala
-- secreta de fora ficam sem terreno só até o teto deles, com chão por cima.
local function buildingCarves(building: Instance?, groundY: number): { Carve }
	local carves: { Carve } = {}
	if building == nil then
		return carves
	end
	local function partBox(part: Instance?, inset: number, top: number?)
		if part ~= nil and part:IsA("BasePart") then
			local low, high = part.Position - part.Size / 2, part.Position + part.Size / 2
			table.insert(carves, { minX = low.X + inset, maxX = high.X - inset, minZ = low.Z + inset, maxZ = high.Z - inset, top = top })
		end
	end
	partBox(building:FindFirstChild("Ceiling"), GameConfig.Building.WallThickness, nil)
	for _, roomName in ipairs(BUILDING_SIDE_ROOMS) do
		local room = building:FindFirstChild(roomName)
		local ceiling = if room ~= nil then room:FindFirstChild("Ceiling") else nil
		local center, size = modelBox(room)
		if ceiling ~= nil and ceiling:IsA("BasePart") and center ~= nil and size ~= nil then
			local ceilingTop = ceiling.Position.Y + ceiling.Size.Y / 2
			if ceilingTop > groundY then
				-- Sobe acima do chão: a coluna inteira dele fica vazia, e o
				-- que sobra da caixa (nichos) só até abaixo do chão.
				partBox(ceiling, 0, nil)
			end
			local low, high = center.Position - size / 2, center.Position + size / 2
			table.insert(carves, { minX = low.X, maxX = high.X, minZ = low.Z, maxZ = high.Z, top = math.min(ceilingTop, groundY - BURIED_ROOF) })
		end
	end
	return carves
end

-- Faixas de calçada (min/max em X e Z) nas faces de fora das salas do
-- prédio que sobem acima do chão, menos as faces encostadas no corpo
-- principal.
local function buildingAprons(building: Instance?, groundY: number): { { min: Vector2, max: Vector2 } }
	local aprons: { { min: Vector2, max: Vector2 } } = {}
	local main = if building ~= nil then building:FindFirstChild("Ceiling") else nil
	if building == nil or main == nil or not main:IsA("BasePart") then
		return aprons
	end
	local mainMin = Vector2.new(main.Position.X - main.Size.X / 2, main.Position.Z - main.Size.Z / 2)
	local mainMax = Vector2.new(main.Position.X + main.Size.X / 2, main.Position.Z + main.Size.Z / 2)
	for _, roomName in ipairs(BUILDING_SIDE_ROOMS) do
		local room = building:FindFirstChild(roomName)
		local ceiling = if room ~= nil then room:FindFirstChild("Ceiling") else nil
		if ceiling ~= nil and ceiling:IsA("BasePart") and ceiling.Position.Y + ceiling.Size.Y / 2 > groundY then
			local low = Vector2.new(ceiling.Position.X - ceiling.Size.X / 2, ceiling.Position.Z - ceiling.Size.Z / 2)
			local high = Vector2.new(ceiling.Position.X + ceiling.Size.X / 2, ceiling.Position.Z + ceiling.Size.Z / 2)
			local w = APRON_WIDTH
			-- As faces em Z cobrem também os cantos.
			local strips = {
				{ min = Vector2.new(low.X - w, low.Y), max = Vector2.new(low.X, high.Y) },
				{ min = Vector2.new(high.X, low.Y), max = Vector2.new(high.X + w, high.Y) },
				{ min = Vector2.new(low.X - w, low.Y - w), max = Vector2.new(high.X + w, low.Y) },
				{ min = Vector2.new(low.X - w, high.Y), max = Vector2.new(high.X + w, high.Y + w) },
			}
			for _, strip in ipairs(strips) do
				local touchesMain = strip.min.X < mainMax.X and strip.max.X > mainMin.X and strip.min.Y < mainMax.Y and strip.max.Y > mainMin.Y
				if not touchesMain then
					table.insert(aprons, strip)
				end
			end
		end
	end
	return aprons
end

local function buildAprons(parent: Instance, world: Instance, groundY: number)
	local aprons = buildingAprons(world:FindFirstChild("Building"), groundY)
	if #aprons == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = APRONS_NAME
	for _, strip in ipairs(aprons) do
		local slab = Instance.new("Part")
		slab.Name = "BuildingApron"
		slab.Size = Vector3.new(strip.max.X - strip.min.X, APRON_DEPTH, strip.max.Y - strip.min.Y)
		local center = (strip.min + strip.max) / 2
		slab.CFrame = CFrame.new(center.X, groundY + APRON_RISE - APRON_DEPTH / 2, center.Y)
		slab.Anchored = true
		slab.CanTouch = false
		slab.Material = Enum.Material.Cobblestone
		slab.Color = APRON_COLOR
		slab.TopSurface = Enum.SurfaceType.Smooth
		slab.BottomSurface = Enum.SurfaceType.Smooth
		slab.Parent = folder
	end
	folder.Parent = parent
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
			-- A Arena vai abaixo do chão (o poço): dentro das salas do prédio
			-- não entra terreno. Só as salas: escavar a caixa inteira deixava
			-- valetas fundas entre as paredes de fora e o chão.
			if name == "Building" then
				for _, carve in ipairs(buildingCarves(world:FindFirstChild(name), groundY)) do
					table.insert(carves, carve)
				end
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
	local front = frontPathPoints(groundY)
	local paths: { Path } = {}
	for _, route in ipairs({ { points = garden, settings = OutdoorConfig.GardenPath }, { points = front, settings = OutdoorConfig.FrontPath } }) do
		for index = 1, #route.points - 1 do
			local a, b = route.points[index], route.points[index + 1]
			table.insert(paths, { ax = a.X, az = a.Z, bx = b.X, bz = b.Z, halfWidth = route.settings.HalfWidth })
		end
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
		frontPath = front,
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

-- Lampiões ao longo de um caminho, alternando os lados.
local function pathLamps(feet: { Vector3 }, shape: Shape, path: { Vector3 }, settings: OutdoorConfig.GardenPathConfig)
	local travelled, nextLamp, sign = 0, settings.LampSpacing, 1
	for index = 1, #path - 1 do
		local a, b = path[index], path[index + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		local direction = flat.Unit
		local side = Vector3.new(-direction.Z, 0, direction.X)
		while nextLamp <= travelled + length do
			local along = Vector3.new(a.X, 0, a.Z) + direction * (nextLamp - travelled)
			table.insert(feet, onGround(shape, along + side * (sign * settings.LampOffset)))
			sign = -sign
			nextLamp += settings.LampSpacing
		end
		travelled += length
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
	pathLamps(feet, shape, path, garden)
	pathLamps(feet, shape, layout.frontPath, OutdoorConfig.FrontPath)
	-- Nenhum lampião dentro (ou colado) de uma torre ou da escadaria.
	local blocks = CastleExterior.blocks()
	local clear: { Vector3 } = {}
	for _, foot in ipairs(feet) do
		local blocked = false
		for _, block in ipairs(blocks) do
			local margin = TOWER_LAMP_CLEARANCE
			if foot.X > block.minX - margin and foot.X < block.maxX + margin and foot.Z > block.minZ - margin and foot.Z < block.maxZ + margin then
				blocked = true
				break
			end
		end
		if not blocked then
			table.insert(clear, foot)
		end
	end
	return clear
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
	buildAprons(folder, world, terrain.GroundY)
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
