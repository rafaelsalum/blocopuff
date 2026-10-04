--!strict

-- O Casarão: lobby principal, anexo grande a leste da galeria da arena e
-- ligado a ela pelas portas da parede leste. Aqui só fica a construção
-- (casca, divisórias com arcos, papel de parede, lustres, tapetes, móveis e
-- placas das salas); as estações (Puff Machine, Puffdex, desafios, Party,
-- Barão, loja) são do LobbyStationsService e o treino, do TrainingService.
-- A geometria vem de MansionLayout.
--
-- Pensado para celular: lustres sem sombra, poucas luzes, placas com
-- distância máxima e nada animado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local BuildingDecor = require(script.Parent.BuildingDecor)
local LobbyService = require(script.Parent.LobbyService)
local MansionDoors = require(script.Parent.MansionDoors)
local MansionPlaque = require(script.Parent.MansionPlaque)
local MansionWing = require(script.Parent.MansionWing)
local WallBuilder = require(script.Parent.WallBuilder)

type BuildingConfig = GameConfig.BuildingConfig
type Box = WallBuilder.Box
type DoorGap = BuildingDecor.DoorGap
type Mansion = MansionLayout.Mansion
type ReservedArea = LobbyService.ReservedArea
type Doorway = MansionWingLayout.Doorway

-- Vão numa face de parede (porta ou arco), com placa opcional por cima.
type Opening = {
	point: Vector3,
	size: Vector2,
	label: string?,
}

-- Face interna de uma parede, de `a` até `b` (Y ignorado).
type Face = {
	name: string,
	a: Vector3,
	b: Vector3,
	inward: Vector3,
	color: Color3,
	openings: { Opening },
}

local MODEL_NAME = "Mansion"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "MansionService"
local DECOR_SEED = 2024
local BEAM_SIZE = 1.2
local BEAM_SPACING = 14
local CHANDELIER_DROP = 6
local PLAQUE_DISTANCE = MansionPlaque.MaxDistance
local STATUE_COLOR = Color3.fromRGB(255, 209, 102)
local GRASS_COLOR = Color3.fromRGB(88, 148, 80)

local MansionService = {}

local mansionModel: Model? = nil

local function destroyExisting(worldRoot: Model)
	local existing = worldRoot:FindFirstChild(MODEL_NAME)
	if existing == nil then
		return
	end
	if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
		error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
	end
	existing:Destroy()
end

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return { min = Vector3.new(minX, minY, minZ), max = Vector3.new(maxX, maxY, maxZ) }
end

-- Portas da parede leste do Casarão para a ala nova.
local function eastDoorways(): { Doorway }
	local list: { Doorway } = {}
	for _, doorway in ipairs(MansionWingLayout.get().doorways) do
		if doorway.normal == Vector3.xAxis then
			table.insert(list, doorway)
		end
	end
	return list
end

local function eastDoorway(name: string): Doorway
	for _, doorway in ipairs(eastDoorways()) do
		if doorway.name == name then
			return doorway
		end
	end
	error(`Unknown wing doorway {name}`)
end

