--!strict

-- Anima um modelo do Barão (BaraoModel) no cliente: cada peça gira em torno
-- da articulação do seu "osso" (corpo, cabeça, orelhas, língua, rabo e
-- patas) e tudo é movido de uma vez com BulkMoveTo.
--
-- Andar natural:
--   * a passada acompanha a velocidade (o ciclo avança pela distância
--     andada, então as patas não "patinam");
--   * trote com as patas em diagonal e galope com as da frente e as de
--     trás juntas; a pata que vai à frente levanta do chão;
--   * o corpo sobe e desce (duas vezes por passo no trote, balançando
--     como cavalinho no galope) e inclina um pouco nas curvas;
--   * a cabeça compensa o balanço do corpo, e as orelhas e a língua
--     chacoalham com mola (atrasam em relação ao corpo).
--
-- Poses (o valor de `mode`):
--   Sleeping  → deitado, respirando, orelhas caídas, rabo enrolado, "Zzz";
--   (acordar) → espreguiça antes de patrulhar;
--   Patrol    → trote ou, parado, farejando o chão;
--   Chase     → galope, orelhas para trás, olha para quem persegue;
--   ToTunnel  → corre para a portinhola;
--   Celebrate → senta e abana o rabo.
-- Eventos: bark (pulinho e cabeça para cima), push (cabeçada e "AU AU!")
-- e pet (carinho no Barão do Jardim: pula e dá uma volta de alegria).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BaraoModel = require(ReplicatedStorage.Shared.modules.BaraoModel)

type Bone = BaraoModel.Bone

export type Input = {
	mode: string,
	speed: number,
	-- Velocidade de giro (rad/s), para inclinar nas curvas.
	turn: number,
	lookYaw: number,
	enraged: boolean,
}

export type Options = {
	zzz: boolean,
	effects: boolean,
}

export type Animator = {
	-- Quantas peças o animador move (0 = modelo ainda sem peças).
	partCount: number,
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
	look: number,
}

type Spring = { value: number, velocity: number }

local BLEND_RATE = 7
local STRETCH_SECONDS = 1.1
local BARK_SECONDS = 0.35
local PUSH_SECONDS = 0.4
local PET_SECONDS = 0.9
local BUBBLE_SECONDS = 1.1
-- Abaixo disso está parado (studs/s); a passada cresce até FULL_STRIDE_SPEED.
local MOVING_SPEED = 0.6
local FULL_STRIDE_SPEED = 5
local MAX_LOOK_YAW = 0.7
-- Distância (studs, tamanho 1) de um ciclo completo de passos.
local TROT_CYCLE = 2.4
local GALLOP_CYCLE = 3.6
local TROT_SWING = 0.55
local GALLOP_SWING = 0.8
local TROT_LIFT = 0.22
local GALLOP_LIFT = 0.32
local MAX_LEAN = 0.18
-- Mola das orelhas e da língua (rigidez e amortecimento).
local SPRING_STIFFNESS = 160
local SPRING_DAMPING = 9
local ZZZ_FRAMES = { "z", "z Z", "z Z z" }
local ZZZ_FRAME_SECONDS = 0.5
local ENRAGED_EYE = Color3.fromRGB(235, 40, 40)
local BONES: { Bone } = { "Body", "Head", "EarL", "EarR", "Tongue", "Tail", "LegFL", "LegFR", "LegBL", "LegBR" }
local TAU = math.pi * 2

local BaraoAnimator = {}

local function around(pivot: Vector3, rotation: CFrame): CFrame
	return CFrame.new(pivot) * rotation * CFrame.new(-pivot)
end

local function blank(): Pose
	return {
		sink = 0,
		bodyPitch = 0,
		headPitch = 0,
		earPitch = 0,
		earRoll = 0.12,
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
		look = 0,
	}
end

