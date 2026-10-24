--!strict

-- Peças dos obstáculos da Corrida da Torre do Relógio (Fase 5F.3): barril,
-- caldeirão de poção (rola de lado, com a boca verde borbulhando),
-- engrenagem de latão do mecanismo do relógio, livro voador e o ponteiro
-- gigante. Tudo ancorado e sem colisão: quem decide o acerto é o servidor,
-- pela conta. Cada modelo tem a peça principal (PrimaryPart) no centro.

local HazardProps = {}

local IRON = Color3.fromRGB(42, 42, 48)
local BRASS = Color3.fromRGB(186, 146, 70)
local POTION = Color3.fromRGB(110, 230, 120)
local HAND_IRON = Color3.fromRGB(30, 30, 36)
local GOLD = Color3.fromRGB(214, 172, 74)
local BOOK_COVERS = {
	Color3.fromRGB(122, 28, 40),
	Color3.fromRGB(32, 70, 120),
	Color3.fromRGB(40, 96, 56),
	Color3.fromRGB(96, 54, 120),
}
local PAGES = Color3.fromRGB(236, 226, 196)
local GEAR_TEETH = 10

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function model(name: string): Model
	local newModel = Instance.new("Model")
	newModel.Name = name
	return newModel
end

-- Barril deitado: o eixo (X) fica atravessado na rampa.
function HazardProps.barrel(radius: number): Model
	local barrel = model("Barrel")
	local body = piece(barrel, "Body", Vector3.new(4, radius * 2, radius * 2), CFrame.new(), Color3.fromRGB(122, 78, 44), Enum.Material.Wood)
	body.Shape = Enum.PartType.Cylinder
	for _, side in ipairs({ -1, 1 }) do
		local hoop = piece(barrel, "Hoop", Vector3.new(0.4, radius * 2 + 0.2, radius * 2 + 0.2), CFrame.new(side * 1.3, 0, 0), IRON, Enum.Material.Metal)
		hoop.Shape = Enum.PartType.Cylinder
	end
	barrel.PrimaryPart = body
	return barrel
end

-- Caldeirão deitado, rolando: o eixo (X) atravessado na rampa, a boca verde
-- numa ponta.
function HazardProps.cauldron(radius: number): Model
	local cauldron = model("Cauldron")
	local length = radius * 1.6
	local body = piece(cauldron, "Body", Vector3.new(length, radius * 2, radius * 2), CFrame.new(), IRON, Enum.Material.Metal)
	body.Shape = Enum.PartType.Cylinder
	local rim = piece(cauldron, "Rim", Vector3.new(0.5, radius * 2 + 0.6, radius * 2 + 0.6), CFrame.new(length / 2, 0, 0), IRON, Enum.Material.Metal)
	rim.Shape = Enum.PartType.Cylinder
	local mouth = piece(cauldron, "Potion", Vector3.new(0.2, radius * 1.6, radius * 1.6), CFrame.new(length / 2 + 0.3, 0, 0), POTION, Enum.Material.Neon)
	mouth.Shape = Enum.PartType.Cylinder
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(POTION)
	bubbles.LightEmission = 0.6
	bubbles.Size = NumberSequence.new(0.6, 0)
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Lifetime = NumberRange.new(0.6, 1)
	bubbles.Rate = 18
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.SpreadAngle = Vector2.new(30, 30)
	bubbles.EmissionDirection = Enum.NormalId.Right
	bubbles.Parent = mouth
	local light = Instance.new("PointLight")
	light.Color = POTION
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = mouth
	cauldron.PrimaryPart = body
	return cauldron
end

-- Engrenagem de pé (roda na vertical): o eixo (X) é o da roda.
function HazardProps.gear(radius: number): Model
	local gear = model("Gear")
	local wheel = piece(gear, "Wheel", Vector3.new(1, radius * 2, radius * 2), CFrame.new(), BRASS, Enum.Material.Metal)
	wheel.Shape = Enum.PartType.Cylinder
	local hub = piece(gear, "Hub", Vector3.new(1.4, radius * 0.6, radius * 0.6), CFrame.new(), IRON, Enum.Material.Metal)
	hub.Shape = Enum.PartType.Cylinder
	for index = 1, GEAR_TEETH do
		local angle = index * 2 * math.pi / GEAR_TEETH
		local offset = CFrame.Angles(angle, 0, 0) * CFrame.new(0, radius + 0.45, 0)
		piece(gear, "Tooth", Vector3.new(1, 1, 1.1), offset, BRASS, Enum.Material.Metal)
	end
	gear.PrimaryPart = wheel
	return gear
end

-- Livro aberto, batendo as capas: a lombada no eixo Z.
function HazardProps.book(random: Random): Model
	local book = model("Book")
	local cover = BOOK_COVERS[random:NextInteger(1, #BOOK_COVERS)]
	local pages = piece(book, "Pages", Vector3.new(1.6, 0.35, 1.2), CFrame.new(), PAGES, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		piece(book, "Cover", Vector3.new(0.9, 0.12, 1.3), CFrame.new(side * 0.45, 0.25, 0) * CFrame.Angles(0, 0, side * math.rad(-25)), cover, Enum.Material.Fabric)
	end
	book.PrimaryPart = pages
	return book
end

-- Ponteiro gigante deitado: o comprimento no eixo X (a ponta em +X).
function HazardProps.clockHand(length: number, height: number): Model
	local hand = model("ClockHand")
	local bar = piece(hand, "Bar", Vector3.new(length, height, 1.6), CFrame.new(), HAND_IRON, Enum.Material.Metal)
	local tip = piece(hand, "Tip", Vector3.new(3, height, 3), CFrame.new(length / 2 - 0.5, 0, 0) * CFrame.Angles(0, math.rad(45), 0), GOLD, Enum.Material.Metal)
	tip.Size = Vector3.new(2.6, height + 0.1, 2.6)
	local ring = piece(hand, "Ring", Vector3.new(height + 0.1, 3.2, 3.2), CFrame.new(length * 0.15, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal)
	ring.Shape = Enum.PartType.Cylinder
	hand.PrimaryPart = bar
	return hand
end

return table.freeze(HazardProps)