-- Piso, teto e paredes externas. A oeste, a parede leste do prédio da arena
-- já fecha o trecho da galeria; aqui só entram as pontas e o pedaço acima
-- do telhado do prédio (o Casarão tem pé-direito mais alto).
local function createShell(parent: Instance, mansion: Mansion, building: BuildingConfig, withWing: boolean)
	local t = building.WallThickness
	local floorY = mansion.floorY
	local topY = mansion.ceilingY
	local wallColor = MansionConfig.WallpaperColors.GrandHall
	local bounds = BuildingLayout.getRoomBounds(GameConfig.Arena, building)
	local buildingMinZ = bounds.center.Z - bounds.halfDepth - t
	local buildingMaxZ = bounds.center.Z + bounds.halfDepth + t
	local westMinX = mansion.minX - t

	WallBuilder.createBox(parent, "MansionFloor", box(mansion.minX, floorY - 1, mansion.minZ - t, mansion.maxX + t, floorY, mansion.maxZ + t), MansionConfig.FloorColor, Enum.Material.WoodPlanks)
	WallBuilder.createBox(parent, "MansionCeiling", box(westMinX, topY, mansion.minZ - t, mansion.maxX + t, topY + 1, mansion.maxZ + t), MansionConfig.CeilingColor, Enum.Material.Plaster)
	WallBuilder.createBox(parent, "MansionWallNorth", box(westMinX, floorY - 1, mansion.minZ - t, mansion.maxX + t, topY, mansion.minZ), wallColor, Enum.Material.Plaster)
	WallBuilder.createBox(parent, "MansionWallSouth", box(westMinX, floorY - 1, mansion.maxZ, mansion.maxX + t, topY, mansion.maxZ + t), wallColor, Enum.Material.Plaster)
	-- Parede leste com as portas para a ala nova (MansionWingLayout).
	local eastHoles: { Box } = {}
	for _, doorway in ipairs(if withWing then eastDoorways() else {}) do
		local point = Vector3.new(mansion.maxX, floorY, doorway.center.Z)
		table.insert(eastHoles, WallBuilder.hole(point, Vector3.new(-1, 0, 0), Vector3.zAxis, t, doorway.size))
	end
	WallBuilder.createWallWithHoles(parent, "MansionWallEast", box(mansion.maxX, floorY - 1, mansion.minZ, mansion.maxX + t, topY, mansion.maxZ), eastHoles, wallColor, Enum.Material.Plaster)
	WallBuilder.createBox(parent, "MansionWallWestNorth", box(westMinX, floorY - 1, mansion.minZ, mansion.minX, topY, buildingMinZ), wallColor, Enum.Material.Plaster)
	WallBuilder.createBox(parent, "MansionWallWestSouth", box(westMinX, floorY - 1, buildingMaxZ, mansion.minX, topY, mansion.maxZ), wallColor, Enum.Material.Plaster)
	WallBuilder.createBox(parent, "MansionWallWestUpper", box(westMinX, bounds.ceilingY + t, buildingMinZ, mansion.minX, topY, buildingMaxZ), wallColor, Enum.Material.Plaster)
end

local function archSize(): Vector2
	return Vector2.new(MansionConfig.ArchWidth, MansionConfig.ArchHeight)
end

-- Divisórias internas, sólidas, com um arco em cada ponto de passagem.
local function createPartitions(parent: Instance, mansion: Mansion)
	local half = MansionConfig.PartitionThickness / 2
	local t = MansionConfig.PartitionThickness
	local color = MansionConfig.WallpaperColors.GrandHall
	for _, partition in ipairs(mansion.partitions) do
		local holes: { Box } = {}
		local wall: Box
		if partition.axis == "X" then
			wall = box(partition.from, mansion.floorY, partition.fixed - half, partition.to, mansion.ceilingY, partition.fixed + half)
			for _, x in ipairs(partition.arches) do
				table.insert(holes, WallBuilder.hole(Vector3.new(x, mansion.floorY, partition.fixed + half), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), t, archSize()))
			end
		else
			wall = box(partition.fixed - half, mansion.floorY, partition.from, partition.fixed + half, mansion.ceilingY, partition.to)
			for _, z in ipairs(partition.arches) do
				table.insert(holes, WallBuilder.hole(Vector3.new(partition.fixed + half, mansion.floorY, z), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), t, archSize()))
			end
		end
		WallBuilder.createWallWithHoles(parent, partition.name, wall, holes, color, Enum.Material.Plaster)
	end
end

-- Papel de parede, lambri e quadros de uma face, recortados em volta dos vãos.
local function decorateFace(parent: Instance, mansion: Mansion, face: Face, style: BuildingConfig, rng: Random)
	local origin = Vector3.new((face.a.X + face.b.X) / 2, 0, (face.a.Z + face.b.Z) / 2)
	local length = Vector2.new(face.b.X - face.a.X, face.b.Z - face.a.Z).Magnitude
	local along = face.inward:Cross(Vector3.yAxis)
	local segment: BuildingDecor.WallSegment = {
		name = face.name,
		origin = origin,
		inward = face.inward,
		length = length,
		bottomY = mansion.floorY,
		topY = mansion.ceilingY,
	}
	local gaps: { DoorGap } = {}
	for _, opening in ipairs(face.openings) do
		local offset = (opening.point - origin):Dot(along)
		if math.abs(offset) + opening.size.X / 2 <= length / 2 then
			table.insert(gaps, { offset = offset, frame = true, width = opening.size.X, height = opening.size.Y })
			local label = opening.label
			if label ~= nil then
				local position = origin + (along * offset) + (face.inward * 0.55) + Vector3.new(0, mansion.floorY + opening.size.Y + 2.6, 0)
				MansionPlaque.create(parent, `{face.name}Plaque`, CFrame.fromMatrix(position, along, Vector3.yAxis), label, style)
			end
		end
	end
	BuildingDecor.decorateStory(parent, segment, mansion.floorY, mansion.ceilingY, style, {
		wallpaperColor = face.color,
		lamps = false,
		art = true,
		windows = false,
		door = false,
		gaps = gaps,
		lampRange = 0,
		lampBrightness = 0,
	}, rng)
