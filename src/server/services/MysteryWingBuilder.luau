--!strict

-- Monta a Ala do Mistério (Fase 5D.3): uma grade de cômodos escuros do
-- Casarão, com portas entre todos os vizinhos, teto, uma luz fraca por
-- cômodo e móveis que viram esconderijo (estantes, armários, mesas, piano,
-- baús). Fica longe do lobby, da Arena e da Torre. Poucas peças, tudo
-- ancorado (celular).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)

export type WingLayout = {
	folder: Folder,
	center: Vector3,
	floorY: number,
	roomCenters: { Vector3 },
	-- Um ponto do chão sorteado dentro de um cômodo sorteado.
	randomPoint: (random: Random) -> Vector3,
}

type Prop = {
	name: string,
	-- Posição em relação ao centro do cômodo (x, z) e tamanho.
	offset: Vector2,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
}

local FOLDER_NAME = "MysteryWing"
local GENERATED_BY = "MysteryWingBuilder"
local WALL_THICKNESS = 1
local FLOOR_THICKNESS = 2
-- Folga das paredes ao sortear um ponto do chão.
local POINT_MARGIN = 5

local COLORS = {
	floor = Color3.fromRGB(86, 62, 48),
	wall = Color3.fromRGB(70, 58, 72),
	roof = Color3.fromRGB(40, 34, 40),
	lamp = Color3.fromRGB(255, 214, 150),
	wood = Color3.fromRGB(110, 74, 46),
	darkWood = Color3.fromRGB(70, 46, 30),
	cloth = Color3.fromRGB(120, 40, 50),
	sheet = Color3.fromRGB(220, 218, 210),
	stone = Color3.fromRGB(110, 108, 104),
}

-- Um tema por cômodo, na ordem da grade (repete se houver mais cômodos).
local THEMES: { { Prop } } = {
	-- Biblioteca: estantes nas paredes e uma mesa de leitura.
	{
		{ name = "Bookshelf", offset = Vector2.new(-15, -8), size = Vector3.new(2, 10, 12), color = COLORS.darkWood, material = Enum.Material.Wood },
		{ name = "Bookshelf", offset = Vector2.new(15, 8), size = Vector3.new(2, 10, 12), color = COLORS.darkWood, material = Enum.Material.Wood },
		{ name = "ReadingTable", offset = Vector2.new(-6, 10), size = Vector3.new(8, 3, 5), color = COLORS.wood, material = Enum.Material.Wood },
	},
	-- Sala de Música: piano e gramofone.
	{
		{ name = "Piano", offset = Vector2.new(-11, -11), size = Vector3.new(9, 5, 5), color = Color3.fromRGB(30, 26, 30), material = Enum.Material.SmoothPlastic },
		{ name = "Gramophone", offset = Vector2.new(12, 12), size = Vector3.new(3, 4, 3), color = COLORS.wood, material = Enum.Material.Wood },
		{ name = "Sofa", offset = Vector2.new(10, -12), size = Vector3.new(8, 3, 3), color = COLORS.cloth, material = Enum.Material.Fabric },
	},
	-- Quarto: cama, armário e baú.
	{
		{ name = "Bed", offset = Vector2.new(-10, 11), size = Vector3.new(7, 3, 10), color = COLORS.cloth, material = Enum.Material.Fabric },
		{ name = "Wardrobe", offset = Vector2.new(14, -12), size = Vector3.new(5, 9, 3), color = COLORS.darkWood, material = Enum.Material.Wood },
		{ name = "Chest", offset = Vector2.new(12, 12), size = Vector3.new(4, 3, 3), color = COLORS.wood, material = Enum.Material.Wood },
	},
	-- Sala de Jantar: mesa comprida.
	{
		{ name = "DiningTable", offset = Vector2.new(-8, 8), size = Vector3.new(14, 3, 5), color = COLORS.wood, material = Enum.Material.Wood },
		{ name = "Cupboard", offset = Vector2.new(15, -10), size = Vector3.new(2, 8, 8), color = COLORS.darkWood, material = Enum.Material.Wood },
	},
	-- Salão com móveis cobertos por lençóis.
	{
		{ name = "CoveredArmchair", offset = Vector2.new(-12, -10), size = Vector3.new(4, 4, 4), color = COLORS.sheet, material = Enum.Material.Fabric },
		{ name = "CoveredArmchair", offset = Vector2.new(12, 10), size = Vector3.new(4, 4, 4), color = COLORS.sheet, material = Enum.Material.Fabric },
		{ name = "CoveredClock", offset = Vector2.new(-14, 12), size = Vector3.new(3, 9, 3), color = COLORS.sheet, material = Enum.Material.Fabric },
	},
	-- Cozinha: fogão de pedra e bancada.
	{
		{ name = "Stove", offset = Vector2.new(-13, -12), size = Vector3.new(6, 5, 4), color = COLORS.stone, material = Enum.Material.Slate },
		{ name = "Counter", offset = Vector2.new(12, 10), size = Vector3.new(10, 4, 3), color = COLORS.wood, material = Enum.Material.Wood },
	},
	-- Sótão: caixas e baús empilhados.
	{
		{ name = "Crates", offset = Vector2.new(-12, 10), size = Vector3.new(6, 6, 6), color = COLORS.wood, material = Enum.Material.WoodPlanks },
		{ name = "Crates", offset = Vector2.new(13, -11), size = Vector3.new(5, 4, 5), color = COLORS.wood, material = Enum.Material.WoodPlanks },
		{ name = "Chest", offset = Vector2.new(-11, -13), size = Vector3.new(4, 3, 3), color = COLORS.darkWood, material = Enum.Material.Wood },
	},
}

