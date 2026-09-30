--!strict

-- Modelo do Barão feito de peças nativas: vira-lata caramelo de orelhas
-- caídas, com camisa verde e amarela e um losango azul de cada lado. Todas
-- as peças são ancoradas e sem colisão. O pivô fica no chão, no meio das
-- patas, e a frente é -Z.
--
-- Cada peça tem o atributo "Bone" (corpo, cabeça, orelhas, língua, rabo e
-- as quatro patas) para o BaraoAnimator (cliente) girar cada parte em
-- torno do seu ponto de articulação (`BaraoModel.pivot`). `scale` aumenta
-- o modelo inteiro; o valor fica no atributo "BaraoScale".

export type Bone = "Body" | "Head" | "EarL" | "EarR" | "Tongue" | "Tail" | "LegFL" | "LegFR" | "LegBL" | "LegBR"

local BaraoModel = {}

local CARAMEL = Color3.fromRGB(201, 136, 64)
local CARAMEL_LIGHT = Color3.fromRGB(232, 184, 120)
local CARAMEL_DARK = Color3.fromRGB(150, 94, 40)
local WHITE = Color3.fromRGB(245, 240, 230)
local BLACK = Color3.fromRGB(28, 24, 22)
local TONGUE = Color3.fromRGB(236, 110, 130)
local SHIRT_GREEN = Color3.fromRGB(0, 150, 64)
local SHIRT_YELLOW = Color3.fromRGB(255, 214, 0)
local SHIRT_BLUE = Color3.fromRGB(30, 60, 170)

-- Pontos de articulação no espaço do modelo, em tamanho 1 (multiplique
-- pelo "BaraoScale" do modelo).
local PIVOTS: { [Bone]: Vector3 } = table.freeze({
	Body = Vector3.new(0, 2.05, 0),
	Head = Vector3.new(0, 2.75, -1.35),
	EarL = Vector3.new(-0.7, 3.65, -1.75),
	EarR = Vector3.new(0.7, 3.65, -1.75),
	Tongue = Vector3.new(0, 2.5, -2.75),
	Tail = Vector3.new(0, 2.55, 1.45),
	LegFL = Vector3.new(-0.55, 1.4, -1.05),
	LegFR = Vector3.new(0.55, 1.4, -1.05),
	LegBL = Vector3.new(-0.55, 1.4, 1.05),
	LegBR = Vector3.new(0.55, 1.4, 1.05),
})

-- Nome da peça que carrega os sons (a do corpo).
BaraoModel.SoundPartName = "Body"
BaraoModel.ScaleAttribute = "BaraoScale"
BaraoModel.BoneAttribute = "Bone"
-- Quanto tempo o Barão do Jardim fica feliz depois de um carinho.
BaraoModel.FriendlyHappySeconds = 2.6

function BaraoModel.pivot(bone: Bone, scale: number): Vector3
	return PIVOTS[bone] * scale
end

