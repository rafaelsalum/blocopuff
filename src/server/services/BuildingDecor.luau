--!strict

-- Construtores de decoração de interior no estilo mansão (lambri, papel de
-- parede, molduras, arandelas, quadros, janelas, portas, lustres e móveis).
-- Tudo usa materiais nativos do Roblox, sem assets externos. As peças
-- decorativas não colidem nem participam de raycasts, para não interferir
-- na mira nem na física da partida.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

type BuildingConfig = GameConfig.BuildingConfig

-- Trecho plano de parede visto de dentro da sala. origin fica no centro do
-- trecho, sobre a face interna e na altura zero.
export type WallSegment = {
	name: string,
	origin: Vector3,
	inward: Vector3,
	length: number,
	bottomY: number,
	topY: number,
}

export type StoryOptions = {
	wallpaperColor: Color3,
	lamps: boolean,
	art: boolean,
	windows: boolean,
	door: boolean,
	lampRange: number,
	lampBrightness: number,
}

local WAINSCOT_HEIGHT = 4.5
local FEATURE_SPACING = 12
local FEATURE_MARGIN = 6
local SCONCE_HEIGHT = 8
local ART_HEIGHT = 8.5
local MIN_HEIGHT_FOR_SCONCE = 11
local MIN_HEIGHT_FOR_ART = 12
local DOOR_SIZE = Vector2.new(5, 8.8)

local BuildingDecor = {}

export type PartOptions = {
	material: Enum.Material?,
	collide: boolean?,
	shape: Enum.PartType?,
	transparency: number?,
}

function BuildingDecor.createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: PartOptions?
): Part
	local collide = options ~= nil and options.collide == true
	local part = Instance.new("Part")
	part.Name = name
	if options ~= nil and options.shape ~= nil then
		part.Shape = options.shape
	end
	part.Anchored = true
	part.CanCollide = collide
	part.CanTouch = false
	part.CanQuery = collide
	part.CastShadow = collide
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = if options ~= nil and options.material ~= nil then options.material else Enum.Material.SmoothPlastic
	part.Transparency = if options ~= nil and options.transparency ~= nil then options.transparency else 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addPointLight(part: BasePart, color: Color3, range: number, brightness: number, shadows: boolean)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows
	light.Parent = part
end

local function getAlong(segment: WallSegment): Vector3
	return segment.inward:Cross(Vector3.yAxis)
end

-- CFrame de uma peça encostada na parede: X ao longo do trecho, Y para
-- cima e Z na espessura, com a face frontal voltada para dentro da sala.
function BuildingDecor.wallCFrame(segment: WallSegment, offset: number, y: number, depth: number): CFrame
	local along = getAlong(segment)
	local position = segment.origin + (along * offset) + (segment.inward * depth) + Vector3.new(0, y, 0)
	return CFrame.fromMatrix(position, along, Vector3.yAxis)
end

local function panel(
	parent: Instance,
	segment: WallSegment,
	name: string,
	offset: number,
	width: number,
	y0: number,
	height: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
): Part
	return BuildingDecor.createPart(
		parent,
		`{segment.name}{name}`,
		Vector3.new(width, height, thickness),
		BuildingDecor.wallCFrame(segment, offset, y0 + (height / 2), thickness / 2),
		color,
		{ material = material }
	)
end

local function createSconce(parent: Instance, segment: WallSegment, offset: number, y: number, style: BuildingConfig, options: StoryOptions)
	BuildingDecor.createPart(
		parent,
		`{segment.name}SconcePlate`,
		Vector3.new(0.8, 1.4, 0.25),
		BuildingDecor.wallCFrame(segment, offset, y, 0.35),
		style.BrassColor,
		{ material = Enum.Material.Metal }
	)
	BuildingDecor.createPart(
		parent,
		`{segment.name}SconceArm`,
		Vector3.new(0.2, 0.2, 0.7),
		BuildingDecor.wallCFrame(segment, offset, y, 0.75),
		style.BrassColor,
		{ material = Enum.Material.Metal }
	)
	local bulb = BuildingDecor.createPart(
		parent,
		`{segment.name}SconceBulb`,
		Vector3.new(0.8, 0.8, 0.8),
		BuildingDecor.wallCFrame(segment, offset, y + 0.5, 1.1),
		style.LampColor,
		{ material = Enum.Material.Neon, shape = Enum.PartType.Ball }
	)
	addPointLight(bulb, style.LampColor, options.lampRange, options.lampBrightness, false)
