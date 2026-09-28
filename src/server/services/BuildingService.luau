--!strict

-- Constrói o prédio fechado onde a partida acontece, com interior no estilo
-- mansão: porão de tijolos no poço, um andar decorado para cada piso da
-- arena, teto com vigas e lustres e uma galeria envidraçada que funciona
-- como mirante da arena, com portas para o Casarão (o lobby principal, ver
-- MansionService). A geometria vem de BuildingLayout; a decoração, de
-- BuildingDecor. Só usa instâncias e materiais nativos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local SecretRoomBuilder = require(script.Parent.SecretRoomBuilder)
local WallBuilder = require(script.Parent.WallBuilder)
local CorridorBuilder = require(script.Parent.CorridorBuilder)

type ArenaConfig = GameConfig.ArenaConfig
type BuildingConfig = GameConfig.BuildingConfig
type WallSegment = BuildingDecor.WallSegment
type DoorGap = BuildingDecor.DoorGap

local MODEL_NAME = "Building"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "BuildingService"
-- Modelos criados por versões anteriores que não devem sobreviver ao novo mapa.
local LEGACY_MODELS: { [string]: string } = {
	SkyIslandLobby = "SkyIslandService",
	SkyIslandBackdrop = "SkyIslandService",
}

-- Semente fixa: quadros e cores ficam iguais em todo servidor e reinício.
local DECOR_SEED = 1987
local FLOOR_BAND_HEIGHT = 1.6
local FLOOR_BAND_DEPTH = 0.5
local BEAM_SIZE = 1.2
local BEAM_SPACING = 14
-- Arandelas e abajures são apenas acentos: luz fraca e curta, para não
-- criar pontos estourados no personagem quando ele passa perto da parede.
local ARENA_LAMP_RANGE = 14
local ARENA_LAMP_BRIGHTNESS = 0.45
-- Andares abaixo do topo não recebem luz dos lustres; arandelas mais fortes
-- e luzes de preenchimento compensam.
local LOWER_LAMP_RANGE = 16
local LOWER_LAMP_BRIGHTNESS = 0.5
-- Preenchimento do andar de baixo: um único painel invisível do tamanho da
-- sala, logo abaixo do piso de cima, com SurfaceLight voltada para baixo.
-- Luz difusa e uniforme, sem somar vários pontos de luz no chão.
local FILL_PANEL_DROP = 1.5
local FILL_PANEL_RANGE = 32
local FILL_PANEL_ANGLE = 90
local FILL_PANEL_BRIGHTNESS = 0.3
local GALLERY_LAMP_RANGE = 12
local GALLERY_LAMP_BRIGHTNESS = 0.4
local CHANDELIER_DROP = 5
local CHANDELIER_RANGE = 40
local CHANDELIER_BRIGHTNESS = 0.6
local GLASS_THICKNESS = 0.4
local GLASS_TRANSPARENCY = 0.78
local GLASS_COLOR = Color3.fromRGB(170, 190, 200)
local MULLION_SPACING = 12
local HANDRAIL_HEIGHT = 3.4
local SOFA_WIDTH = 7
local SOFA_SPACING = 20

local BuildingService = {}

local buildingModel: Model? = nil

local function isOwned(instance: Instance, owner: string): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == owner
end

local function destroyOwnedChild(worldRoot: Model, name: string, owner: string)
	local existing = worldRoot:FindFirstChild(name)
	if existing == nil then
		return
	end
	if not isOwned(existing, owner) then
		error(`Cannot replace {existing:GetFullName()} because it is not owned by {owner}`)
	end
	existing:Destroy()
end

local function removeDefaultBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate ~= nil and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
end

