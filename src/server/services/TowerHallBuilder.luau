--!strict

-- Saguão da Torre (Fase 5C): monta, do lado de fora da parede norte do
-- Salão da Coleção, a sala que leva à ponte coberta da Torre do Relógio:
-- piso de laje sobre um alicerce de pedra, paredes com papel de parede e
-- lambri, duas janelas para a torre, o relógio grande de parede, bancos,
-- lustre, a placa da largada e as portas duplas (Coleção e ponte) com as
-- placas dos dois lados. O vão na parede do Casarão é do MansionService; a
-- ponte e a ilha, do TowerIsland. Tudo aqui é cenário.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local TowerHallLayout = require(ReplicatedStorage.Shared.modules.TowerHallLayout)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local BuildingDecor = require(script.Parent.BuildingDecor)
local MansionDoors = require(script.Parent.MansionDoors)
local MansionPlaque = require(script.Parent.MansionPlaque)
local WallBuilder = require(script.Parent.WallBuilder)

type BuildingConfig = GameConfig.BuildingConfig
type Box = WallBuilder.Box
type Layout = TowerHallLayout.Layout

local MODEL_NAME = "TowerHall"
local SLAB = 1
local THICKNESS = GameConfig.Building.WallThickness
local FOUNDATION_DEPTH = 10
local SHELL_COLOR = MansionConfig.WallpaperColors.GrandHall
local WALLPAPER_COLOR = Color3.fromRGB(44, 58, 92)
local WAINSCOT_COLOR = Color3.fromRGB(70, 44, 28)
local FLOOR_COLOR = Color3.fromRGB(150, 146, 140)
local STONE_COLOR = Color3.fromRGB(96, 92, 88)
local RUG_COLOR = Color3.fromRGB(46, 70, 120)
local GOLD = Color3.fromRGB(255, 196, 60)
local CLOCK_FACE_COLOR = Color3.fromRGB(246, 236, 210)
local INK = Color3.fromRGB(40, 30, 20)
local GLASS_COLOR = Color3.fromRGB(196, 214, 236)
local WAINSCOT_HEIGHT = 4.5
local WINDOW_SIZE = Vector2.new(6, 9)
local WINDOW_SILL = 4
-- Janelas da parede do fundo, a cada lado da porta da ponte (offset em X).
local WINDOW_OFFSETS = { -11, 11 }
local CLOCK_RADIUS = 5
local CLOCK_HEIGHT = 13
local CHANDELIER_DROP = 5
local BENCH_LENGTH = 8

local TowerHallBuilder = {}

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return { min = Vector3.new(minX, minY, minZ), max = Vector3.new(maxX, maxY, maxZ) }
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return BuildingDecor.createPart(parent, name, size, cframe, color, { material = material, collide = collide })
end

local function solid(parent: Instance, name: string, target: Box, color: Color3, material: Enum.Material)
	WallBuilder.createBox(parent, name, target, color, material)
end

-- Vão de porta ou janela numa parede ao longo de X (`z` na face de dentro).
local function holeAt(x: number, y: number, z: number, size: Vector2, inward: number): Box
	return WallBuilder.hole(Vector3.new(x, y, z), Vector3.new(0, 0, inward), Vector3.xAxis, THICKNESS, size)
end

local function windowHoles(layout: Layout): { Box }
	local holes: { Box } = {}
	for _, offset in ipairs(WINDOW_OFFSETS) do
		table.insert(holes, holeAt(layout.exit.center.X + offset, layout.floorY + WINDOW_SILL, layout.room.minZ, WINDOW_SIZE, 1))
	end
	return holes
end

-- Alicerce, piso, teto, paredes oeste, leste e do fundo (com a porta da
-- ponte e as janelas). Ao sul fica a parede do Casarão.
local function shell(parent: Instance, layout: Layout)
	local room = layout.room
	local t = THICKNESS
	local x0, x1 = room.minX - t, room.maxX + t
	local z0, z1 = room.minZ - t, room.maxZ
	solid(parent, "TowerHallFoundation", box(x0, room.minY - SLAB - FOUNDATION_DEPTH, z0, x1, room.minY - SLAB, z1), STONE_COLOR, Enum.Material.Cobblestone)
	solid(parent, "TowerHallFloor", box(x0, room.minY - SLAB, z0, x1, room.minY, z1), FLOOR_COLOR, Enum.Material.Slate)
	solid(parent, "TowerHallCeiling", box(x0, room.maxY, z0, x1, room.maxY + SLAB, z1), MansionConfig.CeilingColor, Enum.Material.Plaster)
	solid(parent, "TowerHallCornice", box(x0 - 0.5, room.maxY + SLAB, z0 - 0.5, x1 + 0.5, room.maxY + SLAB + 1.2, z1), WAINSCOT_COLOR, Enum.Material.Wood)
	solid(parent, "TowerHallWest", box(x0, room.minY, room.minZ, room.minX, room.maxY, z1), SHELL_COLOR, Enum.Material.Plaster)
	solid(parent, "TowerHallEast", box(room.maxX, room.minY, room.minZ, x1, room.maxY, z1), SHELL_COLOR, Enum.Material.Plaster)
	local holes = windowHoles(layout)
	table.insert(holes, holeAt(layout.exit.center.X, layout.floorY, room.minZ, layout.exit.size, 1))
	WallBuilder.createWallWithHoles(parent, "TowerHallNorth", box(x0, room.minY, z0, x1, room.maxY, room.minZ), holes, SHELL_COLOR, Enum.Material.Plaster)
	for index, hole in ipairs(windowHoles(layout)) do
		local size = hole.max - hole.min
		local center = (hole.min + hole.max) / 2
		part(parent, `TowerHallWindow{index}`, Vector3.new(size.X, size.Y, 0.3), CFrame.new(center.X, center.Y, room.minZ - t / 2), GLASS_COLOR, Enum.Material.Glass, true).Transparency = 0.75
		part(parent, `TowerHallWindowMullion{index}`, Vector3.new(0.4, size.Y, 0.5), CFrame.new(center.X, center.Y, room.minZ - t / 2), WAINSCOT_COLOR, Enum.Material.Wood)
		part(parent, `TowerHallWindowSill{index}`, Vector3.new(size.X + 0.6, 0.4, 1.2), CFrame.new(center.X, hole.min.Y - 0.2, room.minZ + 0.4), WAINSCOT_COLOR, Enum.Material.Wood)
	end
