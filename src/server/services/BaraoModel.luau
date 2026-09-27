--!strict

-- Modelo do Barão feito de peças nativas: vira-lata caramelo de orelhas
-- caídas, com camisa verde e amarela e um losango azul de cada lado. Todas
-- as peças são ancoradas e sem colisão; o BaraoService move o modelo com
-- PivotTo. O pivô fica no chão, no meio das patas, e a frente é -Z.

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

-- Nome da peça que carrega os sons (a do corpo).
BaraoModel.SoundPartName = "Body"

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Size = size
	instance.CFrame = cframe
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
	instance.Parent = model
	return instance
end

function BaraoModel.build(): Model
	local model = Instance.new("Model")
	model.Name = "Barao"

	local body = part(model, "Body", Vector3.new(1.7, 1.5, 3), CFrame.new(0, 2.05, 0), CARAMEL)
	part(model, "Belly", Vector3.new(1.4, 0.3, 2.2), CFrame.new(0, 1.3, 0.1), CARAMEL_LIGHT)

	-- Camisa do Brasil: verde com faixa amarela e losango azul nas laterais.
	part(model, "Shirt", Vector3.new(1.85, 1.62, 1.9), CFrame.new(0, 2.07, -0.35), SHIRT_GREEN, Enum.Material.Fabric)
	part(model, "ShirtBand", Vector3.new(1.9, 0.32, 1.95), CFrame.new(0, 2.45, -0.35), SHIRT_YELLOW, Enum.Material.Fabric)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "ShirtDiamond", Vector3.new(0.08, 0.55, 0.55), CFrame.new(side * 0.95, 1.95, -0.35) * CFrame.Angles(math.rad(45), 0, 0), SHIRT_YELLOW, Enum.Material.Fabric)
		part(model, "ShirtGlobe", Vector3.new(0.1, 0.34, 0.34), CFrame.new(side * 0.97, 1.95, -0.35) * CFrame.Angles(0, 0, math.rad(90)), SHIRT_BLUE, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end

	-- Cabeça.
	part(model, "Head", Vector3.new(1.4, 1.3, 1.4), CFrame.new(0, 3.05, -1.85), CARAMEL)
	part(model, "Snout", Vector3.new(0.8, 0.6, 0.75), CFrame.new(0, 2.78, -2.75), CARAMEL_LIGHT)
	part(model, "Nose", Vector3.new(0.36, 0.26, 0.2), CFrame.new(0, 2.98, -3.12), BLACK)
	part(model, "Tongue", Vector3.new(0.3, 0.06, 0.4), CFrame.new(0, 2.45, -2.95) * CFrame.Angles(math.rad(-20), 0, 0), TONGUE)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Eye", Vector3.new(0.24, 0.24, 0.24), CFrame.new(side * 0.36, 3.3, -2.52), BLACK, nil, Enum.PartType.Ball)
		part(model, "Brow", Vector3.new(0.36, 0.1, 0.1), CFrame.new(side * 0.36, 3.5, -2.56) * CFrame.Angles(0, 0, math.rad(side * -12)), CARAMEL_DARK)
		part(model, "Ear", Vector3.new(0.3, 0.75, 0.5), CFrame.new(side * 0.8, 3.35, -1.75) * CFrame.Angles(0, 0, math.rad(side * 18)), CARAMEL_DARK)
	end

	-- Patas.
	for _, x in ipairs({ -0.55, 0.55 }) do
		for _, z in ipairs({ -1.05, 1.05 }) do
			part(model, "Leg", Vector3.new(0.45, 1.3, 0.45), CFrame.new(x, 0.75, z), CARAMEL)
			part(model, "Paw", Vector3.new(0.52, 0.2, 0.6), CFrame.new(x, 0.1, z - 0.05), WHITE)
		end
	end

	-- Rabo pra cima.
	part(model, "Tail", Vector3.new(0.3, 0.3, 1.1), CFrame.new(0, 2.8, 1.8) * CFrame.Angles(math.rad(-40), 0, 0), CARAMEL)
	part(model, "TailTip", Vector3.new(0.32, 0.32, 0.3), CFrame.new(0, 3.18, 2.2), WHITE)

	model.PrimaryPart = body
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

return table.freeze(BaraoModel)
