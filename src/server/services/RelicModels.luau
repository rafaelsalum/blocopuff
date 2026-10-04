--!strict

-- Modelos das relíquias do Casarão (Fase 5C.2): objetos pequenos feitos de
-- peças simples (bonequinho Puff, moeda, chave, retrato, peça de xadrez e a
-- estrela da Relíquia do Dia), com um brilho fraco e o prompt "Pegar".
-- Nada colide nem atrapalha: só a caixa invisível segura o prompt.

local RelicModels = {}

export type Shape = "Key" | "Coin" | "Puff" | "Portrait" | "Chess" | "Daily"

local HITBOX_SIZE = Vector3.new(1.8, 1.8, 1.8)
local PROMPT_DISTANCE = 8
local SPARKLE_COLOR = Color3.fromRGB(255, 236, 170)
local GLOW_RANGE = 5
local GLOW_BRIGHTNESS = 0.7
local EYE_COLOR = Color3.fromRGB(40, 34, 48)
local FRAME_COLOR = Color3.fromRGB(120, 84, 48)
local DAILY_COLOR = Color3.fromRGB(255, 214, 90)

RelicModels.HitboxName = "Hitbox"
RelicModels.PromptName = "PickPrompt"
RelicModels.PromptDistance = PROMPT_DISTANCE

-- Peça decorativa: ancorada, sem colisão, sem toque e fora dos raios.
local function piece(model: Model, name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Cilindro em pé (o eixo do cilindro no Roblox é X).
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local function buildPuff(model: Model, base: CFrame, color: Color3)
	piece(model, "Body", Enum.PartType.Ball, Vector3.one, base * CFrame.new(0, 0.5, 0), color, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Eye", Enum.PartType.Ball, Vector3.one * 0.18, base * CFrame.new(0.18 * side, 0.62, -0.44), EYE_COLOR, Enum.Material.SmoothPlastic)
	end
end

local function buildCoin(model: Model, base: CFrame, color: Color3)
	-- Em pé, de frente, com um aro mais escuro.
	piece(model, "Coin", Enum.PartType.Cylinder, Vector3.new(0.14, 0.9, 0.9), base * CFrame.new(0, 0.46, 0) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.Metal)
	piece(model, "Rim", Enum.PartType.Cylinder, Vector3.new(0.1, 0.96, 0.96), base * CFrame.new(0, 0.46, 0) * CFrame.Angles(0, math.pi / 2, 0), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Metal)
end

local function buildKey(model: Model, base: CFrame, color: Color3)
	-- Deitada no chão: haste, argola e dentes.
	piece(model, "Shaft", Enum.PartType.Block, Vector3.new(0.16, 0.16, 1), base * CFrame.new(0, 0.1, 0.1), color, Enum.Material.Metal)
	piece(model, "Bow", Enum.PartType.Cylinder, Vector3.new(0.16, 0.55, 0.55), base * CFrame.new(0, 0.1, -0.6) * UPRIGHT, color, Enum.Material.Metal)
	piece(model, "Teeth", Enum.PartType.Block, Vector3.new(0.3, 0.16, 0.14), base * CFrame.new(0.14, 0.1, 0.5), color, Enum.Material.Metal)
end

local function buildPortrait(model: Model, base: CFrame, color: Color3)
	-- Encostado, um pouco inclinado para trás.
	local tilt = base * CFrame.new(0, 0.55, 0) * CFrame.Angles(math.rad(12), 0, 0)
	piece(model, "Frame", Enum.PartType.Block, Vector3.new(0.9, 1.1, 0.12), tilt, FRAME_COLOR, Enum.Material.Wood)
	piece(model, "Canvas", Enum.PartType.Block, Vector3.new(0.68, 0.86, 0.04), tilt * CFrame.new(0, 0, -0.07), color, Enum.Material.SmoothPlastic)
end

local function buildChess(model: Model, base: CFrame, color: Color3)
	piece(model, "Base", Enum.PartType.Cylinder, Vector3.new(0.22, 0.62, 0.62), base * CFrame.new(0, 0.11, 0) * UPRIGHT, color, Enum.Material.SmoothPlastic)
	piece(model, "Body", Enum.PartType.Cylinder, Vector3.new(0.6, 0.34, 0.34), base * CFrame.new(0, 0.5, 0) * UPRIGHT, color, Enum.Material.SmoothPlastic)
	piece(model, "Head", Enum.PartType.Ball, Vector3.one * 0.42, base * CFrame.new(0, 0.95, 0), color, Enum.Material.SmoothPlastic)
end

local function buildDaily(model: Model, base: CFrame)
	piece(model, "Core", Enum.PartType.Ball, Vector3.one * 0.8, base * CFrame.new(0, 0.7, 0), DAILY_COLOR, Enum.Material.Neon)
	piece(model, "Ring", Enum.PartType.Cylinder, Vector3.new(0.1, 1.3, 1.3), base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.pi / 4, 0), DAILY_COLOR, Enum.Material.Metal)
	piece(model, "Ring2", Enum.PartType.Cylinder, Vector3.new(0.1, 1.3, 1.3), base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, -math.pi / 4, 0), DAILY_COLOR, Enum.Material.Metal)
end

local BUILDERS: { [Shape]: (model: Model, base: CFrame, color: Color3) -> () } = {
	Puff = buildPuff,
	Coin = buildCoin,
	Key = buildKey,
	Portrait = buildPortrait,
	Chess = buildChess,
	Daily = function(model, base, _color)
		buildDaily(model, base)
	end,
}

-- Brilho fraco de perto (luz curta e poucas faíscas).
local function addGlow(hitbox: BasePart, daily: boolean)
	local light = Instance.new("PointLight")
	light.Color = SPARKLE_COLOR
	light.Range = if daily then GLOW_RANGE * 1.6 else GLOW_RANGE
	light.Brightness = if daily then GLOW_BRIGHTNESS * 1.6 else GLOW_BRIGHTNESS
	light.Shadows = false
	light.Parent = hitbox
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(SPARKLE_COLOR)
	sparkles.LightEmission = 1
	sparkles.Rate = if daily then 6 else 2
	sparkles.Lifetime = NumberRange.new(0.8, 1.3)
	sparkles.Speed = NumberRange.new(0.3, 0.8)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Parent = hitbox
end

-- Monta a relíquia com a base em `base` (no topo da superfície onde está).
-- `name` aparece no prompt (o cliente traduz). Atributos e etiqueta entram
-- antes de ir para o mundo (o cliente sempre vê os dois juntos).
function RelicModels.build(
	parent: Instance,
	modelName: string,
	shape: Shape,
	color: Color3,
	base: CFrame,
	name: string,
	attributes: { [string]: any },
	tag: string
): Model
	local model = Instance.new("Model")
	model.Name = modelName
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local hitbox = Instance.new("Part")
	hitbox.Name = RelicModels.HitboxName
	hitbox.Size = HITBOX_SIZE
	hitbox.CFrame = base * CFrame.new(0, HITBOX_SIZE.Y / 2, 0)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = false
	hitbox.CastShadow = false
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	BUILDERS[shape](model, base, color)
	addGlow(hitbox, shape == "Daily")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = RelicModels.PromptName
	prompt.ActionText = "Pegar"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = hitbox

	for key, value in pairs(attributes) do
		model:SetAttribute(key, value)
	end
	model:AddTag(tag)
	model.Parent = parent
	return model
end

return table.freeze(RelicModels)
