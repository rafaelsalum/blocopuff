--!strict

-- Desenha e anima o Barão no cliente, liso a 60 quadros por segundo:
--   * Barão da arena (tag "Barao"): o servidor move só uma raiz invisível
--     e publica o estado em atributos; aqui um modelo local segue a raiz
--     e o BaraoAnimator faz as poses. Some no túnel.
--   * Portinholas do túnel (tag "BaraoDoor"): a tampa balança quando o
--     atributo "Flap" muda.
--   * Barão do Jardim (tag "BaraoFriendly"): o modelo do servidor é
--     animado aqui mesmo; dorme e, no carinho ("BaraoPet"), acorda, late,
--     pula dando uma volta, solta corações e senta abanando o rabo olhando
--     para você.
-- A posição segue a raiz com suavização e o giro é feito pelo caminho mais
-- curto (sem virar de uma vez), o que também inclina o corpo nas curvas.
-- Longe da câmera nada é animado.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BaraoModel = require(ReplicatedStorage.Shared.modules.BaraoModel)
local BaraoAnimator = require(script.Parent.Parent.effects.BaraoAnimator)

type Animator = BaraoAnimator.Animator

type ArenaBarao = {
	source: Model,
	root: BasePart,
	visual: Model,
	animator: Animator,
	cframe: CFrame,
	yaw: number,
	pitch: number,
	speed: number,
	turn: number,
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
local TURN_RATE = 8
local SNAP_DISTANCE = 12
local ARENA_DRAW_DISTANCE = 170
local FRIENDLY_DRAW_DISTANCE = 100
local LOOK_DISTANCE = 16
local FLAP_SECONDS = 1.2
local FLAP_ANGLE = 1.1
-- Ainda visível um instante depois de entrar no túnel (chega na portinhola).
local TUNNEL_HIDE_DELAY = 0.15
local MAX_STEP = 0.1
local HEART_COUNT = 3
local HEART_SECONDS = 1.4
local HEART_RISE = 3
local PET_BARK_VOLUME = 0.55
-- Espera as peças do Barão do Jardim chegarem do servidor.
local PARTS_TIMEOUT = 15
local PARTS_POLL = 0.2
local MAX_WARNINGS = 5

local BaraoVisualController = {}

local started = false
local arena: { [Model]: ArenaBarao } = {}
local friendly: { [Model]: FriendlyBarao } = {}
local doors: { [BasePart]: Door } = {}
-- Modelos em preparação (evita dois visuais para o mesmo Barão).
local pending: { [Instance]: boolean } = {}
-- Um aviso por mensagem de falha (e no máximo MAX_WARNINGS no total): um
-- erro não pode parar as outras animações nem lotar a saída.
local warned: { [string]: boolean } = {}
local warnings = 0

local function report(kind: string, failure: unknown)
	local message = `[BlocoPuff] Barao visual ({kind}) failed: {failure}`
	if warned[message] or warnings >= MAX_WARNINGS then
		return
	end
	warned[message] = true
	warnings += 1
	warn(message)
end

local function guarded(kind: string, callback: () -> ())
	local ok, failure = pcall(callback)
	if not ok then
		report(kind, failure)
	end
end

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

-- Direção (yaw) e inclinação (pitch, na rampa) de um CFrame que olha para
-- onde anda; a frente é -Z.
local function heading(cframe: CFrame): (number, number)
	local look = cframe.LookVector
	return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end

local function shortestAngle(from: number, to: number): number
	return (to - from + math.pi) % (math.pi * 2) - math.pi
end

local function compose(position: Vector3, yaw: number, pitch: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

-- Ângulo (em torno de Y) de `frame` até `position`, para a cabeça olhar.
local function yawTowards(frame: CFrame, position: Vector3): number
	local relative = frame:PointToObjectSpace(position)
	return math.atan2(-relative.X, -relative.Z)
end

local function characterRoot(player: Player?): BasePart?
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Para onde a cabeça do Barão da arena olha: quem ele persegue.
local function chaseLook(entry: ArenaBarao): number
	local userId = entry.source:GetAttribute("BaraoTarget")
	if typeof(userId) ~= "number" or userId == 0 then
		return 0
	end
	local root = characterRoot(Players:GetPlayerByUserId(userId))
	return if root ~= nil then yawTowards(entry.cframe, root.Position) else 0
end

-- O Barão do Jardim olha para o jogador local, se ele estiver perto.
local function lookAtLocal(rest: CFrame): number
	local root = characterRoot(Players.LocalPlayer)
	if root == nil or (root.Position - rest.Position).Magnitude > LOOK_DISTANCE then
		return 0
	end
	return yawTowards(rest, root.Position)
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
	local yaw, pitch = heading(root.CFrame)
	local cframe = compose(root.Position, yaw, pitch)
	local animator = BaraoAnimator.new(visual, { zzz = true, effects = true })
	visual.Parent = visualFolder()
	-- Primeira pose já no lugar.
	animator.update(cframe, 0, { mode = "Sleeping", speed = 0, turn = 0, lookYaw = 0, enraged = false })
	local entry: ArenaBarao = {
		source = source,
		root = root,
		visual = visual,
		animator = animator,
		cframe = cframe,
		yaw = yaw,
		pitch = pitch,
		speed = 0,
		turn = 0,
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

	local target = entry.root.CFrame
	local targetYaw, targetPitch = heading(target)
	if hidden then
		entry.yaw = targetYaw
		entry.pitch = targetPitch
		entry.cframe = compose(target.Position, targetYaw, targetPitch)
		entry.speed = 0
		entry.turn = 0
		return
	end

	local previous = entry.cframe.Position
	local position: Vector3
	if (target.Position - previous).Magnitude > SNAP_DISTANCE then
		-- Mudou de lugar (rodada nova, saída do túnel): pula direto, sem
		-- contar como corrida.
		position = target.Position
		entry.yaw = targetYaw
		entry.pitch = targetPitch
		entry.speed = 0
		entry.turn = 0
	else
		local follow = 1 - math.exp(-dt * FOLLOW_RATE)
		position = previous:Lerp(target.Position, follow)
		local moved = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z).Magnitude
		local blend = 1 - math.exp(-dt * SPEED_RATE)
		entry.speed += ((moved / math.max(dt, 1e-3)) - entry.speed) * blend
		-- Vira pelo caminho mais curto, aos poucos (e inclina na curva).
		local turnStep = shortestAngle(entry.yaw, targetYaw) * (1 - math.exp(-dt * TURN_RATE))
		entry.yaw += turnStep
		entry.turn += ((turnStep / math.max(dt, 1e-3)) - entry.turn) * blend
		entry.pitch += (targetPitch - entry.pitch) * follow
	end
	entry.cframe = compose(position, entry.yaw, entry.pitch)

	if (position - cameraPosition()).Magnitude > ARENA_DRAW_DISTANCE then
		return
	end
	entry.animator.update(entry.cframe, dt, {
		mode = state,
		speed = entry.speed,
		turn = entry.turn,
		lookYaw = if state == "Chase" then chaseLook(entry) else 0,
		enraged = entry.source:GetAttribute("BaraoEnraged") == true,
	})
end

-- Carinho: um latido baixinho e corações subindo da cabeça.
local function celebratePet(model: Model)
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local soundId = GameConfig.Barao.BarkSoundIds[1]
	if soundId ~= nil then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = PET_BARK_VOLUME
		sound.PlaybackSpeed = 1.15
		sound.RollOffMaxDistance = 40
		sound.Parent = head
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, 5)
		sound:Play()
	end
	for index = 1, HEART_COUNT do
		task.delay((index - 1) * 0.18, function()
			if head.Parent == nil then
				return
			end
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(1.2, 1.2)
			gui.StudsOffsetWorldSpace = Vector3.new((index - 2) * 0.7, 1.2, 0)
			gui.MaxDistance = 60
			gui.Adornee = head
			gui.Parent = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = "💜"
			label.TextScaled = true
			label.Parent = gui
			local info = TweenInfo.new(HEART_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(gui, info, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, HEART_RISE, 0) }):Play()
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			Debris:AddItem(gui, HEART_SECONDS)
		end)
	end
