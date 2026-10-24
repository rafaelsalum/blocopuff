--!strict

-- Sala dos Troféus do Vovô Puff (Fase 5C.1, porta de nível): monta, do lado
-- de fora da parede leste da Escadaria, a sala com prateleiras de taças, um
-- Puff dourado no pedestal, o lustre, a porta dupla do vão e as placas dos
-- dois lados. A tranca (nível 10) é do MansionLocks. Chamado pelo
-- MansionWing. Tudo aqui é cenário.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local TrophyRoomLayout = require(ReplicatedStorage.Shared.modules.TrophyRoomLayout)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local BuildingDecor = require(script.Parent.BuildingDecor)
local MansionDoors = require(script.Parent.MansionDoors)
local MansionPlaque = require(script.Parent.MansionPlaque)
local WallBuilder = require(script.Parent.WallBuilder)

type BuildingConfig = GameConfig.BuildingConfig
type Box = TrophyRoomLayout.Box

local MODEL_NAME = "TrophyRoom"
local SLAB = 1
local THICKNESS = GameConfig.Building.WallThickness
local WALL_COLOR = Color3.fromRGB(40, 62, 52)
local FLOOR_COLOR = Color3.fromRGB(110, 30, 36)
local DARK_WOOD = Color3.fromRGB(62, 38, 24)
local GOLD = Color3.fromRGB(255, 196, 60)
local SILVER = Color3.fromRGB(205, 210, 220)
local BRONZE = Color3.fromRGB(196, 120, 64)
local PUFF_COLOR = Color3.fromRGB(255, 205, 80)
local CHANDELIER_DROP = 4
-- Prateleiras: quantas taças por prateleira e as alturas das prateleiras.
local CUPS_PER_SHELF = 4
local SHELF_HEIGHTS = { 3, 6.5, 10 }
local SHELF_LENGTH = 14
local SHELF_DEPTH = 1.6

local TrophyRoomBuilder = {}

local function solid(parent: Instance, name: string, minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number, color: Color3, material: Enum.Material)
	WallBuilder.createBox(parent, name, { min = Vector3.new(minX, minY, minZ), max = Vector3.new(maxX, maxY, maxZ) }, color, material)
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return BuildingDecor.createPart(parent, name, size, cframe, color, { material = material, collide = collide })
end

-- Piso, teto e paredes norte, sul e leste; a oeste fica a parede da ala.
local function shell(parent: Instance, inner: Box)
	local t = THICKNESS
	local x1 = inner.maxX + t
	solid(parent, "TrophyFloor", inner.minX, inner.minY - SLAB, inner.minZ - t, x1, inner.minY, inner.maxZ + t, FLOOR_COLOR, Enum.Material.Fabric)
	solid(parent, "TrophyCeiling", inner.minX, inner.maxY, inner.minZ - t, x1, inner.maxY + SLAB, inner.maxZ + t, WALL_COLOR, Enum.Material.Plaster)
	solid(parent, "TrophyNorth", inner.minX, inner.minY, inner.minZ - t, x1, inner.maxY, inner.minZ, WALL_COLOR, Enum.Material.Plaster)
	solid(parent, "TrophySouth", inner.minX, inner.minY, inner.maxZ, x1, inner.maxY, inner.maxZ + t, WALL_COLOR, Enum.Material.Plaster)
	solid(parent, "TrophyEast", inner.maxX, inner.minY, inner.minZ, x1, inner.maxY, inner.maxZ, WALL_COLOR, Enum.Material.Plaster)
end

-- Taça pequena com base, haste e copa, de pé em `base`.
local function cup(parent: Instance, base: Vector3, color: Color3, scale: number)
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	part(parent, "CupBase", Vector3.new(0.25, 0.8, 0.8) * scale, CFrame.new(base + Vector3.new(0, 0.12, 0) * scale) * upright, color, Enum.Material.Foil)
	part(parent, "CupStem", Vector3.new(0.6, 0.25, 0.25) * scale, CFrame.new(base + Vector3.new(0, 0.55, 0) * scale) * upright, color, Enum.Material.Foil)
	part(parent, "CupBowl", Vector3.new(0.8, 0.85, 0.85) * scale, CFrame.new(base + Vector3.new(0, 1.25, 0) * scale) * upright, color, Enum.Material.Foil)
