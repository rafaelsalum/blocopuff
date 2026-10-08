--!strict

-- Salas Secretas do Barão (Fase 5C.3, parte 3): monta, do lado de fora da
-- parede leste da ala, o Gabinete do Vovô Puff (andar principal) e o túnel
-- com a Sala do Tesouro (Porão), com os prêmios (troféu e baú). Os vãos na
-- parede ficam fechados por um lacre para todo mundo; o cliente de quem tem
-- acesso (BaronRoomsController) some com o lacre e as tábuas do túnel e
-- gira a estante. Chamado pelo MansionWing, depois da decoração.
-- Tudo aqui é cenário: quem confere o prêmio é o BaronRoomsService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaronRoomsConfig = require(ReplicatedStorage.Shared.config.BaronRoomsConfig)
local BaronRoomsLayout = require(ReplicatedStorage.Shared.modules.BaronRoomsLayout)
local BaronRoomsRules = require(ReplicatedStorage.Shared.modules.BaronRoomsRules)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionWingConfig = require(ReplicatedStorage.Shared.config.MansionWingConfig)
local BuildingDecor = require(script.Parent.BuildingDecor)
local WallBuilder = require(script.Parent.WallBuilder)

type BuildingConfig = GameConfig.BuildingConfig
type Box = BaronRoomsRules.Box
type Room = BaronRoomsLayout.Room

local MODEL_NAME = "BaronRooms"
local SLAB = 1
local THICKNESS = GameConfig.Building.WallThickness

local STUDY_WALL = Color3.fromRGB(92, 58, 38)
local STUDY_FLOOR = Color3.fromRGB(120, 32, 40)
local DARK_WOOD = Color3.fromRGB(62, 38, 24)
local GOLD = Color3.fromRGB(255, 196, 60)
local LAMP_COLOR = Color3.fromRGB(255, 205, 140)
local TORCH_COLOR = Color3.fromRGB(255, 150, 60)
local CHEST_WOOD = Color3.fromRGB(110, 66, 34)
local COIN_COLOR = Color3.fromRGB(245, 195, 60)

local BaronRoomsBuilder = {}

local function wallBox(b: Box): WallBuilder.Box
	return { min = Vector3.new(b.minX, b.minY, b.minZ), max = Vector3.new(b.maxX, b.maxY, b.maxZ) }
end

local function solid(parent: Instance, name: string, minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number, color: Color3, material: Enum.Material)
	WallBuilder.createBox(parent, name, { min = Vector3.new(minX, minY, minZ), max = Vector3.new(maxX, maxY, maxZ) }, color, material)
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return BuildingDecor.createPart(parent, name, size, cframe, color, { material = material, collide = collide })
end

local function light(target: BasePart, color: Color3, range: number, brightness: number)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = range
	point.Brightness = brightness
	point.Shadows = false
	point.Parent = target
end

-- Piso, teto e paredes norte/sul (e leste, se `closeEast`) em volta do
-- interior `inner`. A oeste fica a parede da ala.
local function shell(parent: Instance, name: string, inner: Box, closeEast: boolean, wall: Color3, wallMaterial: Enum.Material, floor: Color3, floorMaterial: Enum.Material)
	local t = THICKNESS
	local x1 = if closeEast then inner.maxX + t else inner.maxX
	solid(parent, `{name}Floor`, inner.minX, inner.minY - SLAB, inner.minZ - t, x1, inner.minY, inner.maxZ + t, floor, floorMaterial)
	solid(parent, `{name}Ceiling`, inner.minX, inner.maxY, inner.minZ - t, x1, inner.maxY + SLAB, inner.maxZ + t, wall, wallMaterial)
	solid(parent, `{name}North`, inner.minX, inner.minY, inner.minZ - t, x1, inner.maxY, inner.minZ, wall, wallMaterial)
	solid(parent, `{name}South`, inner.minX, inner.minY, inner.maxZ, x1, inner.maxY, inner.maxZ + t, wall, wallMaterial)
	if closeEast then
		solid(parent, `{name}East`, inner.maxX, inner.minY, inner.minZ, inner.maxX + t, inner.maxY, inner.maxZ, wall, wallMaterial)
	end
end