end

local function createPainting(parent: Instance, segment: WallSegment, offset: number, y: number, style: BuildingConfig, rng: Random)
	local art = style.ArtColors
	local sky = art[rng:NextInteger(1, #art)]
	local ground = art[rng:NextInteger(1, #art)]
	local width = rng:NextNumber(4.5, 6.5)
	local height = rng:NextNumber(3.5, 4.5)
	BuildingDecor.createPart(
		parent,
		`{segment.name}PaintingFrame`,
		Vector3.new(width, height, 0.3),
		BuildingDecor.wallCFrame(segment, offset, y, 0.25),
		style.FrameColor,
		{ material = Enum.Material.Wood }
	)
	local canvasWidth = width - 0.8
	local canvasHeight = height - 0.8
	BuildingDecor.createPart(
		parent,
		`{segment.name}PaintingSky`,
		Vector3.new(canvasWidth, canvasHeight * 0.55, 0.1),
		BuildingDecor.wallCFrame(segment, offset, y + (canvasHeight * 0.225), 0.45),
		sky
	)
	BuildingDecor.createPart(
		parent,
		`{segment.name}PaintingGround`,
		Vector3.new(canvasWidth, canvasHeight * 0.45, 0.1),
		BuildingDecor.wallCFrame(segment, offset, y - (canvasHeight * 0.275), 0.45),
		ground:Lerp(Color3.new(0, 0, 0), 0.25)
	)
end

local function createWindow(parent: Instance, segment: WallSegment, offset: number, y: number, style: BuildingConfig)
	BuildingDecor.createPart(
		parent,
		`{segment.name}WindowFrame`,
		Vector3.new(5, 7, 0.3),
		BuildingDecor.wallCFrame(segment, offset, y, 0.25),
		style.TrimColor,
		{ material = Enum.Material.Wood }
	)
	BuildingDecor.createPart(
		parent,
		`{segment.name}WindowGlass`,
		Vector3.new(4.2, 6.2, 0.1),
		BuildingDecor.wallCFrame(segment, offset, y, 0.45),
		style.WindowColor,
		{ material = Enum.Material.Glass }
	)
	BuildingDecor.createPart(
		parent,
		`{segment.name}WindowMullionV`,
		Vector3.new(0.25, 6.2, 0.2),
		BuildingDecor.wallCFrame(segment, offset, y, 0.55),
		style.TrimColor,
		{ material = Enum.Material.Wood }
	)
	BuildingDecor.createPart(
		parent,
		`{segment.name}WindowMullionH`,
		Vector3.new(4.2, 0.25, 0.2),
		BuildingDecor.wallCFrame(segment, offset, y + 0.6, 0.55),
		style.TrimColor,
		{ material = Enum.Material.Wood }
	)
	BuildingDecor.createPart(
		parent,
		`{segment.name}WindowSill`,
		Vector3.new(5.6, 0.3, 0.8),
		BuildingDecor.wallCFrame(segment, offset, y - 3.6, 0.4),
		style.TrimColor,
		{ material = Enum.Material.Wood }
	)
end

local function createDoor(parent: Instance, segment: WallSegment, offset: number, floorY: number, style: BuildingConfig)
	BuildingDecor.createPart(
		parent,
		`{segment.name}DoorFrame`,
		Vector3.new(DOOR_SIZE.X + 1, DOOR_SIZE.Y + 0.6, 0.35),
		BuildingDecor.wallCFrame(segment, offset, floorY + ((DOOR_SIZE.Y + 0.6) / 2), 0.3),
		style.TrimColor,
		{ material = Enum.Material.Wood }
	)
	BuildingDecor.createPart(
		parent,
		`{segment.name}Door`,
		Vector3.new(DOOR_SIZE.X, DOOR_SIZE.Y, 0.3),
		BuildingDecor.wallCFrame(segment, offset, floorY + (DOOR_SIZE.Y / 2), 0.45),
		style.WainscotColor,
		{ material = Enum.Material.WoodPlanks }
	)
	BuildingDecor.createPart(
		parent,
		`{segment.name}DoorKnob`,
		Vector3.new(0.4, 0.4, 0.4),
		BuildingDecor.wallCFrame(segment, offset + (DOOR_SIZE.X / 2) - 0.7, floorY + 4, 0.75),
		style.BrassColor,
		{ material = Enum.Material.Metal, shape = Enum.PartType.Ball }
	)
end

local function getFeatureOffsets(length: number): { number }
	local count = math.floor((length - (FEATURE_MARGIN * 2)) / FEATURE_SPACING) + 1
	local offsets: { number } = {}
	if count < 1 then
		return offsets
	end
	for index = 1, count do
		table.insert(offsets, (index - ((count + 1) / 2)) * FEATURE_SPACING)
	end
	return offsets
end

-- Um "andar" de parede: papel de parede, lambri, rodapé, guarda-cadeira,
-- sanca e, conforme a altura disponível, arandelas, quadros, janelas e porta.
function BuildingDecor.decorateStory(
	parent: Instance,
	segment: WallSegment,
	y0: number,
	y1: number,
	style: BuildingConfig,
	options: StoryOptions,
	rng: Random
)
	local bottom = math.max(y0, segment.bottomY)
	local top = math.min(y1, segment.topY)
	local height = top - bottom
	if height <= 0.5 then
		return
	end
	local length = segment.length

	panel(parent, segment, "Wallpaper", 0, length, bottom, height, 0.1, options.wallpaperColor, Enum.Material.Plaster)
	panel(parent, segment, "Wainscot", 0, length, bottom, math.min(WAINSCOT_HEIGHT, height), 0.3, style.WainscotColor, Enum.Material.WoodPlanks)
	panel(parent, segment, "Baseboard", 0, length, bottom, math.min(0.8, height), 0.45, style.BaseboardColor, Enum.Material.Wood)
	if height > WAINSCOT_HEIGHT + 0.5 then
		panel(parent, segment, "ChairRail", 0, length, bottom + WAINSCOT_HEIGHT - 0.2, 0.4, 0.5, style.TrimColor, Enum.Material.Wood)
	end
	if height > MIN_HEIGHT_FOR_ART then
		panel(parent, segment, "Crown", 0, length, top - 0.7, 0.7, 0.6, style.TrimColor, Enum.Material.Wood)
	end

	local offsets = getFeatureOffsets(length)
	if options.door and #offsets < 3 then
		-- Trecho curto: a porta ocupa o centro e dispensa os demais detalhes.
		createDoor(parent, segment, 0, bottom, style)
		return
	end

	local doorIndex = if options.door then math.ceil(#offsets / 2) else -1
	for index, offset in ipairs(offsets) do
		if index == doorIndex then
			createDoor(parent, segment, offset, bottom, style)
		elseif index % 2 == 1 then
			if options.lamps and height > MIN_HEIGHT_FOR_SCONCE then
				createSconce(parent, segment, offset, bottom + SCONCE_HEIGHT, style, options)
			end
		elseif options.art and height > MIN_HEIGHT_FOR_ART then
			if options.windows and index % 4 == 2 then
				createWindow(parent, segment, offset, bottom + ART_HEIGHT, style)
			else
				createPainting(parent, segment, offset, bottom + ART_HEIGHT, style, rng)
			end
		end
	end
end

function BuildingDecor.createChandelier(parent: Instance, name: string, anchor: Vector3, drop: number, radius: number, style: BuildingConfig, range: number, brightness: number)
	local center = anchor - Vector3.new(0, drop, 0)
	BuildingDecor.createPart(
		parent,
		`{name}Chain`,
		Vector3.new(0.2, drop, 0.2),
		CFrame.new(anchor - Vector3.new(0, drop / 2, 0)),
		style.BrassColor,
		{ material = Enum.Material.Metal }
	)
	local body = BuildingDecor.createPart(
		parent,
		`{name}Body`,
		Vector3.new(0.5, radius * 2, radius * 2),
		CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		style.BrassColor,
		{ material = Enum.Material.Metal, shape = Enum.PartType.Cylinder }
	)
	addPointLight(body, style.LampColor, range, brightness, true)

	local bulbCount = 6
	for index = 1, bulbCount do
		local angle = (index / bulbCount) * math.pi * 2
		local position = center + Vector3.new(math.cos(angle) * radius, 0.6, math.sin(angle) * radius)
		BuildingDecor.createPart(
			parent,
			string.format("%sBulb%02d", name, index),
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(position),
			style.LampColor,
			{ material = Enum.Material.Neon, shape = Enum.PartType.Ball }
		)
	end
end

-- Sofá encostado na parede; `facing` aponta para onde o assento está virado.
function BuildingDecor.createSofa(parent: Instance, name: string, base: Vector3, facing: Vector3, width: number, style: BuildingConfig)
	local frame = CFrame.lookAt(base, base + facing)
	local solid = { material = Enum.Material.Fabric, collide = true }
	BuildingDecor.createPart(parent, `{name}Seat`, Vector3.new(width, 1.4, 3), frame * CFrame.new(0, 0.7, 0), style.UpholsteryColor, solid)
	BuildingDecor.createPart(parent, `{name}Back`, Vector3.new(width, 2.8, 0.9), frame * CFrame.new(0, 1.4, 1.5), style.UpholsteryColor, solid)
	for _, side in ipairs({ -1, 1 }) do
		BuildingDecor.createPart(
			parent,
			`{name}Arm`,
			Vector3.new(0.8, 2, 3),
			frame * CFrame.new(side * ((width / 2) - 0.4), 1, 0.2),
			style.UpholsteryColor:Lerp(Color3.new(0, 0, 0), 0.2),
			solid
		)
	end
end

function BuildingDecor.createSideTable(parent: Instance, name: string, base: Vector3, style: BuildingConfig)
	BuildingDecor.createPart(parent, `{name}Table`, Vector3.new(2, 2.4, 2), CFrame.new(base + Vector3.new(0, 1.2, 0)), style.WainscotColor, {
		material = Enum.Material.Wood,
		collide = true,
	})
	BuildingDecor.createPart(parent, `{name}LampBase`, Vector3.new(0.4, 1.2, 0.4), CFrame.new(base + Vector3.new(0, 3, 0)), style.BrassColor, {
		material = Enum.Material.Metal,
	})
	local shade = BuildingDecor.createPart(parent, `{name}LampShade`, Vector3.new(1.4, 1.2, 1.4), CFrame.new(base + Vector3.new(0, 4.1, 0)), style.LampColor, {
		material = Enum.Material.Fabric,
		transparency = 0.1,
	})
	addPointLight(shade, style.LampColor, 10, 0.35, false)
end

function BuildingDecor.createPlant(parent: Instance, name: string, base: Vector3, style: BuildingConfig)
	BuildingDecor.createPart(parent, `{name}Pot`, Vector3.new(1.6, 1.8, 1.6), CFrame.new(base + Vector3.new(0, 0.9, 0)), style.BasementBrickColor, {
		material = Enum.Material.Slate,
		collide = true,
	})
	BuildingDecor.createPart(parent, `{name}Leaves`, Vector3.new(3, 3, 3), CFrame.new(base + Vector3.new(0, 3.2, 0)), Color3.fromRGB(58, 92, 56), {
		material = Enum.Material.LeafyGrass,
		shape = Enum.PartType.Ball,
	})
end

return table.freeze(BuildingDecor)
