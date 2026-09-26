--!strict

-- Constrói o prédio fechado onde a partida acontece: paredes, teto e poço em
-- cores sólidas, faixas de luz por andar e uma galeria envidraçada para quem
-- aguarda ou já foi eliminado. Usa somente instâncias nativas e a geometria
-- de BuildingLayout, para que o invólucro sempre acompanhe os pisos da arena.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)

type ArenaConfig = GameConfig.ArenaConfig
type BuildingConfig = GameConfig.BuildingConfig

local MODEL_NAME = "Building"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "BuildingService"
-- Modelos criados por versões anteriores que não devem sobreviver ao novo mapa.
local LEGACY_MODELS: { [string]: string } = {
	SkyIslandLobby = "SkyIslandService",
	SkyIslandBackdrop = "SkyIslandService",
}

local TRIM_HEIGHT = 1.2
local TRIM_DEPTH = 0.4
local LIGHT_STRIP_HEIGHT = 0.6
local LIGHT_STRIP_DEPTH = 0.3
local LIGHT_STRIP_HEIGHT_ABOVE_FLOOR = 11
local LIGHT_STRIP_LENGTH_RATIO = 0.8
local WALL_LIGHT_RANGE = 40
local WALL_LIGHT_BRIGHTNESS = 1.4
local CEILING_PANEL_SIZE = Vector3.new(18, 0.4, 18)
local CEILING_LIGHT_RANGE = 36
local CEILING_LIGHT_BRIGHTNESS = 1.8
local GLASS_THICKNESS = 0.4
local GLASS_TRANSPARENCY = 0.72
local GLASS_COLOR = Color3.fromRGB(188, 214, 232)

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