-- Pose alvo de cada estado (em radianos; `sink` em múltiplos da escala).
local function targetPose(mode: string, moving: boolean, stretching: boolean): Pose
	local pose = blank()
	if mode == "Sleeping" then
		pose.sink = -0.9
		pose.headPitch = -0.3
		pose.earPitch = 0.1
		pose.earRoll = 0.55
		pose.tailPitch = 0.9
		pose.tailYaw = 1
		pose.frontFold = 1.45
		pose.backFold = -1.45
		pose.wagAmp = 0.04
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
		pose.wagAmp = 0.75
		pose.wagSpeed = 16
		pose.tongue = 0.35
		pose.sit = 1
		pose.look = 1
	elseif mode == "Chase" or (mode == "ToTunnel" and moving) then
		pose.gallop = 1
		pose.headPitch = -0.12
		pose.earPitch = if mode == "Chase" then 0.75 else 0.35
		pose.earRoll = 0.05
		pose.tailPitch = 0.7
		pose.wagAmp = 0.18
		pose.wagSpeed = 12
		pose.tongue = 0.4
		pose.look = 1
	elseif moving then
		pose.trot = 1
		pose.earRoll = 0.18
		pose.wagAmp = 0.45
		pose.wagSpeed = 9
		pose.tongue = 0.15
	else
		pose.sniff = 1
		pose.headPitch = -0.5
		pose.earRoll = 0.22
		pose.wagAmp = 0.25
		pose.wagSpeed = 5
	end
	return pose
end

local function stepSpring(spring: Spring, target: number, dt: number)
	local acceleration = (SPRING_STIFFNESS * (target - spring.value)) - (SPRING_DAMPING * spring.velocity)
	spring.velocity += acceleration * dt
	spring.value += spring.velocity * dt
end

