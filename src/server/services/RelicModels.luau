--!strict

-- Modelos das relíquias do Casarão (Fase 5C.2). A maioria usa malhas
-- gratuitas da Creator Store (relógio de bolso, moedas, chave, peças de
-- xadrez, xícara, livro, bússola e frasco), criadas na hora pelo servidor
-- com AssetService: só malha e textura, nunca scripts. Se a malha não
-- carregar, vale uma versão simples feita de peças. O Puff, a abóbora e a
-- estrela da Relíquia do Dia são sempre de peças.
--
-- Nada colide nem atrapalha. Sem luz: as faíscas começam desligadas e o
-- cliente só as liga quando o jogador chega bem perto (RelicController).

local AssetService = game:GetService("AssetService")

local RelicModels = {}

export type Shape =
	"Puff"
	| "Watch"
	| "GoldCoin"
	| "SilverCoin"
	| "Key"
	| "King"
	| "Rook"
	| "Bishop"
	| "Teacup"
	| "Book"
	| "Compass"
	| "Potion"
	| "Pumpkin"
	| "Daily"

-- Malha da Creator Store: tamanho final (maior lado, studs), rotação para
-- ficar na pose certa e se a cor da relíquia vale (sem textura própria).
type MeshSpec = {
	meshId: string,
	textureId: string?,
	size: number,
	rotation: CFrame,
	material: Enum.Material,
	tinted: boolean,
}

local HITBOX_SIZE = Vector3.new(1.8, 1.8, 1.8)
local PROMPT_DISTANCE = 7
local PRELOAD_TIMEOUT = 15
local SPARKLE_COLOR = Color3.fromRGB(255, 236, 170)
local EYE_COLOR = Color3.fromRGB(40, 34, 48)
local DAILY_COLOR = Color3.fromRGB(255, 214, 90)
local STEM_COLOR = Color3.fromRGB(90, 140, 60)
local FLAT = CFrame.Angles(math.rad(90), 0, 0)

local MESHES: { [string]: MeshSpec } = {
	Watch = { meshId = "rbxassetid://923452098", textureId = "rbxassetid://923452103", size = 1.1, rotation = CFrame.identity, material = Enum.Material.Metal, tinted = false },
	GoldCoin = { meshId = "rbxassetid://434056973", textureId = "rbxassetid://434056985", size = 0.9, rotation = CFrame.identity, material = Enum.Material.Metal, tinted = false },
	SilverCoin = { meshId = "rbxassetid://15326394256", size = 0.9, rotation = CFrame.identity, material = Enum.Material.Metal, tinted = true },
	Key = { meshId = "rbxassetid://16177310201", size = 1.3, rotation = FLAT, material = Enum.Material.Metal, tinted = true },
	King = { meshId = "rbxassetid://458394541", size = 1.3, rotation = CFrame.identity, material = Enum.Material.SmoothPlastic, tinted = true },
	Rook = { meshId = "rbxassetid://1545150506", size = 1.1, rotation = CFrame.identity, material = Enum.Material.Marble, tinted = true },
	Bishop = { meshId = "rbxassetid://1533547756", size = 1.2, rotation = CFrame.identity, material = Enum.Material.Marble, tinted = true },
	Teacup = { meshId = "rbxassetid://4487377395", size = 1.1, rotation = CFrame.identity, material = Enum.Material.SmoothPlastic, tinted = true },
	Book = { meshId = "rbxassetid://7992794295", textureId = "rbxassetid://7992794384", size = 1.2, rotation = CFrame.identity, material = Enum.Material.Fabric, tinted = false },
	Compass = { meshId = "rbxassetid://3532235172", size = 1, rotation = CFrame.identity, material = Enum.Material.Metal, tinted = true },
	Potion = { meshId = "rbxassetid://10441758680", size = 1, rotation = CFrame.identity, material = Enum.Material.Glass, tinted = true },
}

RelicModels.HitboxName = "Hitbox"
RelicModels.PromptName = "PickPrompt"
RelicModels.SparklesName = "Sparkles"
RelicModels.PromptDistance = PROMPT_DISTANCE