end

-- Papel de parede e lambri de uma face (uma lâmina fina com os mesmos
-- vãos da parede). `face` é a lâmina inteira; `holes`, os vãos nela.
local function cover(parent: Instance, name: string, face: Box, holes: { Box })
	WallBuilder.createWallWithHoles(parent, `{name}Wallpaper`, face, holes, WALLPAPER_COLOR, Enum.Material.Fabric)
	local low = { min = face.min, max = Vector3.new(face.max.X, face.min.Y + WAINSCOT_HEIGHT, face.max.Z) }
	local lowHoles: { Box } = {}
	for _, hole in ipairs(holes) do
		if hole.min.Y < low.max.Y then
			table.insert(lowHoles, { min = hole.min, max = Vector3.new(hole.max.X, math.min(hole.max.Y, low.max.Y), hole.max.Z) })
		end
	end
	local runsAlongX = (face.max.X - face.min.X) > (face.max.Z - face.min.Z)
	local grow = if runsAlongX then Vector3.new(0, 0, 0.2) else Vector3.new(0.2, 0, 0)
	WallBuilder.createWallWithHoles(parent, `{name}Wainscot`, { min = low.min - grow, max = low.max + grow }, lowHoles, WAINSCOT_COLOR, Enum.Material.Wood)
end

local function decorateWalls(parent: Instance, layout: Layout)
	local room = layout.room
	local y0, y1 = room.minY, room.maxY
	local skin = 0.1
	-- Os vãos da lâmina: os da parede, esticados para atravessar a lâmina.
	local wallHoles = windowHoles(layout)
	table.insert(wallHoles, holeAt(layout.exit.center.X, layout.floorY, room.minZ, layout.exit.size, 1))
	local northHoles: { Box } = {}
	for _, hole in ipairs(wallHoles) do
		table.insert(northHoles, box(hole.min.X, hole.min.Y, room.minZ - 1, hole.max.X, hole.max.Y, room.minZ + 1))
	end
	cover(parent, "TowerHallNorth", box(room.minX, y0, room.minZ, room.maxX, y1, room.minZ + skin), northHoles)
	local doorHole = layout.hole
	cover(parent, "TowerHallSouth", box(room.minX, y0, room.maxZ - skin, room.maxX, y1, room.maxZ), {
		box(doorHole.minX, doorHole.minY, room.maxZ - 1, doorHole.maxX, doorHole.maxY, room.maxZ + 1),
	})
	cover(parent, "TowerHallWest", box(room.minX, y0, room.minZ, room.minX + skin, y1, room.maxZ), {})
	cover(parent, "TowerHallEast", box(room.maxX - skin, y0, room.minZ, room.maxX, y1, room.maxZ), {})
end

-- Relógio grande na parede oeste, com marcas das horas e os ponteiros.
local function clock(parent: Instance, center: Vector3)
	-- O eixo do cilindro (X) aponta para dentro da sala.
	local facing = CFrame.new(center)
	part(parent, "TowerHallClockRim", Vector3.new(0.4, CLOCK_RADIUS * 2 + 1, CLOCK_RADIUS * 2 + 1), facing, GOLD, Enum.Material.Foil).Shape = Enum.PartType.Cylinder
	part(parent, "TowerHallClockFace", Vector3.new(0.5, CLOCK_RADIUS * 2, CLOCK_RADIUS * 2), facing * CFrame.new(0.1, 0, 0), CLOCK_FACE_COLOR, Enum.Material.SmoothPlastic).Shape = Enum.PartType.Cylinder
	for hour = 0, 11 do
		local angle = hour * math.pi / 6
		local spot = center + Vector3.new(0.4, math.cos(angle), math.sin(angle)) * Vector3.new(1, CLOCK_RADIUS - 0.8, CLOCK_RADIUS - 0.8)
		local long = hour % 3 == 0
		part(parent, "TowerHallClockMark", Vector3.new(0.2, if long then 1 else 0.5, 0.3), CFrame.new(spot) * CFrame.Angles(angle, 0, 0), INK, Enum.Material.SmoothPlastic)
	end
	-- Dez para as duas. Visto de dentro da sala, o horário anda para -Z.
	for _, hand in ipairs({ { length = 2.6, angle = math.rad(-60) }, { length = 4, angle = math.rad(60) } }) do
		local direction = Vector3.new(0, math.cos(hand.angle), math.sin(hand.angle))
		local middle = center + Vector3.new(0.5, 0, 0) + direction * (hand.length / 2)
		part(parent, "TowerHallClockHand", Vector3.new(0.15, hand.length, 0.35), CFrame.new(middle) * CFrame.Angles(hand.angle, 0, 0), INK, Enum.Material.Metal)
	end
	part(parent, "TowerHallClockPin", Vector3.new(0.3, 0.7, 0.7), CFrame.new(center + Vector3.new(0.6, 0, 0)), GOLD, Enum.Material.Foil).Shape = Enum.PartType.Cylinder