end

-- Verdadeiro quando todas as peças do modelo (vindo do servidor) chegaram.
local function hasAllParts(model: Model): boolean
	local expected = model:GetAttribute(BaraoModel.PartCountAttribute)
	if typeof(expected) ~= "number" then
		return false
	end
	local count = 0
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			count += 1
		end
	end
	return count >= expected
end

local function addFriendly(instance: Instance)
	if not instance:IsA("Model") or friendly[instance] ~= nil or pending[instance] then
		return
	end
	local model = instance
	-- As peças chegam aos poucos: animar antes disso não moveria nada.
	pending[model] = true
	local waited = 0
	while not hasAllParts(model) and waited < PARTS_TIMEOUT and model.Parent ~= nil do
		waited += task.wait(PARTS_POLL)
	end
	pending[model] = nil
	if model.Parent == nil or friendly[model] ~= nil then
		return
	end
	if not hasAllParts(model) then
		report("friendly", "parts did not replicate in time")
		return
	end
	local restValue = model:GetAttribute(BaraoModel.RestAttribute)
	local rest = if typeof(restValue) == "CFrame" then restValue else model:GetPivot()
	local entry: FriendlyBarao = {
		model = model,
		rest = rest,
		-- Mede as peças a partir do descanso publicado pelo servidor (não do
		-- pivô do modelo, que pode chegar diferente no cliente).
		animator = BaraoAnimator.new(model, { zzz = false, effects = false }, rest),
		lastPet = counter(model, "BaraoPet"),
		happyUntil = 0,
	}
	model:GetAttributeChangedSignal("BaraoPet"):Connect(function()
		local value = counter(model, "BaraoPet")
		if value ~= entry.lastPet then
			entry.lastPet = value
			entry.happyUntil = os.clock() + BaraoModel.FriendlyHappySeconds
			entry.animator.pet()
			guarded("pet", function()
				celebratePet(model)
			end)
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
		turn = 0,
		lookYaw = if happy then lookAtLocal(entry.rest) else 0,
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
	local function add(instance: Instance)
		task.spawn(guarded, `add {tag}`, function()
			handler(instance)
		end)
	end
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
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
	-- Cada Barão e cada portinhola num pcall: um erro não para os outros.
	RunService.Heartbeat:Connect(function(dt: number)
		for _, entry in pairs(arena) do
			local ok, failure = pcall(stepArena, entry, dt)
			if not ok then
				report("arena", failure)
			end
		end
		for _, entry in pairs(friendly) do
			local ok, failure = pcall(stepFriendly, entry, dt)
			if not ok then
				report("friendly", failure)
			end
		end
		for _, door in pairs(doors) do
			local ok, failure = pcall(stepDoor, door, dt)
			if not ok then
				report("door", failure)
			end
		end
	end)
end

return table.freeze(BaraoVisualController)
