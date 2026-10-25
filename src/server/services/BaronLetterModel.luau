--!strict

-- Carta do Barão: o que os Inocentes coletam no Assassinato no Casarão (no
-- lugar das moedas). Um envelope de pergaminho em pé, com as dobras da aba
-- marcadas, lacrado com um selo de cera vermelha (com respingos) e um
-- brilho dourado discreto de partículas. Tudo ancorado, sem colisão nem
-- raycast; no cliente ela flutua e gira devagar (BaronLetterFloat, pela tag).

local CollectionService = game:GetService("CollectionService")

local TAG = "BaronLetter"
local SIZE = Vector3.new(1.7, 1.15, 0.06)
local COLORS = {
	paper = Color3.fromRGB(236, 222, 186),
	fold = Color3.fromRGB(190, 166, 122),
	wax = Color3.fromRGB(158, 26, 36),
	waxInner = Color3.fromRGB(116, 16, 26),
	sparkle = Color3.fromRGB(255, 224, 150),
}
-- Ponto em que as dobras da aba se encontram (centro do selo).
local FLAP_TIP = Vector2.new(0, -0.08)
local SEAL_DIAMETER = 0.46
local SEAL_INNER_DIAMETER = 0.28
local SEAL_THICKNESS = 0.07
local DRIP_SIZE = 0.12
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local BaronLetterModel = {}

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- Dobra da aba: do canto de cima (`corner`) até a ponta, na face de frente
-- (-Z) do envelope.
local function fold(parent: Instance, body: CFrame, corner: Vector2)
	local delta = FLAP_TIP - corner
	local middle = (corner + FLAP_TIP) / 2
	local angle = math.atan2(delta.Y, delta.X)
	local cframe = body * CFrame.new(middle.X, middle.Y, -SIZE.Z / 2 - 0.01) * CFrame.Angles(0, 0, angle)
	piece(parent, "Fold", Vector3.new(delta.Magnitude, 0.05, 0.02), cframe, COLORS.fold)
end

local function seal(parent: Instance, body: CFrame)
	-- Cilindro deitado na face: o eixo (X da peça) atravessa o envelope.
	local center = body * CFrame.new(FLAP_TIP.X, FLAP_TIP.Y, -SIZE.Z / 2 - SEAL_THICKNESS / 2) * CFrame.Angles(0, math.pi / 2, 0)
	local outer = piece(parent, "Seal", Vector3.new(SEAL_THICKNESS, SEAL_DIAMETER, SEAL_DIAMETER), center, COLORS.wax)
	outer.Shape = Enum.PartType.Cylinder
	local inner = piece(parent, "SealPress", Vector3.new(SEAL_THICKNESS + 0.03, SEAL_INNER_DIAMETER, SEAL_INNER_DIAMETER), center, COLORS.waxInner)
	inner.Shape = Enum.PartType.Cylinder
	-- Respingos de cera em volta do selo.
	for _, offset in ipairs({ Vector2.new(0.24, -0.1), Vector2.new(-0.2, -0.17), Vector2.new(0.05, 0.25) }) do
		local drip = piece(parent, "WaxDrip", Vector3.one * DRIP_SIZE, body * CFrame.new(FLAP_TIP.X + offset.X, FLAP_TIP.Y + offset.Y, -SIZE.Z / 2 - 0.02), COLORS.wax)
		drip.Shape = Enum.PartType.Ball
	end
end

local function sparkle(parent: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(COLORS.sparkle)
	emitter.LightEmission = 0.6
	emitter.Rate = 2
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(0.3, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = parent
end

-- Carta nova com o centro em `cframe` (frente para -Z). O corpo do envelope
-- é a PrimaryPart.
function BaronLetterModel.create(cframe: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "BaronLetter"
	local body = piece(model, "Envelope", SIZE, cframe, COLORS.paper)
	model.PrimaryPart = body
	fold(model, cframe, Vector2.new(-SIZE.X / 2, SIZE.Y / 2))
	fold(model, cframe, Vector2.new(SIZE.X / 2, SIZE.Y / 2))
	seal(model, cframe)
	sparkle(body)
	CollectionService:AddTag(model, TAG)
	model.Parent = parent
	return model
end

BaronLetterModel.TAG = TAG

return table.freeze(BaronLetterModel)
