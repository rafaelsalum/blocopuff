--!strict

-- Eliminação no Assassinato no Casarão (Fase 5E.4): fumaça e confete onde o
-- eliminado estava, o corpo de verdade some e no lugar dele fica um
-- fantasma até o fim da partida. O fantasma é uma cópia do corpo e dos
-- acessórios do personagem, de pé, translúcida e azulada, que flutua
-- devagar, com uma luz fraca e o nome em cima. Não bloqueia passagem, tiro
-- nem faca. A cópia não tem Humanoid: com ele o Roblox religa a colisão do
-- tronco e da cabeça (e aí raios e tiros batem no fantasma).

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

type Ghost = {
	model: Model,
	base: CFrame,
	phase: number,
}

local FOLDER_NAME = "Ghosts"
local POOF_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 214, 90),
	Color3.fromRGB(120, 220, 255),
}
local GHOST_COLOR = Color3.fromRGB(190, 225, 255)
local GHOST_TRANSPARENCY = 0.35
local FACE_TRANSPARENCY = 0.3
-- Sobe um pouco do chão e balança devagar.
local HOVER_HEIGHT = 0.8
local BOB_HEIGHT = 0.4
local BOB_SPEED = 1.6
local SPIN_SPEED = 0.25
local LIGHT_RANGE = 10
local LIGHT_BRIGHTNESS = 0.8
local NAME_MAX_DISTANCE = 45
-- Só o corpo e os acessórios vão para o fantasma (nada de Humanoid,
-- roupas, scripts, sons ou física).
local KEEP_CLASSES = {
	"BasePart",
	"Accessory",
	"DataModelMesh",
	"Decal",
	"SurfaceAppearance",
	"WrapLayer",
	"WrapTarget",
	"Attachment",
	"Motor6D",
	"Weld",
	"WeldConstraint",
}

local MurderGhosts = {}

local ghosts: { Ghost } = {}
-- Quem já virou fantasma nesta partida (o modo chama antes e depois da
-- eliminação; só a primeira vale).
local haunted: { [Combatant]: boolean } = {}
local bobConnection: RBXScriptConnection? = nil

local function keep(instance: Instance): boolean
	for _, className in ipairs(KEEP_CLASSES) do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

local function poofAt(cframe: CFrame, parent: Instance)
	local burst = Instance.new("Part")
	burst.Name = "Poof"
	burst.Size = Vector3.one
	burst.Transparency = 1
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.CFrame = cframe
	burst.Parent = parent
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 245))
	smoke.Size = NumberSequence.new(2.5, 5)
	smoke.Transparency = NumberSequence.new(0.2, 1)
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Speed = NumberRange.new(4, 8)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Enabled = false
	smoke.Parent = burst
	smoke:Emit(16)
	for _, color in ipairs(POOF_COLORS) do
		local confetti = Instance.new("ParticleEmitter")
		confetti.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		confetti.Color = ColorSequence.new(color)
		confetti.Size = NumberSequence.new(0.5)
		confetti.Lifetime = NumberRange.new(0.8, 1.4)
		confetti.Speed = NumberRange.new(10, 18)
		confetti.SpreadAngle = Vector2.new(180, 180)
		confetti.Acceleration = Vector3.new(0, -25, 0)
		confetti.Enabled = false
		confetti.Parent = burst
		confetti:Emit(10)
	end
	Debris:AddItem(burst, 2)
end

-- Uma junta do corpo: a pose de descanso põe `part1` em `rest(part0)`
-- (e o inverso). Serve para Motor6D/Weld (C0 e C1), WeldConstraint e as juntas novas
-- do avatar (AnimationConstraint, RigidConstraint), que alinham dois
-- attachments.
type Joint = {
	part0: BasePart,
	part1: BasePart,
	offset: CFrame,
}

local function jointOf(instance: Instance): Joint?
	if instance:IsA("Motor6D") or instance:IsA("Weld") then
		local part0, part1 = instance.Part0, instance.Part1
		if part0 ~= nil and part1 ~= nil then
			return { part0 = part0, part1 = part1, offset = instance.C0 * instance.C1:Inverse() }
		end
	elseif instance:IsA("WeldConstraint") then
		-- Sem C0/C1: vale a posição relativa de agora (antes de mexer).
		local part0, part1 = instance.Part0, instance.Part1
		if part0 ~= nil and part1 ~= nil then
			return { part0 = part0, part1 = part1, offset = part0.CFrame:ToObjectSpace(part1.CFrame) }
		end
	elseif instance:IsA("AnimationConstraint") or instance:IsA("RigidConstraint") then
		local a0, a1 = instance.Attachment0, instance.Attachment1
		local part0 = if a0 ~= nil then a0.Parent else nil
		local part1 = if a1 ~= nil then a1.Parent else nil
		if a0 ~= nil and a1 ~= nil and part0 ~= nil and part1 ~= nil and part0:IsA("BasePart") and part1:IsA("BasePart") then
			return { part0 = part0, part1 = part1, offset = a0.CFrame * a1.CFrame:Inverse() }
		end
	end
	return nil
end