function BaraoModel.build(scale: number?): Model
	local size = scale or 1
	local model = Instance.new("Model")
	model.Name = "Barao"
	model:SetAttribute(BaraoModel.ScaleAttribute, size)

	local function part(bone: Bone, name: string, partSize: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local instance = Instance.new("Part")
		instance.Name = name
		instance.Size = partSize * size
		instance.CFrame = CFrame.new(cframe.Position * size) * cframe.Rotation
		instance.Color = color
		instance.Material = material or Enum.Material.SmoothPlastic
		instance.Shape = shape or Enum.PartType.Block
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanQuery = false
		instance.CanTouch = false
		instance.CastShadow = true
		instance.TopSurface = Enum.SurfaceType.Smooth
		instance.BottomSurface = Enum.SurfaceType.Smooth
		instance:SetAttribute(BaraoModel.BoneAttribute, bone)
		instance.Parent = model
		return instance
	end

	part("Body", "Body", Vector3.new(1.7, 1.5, 3), CFrame.new(0, 2.05, 0), CARAMEL)
	part("Body", "Belly", Vector3.new(1.4, 0.3, 2.2), CFrame.new(0, 1.3, 0.1), CARAMEL_LIGHT)

	-- Camisa do Brasil: verde com faixa amarela e losango azul nas laterais.
	part("Body", "Shirt", Vector3.new(1.85, 1.62, 1.9), CFrame.new(0, 2.07, -0.35), SHIRT_GREEN, Enum.Material.Fabric)
	part("Body", "ShirtBand", Vector3.new(1.9, 0.32, 1.95), CFrame.new(0, 2.45, -0.35), SHIRT_YELLOW, Enum.Material.Fabric)
	for _, side in ipairs({ -1, 1 }) do
		part("Body", "ShirtDiamond", Vector3.new(0.08, 0.55, 0.55), CFrame.new(side * 0.95, 1.95, -0.35) * CFrame.Angles(math.rad(45), 0, 0), SHIRT_YELLOW, Enum.Material.Fabric)
		part("Body", "ShirtGlobe", Vector3.new(0.1, 0.34, 0.34), CFrame.new(side * 0.97, 1.95, -0.35) * CFrame.Angles(0, 0, math.rad(90)), SHIRT_BLUE, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end

	-- Cabeça.
	part("Head", "Head", Vector3.new(1.4, 1.3, 1.4), CFrame.new(0, 3.05, -1.85), CARAMEL)
	part("Head", "Snout", Vector3.new(0.8, 0.6, 0.75), CFrame.new(0, 2.78, -2.75), CARAMEL_LIGHT)
	part("Head", "Nose", Vector3.new(0.36, 0.26, 0.2), CFrame.new(0, 2.98, -3.12), BLACK)
	part("Tongue", "Tongue", Vector3.new(0.3, 0.06, 0.4), CFrame.new(0, 2.45, -2.95) * CFrame.Angles(math.rad(-20), 0, 0), TONGUE)
	for _, side in ipairs({ -1, 1 }) do
		part("Head", "Eye", Vector3.new(0.24, 0.24, 0.24), CFrame.new(side * 0.36, 3.3, -2.52), BLACK, nil, Enum.PartType.Ball)
		part("Head", "Brow", Vector3.new(0.36, 0.1, 0.1), CFrame.new(side * 0.36, 3.5, -2.56) * CFrame.Angles(0, 0, math.rad(side * -12)), CARAMEL_DARK)
		part(if side < 0 then "EarL" else "EarR", "Ear", Vector3.new(0.3, 0.75, 0.5), CFrame.new(side * 0.8, 3.35, -1.75) * CFrame.Angles(0, 0, math.rad(side * 18)), CARAMEL_DARK)
	end

	-- Patas.
	for _, x in ipairs({ -0.55, 0.55 }) do
		for _, z in ipairs({ -1.05, 1.05 }) do
			local bone: Bone = if z < 0 then (if x < 0 then "LegFL" else "LegFR") else (if x < 0 then "LegBL" else "LegBR")
			part(bone, "Leg", Vector3.new(0.45, 1.3, 0.45), CFrame.new(x, 0.75, z), CARAMEL)
			part(bone, "Paw", Vector3.new(0.52, 0.2, 0.6), CFrame.new(x, 0.1, z - 0.05), WHITE)
		end
	end

	-- Rabo pra cima.
	part("Tail", "Tail", Vector3.new(0.3, 0.3, 1.1), CFrame.new(0, 2.8, 1.8) * CFrame.Angles(math.rad(-40), 0, 0), CARAMEL)
	part("Tail", "TailTip", Vector3.new(0.32, 0.32, 0.3), CFrame.new(0, 3.18, 2.2), WHITE)

	-- Sem PrimaryPart: assim o pivô é o WorldPivot (no chão, entre as
	-- patas), e não o centro do corpo.
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

return table.freeze(BaraoModel)
