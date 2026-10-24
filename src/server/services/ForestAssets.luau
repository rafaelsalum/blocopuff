--!strict

-- Pinheiros da floresta do lado de fora, do pacote gratuito "Ponderosa Pine
-- Tree Pack Realistic Tree Nature" (130515502281374, de Letaij) da Creator
-- Store. Cada árvore é descrita só pelas malhas (tronco e copa) e pela
-- textura de cor de cada uma, e recriada por código
-- (AssetService:CreateMeshPartAsync). O resto que vinha no modelo fica de
-- fora. Se uma malha não carregar, aquela parte da árvore não aparece.

local AssetService = game:GetService("AssetService")

type PartSpec = {
	mesh: string,
	texture: string,
	size: Vector3,
	-- Posição e giro (radianos, XYZ) em relação ao pé do tronco.
	offset: Vector3,
	rotation: Vector3,
}

local function P(mesh: number, texture: number, size: Vector3, offset: Vector3, rotation: Vector3): PartSpec
	return table.freeze({
		mesh = `rbxassetid://{mesh}`,
		texture = `rbxassetid://{texture}`,
		size = size,
		offset = offset,
		rotation = rotation,
	})
end

local V = Vector3.new
local QUARTER = 1.5708
local HALF = 3.1416

local VARIANTS: { { PartSpec } } = {
	{
		P(120615938093308, 122385008811017, V(6.10, 6.12, 28.69), V(-0.15, 15.06, -0.05), V(-QUARTER, 0, QUARTER)),
		P(113638336870612, 139378529098819, V(5.78, 5.78, 29.17), V(0, 14.59, 0), V(-QUARTER, 0, QUARTER)),
		P(96055897935026, 122385008811017, V(1.92, 3.03, 9.15), V(-0.13, 11.31, -0.66), V(-QUARTER, 0, QUARTER)),
	},
	{
		P(107431480752613, 139378529098819, V(7.84, 7.85, 23.79), V(0, 11.89, 0), V(-QUARTER, 0, QUARTER)),
		P(90116814867758, 122385008811017, V(8.72, 8.68, 22.11), V(0.28, 13.44, -0.12), V(-QUARTER, 0, QUARTER)),
	},
	{
		P(135974560430452, 122385008811017, V(8.67, 8.69, 22.92), V(-0.32, 13.04, 0.14), V(-QUARTER, 0, QUARTER)),
		P(74030110324292, 139378529098819, V(5.76, 5.74, 23.79), V(0, 11.89, 0), V(-QUARTER, 0, QUARTER)),
	},
	{
		P(87765311815033, 78447927211856, V(5.54, 3.59, 23.79), V(0, 11.89, 0), V(-QUARTER, 0, -HALF)),
		P(98416655622270, 122385008811017, V(8.93, 9.11, 22.92), V(0.57, 13.04, 0.42), V(-QUARTER, 0, -HALF)),
	},
	{
		P(107129739355437, 122385008811017, V(6.51, 6.41, 26.31), V(0.08, 13.66, -0.02), V(-QUARTER, 0, QUARTER)),
		P(81200861466286, 84377568721955, V(4.65, 4.66, 26.04), V(0, 13.02, 0), V(-QUARTER, 0, QUARTER)),
	},
	{
		P(98796039687733, 122385008811017, V(10.62, 10.14, 25.62), V(-0.07, 13.97, -0.13), V(-QUARTER, 0, QUARTER)),
		P(116882934598454, 84377568721955, V(9.29, 9.43, 26.02), V(0, 13.01, 0), V(-QUARTER, 0, QUARTER)),
	},
	{
		P(118470689208046, 122385008811017, V(6.06, 6.13, 26.56), V(-0.04, 13.53, -0.07), V(-QUARTER, 0, QUARTER)),
		P(127026121555632, 84377568721955, V(4.65, 4.66, 26.04), V(0, 13.02, 0), V(-QUARTER, 0, QUARTER)),
	},
	{
		P(76178437725298, 93374260049097, V(6.10, 6.59, 25.43), V(0, 12.72, 0), V(-QUARTER, 0, -HALF)),
		P(74592415499646, 122385008811017, V(7.86, 7.90, 25.30), V(0.21, 13.54, -0.29), V(-QUARTER, 0, -HALF)),
	},
	{
		P(127163432661708, 93102187834720, V(1.78, 1.71, 23.00), V(0, 11.50, 0), V(-QUARTER, 0, 0)),
		P(138559907629675, 122385008811017, V(8.68, 8.80, 21.05), V(-0.03, 13.08, -0.23), V(-QUARTER, 0, 0)),
	},
	{
		P(89614960810760, 84377568721955, V(5.88, 5.90, 26.03), V(0, 13.01, 0), V(-QUARTER, 0, QUARTER)),
		P(97824257482781, 122385008811017, V(9.04, 8.84, 25.06), V(-0.38, 14.26, 0.19), V(-QUARTER, 0, QUARTER)),
	},
	{
		P(84353089448531, 122385008811017, V(8.33, 8.93, 25.69), V(-0.17, 13.94, 0.38), V(-QUARTER, 0, QUARTER)),
		P(110402428240877, 84377568721955, V(6.26, 6.19, 26.03), V(0, 13.01, 0), V(-QUARTER, 0, QUARTER)),
	},
}

local ForestAssets = {}

ForestAssets.VARIANT_COUNT = #VARIANTS

local templates: { [string]: MeshPart | false } = {}

local function template(mesh: string): MeshPart?
	local cached = templates[mesh]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(mesh)
	end)
	if not ok then
		warn(`[ForestAssets] {mesh} unavailable: {result}`)
		templates[mesh] = false
		return nil
	end
	local meshPart: MeshPart = result
	meshPart.Anchored = true
	meshPart.CanCollide = false
	meshPart.CanQuery = false
	meshPart.CanTouch = false
	templates[mesh] = meshPart
	return meshPart
end

-- Carrega as malhas de todas as árvores antes de plantar (espera).
function ForestAssets.preload()
	for _, variant in ipairs(VARIANTS) do
		for _, spec in ipairs(variant) do
			template(spec.mesh)
		end
	end
end

-- Planta o pinheiro `variant` com o pé em `base` (já girado), `scale` vezes
-- o tamanho do modelo. Enfeite: não colide.
function ForestAssets.place(parent: Instance, variant: number, base: CFrame, scale: number, shadow: boolean)
	for _, spec in ipairs(VARIANTS[variant]) do
		local source = template(spec.mesh)
		if source ~= nil then
			local copy = source:Clone()
			copy.Size = spec.size * scale
			copy.CFrame = base * CFrame.new(spec.offset * scale) * CFrame.fromEulerAnglesXYZ(spec.rotation.X, spec.rotation.Y, spec.rotation.Z)
			copy.TextureID = spec.texture
			copy.CastShadow = shadow
			copy.Parent = parent
		end
	end
end

return table.freeze(ForestAssets)
