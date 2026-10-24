--!strict

-- Cenário fantástico da Torre do Relógio Encantada (Fase 5F.2): gárgulas na
-- mureta do terraço e no portão da ilha, tochas acesas na mureta da rampa,
-- árvores secas e retorcidas na beira da ilha, chafariz no gramado, velas
-- flutuantes ao longo da subida, morcegos em volta do campanário e névoa
-- fria embaixo da ilha. Velas e morcegos ficam parados no servidor; quem os
-- anima é o cliente (TowerAmbienceController), pelas tags abaixo.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local TowerHallLayout = require(ReplicatedStorage.Shared.modules.TowerHallLayout)
local TowerAmbienceNames = require(ReplicatedStorage.Shared.modules.TowerAmbienceNames)
local RaceRules = require(script.Parent.Parent.data.RaceRules)
local TowerAssets = require(script.Parent.TowerAssets)
local TowerKit = require(script.Parent.TowerKit)

local GARGOYLE_HEIGHT = 4.5
local GARGOYLE_ANGLES = { math.rad(60), math.rad(120), math.rad(180), math.rad(240), math.rad(300) }
local GATE_GARGOYLE_HEIGHT = 5
local GATE_PILLAR = Vector3.new(4, 8, 4)
-- Tochas na mureta, entre os checkpoints (frações de volta).
local TORCH_OFFSETS = { 0.125, 0.375, 0.625, 0.875 }
local TORCH_HEIGHT = 4.5
local TORCH_LIGHT_EVERY = 2
-- Árvores no gramado, longe do portão, das torrinhas e do chafariz.
local TREES = {
	{ angle = math.rad(0), name = "BareTree", height = 26 },
	{ angle = math.rad(62), name = "TwistedTree", height = 17 },
	{ angle = math.rad(112), name = "BareTree", height = 22 },
	{ angle = math.rad(188), name = "TwistedTree", height = 19 },
	{ angle = math.rad(250), name = "BareTree", height = 24 },
	{ angle = math.rad(345), name = "TwistedTree", height = 16 },
}
local TREE_RING = 71
local FOUNTAIN_ANGLE = math.rad(285)
local FOUNTAIN_RING = 70
local CANDLES_PER_TURN = 6
local CANDLE_HEIGHT = 3
local CANDLE_LIFT = 10
local CANDLE_INSET = 6
-- Sem vela perto dos arcos dos checkpoints (fração de volta).
local CANDLE_ARCH_GAP = 0.08
local BAT_COUNT = 6
local BAT_SIZE = 3.5
local BELFRY_ORBIT_HEIGHT = 36
local MIST_DEPTH = 18

local COLORS = TowerKit.COLORS
local part = TowerKit.part

local TowerDecor = {}

local function ring(center: Vector3, angle: number, radius: number, y: number): Vector3
	return Vector3.new(center.X + math.cos(angle) * radius, y, center.Z + math.sin(angle) * radius)
end

local function outwardOf(angle: number): Vector3
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local function buildGargoyles(model: Instance, center: Vector3, topY: number)
	local tower = RaceConfig.Tower
	local radius = tower.Radius - tower.RampWidth / 2 - tower.ParapetThickness / 2
	for _, angle in ipairs(GARGOYLE_ANGLES) do
		TowerAssets.place(model, "Gargoyle", GARGOYLE_HEIGHT, ring(center, angle, radius, topY + tower.ParapetHeight), outwardOf(angle))
	end
	-- Portão da ilha (lado do Casarão): dois pilares com gárgula em cima.
	local gateAngle = TowerHallLayout.get().gateAngle
	local gateRadius = tower.IslandRadius - 2
	for _, side in ipairs({ -1, 1 }) do
		local angle = gateAngle + side * math.rad(8)
		local foot = ring(center, angle, gateRadius, center.Y)
		part(model, "GatePillar", GATE_PILLAR, CFrame.new(foot + Vector3.new(0, GATE_PILLAR.Y / 2, 0)), COLORS.stoneDark, Enum.Material.Cobblestone)
		TowerAssets.place(model, "Gargoyle", GATE_GARGOYLE_HEIGHT, foot + Vector3.new(0, GATE_PILLAR.Y, 0), outwardOf(gateAngle))
	end
end

local function buildTorches(model: Instance, center: Vector3, pointAt: (number) -> Vector3)
	local tower = RaceConfig.Tower
	local radius = RaceRules.parapetRadius(tower.Radius, tower.RampWidth, tower.ParapetThickness)
	local count = 0
	for turn = 0, tower.Turns - 1 do
		for _, offset in ipairs(TORCH_OFFSETS) do
			local t = turn + offset
			local angle = t * 2 * math.pi
			local base = ring(center, angle, radius, pointAt(t).Y + tower.ParapetHeight)
			local torch = TowerAssets.place(model, "Torch", TORCH_HEIGHT, base, -outwardOf(angle))
			if torch ~= nil then
				count += 1
				local fire = Instance.new("Fire")
				fire.Size = 2
				fire.Heat = 4
				fire.Color = Color3.fromRGB(255, 150, 60)
				fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
				fire.Parent = torch
				if count % TORCH_LIGHT_EVERY == 0 then
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 170, 90)
					light.Range = 16
					light.Brightness = 1.4
					light.Parent = torch
				end
			end
		end
	end
end

local function buildTrees(model: Instance, center: Vector3)
	for index, tree in ipairs(TREES) do
		local base = ring(center, tree.angle, TREE_RING, center.Y - 0.5)
		TowerAssets.place(model, tree.name, tree.height, base, outwardOf(tree.angle + index))
	end