end

-- Todas as faces internas, sala por sala, com os vãos e as placas que dizem
-- para onde cada passagem leva.
local function getFaces(mansion: Mansion, withWing: boolean): { Face }
	local colors = MansionConfig.WallpaperColors
	local rooms = mansion.rooms
	local hall = rooms.GrandHall
	local meeting = rooms.Meeting
	local half = MansionConfig.PartitionThickness / 2
	local north = hall.minZ
	local south = hall.maxZ
	local hallEast = hall.maxX
	local splitX = meeting.maxX
	local northPartition: MansionLayout.Partition? = nil
	for _, partition in ipairs(mansion.partitions) do
		if partition.name == "NorthPartition" then
			northPartition = partition
		end
	end
	assert(northPartition ~= nil, "MansionLayout must define NorthPartition")
	-- As divisórias norte e sul têm os arcos nas mesmas posições X.
	local leftArch, rightArch = northPartition.arches[1], northPartition.arches[2]
	local arch = archSize()
	local passage = MansionConfig.PassageSize
	local function at(x: number, z: number): Vector3
		return Vector3.new(x, 0, z)
	end
	local function opening(x: number, z: number, size: Vector2, label: string?): Opening
		return { point = at(x, z), size = size, label = label }
	end

	-- Portas para a ala nova, com a placa do lado do Casarão.
	local function wingOpening(name: string): Opening
		local doorway = eastDoorway(name)
		local label = doorway.labelNegative
		return opening(mansion.maxX, doorway.center.Z, doorway.size, if label ~= nil then Lang.t(label) else nil)
	end

	local passages: { Opening } = {}
	for _, z in ipairs(mansion.passages) do
		-- O portal "ENTRAR NA FILA" de cada porta é do MatchQueueService.
		table.insert(passages, opening(mansion.minX, z, passage, nil))
	end
	local x0, x1 = mansion.minX, mansion.maxX
	local z0, z1 = mansion.minZ, mansion.maxZ
	-- Normais das faces (apontam para dentro da sala).
	local toWest = Vector3.new(-1, 0, 0)
	local toEast = Vector3.new(1, 0, 0)
	local toSouth = Vector3.new(0, 0, 1)
	local toNorth = Vector3.new(0, 0, -1)

	return {
		-- Salão Principal
		{ name = "HallWest", a = at(x0, north + half), b = at(x0, south - half), inward = toEast, color = colors.GrandHall, openings = passages },
		{ name = "HallNorth", a = at(x0, north + half), b = at(hallEast - half, north + half), inward = toSouth, color = colors.GrandHall, openings = {
			opening(leftArch, north, arch, Lang.t("✨ SALÃO DA COLEÇÃO")),
		} },
		{ name = "HallSouth", a = at(x0, south - half), b = at(hallEast - half, south - half), inward = toNorth, color = colors.GrandHall, openings = {
			opening(leftArch, south, arch, Lang.t("👥 PONTO DE ENCONTRO")),
		} },
		{ name = "HallEast", a = at(hallEast - half, north + half), b = at(hallEast - half, south - half), inward = toWest, color = colors.GrandHall, openings = {
			opening(hallEast, mansion.center.Z, arch, Lang.t("🐶 JARDIM DO BARÃO")),
		} },
		-- Salão da Coleção (norte)
		{ name = "CollectionNorth", a = at(x0, z0), b = at(x1, z0), inward = toSouth, color = colors.Collection, openings = {} },
		{ name = "CollectionWest", a = at(x0, z0), b = at(x0, north - half), inward = toEast, color = colors.Collection, openings = {} },
		{ name = "CollectionEast", a = at(x1, z0), b = at(x1, north - half), inward = toWest, color = colors.Collection, openings = if withWing then { wingOpening("LibraryDoor") } else {} },
		{ name = "CollectionSouth", a = at(x0, north - half), b = at(x1, north - half), inward = toNorth, color = colors.Collection, openings = {
			opening(leftArch, north, arch, Lang.t("🏠 SALÃO PRINCIPAL")),
			opening(rightArch, north, arch, Lang.t("🐶 JARDIM DO BARÃO")),
		} },
		-- Jardim do Barão (leste)
		{ name = "GardenWest", a = at(hallEast + half, north + half), b = at(hallEast + half, south - half), inward = toEast, color = colors.Garden, openings = {
			opening(hallEast, mansion.center.Z, arch, Lang.t("🏠 SALÃO PRINCIPAL")),
		} },
		{ name = "GardenEast", a = at(x1, north + half), b = at(x1, south - half), inward = toWest, color = colors.Garden, openings = if withWing then { wingOpening("StairHallDoor") } else {} },
		{ name = "GardenNorth", a = at(hallEast + half, north + half), b = at(x1, north + half), inward = toSouth, color = colors.Garden, openings = {
			opening(rightArch, north, arch, Lang.t("✨ SALÃO DA COLEÇÃO")),
		} },
		{ name = "GardenSouth", a = at(hallEast + half, south - half), b = at(x1, south - half), inward = toNorth, color = colors.Garden, openings = {
			opening(rightArch, south, arch, Lang.t("🎯 TREINO")),
		} },
		-- Ala sul: Ponto de Encontro (oeste) e Treino (leste), sem parede entre eles.
		{ name = "MeetingNorth", a = at(x0, south + half), b = at(splitX, south + half), inward = toSouth, color = colors.Meeting, openings = {
			opening(leftArch, south, arch, Lang.t("🏠 SALÃO PRINCIPAL")),
		} },
		{ name = "MeetingWest", a = at(x0, south + half), b = at(x0, z1), inward = toEast, color = colors.Meeting, openings = {} },
		{ name = "MeetingSouth", a = at(x0, z1), b = at(splitX, z1), inward = toNorth, color = colors.Meeting, openings = {} },
		{ name = "TrainingNorth", a = at(splitX, south + half), b = at(x1, south + half), inward = toSouth, color = colors.Training, openings = {
			opening(rightArch, south, arch, Lang.t("🐶 JARDIM DO BARÃO")),
		} },
		{ name = "TrainingEast", a = at(x1, south + half), b = at(x1, z1), inward = toWest, color = colors.Training, openings = {} },
		{ name = "TrainingSouth", a = at(splitX, z1), b = at(x1, z1), inward = toNorth, color = colors.Training, openings = {} },
	}
