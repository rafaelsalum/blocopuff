--!strict

-- Entrada principal do castelo (Fase 5H.2), por fora da porta da parede sul
-- do Ponto de Encontro: patamar no nível do piso, escadaria de pedra até o
-- chão com balaustradas, portal com arco pontudo, placa, estandartes e um
-- lampião de cada lado do pé da escada. A porta (vão e folhas) é do
-- MansionService; os degraus vêm do FrontStairs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local FrontStairs = require(ReplicatedStorage.Shared.modules.FrontStairs)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local MansionPlaque = require(script.Parent.MansionPlaque)
local OutdoorLamps = require(script.Parent.OutdoorLamps)
local TowerKit = require(script.Parent.TowerKit)

local COLORS = TowerKit.COLORS
local STEP_COLOR = Color3.fromRGB(150, 146, 138)
local TREAD_COLOR = Color3.fromRGB(176, 172, 162)
local BASE_SINK = 4
local RAIL_WIDTH = 1.6
local RAIL_HEIGHT = 3
local PILLAR = 2.4
local PORTAL_OUT = 1.6
local BANNER_SIZE = Vector2.new(3.2, 10)
local LAMP_SIDE = 3.5

export type Entrance = {
	plan: FrontStairs.Plan,
	-- Face de fora da parede sul, no Z.
	wallZ: number,
	door: { center: Vector3, size: Vector2 },
}

local CastleEntrance = {}

local function block(parent: Instance, name: string, minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number, color: Color3, material: Enum.Material): Part
	local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	local piece = TowerKit.part(parent, name, size, CFrame.new(center), color, material)
	piece.CanQuery = false
	piece.CanTouch = false
	return piece
end

-- Patamar, degraus e balaustradas (sólidos: é por onde se anda).
local function stairs(parent: Instance, plan: FrontStairs.Plan, wallZ: number, floorY: number, groundY: number)
	local bottom = groundY - BASE_SINK
	block(parent, "EntranceLanding", plan.minX, plan.maxX, bottom, floorY - 0.4, wallZ, plan.landingEnd, STEP_COLOR, Enum.Material.Cobblestone)
	block(parent, "EntranceLandingTop", plan.minX, plan.maxX, floorY - 0.4, floorY, wallZ, plan.landingEnd, TREAD_COLOR, Enum.Material.Limestone)
	for index, step in ipairs(plan.steps) do
		block(parent, `EntranceStep{index}`, plan.minX, plan.maxX, bottom, step.top - 0.3, step.minZ, step.maxZ, STEP_COLOR, Enum.Material.Cobblestone)
		block(parent, `EntranceTread{index}`, plan.minX, plan.maxX, step.top - 0.3, step.top, step.minZ, step.maxZ, TREAD_COLOR, Enum.Material.Limestone)
	end
	-- Balaustradas: mureta dos dois lados, acompanhando os degraus.
	for _, x in ipairs({ plan.minX - RAIL_WIDTH / 2, plan.maxX + RAIL_WIDTH / 2 }) do
		block(parent, "EntranceRail", x - RAIL_WIDTH / 2, x + RAIL_WIDTH / 2, bottom, floorY + RAIL_HEIGHT, wallZ, plan.landingEnd, STEP_COLOR, Enum.Material.Cobblestone)
		for _, step in ipairs(plan.steps) do
			block(parent, "EntranceRail", x - RAIL_WIDTH / 2, x + RAIL_WIDTH / 2, bottom, step.top + RAIL_HEIGHT, step.minZ, step.maxZ, STEP_COLOR, Enum.Material.Cobblestone)
		end
		-- Pilares: no alto (junto ao patamar) e no pé, com uma bola de pedra.
		for _, spot in ipairs({ { z = plan.landingEnd, top = floorY + RAIL_HEIGHT + 1.5 }, { z = plan.foot.z - 1, top = groundY + RAIL_HEIGHT + 2 } }) do
			block(parent, "EntranceNewel", x - PILLAR / 2, x + PILLAR / 2, bottom, spot.top, spot.z - PILLAR / 2, spot.z + PILLAR / 2, COLORS.stoneLight, Enum.Material.Limestone)
			local ball = TowerKit.part(parent, "EntranceNewelBall", Vector3.one * 1.8, CFrame.new(x, spot.top + 0.8, spot.z), COLORS.stoneLight, Enum.Material.Limestone)
			ball.Shape = Enum.PartType.Ball
			TowerKit.decor(ball)
		end
	end
end

