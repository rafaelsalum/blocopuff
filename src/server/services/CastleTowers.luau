--!strict

-- Silhueta de castelo do Casarão: ameias em volta dos telhados, torres
-- redondas com seteiras e telhado cônico pontudo de ardósia (como a Torre
-- do Relógio) e uma torre de menagem no meio do telhado com pináculo e
-- torrinhas. O corpo das torres é sólido; o resto é enfeite.

local TowerKit = require(script.Parent.TowerKit)

local COLORS = TowerKit.COLORS
local STONE = Color3.fromRGB(150, 148, 142)
local MERLON_SPACING = 5
local PARAPET_HEIGHT = 2.5
local PARAPET_THICKNESS = 1.5
local BAND_SPACING = 14
local SLITS_PER_RING = 4
local FINIAL_SIZE = 1.4
-- Telhado de duas águas: recuo da beira (fica atrás das ameias) e inclinação.
local ROOF_INSET = 1.6
local ROOF_PITCH = 0.36
local ROOF_MAX_HEIGHT = 20

export type Tower = {
	center: Vector3,
	radius: number,
	-- Pé (enterrado no chão) e topo do corpo.
	bottom: number,
	top: number,
	roofHeight: number,
}

local CastleTowers = {}

-- Mureta com ameias na beira do telhado, de `from` a `to` (no topo da
-- parede), recuada `PARAPET_THICKNESS / 2` para dentro, em `inward`.
function CastleTowers.parapet(parent: Instance, from: Vector3, to: Vector3, inward: Vector3)
	local shift = inward * (PARAPET_THICKNESS / 2)
	local length = (to - from).Magnitude
	local model = Instance.new("Model")
	model.Name = "CastleParapet"
	TowerKit.wall(model, from + shift, to + shift, PARAPET_HEIGHT, PARAPET_THICKNESS, STONE, math.max(1, math.floor(length / MERLON_SPACING)))
	for _, piece in ipairs(model:GetChildren()) do
		if piece:IsA("BasePart") then
			TowerKit.decor(piece)
		end
	end
	model.Parent = parent
end

-- Telhado cônico com uma bola dourada e uma haste na ponta.
local function roof(parent: Instance, base: Vector3, radius: number, height: number)
	TowerKit.decor(TowerKit.cone(parent, "CastleRoof", radius, height, base, COLORS.roof, Enum.Material.Slate))
	local tip = base + Vector3.new(0, height, 0)
	local ball = TowerKit.part(parent, "CastleFinial", Vector3.one * FINIAL_SIZE, CFrame.new(tip + Vector3.new(0, FINIAL_SIZE * 0.3, 0)), COLORS.gold, Enum.Material.Metal)
	ball.Shape = Enum.PartType.Ball
	TowerKit.decor(ball)
	TowerKit.decor(TowerKit.cylinder(parent, "CastleSpike", 0.2, 3, tip + Vector3.new(0, FINIAL_SIZE + 1.2, 0), COLORS.gold, Enum.Material.Metal))
end

-- Torre redonda: corpo, frisos, seteiras acesas, coroa com ameias e telhado.
function CastleTowers.round(parent: Instance, name: string, tower: Tower)
	local model = Instance.new("Model")
	model.Name = name
	local height = tower.top - tower.bottom
	local center = tower.center
	local body = TowerKit.cylinder(model, "Body", tower.radius, height, Vector3.new(center.X, tower.bottom + height / 2, center.Z), COLORS.stoneDark, Enum.Material.Cobblestone)
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = true

	local ring = 0
	local y = tower.top - BAND_SPACING
	while y > tower.bottom + BAND_SPACING / 2 do
		ring += 1
		TowerKit.decor(TowerKit.cylinder(model, "Band", tower.radius + 0.3, 0.8, Vector3.new(center.X, y, center.Z), COLORS.stoneLight, Enum.Material.Limestone))
		-- Seteiras entre um friso e outro, giradas a cada andar.
		for index = 1, SLITS_PER_RING do
			local angle = (index + ring * 0.5) * 2 * math.pi / SLITS_PER_RING
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local spot = Vector3.new(center.X, y + BAND_SPACING / 2, center.Z) + out * (tower.radius - 0.05)
			TowerKit.decor(TowerKit.part(model, "Slit", Vector3.new(0.7, 3, 0.4), CFrame.lookAt(spot, spot + out), COLORS.window, Enum.Material.Neon))
		end
		y -= BAND_SPACING
	end

	-- Coroa: um anel mais largo (os mata-cães) e as ameias em volta.
	local crown = tower.radius + 1
	TowerKit.decor(TowerKit.cylinder(model, "Corbel", crown, 1.6, Vector3.new(center.X, tower.top + 0.8, center.Z), COLORS.stoneLight, Enum.Material.Limestone))
	local merlons = math.max(6, math.floor(2 * math.pi * crown / 3.2))
	for index = 1, merlons do
		local angle = index * 2 * math.pi / merlons
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = Vector3.new(center.X, tower.top + 2.6, center.Z) + out * (crown - 0.5)
		TowerKit.decor(TowerKit.part(model, "Merlon", Vector3.new(1.6, 2, 1), CFrame.lookAt(spot, spot + out), COLORS.stone, Enum.Material.Cobblestone))
	end
	roof(model, Vector3.new(center.X, tower.top + 1.6, center.Z), tower.radius + 0.4, tower.roofHeight)
	model.Parent = parent