end

-- Banco de madeira encostado na parede (`facing` aponta para o meio).
local function bench(parent: Instance, base: Vector3, facing: Vector3)
	local frame = CFrame.lookAt(base, base + facing)
	part(parent, "TowerHallBenchSeat", Vector3.new(BENCH_LENGTH, 0.5, 2), frame * CFrame.new(0, 1.8, 0), WAINSCOT_COLOR, Enum.Material.Wood, true)
	part(parent, "TowerHallBenchBack", Vector3.new(BENCH_LENGTH, 2.4, 0.4), frame * CFrame.new(0, 3.2, 0.9), WAINSCOT_COLOR, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		part(parent, "TowerHallBenchLeg", Vector3.new(0.4, 1.6, 1.6), frame * CFrame.new(side * (BENCH_LENGTH / 2 - 0.6), 0.8, 0), WAINSCOT_COLOR, Enum.Material.Wood)
	end
end

local function plaques(parent: Instance, layout: Layout, style: BuildingConfig)
	for _, door in ipairs({ layout.doorway, layout.exit }) do
		local y = layout.floorY + door.size.Y + MansionPlaque.Lift
		for _, sideInfo in ipairs({ { 1, door.labelPositive }, { -1, door.labelNegative } }) do
			local side = sideInfo[1] :: number
			local label = sideInfo[2] :: string?
			if label ~= nil then
				local inward = door.normal * side
				local along = inward:Cross(Vector3.yAxis)
				local position = Vector3.new(door.center.X, y, door.center.Z) + inward * (THICKNESS / 2 + 0.55)
				MansionPlaque.create(parent, `{door.name}Plaque`, CFrame.fromMatrix(position, along, Vector3.yAxis), Lang.t(label), style)
			end
		end
	end
end

function TowerHallBuilder.build(mansionModel: Instance, style: BuildingConfig)
	local layout = TowerHallLayout.get()
	local room = layout.room
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	shell(model, layout)
	decorateWalls(model, layout)
	local y = layout.floorY
	local centerX = (room.minX + room.maxX) / 2
	local centerZ = (room.minZ + room.maxZ) / 2
	-- Passadeira da porta da Coleção até a porta da ponte.
	local rugX = (layout.doorway.center.X + layout.exit.center.X) / 2
	part(model, "TowerHallRug", Vector3.new(6, 0.1, room.maxZ - room.minZ - 2), CFrame.new(rugX, y + 0.05, centerZ), RUG_COLOR, Enum.Material.Fabric)
	part(model, "TowerHallRugBorder", Vector3.new(7, 0.08, room.maxZ - room.minZ - 1), CFrame.new(rugX, y + 0.04, centerZ), GOLD, Enum.Material.Fabric)
	clock(model, Vector3.new(room.minX + 0.3, y + CLOCK_HEIGHT, centerZ))
	bench(model, Vector3.new(room.minX + 1.2, y, centerZ + 7), Vector3.xAxis)
	bench(model, Vector3.new(room.maxX - 1.2, y, centerZ + 7), -Vector3.xAxis)
	bench(model, Vector3.new(room.maxX - 1.2, y, centerZ - 5), -Vector3.xAxis)
	-- Aviso na parede leste: a rampa só abre para quem está correndo.
	local signPosition = Vector3.new(room.maxX - 0.25, y + 9, centerZ)
	MansionPlaque.create(model, "TowerHallRaceSign", CFrame.fromMatrix(signPosition, -Vector3.zAxis, Vector3.yAxis), Lang.t("🏁 A RAMPA SÓ ABRE NA CORRIDA"), style)
	BuildingDecor.createChandelier(model, "TowerHallChandelier", Vector3.new(centerX, layout.ceilingY, centerZ), CHANDELIER_DROP, 2, style, MansionConfig.ChandelierRange, MansionConfig.ChandelierBrightness, false)
	plaques(model, layout, style)
	MansionDoors.build(model, { layout.doorway, layout.exit })
	model.Parent = mansionModel
end

return table.freeze(TowerHallBuilder)