local function createSolid(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local part = BuildingDecor.createPart(parent, name, size, CFrame.new(position), color, {
		material = material,
		collide = true,
	})
	return part
end

type Box = WallBuilder.Box

local createWallWithHoles = WallBuilder.createWallWithHoles

-- Vão de porta secreta (cofre, corredores) atravessando a parede inteira,
-- centrado em `point` (face interna, no nível do piso).
local function doorHole(point: Vector3, inward: Vector3, along: Vector3, thickness: number): Box
	return WallBuilder.hole(point, inward, along, thickness, BuildingLayout.SecretDoorSize)
end

-- Portas largas da galeria para o Casarão (lobby principal), na parede leste.
local function getPassageHoles(building: BuildingConfig): { Box }
	local mansion = MansionLayout.get()
	local holes: { Box } = {}
	for _, z in ipairs(mansion.passages) do
		local point = Vector3.new(mansion.galleryWallX - building.WallThickness, mansion.floorY, z)
		table.insert(holes, WallBuilder.hole(point, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), building.WallThickness, MansionConfig.PassageSize))
	end
	return holes
end

-- Mesmas portas vistas da galeria (parede GalleryEast: ao longo = −Z).
local function getPassageGaps(): { DoorGap }
	local mansion = MansionLayout.get()
	local centerZ = mansion.center.Z
	local gaps: { DoorGap } = {}
	for _, z in ipairs(mansion.passages) do
		table.insert(gaps, { offset = centerZ - z, frame = true, width = MansionConfig.PassageSize.X, height = MansionConfig.PassageSize.Y })
	end
	return gaps
end

local function nearPassage(z: number, clearance: number): boolean
	for _, passageZ in ipairs(MansionLayout.get().passages) do
		if math.abs(z - passageZ) < clearance then
			return true
		end
	end
	return false
end

-- Vãos de cada parede: a porta do cofre (oeste) e as duas entradas de cada
-- corredor secreto (norte e sul).
local function getDoorHoles(arena: ArenaConfig, building: BuildingConfig): { [string]: { Box } }
	local holes: { [string]: { Box } } = {}
	local thickness = building.WallThickness
	for _, door in ipairs(BuildingLayout.getSecretDoors(arena, building)) do
		holes[door.name] = holes[door.name] or {}
		table.insert(holes[door.name], doorHole(door.center, door.inward, door.along, thickness))
	end
	for _, corridor in ipairs(BuildingLayout.getCorridors(arena, building)) do
		local list = holes[corridor.name] or {}
		holes[corridor.name] = list
		local lower = corridor.wallCenter + (corridor.along * corridor.lowerAlong) + Vector3.new(0, corridor.lowerY, 0)
		local upper = corridor.wallCenter + (corridor.along * corridor.upperAlong) + Vector3.new(0, corridor.upperY, 0)
		table.insert(list, doorHole(lower, corridor.inward, corridor.along, thickness))
		table.insert(list, doorHole(upper, corridor.inward, corridor.along, thickness))
	end
	return holes
end

type Segments = {
	arena: { WallSegment },
	gallery: { WallSegment },
}

local function getSegments(arena: ArenaConfig, building: BuildingConfig): Segments
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local gallery = BuildingLayout.getGallery(arena, building)
	local center = Vector3.new(bounds.center.X, 0, bounds.center.Z)
	local supportTopY = gallery.floorY - 1
	local galleryCenterX = gallery.center.X

	return {
		arena = {
			{
				name = "West",
				origin = center + Vector3.new(-bounds.halfWidth, 0, 0),
				inward = Vector3.new(1, 0, 0),
				length = bounds.halfDepth * 2,
				bottomY = bounds.bottomY,
				topY = bounds.ceilingY,
			},
			{
				name = "North",
				origin = center + Vector3.new(0, 0, -bounds.halfDepth),
				inward = Vector3.new(0, 0, 1),
				length = bounds.halfWidth * 2,
				bottomY = bounds.bottomY,
				topY = bounds.ceilingY,
			},
			{
				name = "South",
				origin = center + Vector3.new(0, 0, bounds.halfDepth),
				inward = Vector3.new(0, 0, -1),
				length = bounds.halfWidth * 2,
				bottomY = bounds.bottomY,
				topY = bounds.ceilingY,
			},
			{
				-- Face do bloco que sustenta a galeria; acima dela fica o vidro.
				name = "EastSupport",
				origin = center + Vector3.new(bounds.halfWidth, 0, 0),
				inward = Vector3.new(-1, 0, 0),
				length = bounds.halfDepth * 2,
				bottomY = bounds.bottomY,
				topY = supportTopY,
			},
		},
		gallery = {
			{
				name = "GalleryEast",
				origin = Vector3.new(gallery.innerX + building.GalleryDepth, 0, center.Z),
				inward = Vector3.new(-1, 0, 0),
				length = bounds.halfDepth * 2,
				bottomY = gallery.floorY,
				topY = bounds.ceilingY,
			},
			{
				name = "GalleryNorth",
				origin = Vector3.new(galleryCenterX, 0, center.Z - bounds.halfDepth),
				inward = Vector3.new(0, 0, 1),
				length = building.GalleryDepth,
				bottomY = gallery.floorY,
				topY = bounds.ceilingY,
			},
			{
				name = "GallerySouth",
				origin = Vector3.new(galleryCenterX, 0, center.Z + bounds.halfDepth),
				inward = Vector3.new(0, 0, -1),
				length = building.GalleryDepth,
				bottomY = gallery.floorY,
				topY = bounds.ceilingY,
			},
		},
	}
