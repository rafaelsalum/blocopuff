--!strict

-- Arquitetura dos corredores secretos, do lado de fora das paredes norte e
-- sul: um patamar no nível do andar de baixo, uma rampa e um patamar no nível
-- do andar de cima, tudo fechado por parede, teto e cabeceiras. Luz baixa e
-- quente, para o corredor parecer escondido. As entradas (vãos na parede do
-- prédio) e o que as esconde são do BuildingService e do SecretPassageService.
-- Na parede externa, uma Toca Segura em cada patamar: um nicho raso com
-- almofada e uma luz em cima da boca, que o TocaService pinta conforme o
-- estado (livre ou ocupada). Em cada cabeceira, a portinhola do túnel do
-- Barão (tag BaraoDoor; o cliente balança a tampa quando o atributo "Flap"
-- muda), placas de "Território do Barão" e pegadas no chão.
--
-- Espaço local (BuildingLayout.getWallFrame): X ao longo da parede, Y para
-- cima (altura do mundo) e Z para fora do prédio; o interior vai de
-- Z = espessura da parede até espessura + largura do corredor.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)

type BuildingConfig = GameConfig.BuildingConfig
type Corridor = BuildingLayout.Corridor
type Toca = BuildingLayout.Toca

local SHELL = 1
local FLOOR_COLOR = Color3.fromRGB(92, 64, 44)
local WALL_COLOR = Color3.fromRGB(64, 46, 36)
local CEILING_COLOR = Color3.fromRGB(52, 40, 34)
local RUNNER_COLOR = Color3.fromRGB(122, 36, 44)
local LAMP_COLOR = Color3.fromRGB(255, 176, 104)
local CUSHION_COLOR = Color3.fromRGB(46, 128, 72)
local TOCA_LAMP_COLOR = Color3.fromRGB(110, 230, 130)
local DOOR_FRAME_COLOR = Color3.fromRGB(150, 108, 66)
local DOOR_FLAP_COLOR = Color3.fromRGB(122, 84, 52)
local DOOR_HOLE_COLOR = Color3.fromRGB(18, 12, 10)
local SIGN_COLOR = Color3.fromRGB(58, 36, 26)
local SIGN_TEXT_COLOR = Color3.fromRGB(255, 214, 140)
local PAW_COLOR = Color3.fromRGB(62, 42, 30)
local SIGN_ALONG = 35
local PAW_STEPS = 7

local CorridorBuilder = {}

-- Marca da luz de cada Toca (atributo TocaName = nome da Toca).
CorridorBuilder.TocaLampTag = "TocaLamp"
-- Tampa da portinhola do Barão (atributos Corridor e Side = -1 ou 1).
CorridorBuilder.BaraoDoorTag = "BaraoDoor"

