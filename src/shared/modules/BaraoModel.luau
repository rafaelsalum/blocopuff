--!strict

-- Modelo do Barão. Usa o modelo 3D importado no Studio
-- (ReplicatedStorage.Shared.assets.BaraoMesh, 12 MeshParts com textura
-- PBR) e, se ele não estiver disponível, o Barão de blocos (BaraoBlocks).
--
-- Convenções que o BaraoAnimator (cliente) espera:
--   * o pivô do modelo fica no chão, no meio das patas, e a frente é -Z;
--   * cada peça tem o atributo "Bone" (corpo, cabeça, orelhas, língua, rabo
--     e as quatro patas) e gira em torno da articulação desse osso
--     (`BaraoModel.pivot`);
--   * `scale` aumenta o modelo inteiro; o valor fica no atributo
--     "BaraoScale".
--
-- O arquivo importado vem com a frente em +Z, fora da origem, com cada
-- peça centrada em si mesma e solta. Aqui ele é girado 180°, centralizado,
-- ancorado e as articulações são calculadas pela forma de cada peça (topo
-- da pata, topo da orelha, base do rabo, nuca).

local BaraoBlocks = require(script.Parent.BaraoBlocks)

export type Bone = "Body" | "Head" | "EarL" | "EarR" | "Tongue" | "Tail" | "LegFL" | "LegFR" | "LegBL" | "LegBR"

type MeshEntry = {
	source: BasePart,
	name: string,
	bone: Bone,
	-- Já girado e centralizado, em tamanho 1.
	cframe: CFrame,
	size: Vector3,
}

type Bounds = { center: Vector3, size: Vector3, min: Vector3, max: Vector3 }

local BaraoModel = {}

-- Nome da peça que carrega os sons (a do corpo).
BaraoModel.SoundPartName = "Body"
BaraoModel.ScaleAttribute = "BaraoScale"
BaraoModel.BoneAttribute = "Bone"
-- Quantas peças o modelo tem (o cliente espera todas chegarem antes de
-- animar um modelo que veio do servidor) e onde ele descansa.
BaraoModel.PartCountAttribute = "BaraoParts"
BaraoModel.RestAttribute = "BaraoRest"
-- Com que versão o modelo foi montado ("Mesh" ou "Blocks"): quem anima usa
-- as articulações dessa versão, mesmo que ela tenha sido montada em outra
-- máquina (o Barão do Jardim é montado no servidor).
BaraoModel.VariantAttribute = "BaraoVariant"
-- Quanto tempo o Barão do Jardim fica feliz depois de um carinho.
BaraoModel.FriendlyHappySeconds = 2.6

local ASSET_WAIT = 5
local TEMPLATE_NAME = "BaraoMesh"
-- Osso de cada peça do arquivo importado (os dois olhos seguem a cabeça e
-- passam a se chamar "Eye", que o animador pinta de vermelho quando bravo).
local MESH_BONES: { [string]: Bone } = {
	Body = "Body",
	Head = "Head",
	Eye = "Head",
	Eye2 = "Head",
	EarL = "EarL",
	EarR = "EarR",
	Tongue = "Tongue",
	Tail = "Tail",
	LegFL = "LegFL",
	LegFR = "LegFR",
	LegBL = "LegBL",
	LegBR = "LegBR",
}
local RENAMES: { [string]: string } = { Eye2 = "Eye" }
local FACE_MINUS_Z = CFrame.Angles(0, math.pi, 0)
local VARIANT_MESH = "Mesh"
local VARIANT_BLOCKS = "Blocks"
-- Quanto uma peça pode estar girada no arquivo (as caixas das articulações
-- consideram as peças retas).
local MAX_TILT = 0.02

local function findTemplate(): Instance?
	local shared = script.Parent.Parent
	local assets = shared:FindFirstChild("assets") or shared:WaitForChild("assets", ASSET_WAIT)
	if assets == nil then
		return nil
	end
	return assets:FindFirstChild(TEMPLATE_NAME) or assets:WaitForChild(TEMPLATE_NAME, ASSET_WAIT)
end

local function boundsOf(entry: MeshEntry): Bounds
	local center = entry.cframe.Position
	local half = entry.size / 2
	return { center = center, size = entry.size, min = center - half, max = center + half }
end

-- Lê as peças do modelo importado e as coloca no espaço do Barão: pivô no
-- chão entre as patas, frente em -Z.
local function readMesh(template: Instance): { MeshEntry }?
	local found: { [string]: BasePart } = {}
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("BasePart") and MESH_BONES[descendant.Name] ~= nil then
			found[descendant.Name] = descendant
		end
	end
	for name in pairs(MESH_BONES) do
		if found[name] == nil then
			warn(`[BlocoPuff] Barao mesh is missing part {name}; using the block model`)
			return nil
		end
	end
	for name, part in pairs(found) do
		local _, angle = part.CFrame.Rotation:ToAxisAngle()
		if math.abs(angle) > MAX_TILT then
			warn(`[BlocoPuff] Barao mesh part {name} is rotated; joints may be off`)
		end
	end
	local legs = { found.LegFL, found.LegFR, found.LegBL, found.LegBR }
	local legCenter = Vector3.zero
	local floor = math.huge
	for _, leg in ipairs(legs) do
		legCenter += leg.Position / #legs
		floor = math.min(floor, leg.Position.Y - (leg.Size.Y / 2))
	end
	local origin = Vector3.new(legCenter.X, floor, legCenter.Z)
	local entries: { MeshEntry } = {}
	for name, source in pairs(found) do
		local local0 = FACE_MINUS_Z * CFrame.new(source.Position - origin)
		table.insert(entries, {
			source = source,
			name = RENAMES[name] or name,
			bone = MESH_BONES[name],
			cframe = CFrame.new(local0.Position) * FACE_MINUS_Z.Rotation * source.CFrame.Rotation,
			size = source.Size,
		})
	end
	return entries