end

local function createShell(parent: Instance, arena: ArenaConfig, building: BuildingConfig)
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local gallery = BuildingLayout.getGallery(arena, building)
	local thickness = building.WallThickness
	local center = bounds.center
	local height = bounds.ceilingY - bounds.bottomY
	local midY = (bounds.ceilingY + bounds.bottomY) / 2
	local outerWidth = (bounds.halfWidth * 2) + building.GalleryDepth + (thickness * 2)
	local outerCenterX = center.X + (building.GalleryDepth / 2)
	local innerDepth = bounds.halfDepth * 2
	local wallColor = building.StoryWallpaperColors[1]

	createSolid(
		parent,
		"PitFloor",
		Vector3.new(outerWidth, thickness, innerDepth + (thickness * 2)),
		Vector3.new(outerCenterX, bounds.bottomY - (thickness / 2), center.Z),
		building.PitFloorColor,
		Enum.Material.Slate
	)
	createSolid(
		parent,
		"Ceiling",
		Vector3.new(outerWidth, thickness, innerDepth + (thickness * 2)),
		Vector3.new(outerCenterX, bounds.ceilingY + (thickness / 2), center.Z),
		building.CeilingColor,
		Enum.Material.Plaster
	)
	local holes = getDoorHoles(arena, building)
	local halfHeight = Vector3.new(0, height / 2, 0)
	local westCenter = Vector3.new(center.X - bounds.halfWidth - (thickness / 2), midY, center.Z)
	local westHalf = Vector3.new(thickness / 2, 0, innerDepth / 2) + halfHeight
	createWallWithHoles(parent, "WallWest", { min = westCenter - westHalf, max = westCenter + westHalf }, holes.West or {}, wallColor, Enum.Material.Plaster)
	local eastCenter = Vector3.new(gallery.innerX + building.GalleryDepth + (thickness / 2), midY, center.Z)
	local eastHalf = Vector3.new(thickness / 2, 0, innerDepth / 2) + halfHeight
	createWallWithHoles(parent, "WallEast", { min = eastCenter - eastHalf, max = eastCenter + eastHalf }, getPassageHoles(building), wallColor, Enum.Material.Plaster)
	for _, side in ipairs({ -1, 1 }) do
		local wallName = if side < 0 then "North" else "South"
		local wallCenter = Vector3.new(outerCenterX, midY, center.Z + (side * (bounds.halfDepth + (thickness / 2))))
		local wallHalf = Vector3.new(outerWidth / 2, 0, thickness / 2) + halfHeight
		createWallWithHoles(parent, `Wall{wallName}`, { min = wallCenter - wallHalf, max = wallCenter + wallHalf }, holes[wallName] or {}, wallColor, Enum.Material.Plaster)
	end

	local supportTopY = gallery.floorY - 1
	createSolid(
		parent,
		"GallerySupport",
		Vector3.new(building.GalleryDepth, supportTopY - bounds.bottomY, innerDepth),
		Vector3.new(gallery.center.X, (supportTopY + bounds.bottomY) / 2, center.Z),
		building.BasementBrickColor,
		Enum.Material.Brick
	)
	createSolid(
		parent,
		"GalleryFloor",
		Vector3.new(building.GalleryDepth, 1, innerDepth),
		Vector3.new(gallery.center.X, gallery.floorY - 0.5, center.Z),
		building.GalleryCarpetColor,
		Enum.Material.Carpet
	)
