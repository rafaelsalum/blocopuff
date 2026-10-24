--!strict

-- Eliminação no Assassinato no Casarão (Fase 5E.4): fumaça e confete onde o
-- eliminado estava, o corpo de verdade some e no lugar dele aparece um
-- fantasma (cópia do corpo e dos acessórios, translúcida e azulada) que
-- tomba para trás e some aos poucos. No chão fica só a marca: a silhueta
-- deitada, translúcida, com o nome, até o fim da partida (nada de pé
-- atrapalhando a visão). Nada disso bloqueia passagem, tiro nem faca. A
-- cópia não tem Humanoid: com ele o Roblox religa a colisão do tronco e da
-- cabeça (e aí raios e tiros batem no fantasma).

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

type Ghost = {
	model: Model,
	-- Chão sob os pés, olhando para onde o eliminado olhava.
	feet: CFrame,
	-- Do chão até o pivô da cópia (a raiz).
	rootHeight: number,
	startedAt: number,
	parts: { BasePart },
	name: string,
	parent: Instance,
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
-- O tombo (s, acelerando) e quanto tempo o fantasma leva para sumir,
-- contado do começo do tombo.
local FALL_SECONDS = 0.6
local FADE_SECONDS = 1.1
local LIGHT_RANGE = 10
local LIGHT_BRIGHTNESS = 0.8
-- Marca no chão: silhueta deitada (cabeça para onde o fantasma tombou).
local MARK_THICKNESS = 0.05
-- Acima dos tapetes (até 0,1 de altura).
local MARK_LIFT = 0.2
local MARK_TRANSPARENCY = 0.45
local MARK_NAME_SIZE = Vector2.new(6, 1.2)
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
local marks: { Model } = {}
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

local function decorate(model: Model)
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
end

local function markPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, shape: Enum.PartType?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	if shape ~= nil then
		piece.Shape = shape
	end
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = GHOST_COLOR
	piece.Material = Enum.Material.SmoothPlastic
	piece.Transparency = MARK_TRANSPARENCY
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Parent = parent
	return piece
end

-- Silhueta deitada no chão, com os pés em `feet` e a cabeça para trás
-- (+Z local, para onde o fantasma tombou), e o nome junto dos pés.
local function leaveMark(ghost: Ghost)
	local mark = Instance.new("Model")
	mark.Name = "Mark_" .. ghost.name
	local floor = ghost.feet * CFrame.new(0, MARK_LIFT, 0)
	local flat = Vector3.new(0, MARK_THICKNESS, 0)
	markPart(mark, "MarkTorso", Vector3.new(2, 0, 2.2) + flat, floor * CFrame.new(0, 0, 2.9))
	markPart(mark, "MarkHead", Vector3.new(MARK_THICKNESS, 1.5, 1.5), floor * CFrame.new(0, 0, 4.9) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	for _, side in ipairs({ -1, 1 }) do
		markPart(mark, "MarkArm", Vector3.new(0.8, 0, 2.2) + flat, floor * CFrame.new(side * 1.7, 0, 3.1) * CFrame.Angles(0, side * math.rad(-25), 0))
		markPart(mark, "MarkLeg", Vector3.new(0.85, 0, 2) + flat, floor * CFrame.new(side * 0.55, 0, 0.9) * CFrame.Angles(0, side * math.rad(8), 0))
	end
	-- A face de cima escreve ao longo do Z da peça: girada, o nome fica
	-- atravessado aos pés da marca.
	local label = markPart(mark, "MarkName", Vector3.new(MARK_NAME_SIZE.Y, MARK_THICKNESS, MARK_NAME_SIZE.X), floor * CFrame.new(0, 0, -1) * CFrame.Angles(0, math.pi / 2, 0))
	label.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.MaxDistance = NAME_MAX_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = label
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = GHOST_COLOR
	text.TextStrokeTransparency = 0.5
	text.Text = "👻 " .. ghost.name
	text.Parent = gui
	mark.Parent = ghost.parent
	table.insert(marks, mark)
end

-- Tomba para trás girando nos pés (acelerando) e some aos poucos; no fim,
-- deixa a marca no chão.
local function onHeartbeat()
	local now = os.clock()
	for index = #ghosts, 1, -1 do
		local ghost = ghosts[index]
		local elapsed = now - ghost.startedAt
		if ghost.model.Parent == nil or elapsed >= FADE_SECONDS then
			ghost.model:Destroy()
			table.remove(ghosts, index)
			leaveMark(ghost)
		else
			local fall = math.min(1, elapsed / FALL_SECONDS)
			local angle = (math.pi / 2) * fall * fall
			ghost.model:PivotTo(ghost.feet * CFrame.Angles(angle, 0, 0) * CFrame.new(0, ghost.rootHeight, 0))
			local fade = math.clamp(elapsed / FADE_SECONDS, 0, 1)
			local transparency = GHOST_TRANSPARENCY + (1 - GHOST_TRANSPARENCY) * fade
			for _, piece in ipairs(ghost.parts) do
				piece.Transparency = transparency
			end
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

-- Cópia fantasma do personagem, de pé onde ele estava (depois tomba).
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
	decorate(model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootHeight = root.Size.Y / 2 + (if humanoid ~= nil then humanoid.HipHeight else 2)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local facing = if flat.Magnitude > 1e-3 then flat.Unit else -Vector3.zAxis
	local footing = root.Position - Vector3.new(0, rootHeight, 0)
	local feet = CFrame.lookAt(footing, footing + facing)
	model:PivotTo(feet * CFrame.new(0, rootHeight, 0))
	local parts: { BasePart } = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			table.insert(parts, descendant)
		end
	end
	model.Parent = ghostFolder(parent)
	table.insert(ghosts, { model = model, feet = feet, rootHeight = rootHeight, startedAt = os.clock(), parts = parts, name = name, parent = ghostFolder(parent) })
	if bobConnection == nil then
		bobConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

-- Eliminado: fumaça e confete, o corpo some, o fantasma tomba e fica a
-- marca no chão. Melhor
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

-- Fim da partida: somem os fantasmas e as marcas.
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
	for _, mark in ipairs(marks) do
		mark:Destroy()
	end
	table.clear(marks)
	table.clear(haunted)
end

return table.freeze(MurderGhosts)
