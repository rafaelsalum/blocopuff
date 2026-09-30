--!strict

-- Anima um modelo do Barão (BaraoModel) no cliente: cada peça gira em torno
-- da articulação do seu "osso" (corpo, cabeça, orelhas, língua, rabo e
-- patas) e tudo é movido de uma vez com BulkMoveTo.
--
-- Poses (o valor de `mode`):
--   Sleeping  → deitado, respirando, orelhas caídas, rabo enrolado, "Zzz";
--   (acordar) → espreguiça antes de sair;
--   Patrol    → trote (patas em diagonal) ou, parado, farejando o chão;
--   Chase     → galope, orelhas para trás, língua de fora, olha o alvo;
--   ToTunnel  → corre para a portinhola;
--   Celebrate → senta e abana o rabo depois de empurrar alguém.
-- Eventos: bark (pulinho e cabeça para cima), push (cabeçada e "AU AU!")
-- e pet (carinho no Barão do Jardim: pulo de alegria).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BaraoModel = require(ReplicatedStorage.Shared.modules.BaraoModel)

type Bone = BaraoModel.Bone

export type Input = {
	mode: string,
	speed: number,
	lookYaw: number,
	enraged: boolean,
}

export type Options = {
	zzz: boolean,
	effects: boolean,
}

export type Animator = {
	update: (root: CFrame, deltaTime: number, input: Input) -> (),
	bark: () -> (),
	push: () -> (),
	pet: () -> (),
	destroy: () -> (),
}

type Pose = {
	sink: number,
	bodyPitch: number,
	headPitch: number,
	headYaw: number,
	earPitch: number,
	earRoll: number,
	tailPitch: number,
	tailYaw: number,
	frontFold: number,
	backFold: number,
	trot: number,
	gallop: number,
	wagAmp: number,
	wagSpeed: number,
	tongue: number,
	sniff: number,
	sit: number,
}

local BLEND_RATE = 8
local STRETCH_SECONDS = 1.1
local BARK_SECONDS = 0.35
local PUSH_SECONDS = 0.4
local PET_SECONDS = 0.6
local BUBBLE_SECONDS = 1.1
local MOVING_SPEED = 0.6
local MAX_LOOK_YAW = 0.6
local TROT_STRIDE = 0.55
local GALLOP_STRIDE = 0.42
local ZZZ_FRAMES = { "z", "z Z", "z Z z" }
local ZZZ_FRAME_SECONDS = 0.5
local ENRAGED_EYE = Color3.fromRGB(235, 40, 40)
local BONES: { Bone } = { "Body", "Head", "EarL", "EarR", "Tongue", "Tail", "LegFL", "LegFR", "LegBL", "LegBR" }

local BaraoAnimator = {}

local function around(pivot: Vector3, rotation: CFrame): CFrame
	return CFrame.new(pivot) * rotation * CFrame.new(-pivot)
end

local function blank(): Pose
	return {
		sink = 0,
		bodyPitch = 0,
		headPitch = 0,
		headYaw = 0,
		earPitch = 0,
		earRoll = 0,
		tailPitch = 0,
		tailYaw = 0,
		frontFold = 0,
		backFold = 0,
		trot = 0,
		gallop = 0,
		wagAmp = 0.3,
		wagSpeed = 6,
		tongue = 0,
		sniff = 0,
		sit = 0,
	}
end

-- Pose alvo de cada estado (em radianos; `sink` em múltiplos da escala).
local function targetPose(mode: string, moving: boolean, stretching: boolean): Pose
	local pose = blank()
	if mode == "Sleeping" then
		pose.sink = -0.95
		pose.headPitch = -0.25
		pose.earPitch = 0.2
		pose.earRoll = 0.5
		pose.tailPitch = 0.9
		pose.tailYaw = 0.9
		pose.frontFold = 1.45
		pose.backFold = -1.45
		pose.wagAmp = 0.05
		pose.wagSpeed = 1.5
	elseif stretching then
		pose.sink = -0.3
		pose.bodyPitch = -0.3
		pose.frontFold = 1
		pose.headPitch = 0.25
		pose.wagAmp = 0.5
		pose.wagSpeed = 10
	elseif mode == "Celebrate" then
		pose.sink = -0.3
		pose.bodyPitch = 0.38
		pose.backFold = 1.25
		pose.headPitch = -0.3
		pose.wagAmp = 0.7
		pose.wagSpeed = 15
		pose.tongue = 0.35
		pose.sit = 1
	elseif mode == "Chase" or (mode == "ToTunnel" and moving) then
		pose.gallop = 1
		pose.headPitch = -0.1
		pose.earPitch = if mode == "Chase" then 0.8 else 0.3
		pose.earRoll = -0.1
		pose.tailPitch = 0.7
		pose.wagAmp = 0.15
		pose.wagSpeed = 12
		pose.tongue = 0.35
	elseif moving then
		pose.trot = 1
		pose.earRoll = 0.15
		pose.wagAmp = 0.45
		pose.wagSpeed = 9
	else
		pose.sniff = 1
		pose.headPitch = -0.5
		pose.earRoll = 0.2
		pose.wagAmp = 0.25
		pose.wagSpeed = 5
	end
	return pose