end

local function buildFountain(model: Instance, center: Vector3)
	local base = ring(center, FOUNTAIN_ANGLE, FOUNTAIN_RING, center.Y)
	TowerKit.cylinder(model, "FountainBasin", 6, 2.5, base + Vector3.new(0, 1.25, 0), COLORS.stoneLight, Enum.Material.Cobblestone)
	local water = TowerKit.cylinder(model, "FountainWater", 5.3, 0.3, base + Vector3.new(0, 2.4, 0), Color3.fromRGB(90, 150, 210), Enum.Material.Glass)
	water.Transparency = 0.25
	TowerKit.decor(water)
	TowerKit.decor(TowerKit.cylinder(model, "FountainColumn", 1, 5, base + Vector3.new(0, 4.5, 0), COLORS.stoneLight, Enum.Material.Cobblestone))
	local bowl = TowerKit.cylinder(model, "FountainBowl", 2.6, 0.8, base + Vector3.new(0, 7.2, 0), COLORS.stoneLight, Enum.Material.Cobblestone)
	TowerKit.decor(bowl)
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Color = ColorSequence.new(Color3.fromRGB(170, 210, 255))
	spray.LightEmission = 0.3
	spray.Size = NumberSequence.new(0.35, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Lifetime = NumberRange.new(0.9, 1.2)
	spray.Rate = 30
	spray.Speed = NumberRange.new(7, 9)
	spray.SpreadAngle = Vector2.new(20, 20)
	spray.Acceleration = Vector3.new(0, -20, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = bowl
end

local function candleSlots(): { number }
	local tower = RaceConfig.Tower
	local slots: { number } = {}
	for index = 1, tower.Turns * CANDLES_PER_TURN - 1 do
		local t = index / CANDLES_PER_TURN
		local fromArch = math.abs(t - math.floor(t + 0.5))
		if fromArch > CANDLE_ARCH_GAP then
			table.insert(slots, t)
		end
	end
	return slots
end

local function buildCandles(model: Instance, center: Vector3, pointAt: (number) -> Vector3)
	local tower = RaceConfig.Tower
	local radius = tower.Radius - tower.RampWidth / 2 + CANDLE_INSET
	for _, t in ipairs(candleSlots()) do
		local angle = t * 2 * math.pi
		local base = ring(center, angle, radius, pointAt(t).Y + CANDLE_LIFT)
		local candle = TowerAssets.place(model, "Candle", CANDLE_HEIGHT, base)
		if candle ~= nil then
			local flame = part(candle, "Flame", Vector3.new(0.35, 0.6, 0.35), CFrame.new(base + Vector3.new(0, candle.Size.Y + 0.3, 0)), Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
			flame.Shape = Enum.PartType.Ball
			TowerKit.decor(flame)
			CollectionService:AddTag(candle, TowerAmbienceNames.CandleTag)
		end
	end
end

local function buildBats(model: Instance, center: Vector3, topY: number)
	local orbitCenter = Vector3.new(center.X, topY + BELFRY_ORBIT_HEIGHT, center.Z)
	local random = Random.new(5)
	for index = 1, BAT_COUNT do
		local radius = random:NextNumber(20, 34)
		local phase = (index - 1) / BAT_COUNT * 2 * math.pi
		local bat = TowerAssets.place(model, "Bat", BAT_SIZE * 0.75, orbitCenter + Vector3.new(math.cos(phase) * radius, 0, math.sin(phase) * radius))
		if bat ~= nil then
			bat:SetAttribute(TowerAmbienceNames.OrbitCenter, orbitCenter + Vector3.new(0, random:NextNumber(-6, 6), 0))
			bat:SetAttribute(TowerAmbienceNames.OrbitRadius, radius)
			bat:SetAttribute(TowerAmbienceNames.OrbitSpeed, random:NextNumber(0.35, 0.6) * (if index % 2 == 0 then -1 else 1))
			bat:SetAttribute(TowerAmbienceNames.Phase, phase)
			CollectionService:AddTag(bat, TowerAmbienceNames.BatTag)
		end
	end
end

local function buildMist(model: Instance, center: Vector3)
	local radius = RaceConfig.Tower.IslandRadius
	local holder = part(model, "Mist", Vector3.new(radius * 2.2, 1, radius * 2.2), CFrame.new(center - Vector3.new(0, MIST_DEPTH, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	TowerKit.decor(holder)
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "ColdMist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(205, 218, 236))
	mist.LightEmission = 0.15
	mist.Size = NumberSequence.new(28, 46)
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Lifetime = NumberRange.new(10, 14)
	mist.Rate = 8
	mist.Speed = NumberRange.new(1, 3)
	mist.SpreadAngle = Vector2.new(180, 180)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-6, 6)
	mist.Parent = holder
end

-- Monta os enfeites da torre já construída (`pointAt` = meio da rampa na
-- volta `t`).
function TowerDecor.build(parent: Instance, center: Vector3, topY: number, pointAt: (number) -> Vector3)
	local model = Instance.new("Model")
	model.Name = "TowerDecor"
	buildGargoyles(model, center, topY)
	buildTorches(model, center, pointAt)
	buildTrees(model, center)
	buildFountain(model, center)
	buildCandles(model, center, pointAt)
	buildBats(model, center, topY)
	buildMist(model, center)
	model.Parent = parent
end

return table.freeze(TowerDecor)