-- A cópia congela a pose da animação (no meio de um passo, inclinado):
-- recoloca cada parte pelas juntas a partir da raiz, de pé e parado.
local function standUp(model: Model, root: BasePart)
	local placed: { [BasePart]: boolean } = { [root] = true }
	local joints: { Joint } = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		local joint = jointOf(descendant)
		if joint ~= nil then
			table.insert(joints, joint)
		end
	end
	local progress = true
	while progress do
		progress = false
		for _, joint in ipairs(joints) do
			if placed[joint.part0] and not placed[joint.part1] then
				joint.part1.CFrame = joint.part0.CFrame * joint.offset
				placed[joint.part1] = true
				progress = true
			elseif placed[joint.part1] and not placed[joint.part0] then
				joint.part0.CFrame = joint.part1.CFrame * joint.offset:Inverse()
				placed[joint.part0] = true
				progress = true
			end
		end
	end
end

-- Deixa a cópia com cara de fantasma: translúcida, azulada, sem colisão.
local function haunt(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if not keep(descendant) then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
			if descendant.Name ~= "HumanoidRootPart" then
				descendant.Color = descendant.Color:Lerp(GHOST_COLOR, 0.6)
				descendant.Material = Enum.Material.SmoothPlastic
				descendant.Transparency = GHOST_TRANSPARENCY
			end
		elseif descendant:IsA("Decal") then
			descendant.Transparency = FACE_TRANSPARENCY
		elseif descendant:IsA("SurfaceAppearance") then
			descendant:Destroy()
		end
	end
end

local function decorate(model: Model, name: string)
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = GHOST_COLOR
	light.Range = LIGHT_RANGE
	light.Brightness = LIGHT_BRIGHTNESS
	light.Shadows = false
	light.Parent = root
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GhostName"
	billboard.Size = UDim2.fromOffset(160, 28)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.MaxDistance = NAME_MAX_DISTANCE
	billboard.AlwaysOnTop = false
	billboard.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = GHOST_COLOR
	label.TextStrokeTransparency = 0.4
	label.Text = "👻 " .. name
	label.Parent = billboard
end

local function onHeartbeat()
	local now = os.clock()
	for _, ghost in ipairs(ghosts) do
		if ghost.model.Parent ~= nil then
			local t = now + ghost.phase
			local lift = HOVER_HEIGHT + math.sin(t * BOB_SPEED) * BOB_HEIGHT
			ghost.model:PivotTo(ghost.base * CFrame.new(0, lift, 0) * CFrame.Angles(0, t * SPIN_SPEED, 0))
		end
	end
end

local function ghostFolder(parent: Instance): Folder
	local existing = parent:FindFirstChild(FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = parent
	return folder
end

-- Cópia fantasma do personagem, de pé onde ele estava.
local function spawnGhost(character: Model, root: BasePart, name: string, parent: Instance)
	local wasArchivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function(): Model?
		return character:Clone()
	end)
	character.Archivable = wasArchivable
	if not ok or copy == nil then
		return
	end
	local model = copy :: Model
	model.Name = "Ghost_" .. name
	local copyRoot = model:FindFirstChild("HumanoidRootPart")
	if copyRoot ~= nil and copyRoot:IsA("BasePart") then
		model.PrimaryPart = copyRoot
		local look = copyRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
		local facing = if look.Magnitude > 1e-3 then look.Unit else -Vector3.zAxis
		copyRoot.CFrame = CFrame.lookAt(copyRoot.Position, copyRoot.Position + facing)
		standUp(model, copyRoot)
	end
	haunt(model)
	decorate(model, name)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local facing = if flat.Magnitude > 1e-3 then flat.Unit else -Vector3.zAxis
	local base = CFrame.lookAt(root.Position, root.Position + facing)
	model:PivotTo(base * CFrame.new(0, HOVER_HEIGHT, 0))
	model.Parent = ghostFolder(parent)
	table.insert(ghosts, { model = model, base = base, phase = math.random() * math.pi * 2 })
	if bobConnection == nil then
		bobConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

-- Eliminado: fumaça e confete, o corpo some e fica o fantasma. Melhor
-- chamar antes de o RoundService zerar a vida: depois disso o Roblox já
-- desfez as juntas e o fantasma fica com a pose da queda.
function MurderGhosts.eliminate(combatant: Combatant, name: string, parent: Instance)
	if haunted[combatant] then
		return
	end
	local character = CombatantRegistry.getCharacter(combatant)
	local root = CombatantRegistry.getRoot(combatant)
	if character == nil or root == nil then
		return
	end
	haunted[combatant] = true
	poofAt(root.CFrame, parent)
	spawnGhost(character, root, name, parent)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.Transparency = 1
		elseif descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end
end

-- Fim da partida: somem os fantasmas.
function MurderGhosts.clear()
	local connection = bobConnection
	if connection ~= nil then
		connection:Disconnect()
		bobConnection = nil
	end
	for _, ghost in ipairs(ghosts) do
		ghost.model:Destroy()
	end
	table.clear(ghosts)
	table.clear(haunted)
end

return table.freeze(MurderGhosts)
