--!strict

-- Modelos da Creator Store usados na Torre do Relógio Encantada (Fase 5F.2),
-- descritos só pela malha e pela textura e recriados por código
-- (AssetService:CreateMeshPartAsync). Scripts, interfaces e restrições que
-- vinham junto com os modelos ficam de fora. Se uma malha não carregar, o
-- enfeite simplesmente não aparece.

local AssetService = game:GetService("AssetService")

export type AssetSpec = {
	mesh: string,
	texture: string?,
	-- Cor quando não há textura (ou para tingir a textura).
	color: Color3?,
	material: Enum.Material?,
}

local TowerAssets = {}

TowerAssets.SPECS = table.freeze({
	-- "No Texture Gryphon" (14552944954): sem textura, vira estátua de pedra.
	Gargoyle = table.freeze({ mesh = "rbxassetid://14552944868", color = Color3.fromRGB(118, 120, 128), material = Enum.Material.Slate }),
	-- "Torch" (16156315992).
	Torch = table.freeze({ mesh = "rbxassetid://1364430076", texture = "rbxassetid://1364418796" }),
	-- "Tree_bare_large" (76384756113288): árvore seca, casca escura.
	BareTree = table.freeze({ mesh = "rbxassetid://1202490600", color = Color3.fromRGB(58, 46, 40), material = Enum.Material.Wood }),
	-- Árvore retorcida com textura (133095802178542).
	TwistedTree = table.freeze({ mesh = "rbxassetid://740991432", texture = "rbxassetid://740989141" }),
	-- "Candle with no flame" (1949604157).
	Candle = table.freeze({ mesh = "rbxassetid://1949604058", texture = "rbxassetid://1949604104" }),
	-- "Red_Bat" (7492941934), escurecido.
	Bat = table.freeze({ mesh = "rbxassetid://7492941855", color = Color3.fromRGB(34, 30, 40), material = Enum.Material.SmoothPlastic }),
} :: { [string]: AssetSpec })

local templates: { [string]: MeshPart | false } = {}

local function template(name: string): MeshPart?
	local cached = templates[name]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local spec = TowerAssets.SPECS[name]
	if spec == nil then
		templates[name] = false
		return nil
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(spec.mesh)
	end)
	if not ok then
		warn(`[TowerAssets] {name} mesh unavailable: {result}`)
		templates[name] = false
		return nil
	end
	local meshPart: MeshPart = result
	if spec.texture ~= nil then
		meshPart.TextureID = spec.texture
	end
	if spec.color ~= nil then
		meshPart.Color = spec.color
	end
	if spec.material ~= nil then
		meshPart.Material = spec.material
	end
	meshPart.Anchored = true
	meshPart.CanCollide = false
	meshPart.CanQuery = false
	meshPart.CanTouch = false
	meshPart.CastShadow = false
	templates[name] = meshPart
	return meshPart
end

-- Cópia do modelo `name` com a altura `height` (proporções da malha), de pé
-- sobre `base`, olhando para `facing` (direção no chão). Enfeite: não colide.
function TowerAssets.place(parent: Instance, name: string, height: number, base: Vector3, facing: Vector3?): MeshPart?
	local source = template(name)
	if source == nil then
		return nil
	end
	local copy = source:Clone()
	copy.Name = name
	copy.Size = source.Size * (height / source.Size.Y)
	local look = facing or Vector3.zAxis
	local flat = Vector3.new(look.X, 0, look.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local center = base + Vector3.new(0, copy.Size.Y / 2, 0)
	copy.CFrame = CFrame.lookAt(center, center + direction)
	copy.Parent = parent
	return copy
end

return table.freeze(TowerAssets)