end

local function createRug(parent: Instance, name: string, center: Vector3, width: number, depth: number, color: Color3, style: BuildingConfig)
	BuildingDecor.createPart(parent, `{name}Border`, Vector3.new(width + 1, 0.08, depth + 1), CFrame.new(center + Vector3.new(0, 0.04, 0)), style.RugColor, { material = Enum.Material.Fabric })
	BuildingDecor.createPart(parent, name, Vector3.new(width, 0.1, depth), CFrame.new(center + Vector3.new(0, 0.07, 0)), color, { material = Enum.Material.Fabric })
end

local function createCeiling(parent: Instance, mansion: Mansion, style: BuildingConfig)
	local width = mansion.maxX - mansion.minX
	local depth = mansion.maxZ - mansion.minZ
	local beamCount = math.floor(width / BEAM_SPACING)
	for index = 1, beamCount do
		local x = mansion.minX + (index * (width / (beamCount + 1)))
		BuildingDecor.createPart(
			parent,
			string.format("MansionBeam%02d", index),
			Vector3.new(BEAM_SIZE, BEAM_SIZE, depth),
			CFrame.new(x, mansion.ceilingY - (BEAM_SIZE / 2), mansion.center.Z),
			style.CeilingBeamColor,
			{ material = Enum.Material.Wood }
		)
	end
	-- Um lustre por sala (dois nas salas compridas), todos sem sombra.
	local spots: { { name: string, room: string, dx: number, radius: number } } = {
		{ name = "HallChandelier", room = "GrandHall", dx = 0, radius = 3.2 },
		{ name = "CollectionChandelierW", room = "Collection", dx = -0.25, radius = 2.2 },
		{ name = "CollectionChandelierE", room = "Collection", dx = 0.25, radius = 2.2 },
		{ name = "GardenChandelier", room = "Garden", dx = 0, radius = 2.4 },
		{ name = "MeetingChandelier", room = "Meeting", dx = 0, radius = 2.2 },
		{ name = "TrainingChandelier", room = "Training", dx = 0, radius = 2.2 },
	}
	for _, spot in ipairs(spots) do
		local room = MansionLayout.room(spot.room)
		local center = MansionLayout.roomCenter(spot.room)
		local anchor = Vector3.new(center.X + (spot.dx * (room.maxX - room.minX)), mansion.ceilingY, center.Z)
		BuildingDecor.createChandelier(parent, spot.name, anchor, CHANDELIER_DROP, spot.radius, style, MansionConfig.ChandelierRange, MansionConfig.ChandelierBrightness, false)
	end
