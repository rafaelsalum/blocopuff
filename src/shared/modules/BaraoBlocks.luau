--!strict

-- Barão de reserva, feito de peças nativas (usado só se o modelo 3D em
-- ReplicatedStorage.Shared.assets.BaraoMesh não estiver disponível), no
-- visual da capa do jogo:
-- vira-lata caramelo de cabeça grande e quadrada, focinho e bochechas
-- claras, mancha clara subindo pela testa, olhos grandes com brilho,
-- orelhas grandes caídas, sorriso aberto com a língua de fora, rabo peludo
-- de ponta clara e a camisa da seleção: verde com listras amarelas e a
-- bandeira do Brasil nas costas e nos lados.
--
-- Mesmas convenções do modelo 3D: pivô no chão, frente em -Z e o
-- atributo "Bone" em cada peça.

type Bone = "Body" | "Head" | "EarL" | "EarR" | "Tongue" | "Tail" | "LegFL" | "LegFR" | "LegBL" | "LegBR"

local BaraoBlocks = {}

local BONE_ATTRIBUTE = "Bone"

local CARAMEL = Color3.fromRGB(198, 120, 58)
local CARAMEL_DARK = Color3.fromRGB(150, 82, 38)
local EAR_BROWN = Color3.fromRGB(128, 60, 32)
local CREAM = Color3.fromRGB(236, 196, 146)
local CREAM_LIGHT = Color3.fromRGB(246, 222, 186)
local BLACK = Color3.fromRGB(24, 20, 20)
local WHITE = Color3.fromRGB(255, 255, 255)
local MOUTH = Color3.fromRGB(96, 28, 34)
local TONGUE = Color3.fromRGB(240, 108, 138)
local SHIRT_GREEN = Color3.fromRGB(0, 148, 62)
local SHIRT_YELLOW = Color3.fromRGB(255, 212, 0)
local FLAG_GREEN = Color3.fromRGB(0, 156, 59)
local FLAG_YELLOW = Color3.fromRGB(255, 223, 0)
local FLAG_BLUE = Color3.fromRGB(0, 39, 118)

-- Pontos de articulação no espaço do modelo, em tamanho 1 (multiplique
-- pelo "BaraoScale" do modelo).
local PIVOTS: { [Bone]: Vector3 } = table.freeze({
	Body = Vector3.new(0, 1.55, 0),
	Head = Vector3.new(0, 2.2, -1.0),
	EarL = Vector3.new(-0.86, 3.45, -1.45),
	EarR = Vector3.new(0.86, 3.45, -1.45),
	Tongue = Vector3.new(0, 2.2, -2.62),
	Tail = Vector3.new(0, 1.85, 1.15),
	LegFL = Vector3.new(-0.5, 1.15, -0.85),
	LegFR = Vector3.new(0.5, 1.15, -0.85),
	LegBL = Vector3.new(-0.5, 1.15, 0.85),
	LegBR = Vector3.new(0.5, 1.15, 0.85),
})

BaraoBlocks.pivots = PIVOTS

