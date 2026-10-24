--!strict

-- Terraço da Torre do Relógio Encantada (Fase 5F), assentado no chão da
-- floresta (OutdoorService): gramado com pátio de laje em volta da torre,
-- muralha baixa com ameias, torrinhas de telhado pontudo azul e a ponte
-- coberta, sobre pilares de pedra, que sobe até a porta do fundo do Saguão
-- da Torre (TowerHallLayout), por onde quem está no lobby passeia em volta
-- da torre. A muralha e a ponte têm uma barreira invisível por cima
-- (ninguém pula para fora).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local TowerHallLayout = require(ReplicatedStorage.Shared.modules.TowerHallLayout)
local TowerKit = require(script.Parent.TowerKit)

local GROUND_THICKNESS = 4
local COURTYARD_FRACTION = 0.76
local RIM_SEGMENTS = 32
local RIM_HEIGHT = 4
local RIM_THICKNESS = 2
-- A muralha abre onde chega a ponte (ângulo do TowerHallLayout).
local GATE_HALF_WIDTH = math.rad(7)
local TURRET_ANGLES = { math.rad(30), math.rad(150), math.rad(225), math.rad(315) }
local TURRET_RADIUS = 6
local TURRET_HEIGHT = 36
local TURRET_ROOF_HEIGHT = 20
local TURRET_INSET = 9
-- Altura da barreira invisível acima da muralha e das grades da ponte (alta o
-- bastante para não dar pulo por cima nem de cima do corrimão ou dos pilares
-- do portão).
local FENCE_HEIGHT = 16
local BRIDGE_WIDTH = 12
local BRIDGE_PILLAR_SPACING = 13
local BRIDGE_ROOF_HEIGHT = 11
-- Pilares de pedra embaixo da ponte: descem até abaixo do chão (o terreno
-- esconde o pé).
local BRIDGE_PIER_THICKNESS = 2.5
local BRIDGE_PIER_DEPTH = 30

local COLORS = TowerKit.COLORS
local part = TowerKit.part
local cylinder = TowerKit.cylinder

local TowerIsland = {}

local function buildGround(model: Instance, center: Vector3, radius: number)
	cylinder(model, "IslandGround", radius, GROUND_THICKNESS, center - Vector3.new(0, GROUND_THICKNESS / 2, 0), COLORS.grass, Enum.Material.Grass)
	-- Pátio de laje um pouco acima do gramado (sem degrau sensível).
	cylinder(model, "Courtyard", radius * COURTYARD_FRACTION, GROUND_THICKNESS, center - Vector3.new(0, GROUND_THICKNESS / 2 - 0.1, 0), COLORS.stoneLight, Enum.Material.Slate)
end

-- Parede invisível de `from` a `to`, com o pé na altura deles.
local function fence(model: Instance, from: Vector3, to: Vector3, height: number)
	local base = CFrame.lookAt((from + to) / 2, to)
	local wall = part(model, "Fence", Vector3.new(1, height, (to - from).Magnitude + 1), base * CFrame.new(0, height / 2, 0), COLORS.stone, Enum.Material.SmoothPlastic)
	wall.Transparency = 1
	wall.CanTouch = false
	wall.CanQuery = false
end

-- Muralha em volta, com o vão do portão centrado em `gateAngle`. Os cantos
-- entre o fim da muralha e as grades da ponte também ficam fechados.
local function buildRim(model: Instance, center: Vector3, radius: number, gateAngle: number, railEnds: { Vector3 })
	local wallRadius = radius - RIM_THICKNESS
	local segments = RIM_SEGMENTS - 1
	local from = gateAngle + GATE_HALF_WIDTH
	local step = (2 * math.pi - 2 * GATE_HALF_WIDTH) / segments
	local lift = Vector3.new(0, RIM_HEIGHT, 0)
	local function ring(angle: number): Vector3
		return center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * wallRadius
	end
	for index = 1, segments do
		local a, b = ring(from + (index - 1) * step), ring(from + index * step)
		TowerKit.wall(model, a, b, RIM_HEIGHT, RIM_THICKNESS, COLORS.stoneDark, 2)
		fence(model, a + lift, b + lift, FENCE_HEIGHT)
	end
	for _, rimEnd in ipairs({ ring(gateAngle + GATE_HALF_WIDTH), ring(gateAngle - GATE_HALF_WIDTH) }) do
		local nearest = railEnds[1]
		for _, railEnd in ipairs(railEnds) do
			if (railEnd - rimEnd).Magnitude < (nearest - rimEnd).Magnitude then
				nearest = railEnd
			end
		end
		fence(model, rimEnd, Vector3.new(nearest.X, rimEnd.Y, nearest.Z), RIM_HEIGHT + FENCE_HEIGHT)
	end
end

-- Pontas das grades da ponte do lado da ilha.
local function railEnds(gate: Vector3, toward: Vector3): { Vector3 }
	local flat = Vector3.new(toward.X - gate.X, 0, toward.Z - gate.Z).Unit
	local right = flat:Cross(Vector3.yAxis) * (BRIDGE_WIDTH / 2 - 0.3)
	return { gate + right, gate - right }
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
		-- As pontas apoiam no Saguão e no terraço.
		if index > 0 and index < pillars - 1 then
			local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local pier = CFrame.lookAt(along, along + flat) * CFrame.new(0, -1.5 - BRIDGE_PIER_DEPTH / 2, 0)
			TowerKit.decor(part(model, "BridgePier", Vector3.new(BRIDGE_WIDTH - 2, BRIDGE_PIER_DEPTH, BRIDGE_PIER_THICKNESS), pier, COLORS.stone, Enum.Material.Cobblestone))
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
		local edge = deck * CFrame.new(side * (BRIDGE_WIDTH / 2 - 0.3), 0, 0)
		local half = edge.LookVector * (length / 2)
		fence(model, edge.Position - half, edge.Position + half, FENCE_HEIGHT)
	end
end

-- Monta a ilha com o chão em `center` (o mesmo centro da torre).
function TowerIsland.build(parent: Instance, center: Vector3)
	local radius = RaceConfig.Tower.IslandRadius
	local model = Instance.new("Model")
	model.Name = "TowerIsland"
	buildGround(model, center, radius)
	local hall = TowerHallLayout.get()
	buildRim(model, center, radius, hall.gateAngle, railEnds(hall.bridgeTo, hall.bridgeFrom))
	for _, angle in ipairs(TURRET_ANGLES) do
		local base = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius - TURRET_INSET)
		buildTurret(model, base)
	end
	buildBridge(model, hall.bridgeTo, hall.bridgeFrom)
	model.Parent = parent
end

return table.freeze(TowerIsland)