local function billboard(adornee: BasePart, name: string, offset: Vector3, text: string, color: Color3, maxDistance: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(3, 1.4)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
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

-- `origin` é onde o modelo está parado agora (padrão: o pivô dele); cada
-- peça é medida a partir dali.
function BaraoAnimator.new(model: Model, options: Options, origin: CFrame?): Animator
	local scaleValue = model:GetAttribute(BaraoModel.ScaleAttribute)
	local scale = if typeof(scaleValue) == "number" then scaleValue else 1
	local basePivot = origin or model:GetPivot()

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
	local lastBob = 0
	local lean = 0
	local stretchLeft = 0
	local barkLeft = 0
	local pushLeft = 0
	local petLeft = 0
	local bubbleLeft = 0
	local zzzClock = 0
	local enragedShown = false
	local earLeft: Spring = { value = 0, velocity = 0 }
	local earRight: Spring = { value = 0, velocity = 0 }
	local tongueSpring: Spring = { value = 0, velocity = 0 }
	local cframes: { CFrame } = table.create(#parts)
	local transforms: { [Bone]: CFrame } = {}

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

	local function eventCurve(left: number, duration: number): number
		return if left > 0 then math.sin(math.pi * (1 - (left / duration))) else 0
	end

	local animator = {} :: Animator
	animator.partCount = #parts

	animator.update = function(root: CFrame, deltaTime: number, input: Input)
		local dt = math.clamp(deltaTime, 1e-3, 0.1)
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
		local gaitWeight = pose.trot + pose.gallop
		local strideFactor = math.clamp(input.speed / FULL_STRIDE_SPEED, 0, 1)
		if gaitWeight > 0.01 then
			local cycle = ((pose.trot * TROT_CYCLE) + (pose.gallop * GALLOP_CYCLE)) / gaitWeight * scale
			phase = (phase + (input.speed * dt * TAU / cycle)) % TAU
		end
		local trot = pose.trot * strideFactor
		local gallop = pose.gallop * strideFactor

		local function leg(offsetTrot: number, offsetGallop: number): (number, number)
			local trotPhase = phase + offsetTrot
			local gallopPhase = phase + offsetGallop
			local angle = (math.sin(trotPhase) * TROT_SWING * trot) + (math.sin(gallopPhase) * GALLOP_SWING * gallop)
			local lift = (math.max(0, math.cos(trotPhase)) * TROT_LIFT * trot) + (math.max(0, math.cos(gallopPhase)) * GALLOP_LIFT * gallop)
			return angle, lift * scale
		end
		local flAngle, flLift = leg(0, 0)
		local frAngle, frLift = leg(math.pi, 0.4)
		local blAngle, blLift = leg(math.pi, math.pi + 0.2)
		local brAngle, brLift = leg(0, math.pi + 0.6)

		-- Corpo: sobe e desce (2× por ciclo no trote), balança no galope.
		local trotBob = (1 - math.cos(phase * 2)) * 0.5 * 0.1 * trot
		local gallopBob = (0.5 + (0.5 * math.sin(phase + 0.6))) * 0.28 * gallop
		local breathing = if input.mode == "Sleeping" then math.sin(clock * 1.6) * 0.03 else math.sin(clock * 2.2) * 0.008
		local bob = (trotBob + gallopBob + breathing) * scale
		local bobVelocity = (bob - lastBob) / dt
		lastBob = bob
		local rock = math.sin(phase) * 0.12 * gallop
		local sway = math.sin(phase) * 0.045 * trot
		-- Inclina para dentro da curva (giro positivo = para a esquerda).
		lean += (math.clamp(input.turn * 0.06, -MAX_LEAN, MAX_LEAN) - lean) * alpha

		local barkK = eventCurve(barkLeft, BARK_SECONDS)
		local pushK = eventCurve(pushLeft, PUSH_SECONDS)
		local petK = eventCurve(petLeft, PET_SECONDS)
		local petSpin = if petLeft > 0 then TAU * (1 - (petLeft / PET_SECONDS)) else 0
		local hop = ((barkK * 0.25) + (petK * 1.1)) * scale
		local lunge = -pushK * 0.7 * scale

		-- Orelhas e língua com mola: atrasam quando o corpo sobe e desce.
		local flop = math.clamp(-bobVelocity * 0.3, -0.5, 0.7)
		-- Nunca para dentro (a orelha entraria na cabeça).
		local earTarget = math.max(0, pose.earRoll + flop)
		stepSpring(earLeft, earTarget, dt)
		stepSpring(earRight, earTarget, dt)
		stepSpring(tongueSpring, pose.tongue + math.clamp(-bobVelocity * 0.2, -0.3, 0.4), dt)

		local headYaw = (math.sin(clock * 2.4) * 0.5 * pose.sniff) + (math.clamp(input.lookYaw, -MAX_LOOK_YAW, MAX_LOOK_YAW) * pose.look)
		local bodyPitch = pose.bodyPitch + rock
		local headPitch = pose.headPitch
			- (rock * 0.8)
			+ (barkK * 0.35)
			- (pushK * 0.4)
			+ (math.sin(clock * 9) * 0.04 * pose.sniff)
			+ (math.sin(phase * 2) * 0.04 * trot)
		local headRoll = (math.sin(clock * 2.5) * 0.18 * pose.sit) - (sway * 0.6)
		local tailYaw = pose.tailYaw + (math.sin(clock * pose.wagSpeed) * pose.wagAmp)
		local tailPitch = pose.tailPitch + (math.sin(phase) * 0.2 * gallop)

		local spin = CFrame.Angles(0, petSpin, 0)
		local offset = spin * CFrame.new(0, hop + bob + (pose.sink * scale), lunge)
		local body = offset * around(pivots.Body, CFrame.Angles(bodyPitch, 0, sway + lean))
		local headCF = body * around(pivots.Head, CFrame.Angles(headPitch, headYaw, headRoll))
		local legBase = spin * CFrame.new(0, hop + (bob * 0.35) + (pose.sink * scale), lunge)
		transforms.Body = body
		transforms.Head = headCF
		-- Orelha pende da articulação: pitch negativo leva a ponta para trás.
		transforms.EarL = headCF * around(pivots.EarL, CFrame.Angles(-pose.earPitch, 0, -earLeft.value))
		transforms.EarR = headCF * around(pivots.EarR, CFrame.Angles(-pose.earPitch, 0, earRight.value))
		transforms.Tongue = headCF * around(pivots.Tongue, CFrame.Angles(tongueSpring.value, 0, 0))
		-- O rabo fica em pé: abanar é girar de lado (em torno de Z).
		transforms.Tail = body * around(pivots.Tail, CFrame.Angles(tailPitch, 0, tailYaw))
		transforms.LegFL = legBase * CFrame.new(0, flLift, 0) * around(pivots.LegFL, CFrame.Angles(pose.frontFold + flAngle, 0, 0))
		transforms.LegFR = legBase * CFrame.new(0, frLift, 0) * around(pivots.LegFR, CFrame.Angles(pose.frontFold + frAngle, 0, 0))
		transforms.LegBL = legBase * CFrame.new(0, blLift, 0) * around(pivots.LegBL, CFrame.Angles(pose.backFold + blAngle, 0, 0))
		transforms.LegBR = legBase * CFrame.new(0, brLift, 0) * around(pivots.LegBR, CFrame.Angles(pose.backFold + brAngle, 0, 0))
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