-- Peças do Barão de blocos, já no tamanho `size`, dentro de `model`.
function BaraoBlocks.build(model: Model, size: number)
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
		instance:SetAttribute(BONE_ATTRIBUTE, bone)
		instance.Parent = model
		return instance
	end

	-- Bandeira do Brasil num plano: `origin` no centro, `right`/`up` no
	-- plano (a face fica para `right × up`, fora da camisa). Retângulo
	-- verde, losango amarelo e o círculo azul com a faixa branca.
	local function flag(origin: Vector3, right: Vector3, up: Vector3, width: number, height: number)
		local out = right:Cross(up)
		part("Body", "FlagGreen", Vector3.new(width, height, 0.03), CFrame.fromMatrix(origin, right, up), FLAG_GREEN, Enum.Material.Fabric)
		local diamond = height * 0.62
		part(
			"Body",
			"FlagDiamond",
			Vector3.new(diamond, diamond, 0.03),
			CFrame.fromMatrix(origin + (out * 0.015), right, up) * CFrame.Angles(0, 0, math.rad(45)),
			FLAG_YELLOW,
			Enum.Material.Fabric
		)
		local globe = height * 0.46
		part("Body", "FlagGlobe", Vector3.new(0.03, globe, globe), CFrame.fromMatrix(origin + (out * 0.03), out, up), FLAG_BLUE, Enum.Material.Fabric, Enum.PartType.Cylinder)
		part(
			"Body",
			"FlagBand",
			Vector3.new(globe * 0.95, globe * 0.14, 0.03),
			CFrame.fromMatrix(origin + (out * 0.045), right, up) * CFrame.Angles(0, 0, math.rad(-14)),
			WHITE,
			Enum.Material.Fabric
		)
	end

	-- Corpo e camisa da seleção.
	part("Body", "Body", Vector3.new(1.5, 1.2, 2.3), CFrame.new(0, 1.55, 0.05), CARAMEL)
	part("Body", "Belly", Vector3.new(1.2, 0.2, 1.8), CFrame.new(0, 0.95, 0.1), CREAM)
	part("Body", "Shirt", Vector3.new(1.62, 1.3, 1.75), CFrame.new(0, 1.58, -0.28), SHIRT_GREEN, Enum.Material.Fabric)
	part("Body", "ShirtStripe", Vector3.new(1.66, 0.14, 1.79), CFrame.new(0, 1.3, -0.28), SHIRT_YELLOW, Enum.Material.Fabric)
	part("Body", "ShirtStripe", Vector3.new(1.66, 0.14, 1.79), CFrame.new(0, 1.9, -0.28), SHIRT_YELLOW, Enum.Material.Fabric)
	part("Body", "ShirtCollar", Vector3.new(1.2, 0.2, 0.3), CFrame.new(0, 2.12, -1.1), SHIRT_YELLOW, Enum.Material.Fabric)
	-- Bandeira nas costas (quem vê de cima, na câmera de terceira pessoa) e
	-- nos dois lados.
	flag(Vector3.new(0, 2.25, -0.3), Vector3.xAxis, -Vector3.zAxis, 0.95, 0.66)
	flag(Vector3.new(0.85, 1.6, -0.3), -Vector3.zAxis, Vector3.yAxis, 0.95, 0.62)
	flag(Vector3.new(-0.85, 1.6, -0.3), Vector3.zAxis, Vector3.yAxis, 0.95, 0.62)

	-- Cabeça grande e quadrada, caramelo, com o rosto claro na frente.
	local faceZ = -2.2
	part("Head", "Head", Vector3.new(1.72, 1.5, 1.5), CFrame.new(0, 2.74, -1.45), CARAMEL)
	part("Head", "HeadTop", Vector3.new(1.74, 0.3, 1.52), CFrame.new(0, 3.35, -1.45), CARAMEL_DARK)
	part("Head", "Face", Vector3.new(1.4, 0.78, 0.06), CFrame.new(0, 2.42, faceZ), CREAM)
	part("Head", "Blaze", Vector3.new(0.32, 0.8, 0.06), CFrame.new(0, 3.05, faceZ), CREAM)
	part("Head", "BlazeTop", Vector3.new(0.32, 0.06, 0.95), CFrame.new(0, 3.52, -1.72), CREAM)
	part("Head", "Muzzle", Vector3.new(0.9, 0.52, 0.42), CFrame.new(0, 2.42, -2.4), CREAM_LIGHT)
	part("Head", "Nose", Vector3.new(0.44, 0.3, 0.2), CFrame.new(0, 2.62, -2.66), BLACK)
	part("Head", "Mouth", Vector3.new(0.62, 0.2, 0.05), CFrame.new(0, 2.2, -2.62), MOUTH)
	part("Tongue", "Tongue", Vector3.new(0.32, 0.07, 0.5), CFrame.new(0, 2.08, -2.78) * CFrame.Angles(math.rad(-38), 0, 0), TONGUE)
	for _, side in ipairs({ -1, 1 }) do
		part("Head", "Eye", Vector3.new(0.36, 0.36, 0.36), CFrame.new(side * 0.42, 2.96, faceZ - 0.02), BLACK, nil, Enum.PartType.Ball)
		part("Head", "EyeShine", Vector3.new(0.11, 0.11, 0.11), CFrame.new((side * 0.42) + 0.08, 3.04, faceZ - 0.2), WHITE, Enum.Material.Neon, Enum.PartType.Ball)
		part(if side < 0 then "EarL" else "EarR", "Ear", Vector3.new(0.3, 1.4, 0.85), CFrame.new(side * 1.0, 2.8, -1.45) * CFrame.Angles(0, 0, math.rad(side * 10)), EAR_BROWN)
	end

	-- Patas curtas, com as pontas claras.
	for _, x in ipairs({ -0.5, 0.5 }) do
		for _, z in ipairs({ -0.85, 0.85 }) do
			local bone: Bone = if z < 0 then (if x < 0 then "LegFL" else "LegFR") else (if x < 0 then "LegBL" else "LegBR")
			part(bone, "Leg", Vector3.new(0.46, 1.05, 0.46), CFrame.new(x, 0.65, z), CARAMEL)
			part(bone, "Paw", Vector3.new(0.52, 0.2, 0.6), CFrame.new(x, 0.1, z - 0.05), CREAM)
			if z < 0 then
				-- Manga da camisa nas patas da frente.
				part(bone, "Sleeve", Vector3.new(0.54, 0.16, 0.54), CFrame.new(x, 1.08, z), SHIRT_YELLOW, Enum.Material.Fabric)
			end
		end
	end

	-- Rabo peludo, pra cima, com a ponta clara.
	part("Tail", "Tail", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 1.95, 1.3), CARAMEL, nil, Enum.PartType.Ball)
	part("Tail", "Tail", Vector3.new(0.52, 0.52, 0.52), CFrame.new(0, 2.32, 1.52), CARAMEL, nil, Enum.PartType.Ball)
	part("Tail", "TailTip", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.72, 1.58), CREAM_LIGHT, nil, Enum.PartType.Ball)
end

return table.freeze(BaraoBlocks)