local function solid(parent: Instance, name: string, frame: CFrame, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
	return BuildingDecor.createPart(parent, name, size, frame * offset, color, { material = material, collide = true })
end

local function decor(parent: Instance, name: string, frame: CFrame, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	return BuildingDecor.createPart(parent, name, size, frame * offset, color, { material = material, shape = shape })
end

local function addLamp(parent: Instance, frame: CFrame, x: number, y: number, wallZ: number, name: string)
	local plate = decor(parent, `{name}Plate`, frame, Vector3.new(0.8, 1.2, 0.2), CFrame.new(x, y, wallZ - 0.1), Color3.fromRGB(180, 140, 70), Enum.Material.Metal)
	local bulb = decor(parent, `{name}Bulb`, frame, Vector3.new(0.7, 0.7, 0.7), CFrame.new(x, y + 0.4, wallZ - 0.6), LAMP_COLOR, Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = 16
	light.Brightness = 0.55
	light.Shadows = true
	light.Parent = bulb
	plate.CastShadow = false
end

-- Parede externa com os buracos das Tocas: colunas cheias entre os buracos
-- e, em cada buraco, um pedaço abaixo do piso e outro acima da boca.
local function buildOuterWall(parent: Instance, frame: CFrame, tocas: { Toca }, z: number, bottom: number, top: number, halfLength: number)
	local size = BuildingLayout.TocaSize
	local sorted = table.clone(tocas)
	table.sort(sorted, function(a, b)
		return a.along < b.along
	end)
	local function column(fromX: number, toX: number, fromY: number, toY: number)
		if toX - fromX <= 0.01 or toY - fromY <= 0.01 then
			return
		end
		solid(parent, "OuterWall", frame, Vector3.new(toX - fromX, toY - fromY, SHELL), CFrame.new((fromX + toX) / 2, (fromY + toY) / 2, z + (SHELL / 2)), WALL_COLOR, Enum.Material.WoodPlanks)
	end
	local cursor = -(halfLength + SHELL)
	for _, toca in ipairs(sorted) do
		local left = toca.along - (size.X / 2)
		local right = toca.along + (size.X / 2)
		column(cursor, left, bottom, top)
		column(left, right, bottom, toca.floorY)
		column(left, right, toca.floorY + size.Y, top)
		cursor = right
	end
	column(cursor, halfLength + SHELL, bottom, top)
end

local function buildToca(parent: Instance, frame: CFrame, toca: Toca, outerZ: number)
	local size = BuildingLayout.TocaSize
	local x = toca.along
	local y = toca.floorY
	local depth = size.Z
	local zMid = outerZ + (depth / 2)
	local name = `Toca{toca.name}`

	solid(parent, `{name}Floor`, frame, Vector3.new(size.X + (SHELL * 2), SHELL, depth + SHELL), CFrame.new(x, y - (SHELL / 2), outerZ + ((depth + SHELL) / 2)), FLOOR_COLOR, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		solid(parent, `{name}Side`, frame, Vector3.new(SHELL, size.Y, depth), CFrame.new(x + (side * ((size.X + SHELL) / 2)), y + (size.Y / 2), zMid), WALL_COLOR, Enum.Material.WoodPlanks)
	end
	solid(parent, `{name}Back`, frame, Vector3.new(size.X + (SHELL * 2), size.Y + SHELL, SHELL), CFrame.new(x, y + ((size.Y + SHELL) / 2) - (SHELL / 2), outerZ + depth + (SHELL / 2)), WALL_COLOR, Enum.Material.WoodPlanks)
	solid(parent, `{name}Roof`, frame, Vector3.new(size.X + (SHELL * 2), SHELL, depth + SHELL), CFrame.new(x, y + size.Y + (SHELL / 2), outerZ + ((depth + SHELL) / 2)), CEILING_COLOR, Enum.Material.Plaster)

	decor(parent, `{name}Cushion`, frame, Vector3.new(size.X - 0.6, 0.5, depth - 0.6), CFrame.new(x, y + 0.25, zMid + 0.2), CUSHION_COLOR, Enum.Material.Fabric)
	local lamp = decor(parent, `{name}Lamp`, frame, Vector3.new(size.X - 0.4, 0.3, 0.3), CFrame.new(x, y + size.Y - 0.3, outerZ - 0.2), TOCA_LAMP_COLOR, Enum.Material.Neon)
	lamp.CastShadow = false
	lamp:SetAttribute("TocaName", toca.name)
	CollectionService:AddTag(lamp, CorridorBuilder.TocaLampTag)
	local light = Instance.new("PointLight")
	light.Color = TOCA_LAMP_COLOR
	light.Range = 9
	light.Brightness = 0.8
	light.Parent = lamp
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui
end

-- Portinhola na face interna da cabeceira `side` (-1 ou 1), no piso `floorY`.
local function buildBaraoDoor(parent: Instance, frame: CFrame, corridor: Corridor, side: number, halfLength: number, floorY: number, zCenter: number)
	local size = BuildingLayout.BaraoDoorSize
	local width = size.X
	local height = size.Y
	local face = side * halfLength
	local inside = if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right
	decor(parent, "BaraoDoorHole", frame, Vector3.new(0.1, height, width), CFrame.new(face - (side * 0.05), floorY + (height / 2), zCenter), DOOR_HOLE_COLOR, Enum.Material.SmoothPlastic)
	decor(parent, "BaraoDoorTop", frame, Vector3.new(0.3, 0.4, width + 0.8), CFrame.new(face - (side * 0.15), floorY + height + 0.2, zCenter), DOOR_FRAME_COLOR, Enum.Material.Wood)
	for _, edge in ipairs({ -1, 1 }) do
		decor(parent, "BaraoDoorSide", frame, Vector3.new(0.3, height, 0.4), CFrame.new(face - (side * 0.15), floorY + (height / 2), zCenter + (edge * ((width / 2) + 0.2))), DOOR_FRAME_COLOR, Enum.Material.Wood)
	end
	local flap = decor(parent, "BaraoDoorFlap", frame, Vector3.new(0.12, height - 0.15, width - 0.15), CFrame.new(face - (side * 0.3), floorY + ((height - 0.15) / 2) + 0.05, zCenter), DOOR_FLAP_COLOR, Enum.Material.WoodPlanks)
	flap:SetAttribute("Corridor", corridor.name)
	flap:SetAttribute("Side", side)
	CollectionService:AddTag(flap, CorridorBuilder.BaraoDoorTag)
	surfaceText(flap, inside, "🐾", SIGN_TEXT_COLOR)
	local plaque = decor(parent, "BaraoDoorSign", frame, Vector3.new(0.15, 0.9, 4.4), CFrame.new(face - (side * 0.1), floorY + height + 1.1, zCenter), SIGN_COLOR, Enum.Material.Wood)
	surfaceText(plaque, inside, Lang.t("TÚNEL DO BARÃO"), SIGN_TEXT_COLOR)
end

-- Placa na parede externa, de frente para quem entra, e pegadas no piso.
local function buildTerritory(parent: Instance, frame: CFrame, along: number, floorY: number, outerZ: number, zCenter: number)
	local sign = decor(parent, "TerritorySign", frame, Vector3.new(4, 1.2, 0.12), CFrame.new(along, floorY + 5.6, outerZ - 0.06), SIGN_COLOR, Enum.Material.Wood)
	surfaceText(sign, Enum.NormalId.Front, Lang.t("🐾 TERRITÓRIO DO BARÃO"), SIGN_TEXT_COLOR)
	local direction = math.sign(along)
	for index = 1, PAW_STEPS do
		local x = along - (direction * (index - 1) * 1.3)
		local z = zCenter + (if index % 2 == 0 then 0.45 else -0.45)
		local paw = decor(parent, "PawPrint", frame, Vector3.new(0.04, 0.55, 0.55), CFrame.new(x, floorY + 0.02, z) * CFrame.Angles(0, 0, math.rad(90)), PAW_COLOR, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		paw.Transparency = 0.35
	end
end

function CorridorBuilder.build(parent: Instance, corridor: Corridor, building: BuildingConfig): Model
	local model = Instance.new("Model")
	model.Name = `SecretCorridor{corridor.name}`

	local frame = BuildingLayout.getWallFrame(corridor.wallCenter, corridor.along)
	local wall = building.WallThickness
	local width = BuildingLayout.CorridorWidth
	local halfLength = BuildingLayout.CorridorHalfLength
	local rampHalf = BuildingLayout.CorridorRampHalfLength
	local headroom = BuildingLayout.CorridorHeadroom
	local y1 = corridor.lowerY
	local y2 = corridor.upperY
	local zCenter = wall + (width / 2)
	local outerZ = wall + width
	local shellBottom = y1 - SHELL
	local shellTop = y2 + headroom
	local shellHeight = shellTop - shellBottom

	-- Patamar de baixo (entrada do andar 1) e bloco maciço do patamar de cima.
	local landingLength = halfLength - rampHalf
	solid(model, "LowerLanding", frame, Vector3.new(landingLength, SHELL, width), CFrame.new(-(halfLength + rampHalf) / 2, y1 - (SHELL / 2), zCenter), FLOOR_COLOR, Enum.Material.WoodPlanks)
	solid(
		model,
		"UpperLanding",
		frame,
		Vector3.new(landingLength, (y2 - y1) + SHELL, width),
		CFrame.new((halfLength + rampHalf) / 2, (y1 - SHELL + y2) / 2, zCenter),
		FLOOR_COLOR,
		Enum.Material.WoodPlanks
	)

	-- Rampa: a face de cima vai de (-rampHalf, y1) até (rampHalf, y2).
	local rise = y2 - y1
	local run = rampHalf * 2
	local angle = math.atan2(rise, run)
	local rampLength = math.sqrt((run * run) + (rise * rise))
	local normal = Vector3.new(-math.sin(angle), math.cos(angle), 0)
	local rampCenter = Vector3.new(0, (y1 + y2) / 2, zCenter) - (normal * (SHELL / 2))
	solid(model, "Ramp", frame, Vector3.new(rampLength, SHELL, width), CFrame.new(rampCenter) * CFrame.Angles(0, 0, angle), FLOOR_COLOR, Enum.Material.Wood)
	decor(
		model,
		"RampRunner",
		frame,
		Vector3.new(rampLength, 0.06, width - 2.4),
		CFrame.new(Vector3.new(0, (y1 + y2) / 2, zCenter) + (normal * 0.03)) * CFrame.Angles(0, 0, angle),
		RUNNER_COLOR,
		Enum.Material.Fabric
	)

	-- Casca: parede externa, cabeceiras e teto.
	local tocas = BuildingLayout.getTocas(corridor, building)
	buildOuterWall(model, frame, tocas, outerZ, shellBottom, shellTop, halfLength)
	for _, toca in ipairs(tocas) do
		buildToca(model, frame, toca, outerZ)
	end
	for _, side in ipairs({ -1, 1 }) do
		solid(model, "EndWall", frame, Vector3.new(SHELL, shellHeight, width), CFrame.new(side * (halfLength + (SHELL / 2)), shellBottom + (shellHeight / 2), zCenter), WALL_COLOR, Enum.Material.WoodPlanks)
	end
	solid(model, "Ceiling", frame, Vector3.new((halfLength * 2) + (SHELL * 2), SHELL, width + SHELL), CFrame.new(0, shellTop + (SHELL / 2), wall + ((width + SHELL) / 2)), CEILING_COLOR, Enum.Material.Plaster)

	-- Arandelas fracas na parede externa: uma em cada patamar e uma no meio.
	addLamp(model, frame, -(halfLength + rampHalf) / 2, y1 + 7, outerZ, "LowerLamp")
	addLamp(model, frame, 0, ((y1 + y2) / 2) + 7, outerZ, "MiddleLamp")
	addLamp(model, frame, (halfLength + rampHalf) / 2, y2 + 7, outerZ, "UpperLamp")

	-- Portinholas do túnel do Barão e o "território" em cada patamar.
	buildBaraoDoor(model, frame, corridor, -1, halfLength, y1, zCenter)
	buildBaraoDoor(model, frame, corridor, 1, halfLength, y2, zCenter)
	buildTerritory(model, frame, -SIGN_ALONG, y1, outerZ, zCenter)
	buildTerritory(model, frame, SIGN_ALONG, y2, outerZ, zCenter)

	model.Parent = parent
	return model
end

return table.freeze(CorridorBuilder)
