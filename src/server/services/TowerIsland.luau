--!strict

-- Ilha de pedra flutuante da Torre do Relógio Encantada (Fase 5F): gramado
-- com pátio de laje em volta da torre, penhasco pendurado embaixo (cones de
-- rocha virados), muralha baixa com ameias, torrinhas de telhado pontudo
-- azul e a ponte coberta de enfeite até a parede norte do Casarão.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local TowerKit = require(script.Parent.TowerKit)

local GROUND_THICKNESS = 4
local COURTYARD_FRACTION = 0.76
local CLIFF_HEIGHT = 110
local HANGING_ROCKS = 3
local HANGING_ROCK_RADIUS = 24
local HANGING_ROCK_HEIGHT = 55
local RIM_SEGMENTS = 32
local RIM_HEIGHT = 4
local RIM_THICKNESS = 2
-- A muralha abre na direção do Casarão (+Z), onde chega a ponte.
local GATE_ANGLE = math.pi / 2
local GATE_HALF_WIDTH = math.rad(7)
local TURRET_ANGLES = { math.rad(30), math.rad(150), math.rad(225), math.rad(315) }
local TURRET_RADIUS = 6
local TURRET_HEIGHT = 36
local TURRET_ROOF_HEIGHT = 20
local TURRET_INSET = 9
-- Ponte coberta: da muralha até a parede norte do Casarão, chegando por
-- baixo do janelão do Salão da Coleção (o telhado não tapa a vista).
local BRIDGE_END_Z = -67
local BRIDGE_END_Y = 122
local BRIDGE_WIDTH = 12
local BRIDGE_PILLAR_SPACING = 13
local BRIDGE_ROOF_HEIGHT = 11

local COLORS = TowerKit.COLORS
local part = TowerKit.part
local cylinder = TowerKit.cylinder

local TowerIsland = {}

local function buildGround(model: Instance, center: Vector3, radius: number)
	cylinder(model, "IslandGround", radius, GROUND_THICKNESS, center - Vector3.new(0, GROUND_THICKNESS / 2, 0), COLORS.grass, Enum.Material.Grass)
	-- Pátio de laje um pouco acima do gramado (sem degrau sensível).
	cylinder(model, "Courtyard", radius * COURTYARD_FRACTION, GROUND_THICKNESS, center - Vector3.new(0, GROUND_THICKNESS / 2 - 0.1, 0), COLORS.stoneLight, Enum.Material.Slate)
	local underside = center - Vector3.new(0, GROUND_THICKNESS, 0)
	TowerKit.decor(TowerKit.cone(model, "Cliff", radius - 2, CLIFF_HEIGHT, underside, COLORS.rock, Enum.Material.Rock, true))
	for index = 1, HANGING_ROCKS do
		local angle = (index - 0.5) * 2 * math.pi / HANGING_ROCKS + 0.4
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius * 0.55)
		TowerKit.decor(TowerKit.cone(model, "HangingRock", HANGING_ROCK_RADIUS, HANGING_ROCK_HEIGHT, underside + offset, COLORS.rock, Enum.Material.Rock, true))
	end
end

local function buildRim(model: Instance, center: Vector3, radius: number)
	local wallRadius = radius - RIM_THICKNESS
	local step = 2 * math.pi / RIM_SEGMENTS
	for index = 1, RIM_SEGMENTS do
		local fromAngle = (index - 1) * step
		local toAngle = index * step
		local middle = (fromAngle + toAngle) / 2
		local nearGate = math.abs(math.atan2(math.sin(middle - GATE_ANGLE), math.cos(middle - GATE_ANGLE))) < GATE_HALF_WIDTH
		if not nearGate then
			local from = center + Vector3.new(math.cos(fromAngle), 0, math.sin(fromAngle)) * wallRadius
			local to = center + Vector3.new(math.cos(toAngle), 0, math.sin(toAngle)) * wallRadius
			TowerKit.wall(model, from, to, RIM_HEIGHT, RIM_THICKNESS, COLORS.stoneDark, 2)
		end
	end
end