-- Malha carregada uma vez por id (as próximas são cópias). `false` = falhou.
local templates: { [string]: MeshPart | false } = {}

local function template(spec: MeshSpec): MeshPart?
	local cached = templates[spec.meshId]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(spec.meshId, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)
	if not ok or typeof(result) ~= "Instance" or not result:IsA("MeshPart") then
		warn(`[BlocoPuff] Relic mesh {spec.meshId} unavailable, using simple shape: {tostring(result)}`)
		templates[spec.meshId] = false
		return nil
	end
	local mesh = result :: MeshPart
	if spec.textureId ~= nil then
		mesh.TextureID = spec.textureId
	end
	templates[spec.meshId] = mesh
	return mesh
end

-- Carrega todas as malhas ao mesmo tempo (cada uma pode demorar) e espera
-- no máximo PRELOAD_TIMEOUT segundos; as que não chegarem ficam simples.
function RelicModels.preload()
	local pending = 0
	for _, spec in pairs(MESHES) do
		if templates[spec.meshId] == nil then
			pending += 1
			task.spawn(function()
				template(spec)
				pending -= 1
			end)
		end
	end
	local waited = 0
	while pending > 0 and waited < PRELOAD_TIMEOUT do
		waited += task.wait(0.1)
	end
end

-- Peça decorativa: ancorada, sem colisão, sem toque e fora dos raios.
local function settle(part: BasePart, model: Model)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = model
end

