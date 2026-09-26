--!strict

-- Constrói o prédio fechado onde a partida acontece, com interior no estilo
-- mansão: porão de tijolos no poço, um andar decorado para cada piso da
-- arena, teto com vigas e lustres e uma galeria envidraçada que funciona
-- como lobby. A geometria vem de BuildingLayout; a decoração, de
-- BuildingDecor. Só usa instâncias e materiais nativos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)

type ArenaConfig = GameConfig.ArenaConfig
type BuildingConfig = GameConfig.BuildingConfig
type WallSegment = BuildingDecor.WallSegment

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
local ARENA_LAMP_RANGE = 22
local ARENA_LAMP_BRIGHTNESS = 1.1
-- Andares abaixo do topo não recebem luz dos lustres; arandelas mais fortes
-- e luzes de preenchimento compensam.
local LOWER_LAMP_RANGE = 30
local LOWER_LAMP_BRIGHTNESS = 1.5
local FILL_LIGHT_GRID = 4
-- Altura acima do piso inferior: perto o bastante para iluminar o chão
-- (inclusive o meio da sala) e acima da cabeça dos jogadores.
local FILL_LIGHT_HEIGHT = 12
local FILL_LIGHT_RANGE = 34
local FILL_LIGHT_BRIGHTNESS = 1.8
local GALLERY_LAMP_RANGE = 16
local GALLERY_LAMP_BRIGHTNESS = 0.8
local CHANDELIER_DROP = 5
local CHANDELIER_RANGE = 46
local CHANDELIER_BRIGHTNESS = 1.5
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
	createSolid(
		parent,
		"WallWest",
		Vector3.new(thickness, height, innerDepth),
		Vector3.new(center.X - bounds.halfWidth - (thickness / 2), midY, center.Z),
		wallColor,
		Enum.Material.Plaster
	)
	createSolid(
		parent,
		"WallEast",
		Vector3.new(thickness, height, innerDepth),
		Vector3.new(gallery.innerX + building.GalleryDepth + (thickness / 2), midY, center.Z),
		wallColor,
		Enum.Material.Plaster
	)
	for _, side in ipairs({ -1, 1 }) do
		createSolid(
			parent,
			if side < 0 then "WallNorth" else "WallSouth",
			Vector3.new(outerWidth, height, thickness),
			Vector3.new(outerCenterX, midY, center.Z + (side * (bounds.halfDepth + (thickness / 2)))),
			wallColor,
			Enum.Material.Plaster
		)
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
			windows = segment.name == "GalleryEast",
			door = segment.name ~= "GalleryEast",
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
		if index < sofaCount then
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
			28,
			1
		)
	end
end

-- Luzes invisíveis a meia altura de cada andar inferior, fazendo o papel de
-- luminárias de teto. Ficam fora do alcance de tiros e
-- colisões e não dependem dos blocos, que podem ser destruídos.
local function createFillLights(parent: Instance, arena: ArenaConfig, building: BuildingConfig)
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	for floorIndex = 1, arena.FloorCount - 1 do
		local y = BuildingLayout.getFloorSurfaceY(arena, floorIndex) + FILL_LIGHT_HEIGHT
		for row = 1, FILL_LIGHT_GRID do
			for column = 1, FILL_LIGHT_GRID do
				local xRatio = ((column - 0.5) / FILL_LIGHT_GRID) - 0.5
				local zRatio = ((row - 0.5) / FILL_LIGHT_GRID) - 0.5
				local source = BuildingDecor.createPart(
					parent,
					string.format("FillLightF%d_%d_%d", floorIndex, row, column),
					Vector3.new(0.2, 0.2, 0.2),
					CFrame.new(
						bounds.center.X + (xRatio * bounds.halfWidth * 2),
						y,
						bounds.center.Z + (zRatio * bounds.halfDepth * 2)
					),
					building.LampColor,
					{ transparency = 1 }
				)
				local light = Instance.new("PointLight")
				light.Color = building.LampColor
				light.Range = FILL_LIGHT_RANGE
				light.Brightness = FILL_LIGHT_BRIGHTNESS
				light.Shadows = false
				light.Parent = source
			end
		end
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
