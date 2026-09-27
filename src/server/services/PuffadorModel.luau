--!strict

-- Modelo 3D do Puffador, montado só com peças nativas. Duas versões:
--   Standard: corpo lilás, detalhes dourados e tanque de "puff" de vidro.
--   Super: o protótipo dourado do Barão Puff, com cano duplo (quebra dois
--          blocos por tiro), tanque brilhante, faíscas e luz própria.
-- Convenção do espaço do Handle (a empunhadura): frente = -Z, cima = +Y. O
-- attachment Muzzle marca a boca do cano, de onde o projétil visual sai.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)

export type Variant = "Standard" | "Super"

type Palette = {
	body: Color3,
	bodyMaterial: Enum.Material,
	grip: Color3,
	trim: Color3,
	trimMaterial: Enum.Material,
	glow: Color3,
	cloud: Color3,
}

local PALETTES: { [Variant]: Palette } = {
	Standard = {
		body = Color3.fromRGB(186, 158, 255),
		bodyMaterial = Enum.Material.SmoothPlastic,
		grip = Color3.fromRGB(58, 38, 96),
		trim = Color3.fromRGB(255, 204, 96),
		trimMaterial = Enum.Material.Metal,
		glow = Color3.fromRGB(255, 232, 160),
		cloud = Color3.fromRGB(240, 232, 255),
	},
	Super = {
		body = Color3.fromRGB(255, 196, 64),
		bodyMaterial = Enum.Material.Metal,
		grip = Color3.fromRGB(74, 30, 112),
		trim = Color3.fromRGB(196, 150, 255),
		trimMaterial = Enum.Material.SmoothPlastic,
		glow = Color3.fromRGB(255, 244, 200),
		cloud = Color3.fromRGB(255, 214, 120),
	},
}

local BORE_COLOR = Color3.fromRGB(22, 14, 34)
local BODY_Y = 0.85
local BODY_DIAMETER = 0.95
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)
local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local PuffadorModel = {}

type Builder = {
	handle: Part,
	parent: Tool,
}

