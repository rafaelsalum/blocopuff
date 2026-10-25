--!strict

-- Postes de lampião antigos do lado de fora: base de pedra, poste de ferro
-- preto e lanterna de vidro com uma chama dentro. Acendem ao entardecer e
-- apagam de manhã, seguindo a hora do céu (Lighting.ClockTime, ajustada pelo
-- DayCycleService). A base e o poste são sólidos (quem passeia lá fora
-- esbarra neles); a lanterna é enfeite.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LampLayout = require(script.Parent.Parent.data.LampLayout)
local OutdoorConfig = require(ReplicatedStorage.Shared.config.OutdoorConfig)

local IRON = Color3.fromRGB(30, 30, 32)
local STONE = Color3.fromRGB(92, 90, 86)
local GLASS = Color3.fromRGB(255, 220, 160)
local FLAME_LIT = Color3.fromRGB(255, 170, 80)
local FLAME_OUT = Color3.fromRGB(70, 60, 50)
local PLINTH_SIZE = Vector3.new(2.2, 1.2, 2.2)
local POST_WIDTH = 0.7
local COLLAR_WIDTH = 1.2
local LANTERN_SIZE = Vector3.new(1.3, 2, 1.3)
local CAP_SIZE = Vector3.new(1.8, 0.3, 1.8)
local FINIAL_SIZE = 0.6
local BAR_WIDTH = 0.15
local FLAME_SIZE = Vector3.new(0.35, 0.7, 0.35)

type Lamp = { flame: BasePart, glass: BasePart, light: PointLight }

local OutdoorLamps = {}

local lamps: { Lamp } = {}
local lit: boolean? = nil
local listening = false

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Size = size
	created.CFrame = cframe
	created.Color = color
	created.Material = material
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.TopSurface = Enum.SurfaceType.Smooth
	created.BottomSurface = Enum.SurfaceType.Smooth
	created.Parent = parent
	return created
end

local function setLit(lamp: Lamp, on: boolean)
	lamp.light.Enabled = on
	lamp.flame.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	lamp.flame.Color = if on then FLAME_LIT else FLAME_OUT
	lamp.glass.Transparency = if on then 0.25 else 0.45
end

-- Monta um poste com o pé em `foot`.
local function build(parent: Instance, foot: Vector3): Lamp
	local settings = OutdoorConfig.Lamps
	local model = Instance.new("Model")
	model.Name = "OutdoorLamp"
	local height = settings.PostHeight
	local plinth = part(model, "Plinth", PLINTH_SIZE, CFrame.new(foot + Vector3.new(0, PLINTH_SIZE.Y / 2, 0)), STONE, Enum.Material.Cobblestone)
	plinth.CanCollide = true
	local postBase = foot.Y + PLINTH_SIZE.Y
	local post = part(model, "Post", Vector3.new(height, POST_WIDTH, POST_WIDTH), CFrame.new(foot.X, postBase + height / 2, foot.Z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal)
	post.Shape = Enum.PartType.Cylinder
	post.CanCollide = true
	local collar = part(model, "Collar", Vector3.new(0.4, COLLAR_WIDTH, COLLAR_WIDTH), CFrame.new(foot.X, postBase + height, foot.Z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal)
	collar.Shape = Enum.PartType.Cylinder

	local center = Vector3.new(foot.X, postBase + height + 0.2 + LANTERN_SIZE.Y / 2, foot.Z)
	part(model, "LanternBase", Vector3.new(LANTERN_SIZE.X + 0.2, 0.2, LANTERN_SIZE.Z + 0.2), CFrame.new(center - Vector3.new(0, LANTERN_SIZE.Y / 2 + 0.1, 0)), IRON, Enum.Material.Metal)
	local glass = part(model, "Glass", LANTERN_SIZE, CFrame.new(center), GLASS, Enum.Material.Glass)
	glass.CastShadow = false
	local half = LANTERN_SIZE.X / 2
	for _, corner in ipairs({ Vector3.new(half, 0, half), Vector3.new(-half, 0, half), Vector3.new(half, 0, -half), Vector3.new(-half, 0, -half) }) do
		part(model, "Bar", Vector3.new(BAR_WIDTH, LANTERN_SIZE.Y + 0.1, BAR_WIDTH), CFrame.new(center + corner), IRON, Enum.Material.Metal).CastShadow = false
	end
	part(model, "Cap", CAP_SIZE, CFrame.new(center + Vector3.new(0, LANTERN_SIZE.Y / 2 + CAP_SIZE.Y / 2, 0)), IRON, Enum.Material.Metal).CastShadow = false
	local finial = part(model, "Finial", Vector3.one * FINIAL_SIZE, CFrame.new(center + Vector3.new(0, LANTERN_SIZE.Y / 2 + CAP_SIZE.Y + FINIAL_SIZE / 2, 0)), IRON, Enum.Material.Metal)
	finial.Shape = Enum.PartType.Ball
	finial.CastShadow = false
	local flame = part(model, "Flame", FLAME_SIZE, CFrame.new(center - Vector3.new(0, 0.2, 0)), FLAME_LIT, Enum.Material.Neon)
	flame.CastShadow = false

	local light = Instance.new("PointLight")
	light.Range = settings.LightRange
	light.Brightness = settings.LightBrightness
	local rgb = settings.LightColor
	light.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	light.Shadows = false
	light.Parent = flame

	model.Parent = parent
	return { flame = flame, glass = glass, light = light }
end

local function update()
	local settings = OutdoorConfig.Lamps
	local on = LampLayout.isLit(Lighting.ClockTime, settings.OnHour, settings.OffHour)
	if on == lit then
		return
	end
	lit = on
	for _, lamp in ipairs(lamps) do
		setLit(lamp, on)
	end
end

-- Planta postes nos pés `feet` e passa a acendê-los e apagá-los pela hora.
function OutdoorLamps.place(parent: Instance, feet: { Vector3 })
	for _, foot in ipairs(feet) do
		local lamp = build(parent, foot)
		table.insert(lamps, lamp)
		if lit ~= nil then
			setLit(lamp, lit)
		end
	end
	if not listening then
		listening = true
		Lighting:GetPropertyChangedSignal("ClockTime"):Connect(update)
	end
	lit = nil
	update()
end

return table.freeze(OutdoorLamps)
