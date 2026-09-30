--!strict

-- Desenha e anima o Barão no cliente, liso a 60 quadros por segundo:
--   * Barão da arena (tag "Barao"): o servidor move só uma raiz invisível
--     e publica o estado em atributos; aqui um modelo local segue a raiz
--     (suavizado) e o BaraoAnimator faz as poses. Some no túnel.
--   * Portinholas do túnel (tag "BaraoDoor"): a tampa balança quando o
--     atributo "Flap" muda.
--   * Barão do Jardim (tag "BaraoFriendly"): o modelo do servidor é
--     animado aqui mesmo; dorme e, no carinho ("BaraoPet"), pula e abana
--     o rabo.
-- Longe da câmera nada é animado.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BaraoModel = require(ReplicatedStorage.Shared.modules.BaraoModel)
local BaraoAnimator = require(script.Parent.Parent.effects.BaraoAnimator)

type Animator = BaraoAnimator.Animator

type ArenaBarao = {
	source: Model,
	root: BasePart,
	visual: Model,
	animator: Animator,
	cframe: CFrame,
	speed: number,
	lastBark: number,
	lastPush: number,
	tunnelSince: number?,
	connections: { RBXScriptConnection },
}

type FriendlyBarao = {
	model: Model,
	rest: CFrame,
	animator: Animator,
	lastPet: number,
	happyUntil: number,
}

type Door = {
	part: BasePart,
	rest: CFrame,
	side: number,
	elapsed: number?,
}

local BARAO_TAG = "Barao"
local FRIENDLY_TAG = "BaraoFriendly"
local DOOR_TAG = "BaraoDoor"
local VISUAL_FOLDER = "BaraoVisual"
local FOLLOW_RATE = 12
local SPEED_RATE = 10
local SNAP_DISTANCE = 12
local ARENA_DRAW_DISTANCE = 170
local FRIENDLY_DRAW_DISTANCE = 100
local FLAP_SECONDS = 1.2
local FLAP_ANGLE = 1.1
-- Ainda visível um instante depois de entrar no túnel (chega na portinhola).
local TUNNEL_HIDE_DELAY = 0.15
local MAX_STEP = 0.1

local BaraoVisualController = {}

local started = false
local arena: { [Model]: ArenaBarao } = {}
local friendly: { [Model]: FriendlyBarao } = {}
local doors: { [BasePart]: Door } = {}
-- Modelos em preparação (evita dois visuais para o mesmo Barão).
local pending: { [Instance]: boolean } = {}

local function counter(model: Instance, name: string): number
	local value = model:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function cameraPosition(): Vector3
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.CFrame.Position else Vector3.zero
end

local function visualFolder(): Folder
	local existing = Workspace:FindFirstChild(VISUAL_FOLDER)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = VISUAL_FOLDER
	folder.Parent = Workspace
	return folder
end

-- Ângulo (em torno de Y) para a cabeça olhar para quem ele persegue.
local function lookYaw(entry: ArenaBarao): number
	local userId = entry.source:GetAttribute("BaraoTarget")
	if typeof(userId) ~= "number" or userId == 0 then
		return 0
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return 0
	end
	local relative = entry.cframe:PointToObjectSpace(root.Position)
	return math.atan2(-relative.X, -relative.Z)
end

local function removeArena(source: Model)
	local entry = arena[source]
	if entry == nil then
		return
	end
	arena[source] = nil
	for _, connection in ipairs(entry.connections) do
		connection:Disconnect()
	end
	entry.animator.destroy()
	entry.visual:Destroy()
end

local function addArena(source: Instance)
	if not source:IsA("Model") or arena[source] ~= nil or pending[source] then
		return
	end
	pending[source] = true
	local root = source:WaitForChild(BaraoModel.SoundPartName, 10)
	pending[source] = nil
	if root == nil or not root:IsA("BasePart") or source.Parent == nil or arena[source] ~= nil then
		return
	end
	local scale = source:GetAttribute(BaraoModel.ScaleAttribute)
	local visual = BaraoModel.build(if typeof(scale) == "number" then scale else 1)
	visual.Name = "BaraoLocal"
	local cframe = root.CFrame
	visual:PivotTo(CFrame.new())
	local animator = BaraoAnimator.new(visual, { zzz = true, effects = true })
	-- Primeira pose já no lugar, antes de aparecer.
	animator.update(cframe, 0, { mode = "Sleeping", speed = 0, lookYaw = 0, enraged = false })
	visual.Parent = visualFolder()
	local entry: ArenaBarao = {
		source = source,
		root = root,
		visual = visual,
		animator = animator,
		cframe = cframe,
		speed = 0,
		lastBark = counter(source, "BaraoBark"),
		lastPush = counter(source, "BaraoPush"),
		tunnelSince = nil,
		connections = {},
	}
	table.insert(entry.connections, source:GetAttributeChangedSignal("BaraoBark"):Connect(function()
		local value = counter(source, "BaraoBark")
		if value ~= entry.lastBark then
			entry.lastBark = value
			animator.bark()
		end
	end))
	table.insert(entry.connections, source:GetAttributeChangedSignal("BaraoPush"):Connect(function()
		local value = counter(source, "BaraoPush")
		if value ~= entry.lastPush then
			entry.lastPush = value
			animator.push()
		end
	end))
	table.insert(entry.connections, source.Destroying:Connect(function()
		removeArena(source)
	end))
	arena[source] = entry
