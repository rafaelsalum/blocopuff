--!strict

-- Prévia animada de um Puff no Puffdex: o Puff atravessa a janelinha em
-- loop deixando o rastro e as partículas do seu formato (brilhos, bolhas,
-- neve, raio, espiral, confete, chamas, arco-íris…). É 2D de propósito: o
-- ViewportFrame do Roblox não desenha partículas nem rastros. Quem anima é
-- o PuffdexView (chama `step` a cada quadro só com o painel aberto).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)
local UiTheme = require(script.Parent.UiTheme)

type PuffDefinition = PuffTypes.PuffDefinition
type PuffStyle = PuffTypes.PuffStyle

export type PuffPreviewHandle = {
	setPuff: (definition: PuffDefinition?, unlocked: boolean) -> (),
	step: (deltaTime: number) -> (),
	destroy: () -> (),
}

type Particle = {
	frame: Frame,
	position: Vector2,
	velocity: Vector2,
	gravity: number,
	age: number,
	life: number,
	size0: number,
	size1: number,
	spin: number,
	transparency0: number,
	stroke: UIStroke?,
}

local LOOP_SECONDS = 1.7
local ORB_SIZE = 22
local TRAIL_INTERVAL = 0.04
local PARTICLE_INTERVAL = 0.06
local MAX_PARTICLES = 60
-- Tamanho de referência da janelinha: posições e velocidades das partículas
-- ficam nessa escala e viram fração (fromScale), então acompanham o UIScale.
local NOMINAL_SIZE = Vector2.new(190, 90)
local LOCKED_COLOR = Color3.fromRGB(40, 32, 66)
local RAINBOW = {
	Color3.fromRGB(255, 110, 110),
	Color3.fromRGB(255, 210, 100),
	Color3.fromRGB(120, 240, 150),
	Color3.fromRGB(110, 170, 255),
	Color3.fromRGB(200, 130, 255),
}

local PuffPreview = {}

-- Posição do Puff na janelinha (0..1 nos dois eixos) no instante `t` do loop.
local function orbPath(style: PuffStyle, t: number): Vector2
	local x = 0.08 + (0.84 * t)
	local y = 0.5
	if style.effect == "Spiral" then
		y += 0.22 * math.sin(t * math.pi * 4)
	elseif style.effect == "Zigzag" then
		local phase = (t * 5) % 1
		local wave = if phase < 0.5 then (phase * 4) - 1 else 3 - (phase * 4)
		y += 0.2 * wave
	end
	return Vector2.new(x, y)
end