end

-- Vãos reais de porta na decoração de um andar de uma parede: a porta do
-- cofre (com moldura) e as entradas dos corredores (escondidas, sem moldura).
local function getStoryGaps(arena: ArenaConfig, building: BuildingConfig, segmentName: string, floorIndex: number): { DoorGap }
	local gaps: { DoorGap } = {}
	if floorIndex == 1 then
		for _, door in ipairs(BuildingLayout.getSecretDoors(arena, building)) do
			if door.name == segmentName then
				table.insert(gaps, { offset = 0, frame = true })
			end
		end
	end
	for _, corridor in ipairs(BuildingLayout.getCorridors(arena, building)) do
		if corridor.name == segmentName then
			if floorIndex == 1 then
				table.insert(gaps, { offset = corridor.lowerAlong, frame = false })
			end
			if floorIndex == arena.FloorCount then
				table.insert(gaps, { offset = corridor.upperAlong, frame = false })
			end
		end
	end
	return gaps
end

-- Poço como porão de tijolos, um andar decorado por piso da arena e uma
-- faixa de madeira na altura de cada laje, reforçando a ideia de prédio.
local function decorateArenaWalls(parent: Instance, arena: ArenaConfig, building: BuildingConfig, segments: { WallSegment }, rng: Random)
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local halfBlock = arena.BlockSize.Y / 2
	for _, segment in ipairs(segments) do
		local basementTop = math.min(BuildingLayout.getFloorY(arena, 1) - halfBlock, segment.topY)
		BuildingDecor.createPart(
			parent,
			`{segment.name}Basement`,
			Vector3.new(segment.length, basementTop - bounds.bottomY, 0.2),
			BuildingDecor.wallCFrame(segment, 0, (basementTop + bounds.bottomY) / 2, 0.1),
			building.BasementBrickColor,
			{ material = Enum.Material.Brick }
		)

		for floorIndex = 1, arena.FloorCount do
			local floorY = BuildingLayout.getFloorY(arena, floorIndex)
			if floorY < segment.topY then
				BuildingDecor.createPart(
					parent,
					string.format("%sFloorBand%d", segment.name, floorIndex),
					Vector3.new(segment.length, FLOOR_BAND_HEIGHT, FLOOR_BAND_DEPTH),
					BuildingDecor.wallCFrame(segment, 0, floorY, FLOOR_BAND_DEPTH / 2),
					building.TrimColor,
					{ material = Enum.Material.Wood }
				)
			end

			local storyBottom = BuildingLayout.getFloorSurfaceY(arena, floorIndex)
			local isTop = floorIndex == arena.FloorCount
			local storyTop = if isTop then bounds.ceilingY else BuildingLayout.getFloorY(arena, floorIndex + 1) - halfBlock
			local wallpapers = building.StoryWallpaperColors
			local isOuterWall = segment.name ~= "EastSupport"
			BuildingDecor.decorateStory(parent, segment, storyBottom, storyTop, building, {
				wallpaperColor = wallpapers[math.min(floorIndex, #wallpapers)],
				lamps = true,
				art = true,
				windows = isTop and isOuterWall,
				door = not isTop and isOuterWall,
				gaps = getStoryGaps(arena, building, segment.name, floorIndex),
				paintingFloor = floorIndex,
				lampRange = if isTop then ARENA_LAMP_RANGE else LOWER_LAMP_RANGE,
				lampBrightness = if isTop then ARENA_LAMP_BRIGHTNESS else LOWER_LAMP_BRIGHTNESS,
			}, rng)
		end
	end
end

local function decorateGallery(parent: Instance, arena: ArenaConfig, building: BuildingConfig, segments: { WallSegment }, rng: Random)
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local gallery = BuildingLayout.getGallery(arena, building)
	for _, segment in ipairs(segments) do
		BuildingDecor.decorateStory(parent, segment, gallery.floorY, bounds.ceilingY, building, {
			wallpaperColor = building.GalleryWallpaperColor,
			lamps = true,
			art = true,
			-- A parede leste tem as portas reais para o Casarão.
			windows = false,
			door = segment.name ~= "GalleryEast",
			gaps = if segment.name == "GalleryEast" then getPassageGaps() else nil,
			lampRange = GALLERY_LAMP_RANGE,
			lampBrightness = GALLERY_LAMP_BRIGHTNESS,
		}, rng)
	end

	local innerDepth = bounds.halfDepth * 2
	BuildingDecor.createPart(
		parent,
		"GalleryRug",
		Vector3.new(building.GalleryDepth - 8, 0.1, innerDepth * 0.8),
		CFrame.new(gallery.center + Vector3.new(0, 0.05, 0)),
		building.RugColor,
		{ material = Enum.Material.Fabric }
	)

	-- Vidro com montantes de madeira e corrimão: o lobby enxerga a arena,
	-- mas ninguém entra nela antes de ser escalado para a partida.
	local supportTopY = gallery.floorY - 1
	local glassHeight = bounds.ceilingY - supportTopY
	local glass = BuildingDecor.createPart(
		parent,
		"GalleryGlass",
		Vector3.new(GLASS_THICKNESS, glassHeight, innerDepth),
		CFrame.new(gallery.innerX + (GLASS_THICKNESS / 2), supportTopY + (glassHeight / 2), bounds.center.Z),
		GLASS_COLOR,
		{ material = Enum.Material.Glass, collide = true, transparency = GLASS_TRANSPARENCY }
	)
	glass.CastShadow = false

	local mullionCount = math.floor(innerDepth / MULLION_SPACING)
	for index = 0, mullionCount do
		local z = bounds.center.Z - bounds.halfDepth + (index * (innerDepth / mullionCount))
		BuildingDecor.createPart(
			parent,
			string.format("GlassMullion%02d", index),
			Vector3.new(0.8, glassHeight, 0.6),
			CFrame.new(gallery.innerX + 0.4, supportTopY + (glassHeight / 2), z),
			building.TrimColor,
			{ material = Enum.Material.Wood }
		)
	end
	BuildingDecor.createPart(
		parent,
		"GalleryHandrail",
		Vector3.new(0.6, 0.4, innerDepth),
		CFrame.new(gallery.innerX + 1, gallery.floorY + HANDRAIL_HEIGHT, bounds.center.Z),
		building.TrimColor,
		{ material = Enum.Material.Wood }
	)

	local eastX = gallery.innerX + building.GalleryDepth
	local sofaCount = math.floor(innerDepth / SOFA_SPACING)
	for index = 1, sofaCount do
		local z = bounds.center.Z - bounds.halfDepth + ((index - 0.5) * (innerDepth / sofaCount))
		BuildingDecor.createSofa(
			parent,
			string.format("Sofa%02d", index),
			Vector3.new(eastX - 2.4, gallery.floorY, z),
			Vector3.new(-1, 0, 0),
			SOFA_WIDTH,
			building
		)
		local between = z + ((innerDepth / sofaCount) / 2)
		-- Mesinhas e plantas não ficam na frente das portas do Casarão.
		if index < sofaCount and not nearPassage(between, MansionConfig.PassageSize.X / 2 + 1.5) then
			if index % 2 == 1 then
				BuildingDecor.createSideTable(parent, string.format("SideTable%02d", index), Vector3.new(eastX - 1.8, gallery.floorY, between), building)
			else
				BuildingDecor.createPlant(parent, string.format("Plant%02d", index), Vector3.new(eastX - 1.8, gallery.floorY, between), building)
			end
		end
	end
end

local function decorateCeiling(parent: Instance, arena: ArenaConfig, building: BuildingConfig)
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local gallery = BuildingLayout.getGallery(arena, building)
	local innerDepth = bounds.halfDepth * 2
	local fullWidth = (bounds.halfWidth * 2) + building.GalleryDepth
	local fullCenterX = bounds.center.X + (building.GalleryDepth / 2)
	local beamY = bounds.ceilingY - (BEAM_SIZE / 2)

	local beamCount = math.floor(innerDepth / BEAM_SPACING)
	for index = 1, beamCount do
		local z = bounds.center.Z - bounds.halfDepth + (index * (innerDepth / (beamCount + 1)))
		BuildingDecor.createPart(
			parent,
			string.format("CeilingBeam%02d", index),
			Vector3.new(fullWidth, BEAM_SIZE, BEAM_SIZE),
			CFrame.new(fullCenterX, beamY, z),
			building.CeilingBeamColor,
			{ material = Enum.Material.Wood }
		)
	end

	local chandelierOffsets = {
		Vector2.new(-0.5, -0.5),
		Vector2.new(0.5, -0.5),
		Vector2.new(-0.5, 0.5),
		Vector2.new(0.5, 0.5),
	}
	for index, offset in ipairs(chandelierOffsets) do
		BuildingDecor.createChandelier(
			parent,
			string.format("Chandelier%02d", index),
			Vector3.new(
				bounds.center.X + (offset.X * bounds.halfWidth),
				bounds.ceilingY,
				bounds.center.Z + (offset.Y * bounds.halfDepth)
			),
			CHANDELIER_DROP,
			2.4,
			building,
			CHANDELIER_RANGE,
			CHANDELIER_BRIGHTNESS
		)
	end
	for index, zRatio in ipairs({ -0.5, 0.5 }) do
		BuildingDecor.createChandelier(
			parent,
			string.format("GalleryChandelier%02d", index),
			Vector3.new(gallery.center.X, bounds.ceilingY, bounds.center.Z + (zRatio * bounds.halfDepth)),
			CHANDELIER_DROP,
			1.6,
			building,
			24,
			0.45
		)
	end
end

-- Luz de teto invisível para cada andar inferior. Ficam fora do alcance de tiros e
-- colisões e não dependem dos blocos, que podem ser destruídos.
local function createFillLights(parent: Instance, arena: ArenaConfig, building: BuildingConfig)
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	for floorIndex = 1, arena.FloorCount - 1 do
		local y = BuildingLayout.getFloorY(arena, floorIndex + 1) - FILL_PANEL_DROP
		local panel = BuildingDecor.createPart(
			parent,
			string.format("FillLightF%d", floorIndex),
			Vector3.new(bounds.halfWidth * 2, 0.2, bounds.halfDepth * 2),
			CFrame.new(bounds.center.X, y, bounds.center.Z),
			building.LampColor,
			{ transparency = 1 }
		)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = building.LampColor
		light.Range = FILL_PANEL_RANGE
		light.Angle = FILL_PANEL_ANGLE
		light.Brightness = FILL_PANEL_BRIGHTNESS
		light.Shadows = false
		light.Parent = panel
	end
end

function BuildingService.create(worldRoot: Model, arena: ArenaConfig, building: BuildingConfig): Model
	BuildingService.destroy()
	removeDefaultBaseplate()
	for name, owner in pairs(LEGACY_MODELS) do
		destroyOwnedChild(worldRoot, name, owner)
	end
	destroyOwnedChild(worldRoot, MODEL_NAME, SERVICE_NAME)

	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)

	local rng = Random.new(DECOR_SEED)
	local segments = getSegments(arena, building)
	createShell(model, arena, building)
	decorateArenaWalls(model, arena, building, segments.arena, rng)
	decorateGallery(model, arena, building, segments.gallery, rng)
	decorateCeiling(model, arena, building)
	createFillLights(model, arena, building)
	for _, door in ipairs(BuildingLayout.getSecretDoors(arena, building)) do
		SecretRoomBuilder.build(model, door, building)
	end
	for _, corridor in ipairs(BuildingLayout.getCorridors(arena, building)) do
		CorridorBuilder.build(model, corridor, building)
	end

	model.Parent = worldRoot
	buildingModel = model
	return model
end

function BuildingService.destroy()
	if buildingModel ~= nil and buildingModel.Parent ~= nil and isOwned(buildingModel, SERVICE_NAME) then
		buildingModel:Destroy()
	end
	buildingModel = nil
end

function BuildingService.getModel(): Model?
	return buildingModel
end

return table.freeze(BuildingService)
