--!strict

-- Efeitos visuais de cada formato de Puff (PuffTypes.PuffEffect): partículas
-- que acompanham o disparo, a explosão no impacto, o desenho do rastro e o
-- movimento do projétil visual (espiral, zigue-zague). Só visual: o acerto
-- continua seguindo o raio da mira (ProjectileService), igual para todos.
--
-- Texturas: por enquanto só as nativas do Roblox. Quando chegarem as
-- texturas da Camada B (PNG 256 × 256, branco/cinza sobre transparente),
-- basta trocar os ids em TEXTURES; a cor de cada Puff é aplicada aqui.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)

type PuffEffect = PuffTypes.PuffEffect
type PuffStyle = PuffTypes.PuffStyle

export type EffectInfo = {
	label: string,
	icon: string,
}

local TEXTURES = table.freeze({
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
})

local INFO: { [PuffEffect]: EffectInfo } = table.freeze({
	Soft = { label = "Sopro", icon = "💨" },
	Sparkle = { label = "Brilhos", icon = "✨" },
	Bubbles = { label = "Bolhas", icon = "🔵" },
	Cloud = { label = "Nuvenzinha", icon = "☁️" },
	Flakes = { label = "Neve", icon = "❄️" },
	Zigzag = { label = "Raio", icon = "⚡" },
	Spiral = { label = "Espiral", icon = "🌀" },
	Confetti = { label = "Confete", icon = "🎉" },
	Flames = { label = "Chamas", icon = "🔥" },
	Rainbow = { label = "Arco-íris", icon = "🌈" },
})

-- Uma camada de partículas. `color` escolhe quais cores do Puff usar.
type Layer = {
	texture: string,
	rate: number,
	lifetime: NumberRange,
	size: NumberSequence,
	transparency: NumberSequence,
	speed: NumberRange,
	spread: number,
	acceleration: Vector3,
	drag: number,
	rotSpeed: NumberRange,
	lightEmission: number,
	color: "Trail" | "Spark" | "Start" | "End" | "White",
}

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

local function fade(start: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, start), NumberSequenceKeypoint.new(1, 1) })
end

local function layer(values: { [string]: any }): Layer
	return {
		texture = values.texture or TEXTURES.Sparkle,
		rate = values.rate or 20,
		lifetime = values.lifetime or NumberRange.new(0.3, 0.5),
		size = values.size or seq(0.35, 0),
		transparency = values.transparency or fade(0.1),
		speed = values.speed or NumberRange.new(0.5, 1.5),
		spread = values.spread or 180,
		acceleration = values.acceleration or Vector3.zero,
		drag = values.drag or 0,
		rotSpeed = values.rotSpeed or NumberRange.new(0, 0),
		lightEmission = values.lightEmission or 0.6,
		color = values.color or "Trail",
	}
end

local LAYERS: { [PuffEffect]: { Layer } } = {
	Soft = {},
	Sparkle = { layer({ rate = 30, color = "Spark", lightEmission = 1 }) },
	Bubbles = { layer({ texture = TEXTURES.Smoke, rate = 18, size = seq(0.3, 0.55), transparency = fade(0.25), lifetime = NumberRange.new(0.5, 0.8), speed = NumberRange.new(0.3, 0.8), acceleration = Vector3.new(0, 4, 0), color = "Start", lightEmission = 0.3 }) },
	Cloud = { layer({ texture = TEXTURES.Smoke, rate = 24, size = seq(0.6, 1.4), transparency = fade(0.45), lifetime = NumberRange.new(0.4, 0.6), speed = NumberRange.new(0.2, 0.6), drag = 3, color = "Start", lightEmission = 0.1 }) },
	Flakes = { layer({ rate = 18, size = seq(0.3, 0.2), lifetime = NumberRange.new(0.7, 1), speed = NumberRange.new(0.3, 1), acceleration = Vector3.new(0, -3, 0), rotSpeed = NumberRange.new(90, 200), color = "White", lightEmission = 0.8 }) },
	Zigzag = { layer({ rate = 24, size = seq(0.25, 0), lifetime = NumberRange.new(0.15, 0.3), speed = NumberRange.new(2, 4), color = "Spark", lightEmission = 1 }) },
	Spiral = { layer({ rate = 20, size = seq(0.25, 0), lifetime = NumberRange.new(0.3, 0.5), speed = NumberRange.new(0.2, 0.6), color = "End", lightEmission = 1 }) },
	Confetti = {
		layer({ rate = 14, size = seq(0.22, 0.18), lifetime = NumberRange.new(0.6, 0.9), speed = NumberRange.new(1, 2.5), acceleration = Vector3.new(0, -6, 0), rotSpeed = NumberRange.new(-300, 300), color = "Start", lightEmission = 0.2 }),
		layer({ rate = 14, size = seq(0.22, 0.18), lifetime = NumberRange.new(0.6, 0.9), speed = NumberRange.new(1, 2.5), acceleration = Vector3.new(0, -6, 0), rotSpeed = NumberRange.new(-300, 300), color = "End", lightEmission = 0.2 }),
	},
	Flames = { layer({ texture = TEXTURES.Fire, rate = 40, size = seq(0.7, 0), lifetime = NumberRange.new(0.2, 0.35), speed = NumberRange.new(0.5, 1.5), acceleration = Vector3.new(0, 3, 0), color = "Trail", lightEmission = 1 }) },
	Rainbow = { layer({ rate = 16, size = seq(0.25, 0), color = "Spark", lightEmission = 1 }) },
}