local MysteryWingBuilder = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Anchored = true
	newPart.Size = size
	newPart.CFrame = cframe
	newPart.Color = color
	newPart.Material = material
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	newPart.CastShadow = false
	newPart.Parent = parent
	return newPart
end

-- Parede de `length` ao longo de `axis` ("X" ou "Z"), centrada em `middle`,
-- com uma porta no meio quando `door` for true.
local function wall(parent: Instance, middle: Vector3, length: number, axis: string, door: boolean)
	local wing = MysteryModeConfig.Wing
	local height = wing.WallHeight
	local function segment(center: Vector3, segmentLength: number, segmentHeight: number)
		local size = if axis == "X"
			then Vector3.new(segmentLength, segmentHeight, WALL_THICKNESS)
			else Vector3.new(WALL_THICKNESS, segmentHeight, segmentLength)
		part(parent, "Wall", size, CFrame.new(center), COLORS.wall, Enum.Material.Plaster)
	end
	local direction = if axis == "X" then Vector3.xAxis else Vector3.zAxis
	if not door then
		segment(middle + Vector3.new(0, height / 2, 0), length, height)
		return
	end
	local sideLength = (length - wing.DoorWidth) / 2
	local sideOffset = wing.DoorWidth / 2 + sideLength / 2
	segment(middle + direction * sideOffset + Vector3.new(0, height / 2, 0), sideLength, height)
	segment(middle - direction * sideOffset + Vector3.new(0, height / 2, 0), sideLength, height)
	local lintelHeight = height - wing.DoorHeight
	segment(middle + Vector3.new(0, wing.DoorHeight + lintelHeight / 2, 0), wing.DoorWidth, lintelHeight)
end

local function furnish(parent: Instance, roomCenter: Vector3, theme: { Prop })
	for _, prop in ipairs(theme) do
		local position = roomCenter + Vector3.new(prop.offset.X, prop.size.Y / 2, prop.offset.Y)
		part(parent, prop.name, prop.size, CFrame.new(position), prop.color, prop.material)
	end
end

local function lamp(parent: Instance, roomCenter: Vector3)
	local wing = MysteryModeConfig.Wing
	local bulb = part(parent, "Lamp", Vector3.new(1.5, 1.5, 1.5), CFrame.new(roomCenter + Vector3.new(0, wing.WallHeight - 2, 0)), COLORS.lamp, Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Brightness = wing.LightBrightness
	light.Range = wing.LightRange
	light.Color = COLORS.lamp
	light.Shadows = false
	light.Parent = bulb
end

function MysteryWingBuilder.destroy()
	for _, child in ipairs(Workspace:GetDescendants()) do
		if child:IsA("Folder") and child.Name == FOLDER_NAME and child:GetAttribute("GeneratedBy") == GENERATED_BY then
			child:Destroy()
		end
	end
end

function MysteryWingBuilder.build(): WingLayout
	MysteryWingBuilder.destroy()
	local wing = MysteryModeConfig.Wing
	local center = wing.Center
	local size = wing.RoomSize
	local width = wing.Columns * size
	local depth = wing.Rows * size
	local minX = center.X - width / 2
	local minZ = center.Z - depth / 2

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("GeneratedBy", GENERATED_BY)

	part(folder, "Floor", Vector3.new(width, FLOOR_THICKNESS, depth), CFrame.new(center - Vector3.new(0, FLOOR_THICKNESS / 2, 0)), COLORS.floor, Enum.Material.WoodPlanks)
	part(folder, "Roof", Vector3.new(width + 2, 1, depth + 2), CFrame.new(center + Vector3.new(0, wing.WallHeight + 0.5, 0)), COLORS.roof, Enum.Material.Slate)

	-- Paredes de fora, sem porta.
	wall(folder, Vector3.new(center.X, center.Y, minZ), width, "X", false)
	wall(folder, Vector3.new(center.X, center.Y, minZ + depth), width, "X", false)
	wall(folder, Vector3.new(minX, center.Y, center.Z), depth, "Z", false)
	wall(folder, Vector3.new(minX + width, center.Y, center.Z), depth, "Z", false)

	local roomCenters: { Vector3 } = {}
	for column = 1, wing.Columns do
		for row = 1, wing.Rows do
			local roomCenter = Vector3.new(minX + (column - 0.5) * size, center.Y, minZ + (row - 0.5) * size)
			table.insert(roomCenters, roomCenter)
			-- Porta para o vizinho da direita e o de baixo (cada parede uma vez).
			if column < wing.Columns then
				wall(folder, roomCenter + Vector3.new(size / 2, 0, 0), size, "Z", true)
			end
			if row < wing.Rows then
				wall(folder, roomCenter + Vector3.new(0, 0, size / 2), size, "X", true)
			end
			furnish(folder, roomCenter, THEMES[((#roomCenters - 1) % #THEMES) + 1])
			lamp(folder, roomCenter)
		end
	end

	local world = Workspace:FindFirstChild("BlocoPuffWorld")
	folder.Parent = if world ~= nil then world else Workspace

	local half = size / 2 - POINT_MARGIN
	return {
		folder = folder,
		center = center,
		floorY = center.Y,
		roomCenters = roomCenters,
		randomPoint = function(random: Random): Vector3
			local roomCenter = roomCenters[random:NextInteger(1, #roomCenters)]
			return roomCenter + Vector3.new(random:NextNumber(-half, half), 0, random:NextNumber(-half, half))
		end,
	}
end

return table.freeze(MysteryWingBuilder)