local function createSolid(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createDecoration(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = createSolid(parent, name, size, position, color)
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function addSurfaceLight(part: BasePart, face: Enum.NormalId, color: Color3, range: number, brightness: number)
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Angle = 120
	light.Shadows = false
	light.Parent = part
end

type WallFace = {
	name: string,
	-- Ponto na face interna da parede, na altura zero.
	origin: Vector3,
	-- Direção que aponta para dentro da sala.
	inward: Vector3,
	length: number,
	lightFace: Enum.NormalId,
}

local function getWallFaces(arena: ArenaConfig, building: BuildingConfig): { WallFace }
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local center = bounds.center
	return {
		{
			name = "West",
			origin = center + Vector3.new(-bounds.halfWidth, 0, 0),
			inward = Vector3.new(1, 0, 0),
			length = bounds.halfDepth * 2,
			lightFace = Enum.NormalId.Right,
		},
		{
			name = "East",
			origin = center + Vector3.new(bounds.halfWidth, 0, 0),
			inward = Vector3.new(-1, 0, 0),
			length = bounds.halfDepth * 2,
			lightFace = Enum.NormalId.Left,
		},
		{
			name = "North",
			origin = center + Vector3.new(0, 0, -bounds.halfDepth),
			inward = Vector3.new(0, 0, 1),
			length = bounds.halfWidth * 2,
			lightFace = Enum.NormalId.Back,
		},
		{
			name = "South",
			origin = center + Vector3.new(0, 0, bounds.halfDepth),
			inward = Vector3.new(0, 0, -1),
			length = bounds.halfWidth * 2,
			lightFace = Enum.NormalId.Front,
		},
	}
end

local function getStripSize(face: WallFace, length: number, height: number, depth: number): Vector3
	if face.inward.X ~= 0 then
		return Vector3.new(depth, height, length)
	end
	return Vector3.new(length, height, depth)
end

-- Faixas por andar reforçam a ideia de prédio com vários pisos: um friso na
-- altura de cada piso e uma luz na parede para iluminar o nível.
local function createFloorDetails(parent: Instance, arena: ArenaConfig, building: BuildingConfig)
	local topSurfaceY = BuildingLayout.getFloorSurfaceY(arena, arena.FloorCount)
	for floorIndex = 1, arena.FloorCount do
		local floorY = BuildingLayout.getFloorY(arena, floorIndex)
		local surfaceY = BuildingLayout.getFloorSurfaceY(arena, floorIndex)
		for _, face in ipairs(getWallFaces(arena, building)) do
			-- A parede leste do piso de cima é o vidro da galeria.
			local isGalleryGlass = face.name == "East" and surfaceY >= topSurfaceY
			local trimPosition = face.origin + (face.inward * (TRIM_DEPTH / 2)) + Vector3.new(0, floorY, 0)
			createDecoration(
				parent,
				string.format("Trim%s%d", face.name, floorIndex),
				getStripSize(face, face.length, TRIM_HEIGHT, TRIM_DEPTH),
				trimPosition,
				building.TrimColor
			)

			if not isGalleryGlass then
				local stripPosition = face.origin
					+ (face.inward * (LIGHT_STRIP_DEPTH / 2))
					+ Vector3.new(0, surfaceY + LIGHT_STRIP_HEIGHT_ABOVE_FLOOR, 0)
				local strip = createDecoration(
					parent,
					string.format("LightStrip%s%d", face.name, floorIndex),
					getStripSize(face, face.length * LIGHT_STRIP_LENGTH_RATIO, LIGHT_STRIP_HEIGHT, LIGHT_STRIP_DEPTH),
					stripPosition,
					building.LightColor
				)
				strip.Material = Enum.Material.Neon
				addSurfaceLight(strip, face.lightFace, building.LightColor, WALL_LIGHT_RANGE, WALL_LIGHT_BRIGHTNESS)
			end
		end
	end
end

local function createCeilingLights(parent: Instance, arena: ArenaConfig, building: BuildingConfig)
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local offsets = {
		Vector2.new(-0.5, -0.5),
		Vector2.new(0.5, -0.5),
		Vector2.new(-0.5, 0.5),
		Vector2.new(0.5, 0.5),
	}
	for index, offset in ipairs(offsets) do
		local position = Vector3.new(
			bounds.center.X + (offset.X * bounds.halfWidth),
			bounds.ceilingY - (CEILING_PANEL_SIZE.Y / 2),
			bounds.center.Z + (offset.Y * bounds.halfDepth)
		)
		local panel = createDecoration(parent, string.format("CeilingLight%02d", index), CEILING_PANEL_SIZE, position, building.LightColor)
		panel.Material = Enum.Material.Neon
		addSurfaceLight(panel, Enum.NormalId.Bottom, building.LightColor, CEILING_LIGHT_RANGE, CEILING_LIGHT_BRIGHTNESS)
	end
end

local function createShell(parent: Instance, arena: ArenaConfig, building: BuildingConfig)
	local bounds = BuildingLayout.getRoomBounds(arena, building)
	local gallery = BuildingLayout.getGallery(arena, building)
	local thickness = building.WallThickness
	local center = bounds.center
	local height = bounds.ceilingY - bounds.bottomY
	local midY = (bounds.ceilingY + bounds.bottomY) / 2
	-- O prédio se estende para +X para abrigar a galeria.
	local outerWidth = (bounds.halfWidth * 2) + building.GalleryDepth + (thickness * 2)
	local outerCenterX = center.X + (building.GalleryDepth / 2)
	local innerDepth = bounds.halfDepth * 2

	createSolid(
		parent,
		"Pit",
		Vector3.new(outerWidth, thickness, innerDepth + (thickness * 2)),
		Vector3.new(outerCenterX, bounds.bottomY - (thickness / 2), center.Z),
		building.PitColor
	)
	createSolid(
		parent,
		"Ceiling",
		Vector3.new(outerWidth, thickness, innerDepth + (thickness * 2)),
		Vector3.new(outerCenterX, bounds.ceilingY + (thickness / 2), center.Z),
		building.CeilingColor
	)
	createSolid(
		parent,
		"WallWest",
		Vector3.new(thickness, height, innerDepth),
		Vector3.new(center.X - bounds.halfWidth - (thickness / 2), midY, center.Z),
		building.WallColor
	)
	createSolid(
		parent,
		"WallEast",
		Vector3.new(thickness, height, innerDepth),
		Vector3.new(gallery.innerX + building.GalleryDepth + (thickness / 2), midY, center.Z),
		building.WallColor
	)
	for _, side in ipairs({ -1, 1 }) do
		createSolid(
			parent,
			if side < 0 then "WallNorth" else "WallSouth",
			Vector3.new(outerWidth, height, thickness),
			Vector3.new(outerCenterX, midY, center.Z + (side * (bounds.halfDepth + (thickness / 2)))),
			building.WallColor
		)
	end

	-- Os andares inferiores recebem uma pintura mais escura para facilitar a
	-- leitura de em qual piso o jogador está.
	local lowerTopY = BuildingLayout.getFloorSurfaceY(arena, math.max(1, arena.FloorCount - 1))
		+ (arena.FloorSpacing / 2)
	for _, face in ipairs(getWallFaces(arena, building)) do
		if face.name ~= "East" then
			local paintHeight = lowerTopY - bounds.bottomY
			createDecoration(
				parent,
				`LowerPaint{face.name}`,
				getStripSize(face, face.length, paintHeight, 0.1),
				face.origin + (face.inward * 0.05) + Vector3.new(0, bounds.bottomY + (paintHeight / 2), 0),
				building.LowerWallColor
			)
		end
	end

	-- Bloco maciço sob a galeria: sua face oeste fecha a lateral da arena nos
	-- pisos inferiores e seu topo sustenta o piso da galeria.
	local supportTopY = gallery.floorY - 1
	local support = createSolid(
		parent,
		"GallerySupport",
		Vector3.new(building.GalleryDepth, supportTopY - bounds.bottomY, innerDepth),
		Vector3.new(gallery.center.X, (supportTopY + bounds.bottomY) / 2, center.Z),
		building.LowerWallColor
	)
	support.CastShadow = false
	createSolid(
		parent,
		"GalleryFloor",
		Vector3.new(building.GalleryDepth, 1, innerDepth),
		Vector3.new(gallery.center.X, gallery.floorY - 0.5, center.Z),
		building.GalleryFloorColor
	)

	local glass = createSolid(
		parent,
		"GalleryGlass",
		Vector3.new(GLASS_THICKNESS, bounds.ceilingY - supportTopY, innerDepth),
		Vector3.new(gallery.innerX + (GLASS_THICKNESS / 2), (bounds.ceilingY + supportTopY) / 2, center.Z),
		GLASS_COLOR
	)
	glass.Material = Enum.Material.Glass
	glass.Transparency = GLASS_TRANSPARENCY
	glass.CastShadow = false
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

	createShell(model, arena, building)
	createFloorDetails(model, arena, building)
	createCeilingLights(model, arena, building)

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