local function addPart(
	builder: Builder,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape ~= nil then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = builder.handle.CFrame * cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Parent = builder.parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = builder.handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- Cilindro deitado ao longo do cano (eixo Z), centrado em (x, y, z).
local function tube(builder: Builder, name: string, x: number, y: number, z: number, length: number, diameter: number, color: Color3, material: Enum.Material): Part
	return addPart(builder, name, Vector3.new(length, diameter, diameter), CFrame.new(x, y, z) * ALONG_Z, color, material, Enum.PartType.Cylinder)
end

local function createSounds(handle: Part, variant: Variant)
	local shotSound = Instance.new("Sound")
	shotSound.Name = PuffadorConstants.ShotSoundName
	shotSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	shotSound.Volume = if variant == "Super" then 0.7 else 0.55
	shotSound.PlaybackSpeed = if variant == "Super" then 0.62 else 0.82
	shotSound.RollOffMaxDistance = 70
	shotSound.Parent = handle

	local hitSound = Instance.new("Sound")
	hitSound.Name = PuffadorConstants.HitSoundName
	hitSound.SoundId = "rbxasset://sounds/button.wav"
	hitSound.Volume = 0.5
	hitSound.PlaybackSpeed = if variant == "Super" then 1.05 else 1.25
	hitSound.RollOffMaxDistance = 45
	hitSound.Parent = handle
end

-- Empunhadura, guarda-mato e gatilho.
local function buildGrip(builder: Builder, palette: Palette)
	addPart(builder, "GripCap", Vector3.new(0.56, 0.14, 0.7), CFrame.new(0, -0.66, 0.02), palette.trim, palette.trimMaterial)
	addPart(builder, "GripPanelL", Vector3.new(0.04, 0.8, 0.42), CFrame.new(-0.26, -0.05, 0.02), palette.grip:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric)
	addPart(builder, "GripPanelR", Vector3.new(0.04, 0.8, 0.42), CFrame.new(0.26, -0.05, 0.02), palette.grip:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric)
	addPart(builder, "Trigger", Vector3.new(0.08, 0.3, 0.1), CFrame.new(0, 0.26, -0.47) * CFrame.Angles(math.rad(-12), 0, 0), palette.trim, palette.trimMaterial)
	addPart(builder, "GuardBottom", Vector3.new(0.1, 0.07, 0.56), CFrame.new(0, 0.04, -0.56), palette.grip, Enum.Material.SmoothPlastic)
	addPart(builder, "GuardFront", Vector3.new(0.1, 0.36, 0.07), CFrame.new(0, 0.2, -0.82), palette.grip, Enum.Material.SmoothPlastic)
end

-- Corpo, anéis de energia, alça de mira e barbatana traseira.
local function buildBody(builder: Builder, palette: Palette)
	tube(builder, "Body", 0, BODY_Y, -0.55, 2.2, BODY_DIAMETER, palette.body, palette.bodyMaterial)
	addPart(builder, "RearCap", Vector3.new(BODY_DIAMETER, BODY_DIAMETER, BODY_DIAMETER), CFrame.new(0, BODY_Y, 0.55), palette.grip, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	tube(builder, "RearCollar", 0, BODY_Y, 0.42, 0.12, BODY_DIAMETER + 0.08, palette.trim, palette.trimMaterial)
	tube(builder, "FrontCollar", 0, BODY_Y, -1.65, 0.2, BODY_DIAMETER + 0.1, palette.trim, palette.trimMaterial)
	for index, z in ipairs({ -0.2, -1.15 }) do
		tube(builder, `PowerRing{index}`, 0, BODY_Y, z, 0.08, BODY_DIAMETER + 0.03, palette.glow, Enum.Material.Neon)
	end
	for _, side in ipairs({ -1, 1 }) do
		addPart(builder, if side < 0 then "RailL" else "RailR", Vector3.new(0.06, 0.12, 1.3), CFrame.new(side * 0.47, BODY_Y - 0.12, -0.7), palette.grip, Enum.Material.SmoothPlastic)
	end
	addPart(builder, "FrontSight", Vector3.new(0.1, 0.16, 0.12), CFrame.new(0, BODY_Y + 0.52, -1.5), palette.trim, palette.trimMaterial)
	addPart(builder, "Fin", Vector3.new(0.1, 0.42, 0.55), CFrame.new(0, BODY_Y + 0.62, 0.3), palette.grip, Enum.Material.SmoothPlastic)
end

-- Tanque de vidro com a nuvem de "puff" dentro, preso por anéis.
local function buildTank(builder: Builder, palette: Palette, variant: Variant): Part
	local tankY = BODY_Y + 0.58
	local glass = tube(builder, "Tank", 0, tankY, -0.62, 1.1, 0.5, Color3.fromRGB(220, 230, 255), Enum.Material.Glass)
	glass.Transparency = 0.45
	for index, z in ipairs({ -0.05, -1.19 }) do
		tube(builder, `TankCap{index}`, 0, tankY, z, 0.1, 0.58, palette.trim, palette.trimMaterial)
	end
	local cloudSize = if variant == "Super" then 0.4 else 0.34
	local cloud = addPart(builder, "PuffCloud", Vector3.new(cloudSize, cloudSize, cloudSize), CFrame.new(0, tankY, -0.62), palette.cloud, Enum.Material.Neon, Enum.PartType.Ball)
	cloud.Transparency = if variant == "Super" then 0 else 0.15
	addPart(builder, "PuffCloud2", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, tankY + 0.02, -0.35), palette.cloud, Enum.Material.Neon, Enum.PartType.Ball).Transparency = 0.3
	addPart(builder, "PuffCloud3", Vector3.new(0.24, 0.24, 0.24), CFrame.new(0, tankY - 0.02, -0.9), palette.cloud, Enum.Material.Neon, Enum.PartType.Ball).Transparency = 0.3
	return cloud
end

-- Cano e boca em forma de corneta. O Super tem dois canos lado a lado.
local function buildMuzzle(builder: Builder, palette: Palette, variant: Variant): number
	local offsets = if variant == "Super" then { -0.2, 0.2 } else { 0 }
	local barrelDiameter = if variant == "Super" then 0.42 else 0.62
	for index, x in ipairs(offsets) do
		tube(builder, `Barrel{index}`, x, BODY_Y, -2.05, 0.9, barrelDiameter, palette.grip, Enum.Material.SmoothPlastic)
	end

	local flare = { { 0.82, 0.16, -2.5 }, { 1.02, 0.14, -2.63 }, { 1.22, 0.12, -2.74 } }
	local scale = if variant == "Super" then 1.12 else 1
	for index, step in ipairs(flare) do
		tube(builder, `Bell{index}`, 0, BODY_Y, step[3], step[2], step[1] * scale, palette.trim, palette.trimMaterial)
	end
	tube(builder, "BellGlow", 0, BODY_Y, -2.795, 0.02, 1.0 * scale, palette.glow, Enum.Material.Neon)
	for index, x in ipairs(offsets) do
		tube(builder, `Bore{index}`, x, BODY_Y, -2.8, 0.04, barrelDiameter * 0.9, BORE_COLOR, Enum.Material.SmoothPlastic)
	end
	return -2.9
end

local function addSuperEffects(cloud: Part, palette: Palette)
	local light = Instance.new("PointLight")
	light.Color = palette.body
	light.Range = 7
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = cloud

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(palette.body, palette.glow)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new(0.2)
	sparkles.Lifetime = NumberRange.new(0.4, 0.8)
	sparkles.Rate = 10
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = cloud
end

function PuffadorModel.build(variant: Variant, owner: string): Tool
	local palette = PALETTES[variant]

	local tool = Instance.new("Tool")
	tool.Name = PuffadorConstants.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = if variant == "Super" then "Puffador do Cofre" else "Puffador"
	tool.Grip = CFrame.new(0, -0.1, 0)
	tool:SetAttribute("GeneratedBy", owner)
	tool:SetAttribute("Variant", variant)

	local handle = Instance.new("Part")
	handle.Name = PuffadorConstants.HandleName
	handle.Size = Vector3.new(0.5, 1.25, 0.62)
	handle.CFrame = CFrame.new()
	handle.Color = palette.grip
	handle.Material = Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.CastShadow = false
	handle.Massless = true
	handle.Parent = tool

	local builder: Builder = { handle = handle, parent = tool }
	createSounds(handle, variant)
	buildGrip(builder, palette)
	buildBody(builder, palette)
	local cloud = buildTank(builder, palette, variant)
	local muzzleZ = buildMuzzle(builder, palette, variant)
	if variant == "Super" then
		addSuperEffects(cloud, palette)
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = PuffadorConstants.MuzzleAttachmentName
	muzzle.CFrame = CFrame.new(0, BODY_Y, muzzleZ)
	muzzle.Parent = handle

	-- Um Puffador largado no chão não deve permanecer ali: removemos qualquer
	-- cópia que acabe diretamente sob o Workspace (fora de Backpack/Character).
	tool.AncestryChanged:Connect(function(descendant, newParent)
		if descendant == tool and newParent == Workspace then
			tool:Destroy()
		end
	end)

	return tool
end

-- Cor do projétil de cada versão.
function PuffadorModel.getProjectileColor(variant: Variant): Color3
	return if variant == "Super" then PALETTES.Super.body else PuffadorConstants.ProjectileColor
end

return table.freeze(PuffadorModel)