end

-- Estante encostada na parede (`facing` aponta para o meio da sala).
local function shelf(parent: Instance, name: string, center: Vector3, facing: Vector3)
	local frame = CFrame.lookAt(center, center + facing)
	local along = frame.RightVector
	local colors = { GOLD, SILVER, BRONZE }
	for row, height in ipairs(SHELF_HEIGHTS) do
		part(parent, `{name}Board`, Vector3.new(SHELF_LENGTH, 0.3, SHELF_DEPTH), frame * CFrame.new(0, height, 0), DARK_WOOD, Enum.Material.Wood, true)
		for index = 1, CUPS_PER_SHELF do
			local offset = (index - (CUPS_PER_SHELF + 1) / 2) * (SHELF_LENGTH / CUPS_PER_SHELF)
			cup(parent, center + along * offset + Vector3.new(0, height + 0.15, 0), colors[(row + index) % #colors + 1], 1)
		end
	end
end

-- Puff dourado de pé no pedestal, no fundo da sala, olhando para a porta.
local function statue(parent: Instance, base: Vector3)
	part(parent, "TrophyPedestal", Vector3.new(4, 3, 4), CFrame.new(base + Vector3.new(0, 1.5, 0)), DARK_WOOD, Enum.Material.Marble, true)
	local center = base + Vector3.new(0, 5.4, 0)
	local body = BuildingDecor.createPart(parent, "TrophyPuff", Vector3.new(4.6, 4.6, 4.6), CFrame.new(center), PUFF_COLOR, {
		shape = Enum.PartType.Ball,
		material = Enum.Material.Foil,
	})
	for _, side in ipairs({ -1, 1 }) do
		part(parent, "TrophyPuffEye", Vector3.new(0.2, 0.9, 0.6), CFrame.new(center + Vector3.new(-2.25, 0.5, side * 0.8)), Color3.fromRGB(40, 30, 20), Enum.Material.SmoothPlastic)
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 12
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = body
end

local function plaques(parent: Instance, layout: TrophyRoomLayout.Layout, style: BuildingConfig)
	local doorway = layout.doorway
	local y = layout.floorY + doorway.size.Y + MansionPlaque.Lift
	for _, sideInfo in ipairs({ { 1, doorway.labelPositive }, { -1, doorway.labelNegative } }) do
		local side = sideInfo[1] :: number
		local label = sideInfo[2] :: string?
		if label ~= nil then
			local inward = doorway.normal * side
			local along = inward:Cross(Vector3.yAxis)
			local position = Vector3.new(doorway.center.X, y, doorway.center.Z) + inward * (THICKNESS / 2 + 0.55)
			MansionPlaque.create(parent, `{doorway.name}Plaque`, CFrame.fromMatrix(position, along, Vector3.yAxis), Lang.t(label), style)
		end
	end
end

function TrophyRoomBuilder.build(wingModel: Instance, style: BuildingConfig)
	local layout = TrophyRoomLayout.get()
	local inner = layout.room
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	shell(model, inner)
	local y = layout.floorY
	local centerX = (inner.minX + inner.maxX) / 2
	local centerZ = (inner.minZ + inner.maxZ) / 2
	part(model, "TrophyRug", Vector3.new(inner.maxX - inner.minX - 6, 0.1, 8), CFrame.new(centerX, y + 0.05, centerZ), GOLD, Enum.Material.Fabric)
	shelf(model, "TrophyShelfNorth", Vector3.new(centerX, y, inner.minZ + SHELF_DEPTH / 2), Vector3.zAxis)
	shelf(model, "TrophyShelfSouth", Vector3.new(centerX, y, inner.maxZ - SHELF_DEPTH / 2), -Vector3.zAxis)
	statue(model, Vector3.new(inner.maxX - 4, y, centerZ))
	BuildingDecor.createChandelier(model, "TrophyChandelier", Vector3.new(centerX, layout.ceilingY, centerZ), CHANDELIER_DROP, 2, style, MansionConfig.ChandelierRange, MansionConfig.ChandelierBrightness, false)
	plaques(model, layout, style)
	MansionDoors.build(model, { layout.doorway })
	model.Parent = wingModel
end

return table.freeze(TrophyRoomBuilder)
