--!strict

-- Fantasminha Puff (Fase 5C.4): bolinha branca de lençol com barra
-- ondulada, olhinhos, bochechas rosadas, bracinhos e um brilho suave.
-- A frente olha para −Z. A esfera invisível "Hitbox" (PrimaryPart) marca o
-- alcance do toque (o servidor confere a distância até ela). O cliente faz
-- ele flutuar e balançar em volta do atributo "GhostBase".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionLifeConfig = require(ReplicatedStorage.Shared.config.MansionLifeConfig)

local CONFIG = MansionLifeConfig.Ghost
local WHITE = Color3.fromRGB(242, 246, 255)
local INK = Color3.fromRGB(34, 30, 52)
local BLUSH = Color3.fromRGB(255, 150, 190)
local GLOW = Color3.fromRGB(196, 220, 255)
local BODY_SIZE = 2.4
local HEM_BALL = 0.85
local HEM_COUNT = 5
local LIGHT_RANGE = 10
local LIGHT_BRIGHTNESS = 1.2
local LABEL_DISTANCE = 40

local MansionGhostModel = {}

MansionGhostModel.HitboxName = "Hitbox"

local function ball(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, transparency: number?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function label(adornee: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(6, 0, 1.2, 0)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = LABEL_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = adornee
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.Text = "👻"
	text.TextColor3 = WHITE
	text.TextScaled = true
	text.TextStrokeTransparency = 0.4
	text.Parent = gui
end

-- Monta o Fantasminha com o centro do corpo em `base` (rotação inclusa).
function MansionGhostModel.build(base: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "FantasminhaPuff"
	local body = ball(model, "Body", Vector3.one * BODY_SIZE, base, WHITE, 0.08)
	-- Barra do lençol: um cilindro em pé e bolinhas em volta da borda.
	local skirt = Instance.new("Part")
	skirt.Name = "Skirt"
	skirt.Shape = Enum.PartType.Cylinder
	skirt.Size = Vector3.new(1.1, BODY_SIZE * 0.98, BODY_SIZE * 0.98)
	skirt.CFrame = base * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	skirt.Color = WHITE
	skirt.Material = Enum.Material.SmoothPlastic
	skirt.Transparency = 0.08
	skirt.Anchored = true
	skirt.CanCollide = false
	skirt.CanTouch = false
	skirt.CanQuery = false
	skirt.CastShadow = false
	skirt.Parent = model
	local radius = BODY_SIZE / 2 - HEM_BALL / 2
	for index = 1, HEM_COUNT do
		local angle = (index / HEM_COUNT) * math.pi * 2
		ball(model, `Hem{index}`, Vector3.one * HEM_BALL, base * CFrame.new(math.cos(angle) * radius, -1.15, math.sin(angle) * radius), WHITE, 0.08)
	end
	local front = -BODY_SIZE / 2 + 0.12
	for _, side in ipairs({ -1, 1 }) do
		ball(model, if side < 0 then "EyeL" else "EyeR", Vector3.new(0.44, 0.6, 0.24), base * CFrame.new(side * 0.44, 0.24, front), INK)
		ball(model, if side < 0 then "ShineL" else "ShineR", Vector3.one * 0.16, base * CFrame.new(side * 0.44 + 0.08, 0.38, front - 0.12), WHITE)
		ball(model, if side < 0 then "BlushL" else "BlushR", Vector3.new(0.38, 0.22, 0.12), base * CFrame.new(side * 0.74, -0.08, front + 0.1), BLUSH, 0.2)
		ball(model, if side < 0 then "ArmL" else "ArmR", Vector3.one * 0.7, base * CFrame.new(side * 1.25, -0.35, -0.1), WHITE, 0.08)
	end
	ball(model, "Mouth", Vector3.new(0.22, 0.26, 0.12), base * CFrame.new(0, -0.18, front - 0.02), INK)

	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = LIGHT_RANGE
	light.Brightness = LIGHT_BRIGHTNESS
	light.Shadows = false
	light.Parent = body
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(GLOW)
	sparkles.LightEmission = 0.8
	sparkles.Size = NumberSequence.new(0.25, 0)
	sparkles.Transparency = NumberSequence.new(0.2, 1)
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Rate = 5
	sparkles.Speed = NumberRange.new(0.4, 1)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = body
	label(body)

	local hitbox = ball(model, MansionGhostModel.HitboxName, Vector3.one * CONFIG.TouchRadius * 2, base, WHITE, 1)
	model.PrimaryPart = hitbox
	model:SetAttribute(CONFIG.BaseAttribute, base)
	return model
end

return table.freeze(MansionGhostModel)
