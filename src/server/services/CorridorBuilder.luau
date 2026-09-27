--!strict

-- Arquitetura dos corredores secretos, do lado de fora das paredes norte e
-- sul: um patamar no nível do andar de baixo, uma rampa e um patamar no nível
-- do andar de cima, tudo fechado por parede, teto e cabeceiras. Luz baixa e
-- quente, para o corredor parecer escondido. As entradas (vãos na parede do
-- prédio) e o que as esconde são do BuildingService e do SecretPassageService.
--
-- Espaço local (BuildingLayout.getWallFrame): X ao longo da parede, Y para
-- cima (altura do mundo) e Z para fora do prédio; o interior vai de
-- Z = espessura da parede até espessura + largura do corredor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)

type BuildingConfig = GameConfig.BuildingConfig
type Corridor = BuildingLayout.Corridor

local SHELL = 1
local FLOOR_COLOR = Color3.fromRGB(92, 64, 44)
local WALL_COLOR = Color3.fromRGB(64, 46, 36)
local CEILING_COLOR = Color3.fromRGB(52, 40, 34)
local RUNNER_COLOR = Color3.fromRGB(122, 36, 44)
local LAMP_COLOR = Color3.fromRGB(255, 176, 104)

local CorridorBuilder = {}

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
	solid(model, "OuterWall", frame, Vector3.new((halfLength * 2) + (SHELL * 2), shellHeight, SHELL), CFrame.new(0, shellBottom + (shellHeight / 2), outerZ + (SHELL / 2)), WALL_COLOR, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		solid(model, "EndWall", frame, Vector3.new(SHELL, shellHeight, width), CFrame.new(side * (halfLength + (SHELL / 2)), shellBottom + (shellHeight / 2), zCenter), WALL_COLOR, Enum.Material.WoodPlanks)
	end
	solid(model, "Ceiling", frame, Vector3.new((halfLength * 2) + (SHELL * 2), SHELL, width + SHELL), CFrame.new(0, shellTop + (SHELL / 2), wall + ((width + SHELL) / 2)), CEILING_COLOR, Enum.Material.Plaster)

	-- Arandelas fracas na parede externa: uma em cada patamar e uma no meio.
	addLamp(model, frame, -(halfLength + rampHalf) / 2, y1 + 7, outerZ, "LowerLamp")
	addLamp(model, frame, 0, ((y1 + y2) / 2) + 7, outerZ, "MiddleLamp")
	addLamp(model, frame, (halfLength + rampHalf) / 2, y2 + 7, outerZ, "UpperLamp")

	model.Parent = parent
	return model
end

return table.freeze(CorridorBuilder)