end

-- Estátua dourada de Puff no meio do Salão Principal.
local function createStatue(parent: Instance, center: Vector3, style: BuildingConfig)
	local base = BuildingDecor.createPart(parent, "StatueBase", Vector3.new(3, 7, 7), CFrame.new(center + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), style.WainscotColor, {
		material = Enum.Material.Marble,
		collide = true,
		shape = Enum.PartType.Cylinder,
	})
	base.Color = Color3.fromRGB(232, 226, 214)
	BuildingDecor.createPart(parent, "StatueTrim", Vector3.new(0.4, 7.4, 7.4), CFrame.new(center + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), style.BrassColor, {
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
	})
	local puff = BuildingDecor.createPart(parent, "StatuePuff", Vector3.new(4.2, 4.2, 4.2), CFrame.new(center + Vector3.new(0, 5.4, 0)), STATUE_COLOR, {
		material = Enum.Material.Foil,
		collide = true,
		shape = Enum.PartType.Ball,
	})
	-- Olhando para oeste, para quem chega pelas portas da galeria.
	for _, side in ipairs({ -1, 1 }) do
		BuildingDecor.createPart(parent, "StatueEye", Vector3.new(0.5, 0.9, 0.5), CFrame.new(center + Vector3.new(-2, 5.9, side * 0.8)), Color3.fromRGB(40, 30, 60), {
			shape = Enum.PartType.Ball,
		})
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(12, 0, 2.4, 0)
	gui.StudsOffset = Vector3.new(0, 4.4, 0)
	gui.MaxDistance = PLAQUE_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = puff
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = Lang.t("CASARÃO PUFF")
	title.TextColor3 = STATUE_COLOR
	title.TextScaled = true
	title.TextStrokeTransparency = 0.2
	title.Parent = gui
	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromScale(0, 0.62)
	subtitle.Size = UDim2.fromScale(1, 0.38)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = Lang.t("Explore as salas enquanto a partida não começa")
	subtitle.TextColor3 = Color3.fromRGB(255, 248, 238)
	subtitle.TextScaled = true
	subtitle.TextStrokeTransparency = 0.3
	subtitle.Parent = gui
end