end

local function stepArena(entry: ArenaBarao, deltaTime: number)
	local dt = math.min(deltaTime, MAX_STEP)
	local mode = entry.source:GetAttribute("BaraoState")
	local state = if typeof(mode) == "string" then mode else "Sleeping"
	if state == "Tunnel" then
		entry.tunnelSince = entry.tunnelSince or os.clock()
	else
		entry.tunnelSince = nil
	end
	local since = entry.tunnelSince
	local hidden = since ~= nil and os.clock() - since >= TUNNEL_HIDE_DELAY
	local parent: Instance? = if hidden then nil else visualFolder()
	if entry.visual.Parent ~= parent then
		entry.visual.Parent = parent
	end
	if hidden then
		entry.cframe = entry.root.CFrame
		entry.speed = 0
		return
	end

	local target = entry.root.CFrame
	local previous = entry.cframe.Position
	if (target.Position - previous).Magnitude > SNAP_DISTANCE then
		-- Mudou de lugar (rodada nova, saída do túnel): pula direto, sem
		-- contar como corrida.
		entry.cframe = target
		entry.speed = 0
	else
		entry.cframe = entry.cframe:Lerp(target, 1 - math.exp(-dt * FOLLOW_RATE))
		local moved = Vector3.new(entry.cframe.X - previous.X, 0, entry.cframe.Z - previous.Z).Magnitude
		local speed = moved / math.max(dt, 1e-3)
		entry.speed += (speed - entry.speed) * (1 - math.exp(-dt * SPEED_RATE))
	end

	if (entry.cframe.Position - cameraPosition()).Magnitude > ARENA_DRAW_DISTANCE then
		return
	end
	entry.animator.update(entry.cframe, dt, {
		mode = state,
		speed = entry.speed,
		lookYaw = if state == "Chase" then lookYaw(entry) else 0,
		enraged = entry.source:GetAttribute("BaraoEnraged") == true,
	})
end

local function addFriendly(instance: Instance)
	if not instance:IsA("Model") or friendly[instance] ~= nil then
		return
	end
	local model = instance
	local entry: FriendlyBarao = {
		model = model,
		rest = model:GetPivot(),
		animator = BaraoAnimator.new(model, { zzz = false, effects = false }),
		lastPet = counter(model, "BaraoPet"),
		happyUntil = 0,
	}
	model:GetAttributeChangedSignal("BaraoPet"):Connect(function()
		local value = counter(model, "BaraoPet")
		if value ~= entry.lastPet then
			entry.lastPet = value
			entry.happyUntil = os.clock() + BaraoModel.FriendlyHappySeconds
			entry.animator.pet()
		end
	end)
	model.Destroying:Connect(function()
		friendly[model] = nil
	end)
	friendly[model] = entry
end

local function stepFriendly(entry: FriendlyBarao, deltaTime: number)
	local dt = math.min(deltaTime, MAX_STEP)
	if (entry.rest.Position - cameraPosition()).Magnitude > FRIENDLY_DRAW_DISTANCE then
		return
	end
	local happy = os.clock() < entry.happyUntil
	entry.animator.update(entry.rest, dt, {
		mode = if happy then "Celebrate" else "Sleeping",
		speed = 0,
		lookYaw = 0,
		enraged = false,
	})
end

local function addDoor(instance: Instance)
	if not instance:IsA("BasePart") or doors[instance] ~= nil then
		return
	end
	local side = instance:GetAttribute("Side")
	local door: Door = { part = instance, rest = instance.CFrame, side = if typeof(side) == "number" then side else 1, elapsed = nil }
	instance:GetAttributeChangedSignal("Flap"):Connect(function()
		door.elapsed = 0
	end)
	instance.Destroying:Connect(function()
		doors[instance] = nil
	end)
	doors[instance] = door
end

-- Tampa presa em cima: balança para o lado do corredor (a parede fica atrás)
-- e para aos poucos.
local function stepDoor(door: Door, dt: number)
	local elapsed = door.elapsed
	if elapsed == nil then
		return
	end
	elapsed += dt
	local half = door.part.Size.Y / 2
	if elapsed >= FLAP_SECONDS then
		door.elapsed = nil
		door.part.CFrame = door.rest
		return
	end
	door.elapsed = elapsed
	local angle = -door.side * FLAP_ANGLE * math.exp(-3.2 * elapsed) * math.abs(math.sin(11 * elapsed))
	door.part.CFrame = door.rest * CFrame.new(0, half, 0) * CFrame.Angles(0, 0, angle) * CFrame.new(0, -half, 0)
end

local function watch(tag: string, handler: (Instance) -> ())
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		task.spawn(handler, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
		task.spawn(handler, instance)
	end)
end

function BaraoVisualController.start()
	if started then
		return
	end
	started = true
	watch(BARAO_TAG, addArena)
	watch(FRIENDLY_TAG, addFriendly)
	watch(DOOR_TAG, addDoor)
	CollectionService:GetInstanceRemovedSignal(BARAO_TAG):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			removeArena(instance)
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		for _, entry in pairs(arena) do
			stepArena(entry, dt)
		end
		for _, entry in pairs(friendly) do
			stepFriendly(entry, dt)
		end
		for _, door in pairs(doors) do
			stepDoor(door, dt)
		end
	end)
end

return table.freeze(BaraoVisualController)