-- Espiral: raio (studs) e voltas por stud; zigue-zague: amplitude e período.
local SPIRAL_RADIUS = 0.45
local SPIRAL_TURNS_PER_STUD = 0.2
local ZIGZAG_AMPLITUDE = 0.6
local ZIGZAG_PERIOD = 3
-- O desvio cresce nos primeiros studs, para o disparo sair do cano.
local MOTION_RAMP = 4

local PuffEffects = {}

function PuffEffects.info(effect: PuffEffect): EffectInfo
	return INFO[effect] or INFO.Soft
end

local function colorFor(style: PuffStyle, choice: string): ColorSequence
	if choice == "Spark" then
		return ColorSequence.new(style.spark, style.glow)
	elseif choice == "Start" then
		return ColorSequence.new(style.trailStart)
	elseif choice == "End" then
		return ColorSequence.new(style.trailEnd)
	elseif choice == "White" then
		return ColorSequence.new(Color3.new(1, 1, 1), style.trailEnd)
	end
	return ColorSequence.new(style.trailStart, style.trailEnd)
end

-- Cores do rastro (o Arco-íris usa o espectro inteiro).
function PuffEffects.trailColor(style: PuffStyle): ColorSequence
	if style.effect == "Rainbow" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 110)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 100)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 240, 150)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(110, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 130, 255)),
		})
	end
	return ColorSequence.new(style.trailStart, style.trailEnd)
end

-- Rastro mais largo e duradouro para os formatos que desenham no ar.
function PuffEffects.trailLifetime(style: PuffStyle): number
	if style.effect == "Spiral" or style.effect == "Rainbow" or style.effect == "Zigzag" then
		return 0.3
	end
	return 0.18
end

-- Cria os emissores do efeito em `part`. `rateScale` reduz a quantidade
-- (vitrine) ou zera (a explosão define a própria taxa).
function PuffEffects.attach(part: BasePart, style: PuffStyle, rateScale: number): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}
	for index, definition in ipairs(LAYERS[style.effect] or {}) do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = `PuffEffect{index}`
		emitter.Texture = definition.texture
		emitter.Rate = definition.rate * rateScale
		emitter.Lifetime = definition.lifetime
		emitter.Size = definition.size
		emitter.Transparency = definition.transparency
		emitter.Speed = definition.speed
		emitter.SpreadAngle = Vector2.new(definition.spread, definition.spread)
		emitter.Acceleration = definition.acceleration
		emitter.Drag = definition.drag
		emitter.RotSpeed = definition.rotSpeed
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.LightEmission = definition.lightEmission
		emitter.Color = colorFor(style, definition.color)
		emitter.LockedToPart = false
		emitter.Parent = part
		table.insert(emitters, emitter)
	end
	return emitters
end

-- Explosão de partículas do efeito num ponto (impacto). Some sozinha.
-- Em vez de :Emit (que no servidor pode acontecer antes de o emissor chegar
-- ao cliente), o emissor fica ligado por um instante com a taxa equivalente.
local BURST_SECONDS = 0.12

function PuffEffects.burst(parent: Instance, position: Vector3, style: PuffStyle, amount: number): BasePart?
	if #(LAYERS[style.effect] or {}) == 0 then
		return nil
	end
	local anchor = Instance.new("Part")
	anchor.Name = "PuffBurst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = parent
	local emitters = PuffEffects.attach(anchor, style, 0)
	for _, emitter in ipairs(emitters) do
		emitter.Speed = NumberRange.new(emitter.Speed.Min + 2, emitter.Speed.Max + 4)
		emitter.Rate = amount / BURST_SECONDS
	end
	task.delay(BURST_SECONDS, function()
		for _, emitter in ipairs(emitters) do
			if emitter.Parent ~= nil then
				emitter.Enabled = false
			end
		end
	end)
	return anchor
end

-- Desvio do projétil visual em relação à linha da mira, conforme o
-- formato (espiral ou zigue-zague), a `distance` studs do cano.
function PuffEffects.motionOffset(style: PuffStyle, direction: Vector3, distance: number): Vector3
	local effect = style.effect
	if effect ~= "Spiral" and effect ~= "Zigzag" then
		return Vector3.zero
	end
	local up = if math.abs(direction.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	local side = direction:Cross(up).Unit
	local ramp = math.clamp(distance / MOTION_RAMP, 0, 1)
	if effect == "Spiral" then
		local other = direction:Cross(side).Unit
		local angle = distance * SPIRAL_TURNS_PER_STUD * math.pi * 2
		return ((side * math.cos(angle)) + (other * math.sin(angle))) * SPIRAL_RADIUS * ramp
	end
	-- Onda triangular (vai e volta em linha reta, como um raio).
	local phase = (distance / ZIGZAG_PERIOD) % 1
	local wave = if phase < 0.5 then (phase * 4) - 1 else 3 - (phase * 4)
	return side * wave * ZIGZAG_AMPLITUDE * ramp
end

return table.freeze(PuffEffects)
