--!strict

-- Peças básicas da Torre do Relógio Encantada (Fase 5F): blocos, cilindros
-- de pé, cones (telhados pontudos) e a paleta de pedra e ardósia. O cone é
-- a malha "Improved Cone" da Creator Store (asset 703458255), recriada por
-- código; se a malha não carregar, vira uma pilha de discos.

local AssetService = game:GetService("AssetService")

local CONE_MESH_ID = "rbxassetid://703458158"
local CONE_FALLBACK_TIERS = 6

local TowerKit = {}

TowerKit.COLORS = table.freeze({
	stone = Color3.fromRGB(128, 132, 142),
	stoneDark = Color3.fromRGB(92, 96, 108),
	stoneLight = Color3.fromRGB(168, 166, 160),
	ramp = Color3.fromRGB(156, 150, 140),
	landing = Color3.fromRGB(150, 134, 108),
	roof = Color3.fromRGB(46, 62, 110),
	gold = Color3.fromRGB(214, 172, 74),
	wood = Color3.fromRGB(92, 64, 44),
	banner = Color3.fromRGB(122, 28, 40),
	window = Color3.fromRGB(196, 128, 58),
	grass = Color3.fromRGB(74, 98, 62),
	rock = Color3.fromRGB(86, 80, 76),
	clockRim = Color3.fromRGB(60, 52, 44),
})

local coneTemplate: MeshPart? = nil
local coneLoaded = false

function TowerKit.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Anchored = true
	newPart.Size = size
	newPart.CFrame = cframe
	newPart.Color = color
	newPart.Material = material
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	newPart.CastShadow = false
	newPart.Parent = parent
	return newPart
end

-- Enfeite: não colide, não recebe raio nem toque (celular).
function TowerKit.decor(target: BasePart): BasePart
	target.CanCollide = false
	target.CanQuery = false
	target.CanTouch = false
	return target
end

-- Cilindro de pé (o eixo do cilindro do Roblox é o X).
function TowerKit.cylinder(parent: Instance, name: string, radius: number, height: number, centerPosition: Vector3, color: Color3, material: Enum.Material): Part
	local newPart = TowerKit.part(parent, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(centerPosition) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	newPart.Shape = Enum.PartType.Cylinder
	return newPart
end

local function loadCone(): MeshPart?
	if coneLoaded then
		return coneTemplate
	end
	coneLoaded = true
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(CONE_MESH_ID)
	end)
	if ok then
		coneTemplate = result
	else
		warn("[TowerKit] cone mesh unavailable, using stacked discs:", result)
	end
	return coneTemplate
end

-- Cone de pé com a base em `basePosition` (ponta para cima). `upsideDown`
-- vira a ponta para baixo (o penhasco embaixo da ilha).
function TowerKit.cone(parent: Instance, name: string, radius: number, height: number, basePosition: Vector3, color: Color3, material: Enum.Material, upsideDown: boolean?): BasePart
	local direction = if upsideDown then -1 else 1
	local template = loadCone()
	if template ~= nil then
		local cone = template:Clone()
		cone.Name = name
		cone.Anchored = true
		cone.Size = Vector3.new(radius * 2, height, radius * 2)
		local flip = if upsideDown then CFrame.Angles(math.pi, 0, 0) else CFrame.identity
		cone.CFrame = CFrame.new(basePosition + Vector3.new(0, direction * height / 2, 0)) * flip
		cone.Color = color
		cone.Material = material
		cone.CastShadow = false
		cone.Parent = parent
		return cone
	end
	local model = Instance.new("Model")
	model.Name = name
	local tierHeight = height / CONE_FALLBACK_TIERS
	for tier = 0, CONE_FALLBACK_TIERS - 1 do
		local tierRadius = radius * (1 - tier / CONE_FALLBACK_TIERS)
		local y = direction * (tier + 0.5) * tierHeight
		TowerKit.cylinder(model, "Tier", tierRadius, tierHeight, basePosition + Vector3.new(0, y, 0), color, material)
	end
	model.Parent = parent
	return model:FindFirstChildWhichIsA("BasePart") :: BasePart
end

-- Mureta reta de `from` a `to` (pontos no chão), com ameias em cima.
function TowerKit.wall(parent: Instance, from: Vector3, to: Vector3, height: number, thickness: number, color: Color3, merlons: number)
	local middle = (from + to) / 2
	local length = (to - from).Magnitude
	if length < 1e-3 then
		return
	end
	local base = CFrame.lookAt(middle, to)
	TowerKit.part(parent, "Wall", Vector3.new(thickness, height, length + thickness), base * CFrame.new(0, height / 2, 0), color, Enum.Material.Cobblestone)
	local merlonHeight = math.min(2, height * 0.5)
	for index = 1, merlons do
		local along = (index - 0.5) / merlons - 0.5
		local merlon = TowerKit.part(parent, "Merlon", Vector3.new(thickness + 0.2, merlonHeight, math.min(3, length / (merlons * 2))), base * CFrame.new(0, height + merlonHeight / 2, along * length), color, Enum.Material.Cobblestone)
		TowerKit.decor(merlon)
	end
end

return table.freeze(TowerKit)