-- Portal por fora da porta: pilastras, arco pontudo, placa e estandartes.
local function portal(parent: Instance, door: { center: Vector3, size: Vector2 }, wallZ: number, floorY: number)
	local width, height = door.size.X, door.size.Y
	local x = door.center.X
	local frontZ = wallZ + PORTAL_OUT / 2
	for _, sign in ipairs({ -1, 1 }) do
		local px = x + sign * (width / 2 + PILLAR / 2)
		TowerKit.decor(TowerKit.part(parent, "PortalPillar", Vector3.new(PILLAR, height + 1, PORTAL_OUT), CFrame.new(px, floorY + (height + 1) / 2, frontZ), COLORS.stoneLight, Enum.Material.Limestone))
		-- Arco pontudo: duas pedras inclinadas do alto das pilastras até a ponta.
		local half = width / 2 + PILLAR / 2
		local length = half * math.sqrt(2) + PILLAR
		local mid = Vector3.new(x + sign * half / 2, floorY + height + 1 + half / 2, frontZ)
		TowerKit.decor(TowerKit.part(parent, "PortalArch", Vector3.new(PILLAR, length, PORTAL_OUT), CFrame.new(mid) * CFrame.Angles(0, 0, sign * math.rad(45)), COLORS.stoneLight, Enum.Material.Limestone))
		-- Estandarte vermelho com barra dourada, ao lado do portal.
		local bx = x + sign * (width / 2 + PILLAR + 3)
		local bannerTop = floorY + height + 2
		TowerKit.decor(TowerKit.part(parent, "PortalBannerRod", Vector3.new(BANNER_SIZE.X + 0.8, 0.3, 0.3), CFrame.new(bx, bannerTop, wallZ + 0.85), COLORS.gold, Enum.Material.Metal))
		TowerKit.decor(TowerKit.part(parent, "PortalBanner", Vector3.new(BANNER_SIZE.X, BANNER_SIZE.Y, 0.15), CFrame.new(bx, bannerTop - BANNER_SIZE.Y / 2, wallZ + 0.75), COLORS.banner, Enum.Material.Fabric))
		TowerKit.decor(TowerKit.part(parent, "PortalBannerStripe", Vector3.new(BANNER_SIZE.X, 0.5, 0.17), CFrame.new(bx, bannerTop - BANNER_SIZE.Y + 1, wallZ + 0.85), COLORS.gold, Enum.Material.Fabric))
	end
	-- Verga por cima da porta e a placa do castelo acima do arco.
	TowerKit.decor(TowerKit.part(parent, "PortalLintel", Vector3.new(width + PILLAR * 2, 1, PORTAL_OUT), CFrame.new(x, floorY + height + 0.5, frontZ), COLORS.stoneLight, Enum.Material.Limestone))
	local plaqueAt = Vector3.new(x, floorY + height + 3.2, wallZ + PORTAL_OUT + 0.1)
	MansionPlaque.create(parent, "PortalPlaque", CFrame.fromMatrix(plaqueAt, Vector3.new(-1, 0, 0), Vector3.yAxis), Lang.t("🏰 CASARÃO DO BARÃO"), GameConfig.Building)
end

-- Monta a entrada; devolve a planta (para as fachadas e o caminho lá fora).
function CastleEntrance.build(parent: Instance, groundY: number): Entrance
	local mansion = MansionLayout.get()
	local door = mansion.frontDoor
	local wallZ = door.center.Z + GameConfig.Building.WallThickness
	local plan = FrontStairs.plan(door.center.X, mansion.floorY, wallZ, groundY, MansionConfig.FrontStairs)
	local model = Instance.new("Model")
	model.Name = "CastleEntrance"
	stairs(model, plan, wallZ, mansion.floorY, groundY)
	portal(model, door, wallZ, mansion.floorY)
	model.Parent = parent
	OutdoorLamps.place(model, {
		Vector3.new(plan.minX - LAMP_SIDE, groundY, plan.foot.z + 2),
		Vector3.new(plan.maxX + LAMP_SIDE, groundY, plan.foot.z + 2),
	})
	return { plan = plan, wallZ = wallZ, door = door }
end

-- A planta da entrada sem construir nada (para o OutdoorService).
function CastleEntrance.plan(groundY: number): FrontStairs.Plan
	local mansion = MansionLayout.get()
	local door = mansion.frontDoor
	return FrontStairs.plan(door.center.X, mansion.floorY, door.center.Z + GameConfig.Building.WallThickness, groundY, MansionConfig.FrontStairs)
end

return table.freeze(CastleEntrance)
