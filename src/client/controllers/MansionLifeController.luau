--!strict

-- Vida no Casarão no cliente (Fase 5C.4, parte 1):
--   * avisos do remote "MansionLife" (Fantasminha apareceu, quem pegou,
--     limite do dia e o presente do Barão);
--   * o Fantasminha (tag MansionLifeConfig.Ghost.Tag) flutua, balança e
--     vira para quem chega perto; dá risinhos de vez em quando e some numa
--     nuvenzinha quando alguém pega (ou quando o tempo acaba).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local MansionLifeConfig = require(ReplicatedStorage.Shared.config.MansionLifeConfig)
local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

type Ghost = {
	model: Model,
	base: CFrame,
	phase: number,
	yaw: number,
	nextGiggle: number,
	sound: Sound?,
}

local CONFIG = MansionLifeConfig.Ghost
local WAIT_TIMEOUT = 30
local DRAW_DISTANCE = 150
local BOB_HEIGHT = 0.5
local BOB_SPEED = 2.2
local SWAY_ANGLE = math.rad(14)
local SWAY_SPEED = 0.9
local TILT_ANGLE = math.rad(6)
local TILT_SPEED = 1.7
-- Vira para o jogador local quando ele chega a esta distância.
local FACE_DISTANCE = 22
local TURN_RATE = 3
local GIGGLE_MIN = 6
local GIGGLE_MAX = 11
local GIGGLE_VOLUME = 0.7
local GIGGLE_DISTANCE = 70
local CLAIM_VOLUME = 0.6
local POOF_COUNT = 24
local POOF_SECONDS = 2
local MAX_STEP = 0.1

local MansionLifeController = {}

local started = false
local ghosts: { [Model]: Ghost } = {}
local random = Random.new()

local function roomName(id: unknown): string
	for _, group in ipairs(RelicCatalog.rooms()) do
		if group.id == id then
			return `{group.emoji} {Lang.t(group.name)}`
		end
	end
	return Lang.t("Casarão")
end

local function notify(key: string, icon: string, title: string, subtitle: string, priority: NotificationManager.Priority, tone: NotificationManager.Tone)
	NotificationManager.notify({
		channel = "Banner",
		category = "MansionLife",
		priority = priority,
		key = key,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = tone,
		duration = 4,
		maxWait = 8,
	})
end

local function playSound(soundId: string, volume: number)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function count(value: unknown): number
	return if typeof(value) == "number" then math.clamp(math.floor(value), 0, 999) else 0
end

local function onEvent(kind: unknown, a: unknown, b: unknown, c: unknown)
	if kind == "GhostAppeared" then
		notify("ghost", "👻", Lang.t("Um Fantasminha apareceu!"), Lang.t("%s · o primeiro a encostar ganha 🎟", roomName(a)), "Low", "Info")
	elseif kind == "GhostClaimed" then
		notify("ghost", "👻", Lang.t("VOCÊ PEGOU O FANTASMINHA!"), Lang.t("+%d 🎟 · %d/%d hoje", count(a), count(b), count(c)), "High", "Gold")
		playSound(CONFIG.ClaimSoundId, CLAIM_VOLUME)
	elseif kind == "GhostCaught" then
		local name = if typeof(a) == "string" then string.sub(a, 1, 40) else "?"
		notify("ghost", "👻", Lang.t("%s pegou o Fantasminha!", name), Lang.t("Fique de olho: logo aparece outro"), "Low", "Info")
	elseif kind == "GhostLimit" then
		notify("ghost-limit", "👻", Lang.t("Você já pegou %d Fantasminhas hoje", count(a)), Lang.t("Amanhã tem mais!"), "Low", "Info")
	elseif kind == "BaraoGift" then
		notify("barao-gift", "🎁", Lang.t("PRESENTE DO BARÃO!"), Lang.t("Ele trouxe +%d 🎟 · %d/%d hoje", count(a), count(b), count(c)), "High", "Gold")
		playSound(CONFIG.ClaimSoundId, CLAIM_VOLUME)
	end
end

local function localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function cameraPosition(): Vector3
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.CFrame.Position else Vector3.zero
end