function PuffPreview.new(parent: GuiObject, zIndex: number): PuffPreviewHandle
	local root = Instance.new("Frame")
	root.Name = "PuffPreview"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(18, 14, 36)
	root.ClipsDescendants = true
	root.ZIndex = zIndex
	root.Parent = parent
	UiTheme.addCorner(root, 12)

	local orb = Instance.new("Frame")
	orb.Name = "Orb"
	orb.AnchorPoint = Vector2.new(0.5, 0.5)
	orb.Size = UDim2.fromOffset(ORB_SIZE, ORB_SIZE)
	orb.BackgroundColor3 = UiTheme.Colors.White
	orb.ZIndex = zIndex + 2
	orb.Parent = root
	UiTheme.addCorner(orb, 999)
	UiTheme.addStroke(orb, UiTheme.Colors.White, 1.5)
	local orbGradient = UiTheme.addGradient(orb, LOCKED_COLOR, LOCKED_COLOR, 45)

	local mark = UiTheme.createLabel(root, "Locked", "?", UiTheme.Fonts.Display, 30, UiTheme.Colors.InkSoft)
	mark.Size = UDim2.fromScale(1, 1)
	mark.ZIndex = zIndex + 3

	local style: PuffStyle? = nil
	local clock = 0
	local trailTimer = 0
	local particleTimer = 0
	local rainbowIndex = 0
	local particles: { Particle } = {}
	-- Quadros reaproveitados (sem criar e destruir dezenas por segundo).
	local pool: { Frame } = {}

	local function release(particle: Particle)
		local frame = particle.frame
		frame.Visible = false
		table.insert(pool, frame)
	end

	local function clearParticles()
		for _, particle in ipairs(particles) do
			release(particle)
		end
		table.clear(particles)
	end

	local function acquire(): (Frame, UICorner, UIStroke)
		local frame = table.remove(pool)
		if frame == nil then
			local created = Instance.new("Frame")
			created.AnchorPoint = Vector2.new(0.5, 0.5)
			created.BorderSizePixel = 0
			created.ZIndex = zIndex + 1
			local corner = Instance.new("UICorner")
			corner.Parent = created
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1.5
			stroke.Parent = created
			created.Parent = root
			frame = created
		end
		local found = frame :: Frame
		return found, found:FindFirstChildOfClass("UICorner") :: UICorner, found:FindFirstChildOfClass("UIStroke") :: UIStroke
	end

	local function emitParticle(color: Color3, position: Vector2, velocity: Vector2, options: { [string]: any })
		if #particles >= MAX_PARTICLES then
			return
		end
		local size0 = options.size0 or 8
		local frame, corner, stroke = acquire()
		local round = options.shape == "circle" or options.shape == "ring"
		local isRing = options.shape == "ring"
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = if isRing then 1 else 0
		frame.Size = UDim2.fromOffset(size0, size0)
		frame.Position = UDim2.fromScale(position.X / NOMINAL_SIZE.X, position.Y / NOMINAL_SIZE.Y)
		frame.Rotation = options.rotation or 0
		frame.Visible = true
		corner.CornerRadius = UDim.new(if round then 1 else 0, 0)
		stroke.Enabled = isRing
		stroke.Color = color
		stroke.Transparency = 0
		local ring: UIStroke? = if isRing then stroke else nil
		table.insert(particles, {
			frame = frame,
			position = position,
			velocity = velocity,
			gravity = options.gravity or 0,
			age = 0,
			life = options.life or 0.4,
			size0 = size0,
			size1 = options.size1 or 0,
			spin = options.spin or 0,
			transparency0 = options.transparency or 0,
			stroke = ring,
		})
	end

	local function randomVelocity(speed: number): Vector2
		local angle = math.random() * math.pi * 2
		return Vector2.new(math.cos(angle), math.sin(angle)) * speed * (0.5 + math.random())
	end

	-- Partículas do formato do Puff, saindo da posição (em NOMINAL_SIZE) do Puff.
	local function emitEffect(current: PuffStyle, at: Vector2)
		local effect = current.effect
		if effect == "Sparkle" or effect == "Rainbow" then
			local color = if effect == "Rainbow" then RAINBOW[math.random(1, #RAINBOW)] else current.spark
			emitParticle(color, at, randomVelocity(40), { size0 = 7, rotation = 45, life = 0.45 })
		elseif effect == "Bubbles" then
			emitParticle(current.trailStart, at, Vector2.new(math.random(-10, 10), -45), { shape = "ring", size0 = 7, size1 = 13, life = 0.7 })
		elseif effect == "Cloud" then
			emitParticle(current.trailStart, at, randomVelocity(12), { shape = "circle", size0 = 12, size1 = 24, life = 0.55, transparency = 0.45 })
		elseif effect == "Flakes" then
			emitParticle(Color3.new(1, 1, 1), at, Vector2.new(math.random(-12, 12), 30), { size0 = 6, size1 = 5, rotation = 45, spin = 180, life = 0.9 })
		elseif effect == "Zigzag" then
			emitParticle(current.spark, at, randomVelocity(70), { size0 = 10, size1 = 2, rotation = math.random(0, 180), life = 0.2 })
		elseif effect == "Spiral" then
			emitParticle(current.trailEnd, at, randomVelocity(10), { shape = "circle", size0 = 6, life = 0.5 })
		elseif effect == "Confetti" then
			local color = if math.random() < 0.5 then current.trailStart else current.trailEnd
			emitParticle(color, at, Vector2.new(math.random(-30, 30), -50), { size0 = 6, size1 = 5, spin = 360, gravity = 180, life = 0.9, rotation = math.random(0, 90) })
		elseif effect == "Flames" then
			emitParticle(current.trailStart:Lerp(current.trailEnd, math.random()), at, Vector2.new(math.random(-8, 8), -60), { shape = "circle", size0 = 12, size1 = 2, life = 0.35 })
		end
	end

	local handle = {} :: PuffPreviewHandle

	handle.setPuff = function(definition: PuffDefinition?, unlocked: boolean)
		clearParticles()
		clock = 0
		if definition == nil or not unlocked then
			style = nil
			orbGradient.Color = ColorSequence.new(LOCKED_COLOR, LOCKED_COLOR)
			orb.Position = UDim2.fromScale(0.5, 0.5)
			orb.Visible = false
			mark.Visible = true
			return
		end
		style = definition.style
		orbGradient.Color = ColorSequence.new(definition.style.trailStart, definition.style.trailEnd)
		orb.Visible = true
		mark.Visible = false
	end

	handle.step = function(deltaTime: number)
		local current = style
		if current ~= nil then
			clock = (clock + deltaTime) % LOOP_SECONDS
			local point = orbPath(current, clock / LOOP_SECONDS)
			orb.Position = UDim2.fromScale(point.X, point.Y)
			local at = Vector2.new(point.X * NOMINAL_SIZE.X, point.Y * NOMINAL_SIZE.Y)
			trailTimer += deltaTime
			if trailTimer >= TRAIL_INTERVAL then
				trailTimer = 0
				local color: Color3
				if current.effect == "Rainbow" then
					rainbowIndex = (rainbowIndex % #RAINBOW) + 1
					color = RAINBOW[rainbowIndex]
				else
					color = current.trailStart:Lerp(current.trailEnd, clock / LOOP_SECONDS)
				end
				emitParticle(color, at, Vector2.zero, { shape = "circle", size0 = 11, size1 = 2, life = 0.32, transparency = 0.15 })
			end
			particleTimer += deltaTime
			if particleTimer >= PARTICLE_INTERVAL then
				particleTimer = 0
				emitEffect(current, at)
			end
		end
		for index = #particles, 1, -1 do
			local particle = particles[index]
			particle.age += deltaTime
			local alpha = particle.age / particle.life
			if alpha >= 1 then
				release(particle)
				table.remove(particles, index)
			else
				particle.velocity += Vector2.new(0, particle.gravity * deltaTime)
				particle.position += particle.velocity * deltaTime
				local pixels = particle.size0 + ((particle.size1 - particle.size0) * alpha)
				particle.frame.Position = UDim2.fromScale(particle.position.X / NOMINAL_SIZE.X, particle.position.Y / NOMINAL_SIZE.Y)
				particle.frame.Size = UDim2.fromOffset(pixels, pixels)
				particle.frame.Rotation += particle.spin * deltaTime
				local transparency = particle.transparency0 + ((1 - particle.transparency0) * alpha)
				local stroke = particle.stroke
				if stroke ~= nil then
					stroke.Transparency = transparency
				else
					particle.frame.BackgroundTransparency = transparency
				end
			end
		end
	end

	handle.destroy = function()
		clearParticles()
		root:Destroy()
	end

	return handle
end

return table.freeze(PuffPreview)