local function piece(model: Model, name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	settle(part, model)
	return part
end

-- Cilindro em pé (o eixo do cilindro no Roblox é X).
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

-- Malha da loja apoiada na base, no tamanho e na pose do `spec`.
local function buildMesh(model: Model, base: CFrame, color: Color3, spec: MeshSpec): boolean
	local source = template(spec)
	if source == nil then
		return false
	end
	local mesh = source:Clone()
	mesh.Name = "Relic"
	local natural = mesh.Size
	mesh.Size = natural * (spec.size / math.max(natural.X, natural.Y, natural.Z))
	mesh.Material = spec.material
	if spec.tinted then
		mesh.Color = color
	end
	-- Altura depois de girar: a pose decide qual lado fica para cima.
	local up = spec.rotation:VectorToObjectSpace(Vector3.yAxis)
	local half = mesh.Size / 2
	local lift = math.abs(up.X) * half.X + math.abs(up.Y) * half.Y + math.abs(up.Z) * half.Z
	mesh.CFrame = base * CFrame.new(0, lift, 0) * spec.rotation
	settle(mesh, model)
	return true
end

local function buildPuff(model: Model, base: CFrame, color: Color3)
	piece(model, "Body", Enum.PartType.Ball, Vector3.one, base * CFrame.new(0, 0.5, 0), color, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Eye", Enum.PartType.Ball, Vector3.one * 0.18, base * CFrame.new(0.18 * side, 0.62, -0.44), EYE_COLOR, Enum.Material.SmoothPlastic)
	end
end

local function buildPumpkin(model: Model, base: CFrame, color: Color3)
	piece(model, "Body", Enum.PartType.Ball, Vector3.new(1.1, 0.85, 1.1), base * CFrame.new(0, 0.43, 0), color, Enum.Material.SmoothPlastic)
	piece(model, "Stem", Enum.PartType.Cylinder, Vector3.new(0.3, 0.18, 0.18), base * CFrame.new(0, 0.95, 0) * UPRIGHT, STEM_COLOR, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Eye", Enum.PartType.Block, Vector3.new(0.16, 0.16, 0.05), base * CFrame.new(0.2 * side, 0.55, -0.5), EYE_COLOR, Enum.Material.SmoothPlastic)
	end
	piece(model, "Smile", Enum.PartType.Block, Vector3.new(0.5, 0.08, 0.05), base * CFrame.new(0, 0.32, -0.52), EYE_COLOR, Enum.Material.SmoothPlastic)
end

local function buildDaily(model: Model, base: CFrame)
	piece(model, "Core", Enum.PartType.Ball, Vector3.one * 0.8, base * CFrame.new(0, 0.7, 0), DAILY_COLOR, Enum.Material.Neon)
	piece(model, "Ring", Enum.PartType.Cylinder, Vector3.new(0.1, 1.3, 1.3), base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.pi / 4, 0), DAILY_COLOR, Enum.Material.Metal)
	piece(model, "Ring2", Enum.PartType.Cylinder, Vector3.new(0.1, 1.3, 1.3), base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, -math.pi / 4, 0), DAILY_COLOR, Enum.Material.Metal)
end

-- Versões simples (reserva quando a malha não carrega).
local function buildSimple(model: Model, shape: Shape, base: CFrame, color: Color3)
	if shape == "GoldCoin" or shape == "SilverCoin" or shape == "Compass" or shape == "Watch" then
		piece(model, "Disc", Enum.PartType.Cylinder, Vector3.new(0.14, 0.9, 0.9), base * CFrame.new(0, 0.07, 0) * UPRIGHT, color, Enum.Material.Metal)
	elseif shape == "Key" then
		piece(model, "Shaft", Enum.PartType.Block, Vector3.new(0.16, 0.16, 1), base * CFrame.new(0, 0.1, 0.1), color, Enum.Material.Metal)
		piece(model, "Bow", Enum.PartType.Cylinder, Vector3.new(0.16, 0.55, 0.55), base * CFrame.new(0, 0.1, -0.6) * UPRIGHT, color, Enum.Material.Metal)
	elseif shape == "Book" then
		piece(model, "Cover", Enum.PartType.Block, Vector3.new(1, 0.3, 0.75), base * CFrame.new(0, 0.15, 0), color, Enum.Material.Fabric)
	else
		piece(model, "Base", Enum.PartType.Cylinder, Vector3.new(0.22, 0.62, 0.62), base * CFrame.new(0, 0.11, 0) * UPRIGHT, color, Enum.Material.SmoothPlastic)
		piece(model, "Body", Enum.PartType.Cylinder, Vector3.new(0.6, 0.34, 0.34), base * CFrame.new(0, 0.5, 0) * UPRIGHT, color, Enum.Material.SmoothPlastic)
		piece(model, "Head", Enum.PartType.Ball, Vector3.one * 0.42, base * CFrame.new(0, 0.95, 0), color, Enum.Material.SmoothPlastic)
	end
end

local function buildVisual(model: Model, shape: Shape, base: CFrame, color: Color3)
	if shape == "Puff" then
		buildPuff(model, base, color)
	elseif shape == "Pumpkin" then
		buildPumpkin(model, base, color)
	elseif shape == "Daily" then
		buildDaily(model, base)
	else
		local spec = MESHES[shape]
		if spec == nil or not buildMesh(model, base, color, spec) then
			buildSimple(model, shape, base, color)
		end
	end
end

-- Faíscas pequenas, desligadas: o cliente liga quando o jogador está perto.
local function addSparkles(hitbox: BasePart, daily: boolean)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = RelicModels.SparklesName
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(SPARKLE_COLOR)
	sparkles.LightEmission = 1
	sparkles.Rate = if daily then 4 else 1.5
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Speed = NumberRange.new(0.2, 0.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Enabled = false
	sparkles.Parent = hitbox
end

-- Só a parte visível da relíquia (sem caixa de toque, prompt nem
-- faíscas), para a miniatura do Álbum.
function RelicModels.icon(parent: Instance, name: string, shape: Shape, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	buildVisual(model, shape, CFrame.identity, color)
	model.Parent = parent
	return model
end

-- Monta a relíquia com a base em `base` (no topo da superfície onde está).
-- `name` aparece no prompt (o cliente traduz). Atributos e etiqueta entram
-- antes de ir para o mundo (o cliente sempre vê os dois juntos). Pode
-- pausar (carrega a malha na primeira vez).
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

	buildVisual(model, shape, base, color)
	addSparkles(hitbox, shape == "Daily")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = RelicModels.PromptName
	prompt.ActionText = "Pegar"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	-- Barris e baús bloqueiam a visão: sem exigir linha de visão, o
	-- esconderijo entre eles continua alcançável (o servidor confere a
	-- distância).
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