local function giggleSound(model: Model): Sound?
	if CONFIG.GiggleSoundId == "" then
		return nil
	end
	local body = model:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Giggle"
	sound.SoundId = CONFIG.GiggleSoundId
	sound.Volume = GIGGLE_VOLUME
	sound.RollOffMaxDistance = GIGGLE_DISTANCE
	sound.Parent = body
	sound:Play()
	return sound
end

-- Nuvenzinha branca onde o Fantasminha estava.
local function poof(position: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "GhostPoof"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(242, 246, 255))
	emitter.LightEmission = 0.4
	emitter.Size = NumberSequence.new(1.2, 2.4)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(POOF_COUNT)
	Debris:AddItem(holder, POOF_SECONDS)
end

local function addGhost(instance: Instance)
	if not instance:IsA("Model") or ghosts[instance] ~= nil then
		return
	end
	local baseValue = instance:GetAttribute(CONFIG.BaseAttribute)
	local base = if typeof(baseValue) == "CFrame" then baseValue else instance:GetPivot()
	local look = base.LookVector
	ghosts[instance] = {
		model = instance,
		base = base,
		phase = random:NextNumber() * math.pi * 2,
		yaw = math.atan2(-look.X, -look.Z),
		nextGiggle = os.clock() + random:NextNumber(GIGGLE_MIN, GIGGLE_MAX),
		sound = giggleSound(instance),
	}
end

local function removeGhost(instance: Instance)
	local ghost = if instance:IsA("Model") then ghosts[instance] else nil
	if ghost == nil then
		return
	end
	ghosts[instance :: Model] = nil
	if (ghost.base.Position - cameraPosition()).Magnitude <= DRAW_DISTANCE then
		poof(ghost.base.Position)
	end
end

local function stepGhost(ghost: Ghost, dt: number, clock: number)
	local base = ghost.base
	if (base.Position - cameraPosition()).Magnitude > DRAW_DISTANCE then
		return
	end
	local root = localRoot()
	local targetYaw = ghost.yaw
	if root ~= nil and (root.Position - base.Position).Magnitude <= FACE_DISTANCE then
		local offset = root.Position - base.Position
		targetYaw = math.atan2(-offset.X, -offset.Z)
	end
	local delta = (targetYaw - ghost.yaw + math.pi) % (math.pi * 2) - math.pi
	ghost.yaw += delta * (1 - math.exp(-dt * TURN_RATE))
	local t = clock + ghost.phase
	local bob = math.sin(t * BOB_SPEED) * BOB_HEIGHT
	local sway = math.sin(t * SWAY_SPEED) * SWAY_ANGLE
	local tilt = math.sin(t * TILT_SPEED) * TILT_ANGLE
	ghost.model:PivotTo(CFrame.new(base.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, ghost.yaw + sway, 0) * CFrame.Angles(0, 0, tilt))
	local sound = ghost.sound
	if sound ~= nil and clock >= ghost.nextGiggle then
		ghost.nextGiggle = clock + random:NextNumber(GIGGLE_MIN, GIGGLE_MAX)
		sound:Play()
	end
end

local function connectRemote()
	local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
	local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.MansionLifeRemoteName, WAIT_TIMEOUT) else nil
	if instance == nil or not instance:IsA("RemoteEvent") then
		warn("[BlocoPuff] Mansion life controller: remote not found")
		return
	end
	instance.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown, c: unknown)
		local ok, failure = pcall(onEvent, kind, a, b, c)
		if not ok then
			warn(`[BlocoPuff] Mansion life event failed: {failure}`)
		end
	end)
end

function MansionLifeController.start()
	if started then
		return
	end
	started = true
	for _, instance in ipairs(CollectionService:GetTagged(CONFIG.Tag)) do
		addGhost(instance)
	end
	CollectionService:GetInstanceAddedSignal(CONFIG.Tag):Connect(addGhost)
	CollectionService:GetInstanceRemovedSignal(CONFIG.Tag):Connect(removeGhost)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local dt = math.min(deltaTime, MAX_STEP)
		local clock = os.clock()
		for _, ghost in pairs(ghosts) do
			local ok, failure = pcall(stepGhost, ghost, dt, clock)
			if not ok then
				warn(`[BlocoPuff] Ghost animation failed: {failure}`)
				ghosts[ghost.model] = nil
			end
		end
	end)
	task.spawn(connectRemote)
end

return table.freeze(MansionLifeController)