end

-- Articulações pela forma de cada peça (tudo já com a frente em -Z).
local function meshPivots(entries: { MeshEntry }): { [Bone]: Vector3 }
	local byName: { [string]: Bounds } = {}
	for _, entry in ipairs(entries) do
		if entry.name ~= "Eye" then
			byName[entry.name] = boundsOf(entry)
		end
	end
	local pivots: { [Bone]: Vector3 } = {}
	if byName.EarL.center.X >= 0 then
		-- De frente para -Z, a esquerda do Barão é -X.
		warn("[BlocoPuff] Barao mesh EarL is on the right side; ears may flap the wrong way")
	end
	local body = byName.Body
	pivots.Body = body.center
	local head = byName.Head
	-- Nuca: embaixo e atrás na cabeça.
	pivots.Head = Vector3.new(0, head.min.Y + (head.size.Y * 0.25), head.max.Z - (head.size.Z * 0.3))
	for _, ear in ipairs({ "EarL", "EarR" } :: { Bone }) do
		local bounds = byName[ear]
		-- Presa em cima, do lado de dentro (junto da cabeça).
		local inward = -math.sign(bounds.center.X)
		pivots[ear] = Vector3.new(bounds.center.X + (inward * bounds.size.X * 0.35), bounds.max.Y - (bounds.size.Y * 0.15), bounds.center.Z)
	end
	local tongue = byName.Tongue
	-- Raiz da língua: em cima e atrás, dentro da boca.
	pivots.Tongue = Vector3.new(0, tongue.max.Y, tongue.max.Z)
	local tail = byName.Tail
	-- Base do rabo: embaixo e do lado do corpo.
	pivots.Tail = Vector3.new(0, tail.min.Y + (tail.size.Y * 0.15), tail.min.Z + (tail.size.Z * 0.2))
	for _, leg in ipairs({ "LegFL", "LegFR", "LegBL", "LegBR" } :: { Bone }) do
		local bounds = byName[leg]
		-- Ombro ou quadril: no topo da pata.
		pivots[leg] = Vector3.new(bounds.center.X, bounds.max.Y - (bounds.size.Y * 0.1), bounds.center.Z)
	end
	return pivots
end

local template = findTemplate()
local meshEntries = if template ~= nil then readMesh(template) else nil
if template == nil then
	warn("[BlocoPuff] Barao mesh not found; using the block model")
end
local MESH_PIVOTS: { [Bone]: Vector3 }? = if meshEntries ~= nil then meshPivots(meshEntries) else nil
local BLOCK_PIVOTS: { [Bone]: Vector3 } = BaraoBlocks.pivots
local warnedMissingMesh = false

-- Articulação de `bone` na escala `scale`. `variant` é o atributo
-- "BaraoVariant" do modelo; sem ele, vale a versão que esta máquina monta.
function BaraoModel.pivot(bone: Bone, scale: number, variant: string?): Vector3
	local pivots = if variant == VARIANT_BLOCKS then BLOCK_PIVOTS else MESH_PIVOTS or BLOCK_PIVOTS
	if variant == VARIANT_MESH and MESH_PIVOTS == nil and not warnedMissingMesh then
		warnedMissingMesh = true
		warn("[BlocoPuff] Barao mesh not available here; animating with block joints")
	end
	return pivots[bone] * scale
end

local function buildMesh(model: Model, entries: { MeshEntry }, size: number)
	for _, entry in ipairs(entries) do
		local part = entry.source:Clone()
		for _, child in ipairs(part:GetChildren()) do
			if not child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		part.Name = entry.name
		part.Size = entry.size * size
		part.CFrame = CFrame.new(entry.cframe.Position * size) * entry.cframe.Rotation
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		part.Massless = true
		part:SetAttribute(BaraoModel.BoneAttribute, entry.bone)
		part.Parent = model
	end
end

function BaraoModel.build(scale: number?): Model
	local size = scale or 1
	local model = Instance.new("Model")
	model.Name = "Barao"
	model:SetAttribute(BaraoModel.ScaleAttribute, size)
	local entries = meshEntries
	if entries ~= nil then
		buildMesh(model, entries, size)
		model:SetAttribute(BaraoModel.VariantAttribute, VARIANT_MESH)
	else
		BaraoBlocks.build(model, size)
		model:SetAttribute(BaraoModel.VariantAttribute, VARIANT_BLOCKS)
	end
	-- Sem PrimaryPart: assim o pivô é o WorldPivot (no chão, entre as
	-- patas), e não o centro do corpo.
	model.WorldPivot = CFrame.new(0, 0, 0)
	model:SetAttribute(BaraoModel.PartCountAttribute, #model:GetChildren())
	return model
end

return table.freeze(BaraoModel)