end

local function billboard(adornee: BasePart, name: string, offset: Vector3, text: string, color: Color3, maxDistance: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(3, 1.4)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
	gui.AlwaysOnTop = false
	gui.Enabled = false
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = gui
	return gui, label
end

function BaraoAnimator.new(model: Model, options: Options): Animator
	local scaleValue = model:GetAttribute(BaraoModel.ScaleAttribute)
	local scale = if typeof(scaleValue) == "number" then scaleValue else 1
	local basePivot = model:GetPivot()

	local parts: { BasePart } = {}
	local rest: { CFrame } = {}
	local bones: { Bone } = {}
	local eyes: { BasePart } = {}
	local head: BasePart? = nil
	for _, child in ipairs(model:GetChildren()) do
		local bone = child:GetAttribute(BaraoModel.BoneAttribute)
		if child:IsA("BasePart") and typeof(bone) == "string" then
			table.insert(parts, child)
			table.insert(rest, basePivot:Inverse() * child.CFrame)
			table.insert(bones, bone :: Bone)
			if child.Name == "Eye" then
				table.insert(eyes, child)
			elseif child.Name == "Head" then
				head = child
			end
		end
	end
	local pivots: { [Bone]: Vector3 } = {}
	for _, bone in ipairs(BONES) do
		pivots[bone] = BaraoModel.pivot(bone, scale)
	end
	local eyeColor = if #eyes > 0 then eyes[1].Color else Color3.new()

	local zzzGui: BillboardGui? = nil
	local zzzLabel: TextLabel? = nil
	local bubble: BillboardGui? = nil
	local smoke: ParticleEmitter? = nil
	local headPart = head
	if headPart ~= nil then
		if options.zzz then
			zzzGui, zzzLabel = billboard(headPart, "Zzz", Vector3.new(0, 1.6 * scale, 0), "z", Color3.fromRGB(200, 190, 235), 60)
		end
		if options.effects then
			bubble = billboard(headPart, "Bark", Vector3.new(0, 2 * scale, 0), "AU AU!", Color3.fromRGB(255, 220, 120), 80)
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emitter.Rate = 10
			emitter.Lifetime = NumberRange.new(0.5, 0.9)
			emitter.Speed = NumberRange.new(1.5, 3)
			emitter.SpreadAngle = Vector2.new(20, 20)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Size = NumberSequence.new(0.4 * scale, 1.1 * scale)
			emitter.Transparency = NumberSequence.new(0.35, 1)
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 140, 120))
			emitter.Enabled = false
			emitter.Parent = headPart
			smoke = emitter
		end
	end

	local pose = targetPose("Sleeping", false, false)
	local clock = 0
	local phase = 0
	local lastMode: string? = nil
	local stretchLeft = 0
	local barkLeft = 0
	local pushLeft = 0
	local petLeft = 0
	local bubbleLeft = 0
	local zzzClock = 0
	local enragedShown = false
	local cframes: { CFrame } = table.create(#parts)

	local function setEnraged(enraged: boolean)
		if enraged == enragedShown then
			return
		end
		enragedShown = enraged
		for _, eye in ipairs(eyes) do
			eye.Color = if enraged then ENRAGED_EYE else eyeColor
			eye.Material = if enraged then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
		local emitter = smoke
		if emitter ~= nil then
			emitter.Enabled = enraged
		end
	end

	local animator = {} :: Animator

	animator.update = function(root: CFrame, deltaTime: number, input: Input)
		local dt = math.min(deltaTime, 0.1)
		clock += dt
		-- Espreguiça só ao acordar para patrulhar (não ao entrar no alcance
		-- no meio de uma perseguição).
		if lastMode == "Sleeping" and input.mode == "Patrol" then
			stretchLeft = STRETCH_SECONDS
		end
		lastMode = input.mode
		stretchLeft = math.max(0, stretchLeft - dt)
		barkLeft = math.max(0, barkLeft - dt)
		pushLeft = math.max(0, pushLeft - dt)
		petLeft = math.max(0, petLeft - dt)
		setEnraged(input.enraged)

		local moving = input.speed > MOVING_SPEED
		local target = targetPose(input.mode, moving, stretchLeft > 0)
		local alpha = 1 - math.exp(-dt * BLEND_RATE)
		for key, value in pairs(target) do
			local current = (pose :: any)[key] :: number
			;(pose :: any)[key] = current + ((value - current) * alpha)
		end

		-- Passada: o ciclo avança pela distância andada.
		local stride = (pose.trot * TROT_STRIDE) + (pose.gallop * GALLOP_STRIDE)
		phase += input.speed * dt * stride
		local swing = math.sin(phase)
		local trotSwing = swing * 0.45 * pose.trot
		local gallopFront = swing * 0.7 * pose.gallop
		local gallopBack = math.sin(phase + math.pi) * 0.7 * pose.gallop
		local bob = math.abs(swing) * ((0.1 * pose.trot) + (0.2 * pose.gallop)) * scale
		if input.mode == "Sleeping" then
			bob += math.sin(clock * 1.6) * 0.03 * scale
		end

		local barkK = if barkLeft > 0 then math.sin(math.pi * (1 - (barkLeft / BARK_SECONDS))) else 0
		local pushK = if pushLeft > 0 then math.sin(math.pi * (1 - (pushLeft / PUSH_SECONDS))) else 0
		local petK = if petLeft > 0 then math.sin(math.pi * (1 - (petLeft / PET_SECONDS))) else 0
		local hop = ((barkK * 0.3) + (petK * 1.2)) * scale
		local lunge = -pushK * 0.7 * scale

		local headYaw = pose.headYaw
			+ (math.sin(clock * 2.4) * 0.5 * pose.sniff)
			+ (math.clamp(input.lookYaw, -MAX_LOOK_YAW, MAX_LOOK_YAW) * pose.gallop)
		local headPitch = pose.headPitch + (barkK * 0.35) - (pushK * 0.4) + (math.sin(clock * 9) * 0.04 * pose.sniff) + (math.sin(phase * 2) * 0.05 * pose.trot)
		local headRoll = math.sin(clock * 2.5) * 0.18 * pose.sit
		local bodyPitch = pose.bodyPitch + (swing * 0.07 * pose.gallop)
		local earPitch = pose.earPitch + (math.sin(phase * 2) * 0.1 * (pose.trot + pose.gallop))
		local tailYaw = pose.tailYaw + (math.sin(clock * pose.wagSpeed) * pose.wagAmp)

		local offset = CFrame.new(0, hop + bob + (pose.sink * scale), lunge)
		local body = offset * around(pivots.Body, CFrame.Angles(bodyPitch, 0, 0))
		local headCF = body * around(pivots.Head, CFrame.Angles(headPitch, headYaw, headRoll))
		local legOffset = CFrame.new(0, hop + (bob * 0.4) + (pose.sink * scale), lunge)
		local transforms: { [Bone]: CFrame } = {
			Body = body,
			Head = headCF,
			-- Orelha pende da articulação: pitch negativo leva a ponta para trás.
			EarL = headCF * around(pivots.EarL, CFrame.Angles(-earPitch, 0, -pose.earRoll)),
			EarR = headCF * around(pivots.EarR, CFrame.Angles(-earPitch, 0, pose.earRoll)),
			Tongue = headCF * around(pivots.Tongue, CFrame.Angles(pose.tongue + (math.sin(clock * 14) * 0.1 * pose.tongue), 0, 0)),
			Tail = body * around(pivots.Tail, CFrame.Angles(pose.tailPitch, tailYaw, 0)),
			LegFL = legOffset * around(pivots.LegFL, CFrame.Angles(pose.frontFold + trotSwing + gallopFront, 0, 0)),
			LegFR = legOffset * around(pivots.LegFR, CFrame.Angles(pose.frontFold - trotSwing + gallopFront, 0, 0)),
			LegBL = legOffset * around(pivots.LegBL, CFrame.Angles(pose.backFold - trotSwing + gallopBack, 0, 0)),
			LegBR = legOffset * around(pivots.LegBR, CFrame.Angles(pose.backFold + trotSwing + gallopBack, 0, 0)),
		}
		for index, part in ipairs(parts) do
			cframes[index] = root * transforms[bones[index]] * rest[index]
		end
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

		local gui = zzzGui
		local label = zzzLabel
		if gui ~= nil and label ~= nil then
			local sleeping = input.mode == "Sleeping"
			gui.Enabled = sleeping
			if sleeping then
				zzzClock += dt
				local frame = math.floor(zzzClock / ZZZ_FRAME_SECONDS) % #ZZZ_FRAMES + 1
				label.Text = ZZZ_FRAMES[frame]
			end
		end
		local barkBubble = bubble
		if barkBubble ~= nil then
			bubbleLeft = math.max(0, bubbleLeft - dt)
			barkBubble.Enabled = bubbleLeft > 0
		end
	end

	animator.bark = function()
		barkLeft = BARK_SECONDS
	end

	animator.push = function()
		pushLeft = PUSH_SECONDS
		bubbleLeft = BUBBLE_SECONDS
	end

	animator.pet = function()
		petLeft = PET_SECONDS
	end

	animator.destroy = function()
		local sleepGui = zzzGui
		if sleepGui ~= nil then
			sleepGui:Destroy()
		end
		local barkBubble = bubble
		if barkBubble ~= nil then
			barkBubble:Destroy()
		end
		local emitter = smoke
		if emitter ~= nil then
			emitter:Destroy()
		end
		setEnraged(false)
	end

	return animator
end

return table.freeze(BaraoAnimator)