-- Lacre do vão: mesma parede, mas o cliente de quem tem acesso some com ele.
local function seal(parent: Instance, room: Room, color: Color3, material: Enum.Material)
	local model = Instance.new("Model")
	model.Name = `BaronSeal{room.id}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hole = room.passage.hole
	local sealPart = WallBuilder.createBox(model, "BaronSealPart", wallBox(hole), color, material)
	if sealPart ~= nil then
		sealPart:SetAttribute(BaronRoomsConfig.PassageAttribute, room.id)
	end
	model.Parent = parent
end

-- Prompt do prêmio: desligado no servidor; o cliente liga para quem tem
-- acesso e ainda não pegou.
local function prompt(target: BasePart, id: string)
	local info = BaronRoomsConfig.Info[id :: any]
	local proximity = Instance.new("ProximityPrompt")
	proximity.Name = "BaronRoomPrompt"
	proximity.ActionText = info.action
	proximity.ObjectText = info.object
	proximity.HoldDuration = 0.5
	proximity.MaxActivationDistance = BaronRoomsConfig.PromptDistance
	proximity.RequiresLineOfSight = false
	proximity.Enabled = false
	proximity:SetAttribute(BaronRoomsConfig.PromptAttribute, id)
	proximity.Parent = target
end

local function trophy(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "BaronTrophy"
	local pedestal = part(model, "BaronPedestal", Vector3.new(3, 3.5, 3), CFrame.new(base + Vector3.new(0, 1.75, 0)), DARK_WOOD, Enum.Material.Wood, true)
	local top = base + Vector3.new(0, 3.5, 0)
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	part(model, "TrophyBase", Vector3.new(0.5, 1.8, 1.8), CFrame.new(top + Vector3.new(0, 0.25, 0)) * upright, GOLD, Enum.Material.Foil)
	part(model, "TrophyStem", Vector3.new(1.2, 0.5, 0.5), CFrame.new(top + Vector3.new(0, 1.1, 0)) * upright, GOLD, Enum.Material.Foil)
	local cup = part(model, "TrophyCup", Vector3.new(1.6, 1.7, 1.7), CFrame.new(top + Vector3.new(0, 2.5, 0)) * upright, GOLD, Enum.Material.Foil)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "TrophyHandle", Vector3.new(0.3, 0.8, 0.3), CFrame.new(top + Vector3.new(0, 2.6, side * 1.05)) * CFrame.Angles(side * -0.5, 0, 0), GOLD, Enum.Material.Foil)
	end
	-- Pata do Barão gravada na frente (virada para oeste, de onde se chega).
	part(model, "TrophyPaw", Vector3.new(0.1, 0.6, 0.6), CFrame.new(top + Vector3.new(-0.86, 2.5, 0)), Color3.fromRGB(140, 90, 30), Enum.Material.SmoothPlastic)
	light(cup, GOLD, 10, 1.4)
	prompt(pedestal, "Study")
	model.Parent = parent
end

local function chest(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "BaronChest"
	-- Frente virada para oeste (de onde se chega).
	local frame = CFrame.lookAt(base, base - Vector3.xAxis)
	local body = part(model, "ChestBody", Vector3.new(4, 2.4, 2.6), frame * CFrame.new(0, 1.2, 0), CHEST_WOOD, Enum.Material.WoodPlanks, true)
	local lid = part(model, "ChestLid", Vector3.new(4, 0.8, 2.6), frame * CFrame.new(0, 2.8, 0), CHEST_WOOD, Enum.Material.WoodPlanks, true)
	for _, dx in ipairs({ -1.5, 1.5 }) do
		part(model, "ChestBand", Vector3.new(0.3, 3.3, 2.7), frame * CFrame.new(dx, 1.65, 0), GOLD, Enum.Material.Foil)
	end
	part(model, "ChestLock", Vector3.new(0.6, 0.7, 0.2), frame * CFrame.new(0, 2.2, -1.35), GOLD, Enum.Material.Foil)
	local glow = part(model, "ChestGold", Vector3.new(3.4, 0.4, 2), frame * CFrame.new(0, 2.25, 0), GOLD, Enum.Material.Neon)
	light(glow, GOLD, 10, 0.9)
	lid:SetAttribute("ChestLid", true)
	prompt(body, "Treasure")
	model.Parent = parent
end

local function bookcase(parent: Instance, name: string, center: Vector3, facing: Vector3, width: number, height: number)
	local frame = CFrame.lookAt(center, center + facing)
	part(parent, name, Vector3.new(width, height, 1.6), frame * CFrame.new(0, height / 2, 0), DARK_WOOD, Enum.Material.Wood, true)
	local colors = { Color3.fromRGB(150, 40, 40), Color3.fromRGB(40, 80, 130), Color3.fromRGB(50, 110, 60), Color3.fromRGB(170, 130, 50) }
	for row = 0, 3 do
		part(parent, `{name}Books`, Vector3.new(width - 0.6, 1.6, 0.3), frame * CFrame.new(0, 1.4 + row * 2.4, -0.82), colors[row + 1], Enum.Material.Fabric)
	end
end

local function buildStudy(parent: Instance, room: Room)
	local inner = room.room
	shell(parent, "Study", inner, true, STUDY_WALL, Enum.Material.WoodPlanks, STUDY_FLOOR, Enum.Material.Fabric)
	local y = room.floorY
	local centerZ = (inner.minZ + inner.maxZ) / 2
	-- Tapete, escrivaninha com o globo, poltrona e estantes nas laterais.
	part(parent, "StudyRug", Vector3.new(10, 0.1, 8), CFrame.new((inner.minX + inner.maxX) / 2, y + 0.05, centerZ), Color3.fromRGB(180, 140, 60), Enum.Material.Fabric)
	local desk = Vector3.new(inner.minX + 8, y, inner.minZ + 4)
	part(parent, "StudyDesk", Vector3.new(6, 3, 3), CFrame.new(desk + Vector3.new(0, 1.5, 0)), DARK_WOOD, Enum.Material.Wood, true)
	part(parent, "StudyGlobe", Vector3.new(1.4, 1.4, 1.4), CFrame.new(desk + Vector3.new(-1.8, 3.7, 0)), Color3.fromRGB(70, 130, 170), Enum.Material.SmoothPlastic)
	local lamp = part(parent, "StudyLamp", Vector3.new(0.8, 1.2, 0.8), CFrame.new(desk + Vector3.new(2, 3.6, 0)), LAMP_COLOR, Enum.Material.Neon)
	light(lamp, LAMP_COLOR, 22, 1.2)
	part(parent, "StudyArmchair", Vector3.new(3, 3, 3), CFrame.new(inner.minX + 8, y + 1.5, inner.maxZ - 4), Color3.fromRGB(130, 40, 50), Enum.Material.Fabric, true)
	bookcase(parent, "StudyShelfNorth", Vector3.new(inner.maxX - 6, y, inner.minZ + 0.8), Vector3.zAxis, 6, 10)
	bookcase(parent, "StudyShelfSouth", Vector3.new(inner.maxX - 6, y, inner.maxZ - 0.8), -Vector3.zAxis, 6, 10)
	-- Retrato do Vovô Puff (moldura dourada) acima do troféu.
	local portrait = Vector3.new(inner.maxX - 0.15, y + 9, centerZ)
	part(parent, "StudyPortraitFrame", Vector3.new(0.3, 5, 4.2), CFrame.new(portrait), GOLD, Enum.Material.Foil)
	part(parent, "StudyPortrait", Vector3.new(0.35, 4.2, 3.4), CFrame.new(portrait - Vector3.new(0.05, 0, 0)), Color3.fromRGB(235, 220, 200), Enum.Material.SmoothPlastic)
	BuildingDecor.createPart(parent, "StudyPortraitPuff", Vector3.new(0.4, 2.2, 2.2), CFrame.new(portrait - Vector3.new(0.1, 0.2, 0)), Color3.fromRGB(240, 170, 190), {
		shape = Enum.PartType.Cylinder,
	})
	trophy(parent, room.prize)
end

local function buildTreasure(parent: Instance, room: Room)
	local tunnel = room.tunnel
	assert(tunnel ~= nil, "Treasure room needs a tunnel")
	local wall = MansionWingConfig.CellarColor
	local floor = MansionWingConfig.CellarFloorColor
	shell(parent, "Tunnel", tunnel, false, wall, Enum.Material.Brick, floor, Enum.Material.Cobblestone)
	local inner = room.room
	shell(parent, "Treasure", inner, true, wall, Enum.Material.Brick, floor, Enum.Material.Cobblestone)
	-- Parede oeste da sala, com a boca do túnel.
	WallBuilder.createWallWithHoles(
		parent,
		"TreasureWest",
		{ min = Vector3.new(inner.minX - THICKNESS, inner.minY, inner.minZ), max = Vector3.new(inner.minX, inner.maxY, inner.maxZ) },
		{ { min = Vector3.new(inner.minX - THICKNESS - 0.5, tunnel.minY, tunnel.minZ), max = Vector3.new(inner.minX + 0.5, tunnel.maxY, tunnel.maxZ) } },
		wall,
		Enum.Material.Brick
	)
	-- Tochas ao longo do túnel e na sala.
	local tunnelZ = (tunnel.minZ + tunnel.maxZ) / 2
	for index, x in ipairs({ tunnel.minX + 6, tunnel.minX + 16 }) do
		local torch = part(parent, `TunnelTorch{index}`, Vector3.new(0.4, 1, 0.4), CFrame.new(x, tunnel.minY + 5.5, tunnel.minZ + 0.4), TORCH_COLOR, Enum.Material.Neon)
		light(torch, TORCH_COLOR, 16, 0.9)
	end
	for index, z in ipairs({ inner.minZ + 0.4, inner.maxZ - 0.4 }) do
		local torch = part(parent, `TreasureTorch{index}`, Vector3.new(0.4, 1, 0.4), CFrame.new((inner.minX + inner.maxX) / 2, inner.minY + 6, z), TORCH_COLOR, Enum.Material.Neon)
		light(torch, TORCH_COLOR, 18, 0.9)
	end
	-- Montes de moedas em volta do baú.
	local rng = Random.new(5033)
	for index = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(3.5, 6.5)
		local size = rng:NextNumber(0.8, 1.8)
		local at = room.prize + Vector3.new(math.cos(angle) * distance - 2, size * 0.3, math.sin(angle) * distance)
		BuildingDecor.createPart(parent, `TreasureCoins{index}`, Vector3.new(size * 0.6, size * 2, size * 2), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), COIN_COLOR, {
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
	end
	part(parent, "TreasureRug", Vector3.new(8, 0.1, 8), CFrame.new(room.prize.X - 2, inner.minY + 0.05, tunnelZ), Color3.fromRGB(120, 30, 40), Enum.Material.Fabric)
	chest(parent, room.prize)
end

-- Marca as peças que já existem (da decoração) como parte das passagens.
local function markPassages(wingModel: Instance)
	local shelf = wingModel:FindFirstChild("EastShelf2", true)
	if shelf ~= nil and shelf:IsA("Model") then
		shelf.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		shelf:SetAttribute(BaronRoomsConfig.ShelfAttribute, "Study")
	else
		warn("[BlocoPuff] Baron rooms: EastShelf2 not found")
	end
	local tunnel = wingModel:FindFirstChild("CellarTunnel", true)
	if tunnel ~= nil and tunnel:IsA("Model") then
		tunnel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		for _, child in ipairs(tunnel:GetChildren()) do
			if child:IsA("BasePart") and (child.Name == "TunnelPlank" or child.Name == "TunnelDark") then
				child:SetAttribute(BaronRoomsConfig.PassageAttribute, "Treasure")
			end
		end
	else
		warn("[BlocoPuff] Baron rooms: CellarTunnel not found")
	end
end

function BaronRoomsBuilder.build(wingModel: Instance, _style: BuildingConfig)
	local layout = BaronRoomsLayout.get()
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	seal(model, layout.Study, MansionWingConfig.WallpaperColors.StairHall :: Color3, Enum.Material.Plaster)
	seal(model, layout.Treasure, MansionWingConfig.CellarColor, Enum.Material.Brick)
	buildStudy(model, layout.Study)
	buildTreasure(model, layout.Treasure)
	markPassages(wingModel)
	model.Parent = wingModel
end

return table.freeze(BaronRoomsBuilder)