local function buildTurret(model: Instance, base: Vector3)
	cylinder(model, "Turret", TURRET_RADIUS, TURRET_HEIGHT, base + Vector3.new(0, TURRET_HEIGHT / 2, 0), COLORS.stone, Enum.Material.Cobblestone)
	TowerKit.decor(cylinder(model, "TurretRing", TURRET_RADIUS + 1, 2, base + Vector3.new(0, TURRET_HEIGHT - 1, 0), COLORS.stoneDark, Enum.Material.Cobblestone))
	local roofBase = base + Vector3.new(0, TURRET_HEIGHT, 0)
	TowerKit.decor(TowerKit.cone(model, "TurretRoof", TURRET_RADIUS + 2, TURRET_ROOF_HEIGHT, roofBase, COLORS.roof, Enum.Material.Slate))
	TowerKit.decor(part(model, "TurretFinial", Vector3.new(0.5, 5, 0.5), CFrame.new(roofBase + Vector3.new(0, TURRET_ROOF_HEIGHT + 2.5, 0)), COLORS.gold, Enum.Material.Metal))
	-- Janelinhas acesas em volta, no alto.
	for slot = 0, 3 do
		local angle = slot * math.pi / 2 + math.pi / 4
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = base + Vector3.new(0, TURRET_HEIGHT - 8, 0) + outward * (TURRET_RADIUS + 0.05)
		TowerKit.decor(part(model, "TurretWindow", Vector3.new(1.6, 3.5, 0.3), CFrame.lookAt(position, position + outward), COLORS.window, Enum.Material.Neon))
	end
end

local function buildBridge(model: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local deck = CFrame.lookAt((from + to) / 2, to)
	part(model, "BridgeDeck", Vector3.new(BRIDGE_WIDTH, 1.5, length), deck * CFrame.new(0, -0.75, 0), COLORS.wood, Enum.Material.WoodPlanks)
	local pillars = math.max(2, math.floor(length / BRIDGE_PILLAR_SPACING) + 1)
	for index = 0, pillars - 1 do
		local along = from:Lerp(to, index / (pillars - 1))
		for _, side in ipairs({ -1, 1 }) do
			local foot = (CFrame.lookAt(along, along + (to - from)) * CFrame.new(side * (BRIDGE_WIDTH / 2 - 0.5), BRIDGE_ROOF_HEIGHT / 2, 0)).Position
			TowerKit.decor(part(model, "BridgePost", Vector3.new(1, BRIDGE_ROOF_HEIGHT, 1), CFrame.new(foot), COLORS.wood, Enum.Material.Wood))
		end
	end
	-- Telhado de duas águas de ardósia.
	for _, side in ipairs({ -1, 1 }) do
		local slope = deck * CFrame.new(side * BRIDGE_WIDTH / 4, BRIDGE_ROOF_HEIGHT + 1.5, 0) * CFrame.Angles(0, 0, side * math.rad(-25))
		TowerKit.decor(part(model, "BridgeRoof", Vector3.new(BRIDGE_WIDTH / 2 + 2.5, 0.8, length + 2), slope, COLORS.roof, Enum.Material.Slate))
	end
	for _, side in ipairs({ -1, 1 }) do
		local rail = deck * CFrame.new(side * (BRIDGE_WIDTH / 2 - 0.3), 1.5, 0)
		part(model, "BridgeRail", Vector3.new(0.6, 3, length), rail, COLORS.wood, Enum.Material.Wood)
	end
end

-- Monta a ilha com o chão em `center` (o mesmo centro da torre).
function TowerIsland.build(parent: Instance, center: Vector3)
	local radius = RaceConfig.Tower.IslandRadius
	local model = Instance.new("Model")
	model.Name = "TowerIsland"
	buildGround(model, center, radius)
	buildRim(model, center, radius)
	for _, angle in ipairs(TURRET_ANGLES) do
		local base = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius - TURRET_INSET)
		buildTurret(model, base)
	end
	local gate = center + Vector3.new(math.cos(GATE_ANGLE), 0, math.sin(GATE_ANGLE)) * radius
	if gate.Z < BRIDGE_END_Z then
		buildBridge(model, gate, Vector3.new(gate.X, BRIDGE_END_Y, BRIDGE_END_Z))
	end
	model.Parent = parent
end

return table.freeze(TowerIsland)