end

-- Telhado de duas águas de ardósia sobre o retângulo, com a cumeeira no
-- sentido mais comprido. Cada água é uma cunha (a do Roblox desce para -Z
-- local), e as pontas triangulares viram as empenas.
function CastleTowers.gable(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number, base: number)
	minX, maxX, minZ, maxZ = minX + ROOF_INSET, maxX - ROOF_INSET, minZ + ROOF_INSET, maxZ - ROOF_INSET
	local width, depth = maxX - minX, maxZ - minZ
	local alongZ = depth >= width
	local half = (if alongZ then width else depth) / 2
	local length = if alongZ then depth else width
	local height = math.min(ROOF_MAX_HEIGHT, half * ROOF_PITCH * 2)
	local center = Vector3.new((minX + maxX) / 2, base + height / 2, (minZ + maxZ) / 2)
	for _, sign in ipairs({ -1, 1 }) do
		-- `sign` diz para que lado a água desce (-1: oeste/norte, 1: leste/sul).
		local offset = if alongZ then Vector3.new(sign * half / 2, 0, 0) else Vector3.new(0, 0, sign * half / 2)
		local turn = if alongZ then -sign * math.pi / 2 else (if sign < 0 then 0 else math.pi)
		local slope = Instance.new("WedgePart")
		slope.Name = "CastleGable"
		slope.Anchored = true
		slope.Size = Vector3.new(length, height, half)
		slope.CFrame = CFrame.new(center + offset) * CFrame.Angles(0, turn, 0)
		slope.Color = COLORS.roof
		slope.Material = Enum.Material.Slate
		slope.CastShadow = false
		TowerKit.decor(slope)
		slope.Parent = parent
	end
end

-- Torre de menagem quadrada no meio do telhado: corpo, janelas, ameias,
-- quatro torrinhas nos cantos e o pináculo alto no meio.
function CastleTowers.keep(parent: Instance, center: Vector3, half: number, bottom: number, top: number, spireHeight: number)
	local model = Instance.new("Model")
	model.Name = "CastleKeep"
	local height = top - bottom
	TowerKit.decor(TowerKit.part(model, "Body", Vector3.new(half * 2, height, half * 2), CFrame.new(center.X, bottom + height / 2, center.Z), COLORS.stoneDark, Enum.Material.Cobblestone))
	TowerKit.decor(TowerKit.part(model, "Band", Vector3.new(half * 2 + 0.6, 0.8, half * 2 + 0.6), CFrame.new(center.X, bottom + height * 0.45, center.Z), COLORS.stoneLight, Enum.Material.Limestone))
	-- Duas janelas altas acesas em cada face.
	for side = 0, 3 do
		local out = Vector3.new(math.cos(side * math.pi / 2), 0, math.sin(side * math.pi / 2))
		local across = Vector3.new(-out.Z, 0, out.X)
		for _, offset in ipairs({ -half / 2, half / 2 }) do
			local spot = Vector3.new(center.X, bottom + height * 0.7, center.Z) + out * (half + 0.1) + across * offset
			TowerKit.decor(TowerKit.part(model, "Window", Vector3.new(2.4, 6, 0.3), CFrame.lookAt(spot, spot + out), COLORS.window, Enum.Material.Neon))
		end
		local corner = Vector3.new(center.X, top, center.Z) + (out + across) * half
		local edgeFrom = Vector3.new(center.X, top, center.Z) + (out - across) * half
		CastleTowers.parapet(model, edgeFrom, corner, -out)
	end
	for side = 0, 3 do
		local angle = side * math.pi / 2 + math.pi / 4
		local spot = Vector3.new(center.X, 0, center.Z) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (half * math.sqrt(2) - 1)
		local turretTop = top + 6
		TowerKit.decor(TowerKit.cylinder(model, "Turret", 2.2, turretTop - top + 2, Vector3.new(spot.X, top + (turretTop - top + 2) / 2 - 2, spot.Z), COLORS.stone, Enum.Material.Cobblestone))
		roof(model, Vector3.new(spot.X, turretTop, spot.Z), 2.8, 8)
	end
	roof(model, Vector3.new(center.X, top, center.Z), half * 0.75, spireHeight)
	model.Parent = parent
end

return table.freeze(CastleTowers)