-- Móveis e tapetes. Devolve as áreas do Salão Principal ocupadas por móveis,
-- onde o LobbyService não deve colocar ninguém.
local function furnish(parent: Instance, mansion: Mansion, style: BuildingConfig): { ReservedArea }
	local floorY = mansion.floorY
	local half = MansionConfig.PartitionThickness / 2
	local hall = mansion.rooms.GrandHall
	local hallCenter = MansionLayout.roomCenter("GrandHall")
	local reserved: { ReservedArea } = {}

	createRug(parent, "HallRug", hallCenter, (hall.maxX - hall.minX) - 16, (hall.maxZ - hall.minZ) - 16, MansionConfig.HallRugColor, style)
	-- Passadeira entre a vitrine e o púlpito do Puffdex (LobbyStationsService).
	createRug(parent, "CollectionRunner", MansionLayout.roomCenter("Collection") + Vector3.new(0, 0, 5.5), (mansion.maxX - mansion.minX) - 24, 6, MansionConfig.HallRugColor, style)
	local meeting = MansionLayout.roomCenter("Meeting")
	createRug(parent, "MeetingRug", meeting + Vector3.new(0, 0, 4), 22, 16, Color3.fromRGB(64, 92, 140), style)
	local garden = MansionLayout.roomCenter("Garden")
	BuildingDecor.createPart(parent, "GardenLawn", Vector3.new(0.12, 30, 30), CFrame.new(garden + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2), GRASS_COLOR, {
		material = Enum.Material.Grass,
		shape = Enum.PartType.Cylinder,
	})

	createStatue(parent, hallCenter, style)
	table.insert(reserved, { center = hallCenter, size = Vector3.new(9, 0, 9) })

	-- Sofás do Salão encostados na divisória leste, dos dois lados do arco.
	for index, dz in ipairs({ -17, 17 }) do
		local base = Vector3.new(hall.maxX - half - 2.4, floorY, hallCenter.Z + dz)
		BuildingDecor.createSofa(parent, `HallSofa{index}`, base, Vector3.new(-1, 0, 0), 8, style)
		table.insert(reserved, { center = base, size = Vector3.new(6, 0, 10) })
	end
	-- Plantas nos cantos do Salão.
	local inset = 2.4
	for index, corner in ipairs({
		Vector3.new(hall.minX + inset, floorY, hall.minZ + half + inset),
		Vector3.new(hall.maxX - half - inset, floorY, hall.minZ + half + inset),
		Vector3.new(hall.minX + inset, floorY, hall.maxZ - half - inset),
		Vector3.new(hall.maxX - half - inset, floorY, hall.maxZ - half - inset),
	}) do
		BuildingDecor.createPlant(parent, `HallPlant{index}`, corner, style)
		table.insert(reserved, { center = corner, size = Vector3.new(5, 0, 5) })
	end

	-- Plantas nas diagonais do gramado: os caminhos dos três arcos e da
	-- loja (parede leste) ficam livres.
	for index = 1, 4 do
		local angle = math.rad(45 + (index - 1) * 90)
		BuildingDecor.createPlant(parent, `GardenPlant{index}`, garden + Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12), style)
	end
	-- Sofás de frente um para o outro no Ponto de Encontro (a Party fica ali).
	for index, side in ipairs({ -1, 1 }) do
		BuildingDecor.createSofa(parent, `MeetingSofa{index}`, meeting + Vector3.new(side * 8, 0, 6), Vector3.new(-side, 0, 0), 8, style)
	end
	BuildingDecor.createSideTable(parent, "MeetingTable", meeting + Vector3.new(0, 0, 6), style)
	return reserved
end

-- Constrói o Casarão. Chamar depois do BuildingService (as portas ficam na
-- parede leste do prédio) e depois do LobbyService (reserva as áreas dos móveis).
function MansionService.create(worldRoot: Model, building: BuildingConfig): Model
	MansionService.destroy()
	destroyExisting(worldRoot)
	local mansion = MansionLayout.get()
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)

	local rng = Random.new(DECOR_SEED)
	-- A ala leste é opcional: uma falha nela não impede o servidor de subir.
	-- Sem ela, a parede leste fica fechada (sem portas para o vazio).
	local wingOk, wingFailure = pcall(MansionWing.build, model, building)
	if not wingOk then
		warn(`[BlocoPuff] Mansion east wing unavailable: {wingFailure}`)
	end
	createShell(model, mansion, building, wingOk)
	createPartitions(model, mansion)
	MansionDoors.build(model, MansionDoors.partitionDoorways(mansion))
	for _, face in ipairs(getFaces(mansion, wingOk)) do
		decorateFace(model, mansion, face, building, rng)
	end
	createCeiling(model, mansion, building)
	LobbyService.addReservedAreas(furnish(model, mansion, building))

	model.Parent = worldRoot
	mansionModel = model
	return model
end

function MansionService.destroy()
	local model = mansionModel
	if model ~= nil and model.Parent ~= nil and model:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME then
		model:Destroy()
	end
	mansionModel = nil
end

return table.freeze(MansionService)
