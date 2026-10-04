--!strict

-- Portas do Casarão no cliente (Fase 5C.1). O servidor monta as folhas
-- fechadas (MansionDoors); aqui cada porta abre sozinha quando alguém (você,
-- outro jogador ou um bot) chega perto, para o lado oposto de quem chegou,
-- com rangido, e fecha batendo quando todos saem. As folhas não têm
-- colisão: a animação é só visual e cada cliente anima a sua.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

local CONFIG = MansionConfig.Door
-- Intervalo (s) entre as buscas de quem está perto.
local SCAN_INTERVAL = 0.1
-- Folhas que ainda não chegaram do servidor: novas tentativas.
local REGISTER_RETRIES = 10
local REGISTER_RETRY_DELAY = 1

type Piece = { part: BasePart, offset: CFrame }

type Leaf = {
	hinge: CFrame,
	panel: BasePart,
	pieces: { Piece },
	-- Centro da folha fechada, para decidir o lado de abrir.
	offset: CFrame,
	-- +1/-1: sentido do giro desta abertura.
	swing: number,
}

type Door = {
	model: Model,
	center: Vector3,
	normal: Vector3,
	leaves: { Leaf },
	-- 0 fechada, 1 aberta.
	progress: number,
	target: number,
	lastNear: number,
	sound: BasePart?,
}

local MansionDoorController = {}

local started = false
local doors: { [Model]: Door } = {}
local scanAccumulator = 0
-- Relógio próprio (soma dos quadros).
local elapsed = 0

local function readLeaf(leafModel: Instance): Leaf?
	if not leafModel:IsA("Model") then
		return nil
	end
	local hinge = leafModel:GetAttribute(CONFIG.HingeAttribute)
	if typeof(hinge) ~= "CFrame" then
		return nil
	end
	local pieces: { Piece } = {}
	local panel: BasePart? = nil
	for _, child in ipairs(leafModel:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(pieces, { part = child, offset = hinge:ToObjectSpace(child.CFrame) })
			if child.Name == "Panel" then
				panel = child
			end
		end
	end
	-- Ainda faltam peças chegando do servidor.
	if panel == nil or #pieces < (tonumber(leafModel:GetAttribute(CONFIG.PartCountAttribute)) or 1) then
		return nil
	end
	return { hinge = hinge, panel = panel, pieces = pieces, offset = hinge:ToObjectSpace(panel.CFrame), swing = 1 }
end

local function register(instance: Instance, attempt: number?)
	if not instance:IsA("Model") or doors[instance] ~= nil or instance.Parent == nil then
		return
	end
	local normal = instance:GetAttribute(CONFIG.NormalAttribute)
	if typeof(normal) ~= "Vector3" then
		return
	end
	local leaves: { Leaf } = {}
	local sum = Vector3.zero
	for _, child in ipairs(instance:GetChildren()) do
		local leaf = readLeaf(child)
		if leaf ~= nil then
			table.insert(leaves, leaf)
			sum += leaf.hinge.Position
		end
	end
	if #leaves < 2 then
		local tries = attempt or 0
		if tries < REGISTER_RETRIES then
			task.delay(REGISTER_RETRY_DELAY, register, instance, tries + 1)
		end
		return
	end
	doors[instance] = {
		model = instance,
		center = sum / #leaves,
		normal = normal,
		leaves = leaves,
		progress = 0,
		target = 0,
		lastNear = -math.huge,
		sound = leaves[1].panel,
	}
end

local function unregister(instance: Instance)
	if instance:IsA("Model") then
		doors[instance] = nil
	end
end

local function playSound(door: Door, soundId: string, speed: number)
	local parent = door.sound
	if parent == nil or parent.Parent == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = CONFIG.SoundVolume
	sound.RollOffMaxDistance = CONFIG.SoundRange
	sound.Parent = parent
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Ângulo da folha para o progresso `p` (rápido no fim do fechamento: bate).
local function angleFor(progress: number): number
	local eased = 1 - (1 - progress) ^ 2
	return math.rad(CONFIG.OpenAngle) * eased
end

local function pose(door: Door)
	local angle = angleFor(door.progress)
	for _, leaf in ipairs(door.leaves) do
		local turned = leaf.hinge * CFrame.Angles(0, angle * leaf.swing, 0)
		for _, piece in ipairs(leaf.pieces) do
			if piece.part.Parent ~= nil then
				piece.part.CFrame = turned * piece.offset
			end
		end
	end
end

-- Cada folha gira para o lado oposto de `toward` (quem chegou).
local function chooseSwing(door: Door, toward: Vector3)
	local side = if (toward - door.center):Dot(door.normal) >= 0 then 1 else -1
	local quarter = CFrame.Angles(0, math.rad(90), 0)
	for _, leaf in ipairs(door.leaves) do
		local opened = (leaf.hinge * quarter * leaf.offset).Position
		leaf.swing = if (opened - door.center):Dot(door.normal) * side < 0 then 1 else -1
	end
end

local function collectRoots(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	for _, bot in ipairs(CollectionService:GetTagged(StateAttributeNames.BotTag)) do
		local root = bot:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

-- Quem está mais perto da porta, dentro do raio (nil: ninguém).
local function nearest(door: Door, positions: { Vector3 }): Vector3?
	local best: Vector3? = nil
	local bestDistance = CONFIG.OpenRadius
	for _, position in ipairs(positions) do
		local offset = position - door.center
		local distance = Vector2.new(offset.X, offset.Z).Magnitude
		if distance <= bestDistance and offset.Y >= -2 and offset.Y <= MansionConfig.ArchHeight then
			best = position
			bestDistance = distance
		end
	end
	return best
end

local function scan(clock: number)
	local positions = collectRoots()
	for _, door in pairs(doors) do
		local who = nearest(door, positions)
		if who ~= nil then
			door.lastNear = clock
			if door.target == 0 then
				if door.progress <= 0 then
					chooseSwing(door, who)
					playSound(door, CONFIG.CreakSoundId, CONFIG.CreakSpeed)
				end
				door.target = 1
			end
		elseif door.target == 1 and clock - door.lastNear >= CONFIG.CloseDelay then
			door.target = 0
		end
	end
end

local function step(deltaTime: number)
	elapsed += deltaTime
	scanAccumulator += deltaTime
	if scanAccumulator >= SCAN_INTERVAL then
		scanAccumulator = 0
		scan(elapsed)
	end
	for model, door in pairs(doors) do
		if model.Parent == nil then
			doors[model] = nil
		elseif door.progress ~= door.target then
			if door.target > door.progress then
				door.progress = math.min(1, door.progress + deltaTime / CONFIG.OpenTime)
			else
				door.progress = math.max(0, door.progress - deltaTime / CONFIG.CloseTime)
				if door.progress <= 0 then
					playSound(door, CONFIG.SlamSoundId, CONFIG.SlamSpeed)
				end
			end
			pose(door)
		end
	end
end

function MansionDoorController.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(CONFIG.Tag):Connect(function(instance: Instance)
		register(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(CONFIG.Tag):Connect(unregister)
	for _, instance in ipairs(CollectionService:GetTagged(CONFIG.Tag)) do
		register(instance)
	end
	local warned = false
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local ok, err = pcall(step, deltaTime)
		if not ok and not warned then
			warned = true
			warn(`[BlocoPuff] Mansion doors step failed: {err}`)
		end
	end)
end

return table.freeze(MansionDoorController)
