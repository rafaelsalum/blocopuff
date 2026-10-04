--!strict

-- Desenho das janelas-armadilha num cliente (Fase 5, 5.2 e 5.6). Lê os
-- atributos que o servidor põe no vidro (TrapConstants) e mostra:
--   * pronta: um brilho leve no vidro (dá para atirar);
--   * trinca (tiro de perto): estalo e rachaduras que somem;
--   * aviso: rachaduras, vidro tremendo e cortinas inflando; na Ventania,
--     vento rasteiro no chão; nos Pombos, penas; na Chuva, respingos;
--   * efeito: confete de vidro e cortinas batendo até a janela ser
--     pregada com tábuas; na Ventania, o vento entrando; nos Pombos, o
--     bando atravessando a faixa (no mesmo relógio dos esbarrões do
--     servidor); na Chuva, chuva e poça no chão molhado enquanto durar.
-- O vidro some e as tábuas aparecem pelo servidor (vale para todos, mesmo
-- quem chega depois); aqui só ficam os efeitos passageiros. Nada colide nem
-- participa de raycasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local WindowGeometry = require(ReplicatedStorage.Shared.modules.WindowGeometry)
local TrapFxUtil = require(script.Parent.TrapFxUtil)

local CONFIG = TrapConfig.Window
local SPARKLE_TEXTURE = TrapFxUtil.SparkleTexture
local SMOKE_TEXTURE = TrapFxUtil.SmokeTexture
local GLASS_COLOR = Color3.fromRGB(190, 235, 255)
local CRACK_COLOR = Color3.fromRGB(245, 250, 255)
local CRACK_SHOW_TIME = 1.2
local CRACK_LINES_HIT = 3
local CRACK_LINES_WARNING = 7
local SHAKE_AMPLITUDE = 0.06
-- Só repete a quebra se ela aconteceu há pouco (quem chega depois não vê).
local REPLAY_WINDOW = 1
local CURTAIN_INFLATE = math.rad(22)
local CURTAIN_FLAP = math.rad(30)
local CURTAIN_FLAP_SPEED = 9
local CURTAIN_EASE = 8
local FLOOR_STREAK_HEIGHT = 0.6
local CURTAIN_REST_EPSILON = math.rad(0.5)
local PIGEON_BODY = Color3.fromRGB(125, 128, 140)
local PIGEON_HEAD = Color3.fromRGB(80, 95, 110)
local PIGEON_WING = Color3.fromRGB(205, 205, 212)
local PIGEON_MIN_HEIGHT = 2.6
local PIGEON_EXTRA_HEIGHT = 2.6
local PIGEON_FLAP_SPEED = 26
local PIGEON_FLAP = math.rad(55)
local PIGEON_FADE = 0.4
local RAIN_COLOR = Color3.fromRGB(170, 205, 255)
local PUDDLE_COLOR = Color3.fromRGB(70, 120, 190)
local PUDDLE_TRANSPARENCY = 0.55

export type Handle = {
	update: (dt: number) -> (),
	destroy: () -> (),
}

type Curtain = {
	part: BasePart,
	rest: CFrame,
	angle: number,
}

type Pigeon = {
	body: BasePart,
	head: BasePart,
	wings: { BasePart },
	-- Atraso dentro do bando (studs atrás da frente), lado e altura.
	behind: number,
	lateral: number,
	height: number,
	phase: number,
}

local function newPiece(parent: Instance, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	if shape ~= nil then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local WindowTrapFx = {}

function WindowTrapFx.new(glass: BasePart, effectsFolder: Folder): Handle
	local model = glass.Parent
	local restGlass = glass.CFrame
	local inwardValue = glass:GetAttribute(TrapConstants.InwardAttribute)
	local inward = if typeof(inwardValue) == "Vector3" and inwardValue.Magnitude > 1e-3 then inwardValue.Unit else glass.CFrame.LookVector

	-- Pontos de emissão: no vidro (brilho e confete) e no chão junto da
	-- parede, virado para dentro (vento).
	local anchor = TrapFxUtil.newAnchor(effectsFolder, "WindowTrapFx", CFrame.lookAt(glass.Position, glass.Position + inward))

	local glassPoint = Instance.new("Attachment")
	glassPoint.Parent = anchor
	local floorPoint = Instance.new("Attachment")
	floorPoint.Parent = anchor
	local floor = glass:GetAttribute(TrapConstants.FloorAttribute)
	if typeof(floor) == "number" then
		local floorY = BuildingLayout.getFloorSurfaceY(GameConfig.Arena, floor)
		floorPoint.WorldPosition = Vector3.new(glass.Position.X, floorY + FLOOR_STREAK_HEIGHT, glass.Position.Z) + (inward * 0.5)
	end

	local sparkle = TrapFxUtil.newReadySparkle(glassPoint, GLASS_COLOR)

	local shards = TrapFxUtil.newEmitter(glassPoint, SPARKLE_TEXTURE, GLASS_COLOR)
	shards.Lifetime = NumberRange.new(0.6, 1.1)
	shards.Size = NumberSequence.new(0.45, 0.1)
	shards.Speed = NumberRange.new(16, 30)
	shards.SpreadAngle = Vector2.new(55, 55)
	shards.Acceleration = Vector3.new(0, -40, 0)
	shards.RotSpeed = NumberRange.new(-360, 360)
	shards.EmissionDirection = Enum.NormalId.Front

	local streaks = TrapFxUtil.newEmitter(floorPoint, SMOKE_TEXTURE, Color3.new(1, 1, 1))
	streaks.Rate = 26
	streaks.Lifetime = NumberRange.new(0.7, 1)
	streaks.Size = NumberSequence.new(0.6, 1.4)
	streaks.Transparency = NumberSequence.new(0.6, 1)
	streaks.Speed = NumberRange.new(CONFIG.ConeLength * 0.9, CONFIG.ConeLength * 1.2)
	streaks.SpreadAngle = Vector2.new(CONFIG.ConeHalfAngle, 4)
	streaks.EmissionDirection = Enum.NormalId.Front

	local gust = TrapFxUtil.newEmitter(glassPoint, SMOKE_TEXTURE, Color3.fromRGB(235, 245, 255))
	gust.Lifetime = NumberRange.new(0.5, 0.8)
	gust.Size = NumberSequence.new(1.5, 5)
	gust.Transparency = NumberSequence.new(0.45, 1)
	gust.Speed = NumberRange.new(40, 55)
	gust.SpreadAngle = Vector2.new(CONFIG.ConeHalfAngle, CONFIG.ConeHalfAngle * 0.6)
	gust.EmissionDirection = Enum.NormalId.Front

	local crackSound = TrapFxUtil.newSound(anchor, CONFIG.CrackSoundId, 0.7, 0.8)
	local shatterSound = TrapFxUtil.newSound(anchor, CONFIG.ShatterSoundId, 1.7, 1)
	local gustSound = TrapFxUtil.newSound(anchor, CONFIG.GustSoundId, 0.6, 1)
	local flapSound = TrapFxUtil.newSound(anchor, CONFIG.FlapSoundId, 1.6, 0.9)
	local rainSound = TrapFxUtil.newSound(anchor, CONFIG.RainSoundId, 0.8, 0.9)
	rainSound.Looped = true

	-- Penas (aviso e saída dos Pombos) e respingos (aviso da Chuva).
	local feathers = TrapFxUtil.newEmitter(glassPoint, SPARKLE_TEXTURE, PIGEON_WING)
	feathers.LightEmission = 0
	feathers.Rate = 12
	feathers.Lifetime = NumberRange.new(0.8, 1.4)
	feathers.Size = NumberSequence.new(0.35, 0.2)
	feathers.Speed = NumberRange.new(2, 6)
	feathers.SpreadAngle = Vector2.new(60, 60)
	feathers.Acceleration = Vector3.new(0, -6, 0)
	feathers.RotSpeed = NumberRange.new(-200, 200)
	feathers.EmissionDirection = Enum.NormalId.Front
	local drizzle = TrapFxUtil.newEmitter(glassPoint, SPARKLE_TEXTURE, RAIN_COLOR)
	drizzle.Rate = 25
	drizzle.Lifetime = NumberRange.new(0.4, 0.7)
	drizzle.Size = NumberSequence.new(0.18, 0.08)
	drizzle.Speed = NumberRange.new(6, 12)
	drizzle.SpreadAngle = Vector2.new(30, 30)
	drizzle.Acceleration = Vector3.new(0, -50, 0)
	drizzle.EmissionDirection = Enum.NormalId.Front

	-- Chuva: um volume em cima do chão molhado e a poça (só neste cliente).
	local frame = WindowGeometry.frameOf(glass)
	local rainCloud: Part? = nil
	local rainFall: ParticleEmitter? = nil
	local puddle: Part? = nil
	if frame ~= nil then
		local middle = frame.base + (frame.inward * (CONFIG.RainLength / 2))
		local facing = CFrame.lookAt(middle, middle + frame.inward)
		local cloudPart = TrapFxUtil.newAnchor(effectsFolder, "WindowRain", facing + Vector3.new(0, CONFIG.RainHeight, 0))
		cloudPart.Size = Vector3.new(CONFIG.RainWidth, 0.2, CONFIG.RainLength)
		local fall = Instance.new("ParticleEmitter")
		fall.Texture = SPARKLE_TEXTURE
		fall.Color = ColorSequence.new(RAIN_COLOR)
		fall.LightEmission = 0.3
		fall.Shape = Enum.ParticleEmitterShape.Box
		fall.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		fall.EmissionDirection = Enum.NormalId.Bottom
		fall.Rate = 140
		fall.Lifetime = NumberRange.new(0.18, 0.26)
		fall.Speed = NumberRange.new(30, 40)
		fall.Size = NumberSequence.new(0.14, 0.08)
		fall.Enabled = false
		fall.Parent = cloudPart
		rainCloud = cloudPart
		rainFall = fall
		local puddlePart = newPiece(effectsFolder, "WindowPuddle", Vector3.new(CONFIG.RainWidth, 0.05, CONFIG.RainLength), PUDDLE_COLOR)
		puddlePart.Material = Enum.Material.Glass
		puddlePart.Transparency = 1
		puddlePart.CFrame = facing + Vector3.new(0, 0.06, 0)
		puddle = puddlePart
	end

	-- Bando de pombos (criado a cada acionamento, some no fim do voo).
	local flock: { Pigeon } = {}
	local flockFolder: Folder? = nil

	local curtains: { Curtain } = {}
	if model ~= nil then
		for _, name in ipairs(TrapConstants.WindowCurtainNames) do
			local part = model:FindFirstChild(name)
			if part ~= nil and part:IsA("BasePart") then
				table.insert(curtains, { part = part, rest = part.CFrame, angle = 0 })
			end
		end
	end

	local crackLines: { BasePart } = {}
	local crackHideAt = 0
	local random = Random.new()
	local state = glass:GetAttribute(TrapConstants.StateAttribute)
	local cracks = glass:GetAttribute(TrapConstants.CracksAttribute)
	local openSince: number? = nil
	local clock = 0
	local connections: { RBXScriptConnection } = {}

	local function clearCracks()
		for _, line in ipairs(crackLines) do
			line:Destroy()
		end
		table.clear(crackLines)
	end

	-- Rachaduras saindo de um ponto do vidro, do lado de dentro da sala.
	local function showCracks(count: number, duration: number?)
		clearCracks()
		local half = glass.Size / 2
		local origin = Vector3.new(random:NextNumber(-half.X, half.X) * 0.5, random:NextNumber(-half.Y, half.Y) * 0.5, 0)
		for index = 1, count do
			local angle = ((index / count) * math.pi * 2) + random:NextNumber(-0.3, 0.3)
			local length = random:NextNumber(0.8, 2.2)
			local line = Instance.new("Part")
			line.Name = "Crack"
			line.Anchored = true
			line.CanCollide = false
			line.CanQuery = false
			line.CanTouch = false
			line.CastShadow = false
			line.Material = Enum.Material.SmoothPlastic
			line.Color = CRACK_COLOR
			line.Transparency = 0.15
			line.Size = Vector3.new(0.06, length, 0.02)
			line.CFrame = restGlass * CFrame.new(origin) * CFrame.Angles(0, 0, angle) * CFrame.new(0, length / 2, -0.07)
			line.Parent = effectsFolder
			table.insert(crackLines, line)
		end
		crackHideAt = if duration ~= nil then clock + duration else math.huge
	end

	local function clearFlock()
		if flockFolder ~= nil then
			flockFolder:Destroy()
			flockFolder = nil
		end
		table.clear(flock)
	end

	local function spawnFlock()
		clearFlock()
		local folder = Instance.new("Folder")
		folder.Name = "Pigeons"
		folder.Parent = effectsFolder
		flockFolder = folder
		local halfWidth = CONFIG.PigeonLaneWidth / 2
		for index = 1, CONFIG.PigeonCount do
			local body = newPiece(folder, "Body", Vector3.new(0.7, 0.6, 1.1), PIGEON_BODY)
			local head = newPiece(folder, "Head", Vector3.new(0.5, 0.5, 0.5), PIGEON_HEAD, Enum.PartType.Ball)
			local wings = {
				newPiece(folder, "WingL", Vector3.new(1, 0.08, 0.6), PIGEON_WING),
				newPiece(folder, "WingR", Vector3.new(1, 0.08, 0.6), PIGEON_WING),
			}
			table.insert(flock, {
				body = body,
				head = head,
				wings = wings,
				behind = random:NextNumber(0, CONFIG.PigeonFlockLength),
				lateral = random:NextNumber(-halfWidth, halfWidth) * 0.85,
				height = PIGEON_MIN_HEIGHT + random:NextNumber(0, PIGEON_EXTRA_HEIGHT),
				phase = random:NextNumber(0, math.pi * 2) + index,
			})
		end
	end

	local variant = WindowGeometry.variantOf(glass)

	local function stateAge(): number
		local at = glass:GetAttribute(TrapConstants.StateAtAttribute)
		return if typeof(at) == "number" then Workspace:GetServerTimeNow() - at else math.huge
	end

	local function isBoarded(): boolean
		if model == nil then
			return false
		end
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") and string.sub(child.Name, 1, #TrapConstants.WindowBoardPrefix) == TrapConstants.WindowBoardPrefix and child.Transparency < 1 then
				return true
			end
		end
		return false
	end

	-- `silent`: estado de quem acabou de chegar (mostra, sem som nem quebra).
	local function applyState(previous: unknown, silent: boolean)
		local warning = state == TrapConstants.Warning
		sparkle.Enabled = state == TrapConstants.Ready
		streaks.Enabled = warning and variant == "Gust"
		feathers.Enabled = warning and variant == "Pigeons"
		drizzle.Enabled = warning and variant == "Rain"
		if state == TrapConstants.Warning then
			showCracks(CRACK_LINES_WARNING, nil)
			if not silent then
				crackSound:Play()
				task.delay(0.25, function()
					crackSound:Play()
				end)
			end
		elseif state == TrapConstants.Recharging or state == TrapConstants.Spent then
			clearCracks()
			glass.CFrame = restGlass
			if not silent and previous == TrapConstants.Warning and stateAge() < REPLAY_WINDOW then
				shards:Emit(45)
				shatterSound:Play()
				if variant == "Gust" then
					gust:Emit(70)
					gustSound:Play()
				elseif variant == "Pigeons" then
					feathers:Emit(30)
					flapSound:Play()
					spawnFlock()
				end
				openSince = clock
			end
		else
			clearCracks()
			clearFlock()
			glass.CFrame = restGlass
			openSince = nil
		end
	end

	local function onCracks()
		local current = glass:GetAttribute(TrapConstants.CracksAttribute)
		if typeof(current) == "number" and (typeof(cracks) ~= "number" or current > cracks) and state == TrapConstants.Ready then
			showCracks(CRACK_LINES_HIT, CRACK_SHOW_TIME)
			crackSound:Play()
		end
		cracks = current
	end

	local function onState()
		local previous = state
		state = glass:GetAttribute(TrapConstants.StateAttribute)
		applyState(previous, false)
	end

	table.insert(connections, glass:GetAttributeChangedSignal(TrapConstants.StateAttribute):Connect(onState))
	table.insert(connections, glass:GetAttributeChangedSignal(TrapConstants.CracksAttribute):Connect(onCracks))
	table.insert(connections, glass:GetAttributeChangedSignal(TrapConstants.WindowVariantAttribute):Connect(function()
		variant = WindowGeometry.variantOf(glass)
	end))
	applyState(nil, true)

	local handle = {} :: Handle

	-- Bando no mesmo relógio do servidor: a frente sai da janela e anda
	-- a faixa toda em PigeonFlightTime.
	local function updateFlock()
		if #flock == 0 or frame == nil then
			return
		end
		local age = stateAge()
		local total = CONFIG.PigeonFlightTime + PIGEON_FADE
		if state ~= TrapConstants.Recharging or age > total then
			clearFlock()
			return
		end
		local progress = math.clamp(age / CONFIG.PigeonFlightTime, 0, 1)
		local head = progress * (CONFIG.PigeonLaneLength + CONFIG.PigeonFlockLength)
		local fade = math.clamp((age - CONFIG.PigeonFlightTime) / PIGEON_FADE, 0, 1)
		for _, pigeon in ipairs(flock) do
			local depth = head - pigeon.behind
			local hidden = depth < -0.5 or fade >= 1
			local bob = math.sin((clock * 6) + pigeon.phase) * 0.25
			local position = frame.base + (frame.inward * depth) + (frame.along * pigeon.lateral) + Vector3.new(0, pigeon.height + bob, 0)
			local bodyFrame = CFrame.lookAt(position, position + frame.inward)
			local transparency = if hidden then 1 else fade
			pigeon.body.CFrame = bodyFrame
			pigeon.body.Transparency = transparency
			pigeon.head.CFrame = bodyFrame * CFrame.new(0, 0.3, -0.65)
			pigeon.head.Transparency = transparency
			local flap = math.sin((clock * PIGEON_FLAP_SPEED) + pigeon.phase) * PIGEON_FLAP
			for side, wing in ipairs(pigeon.wings) do
				local sign = if side == 1 then -1 else 1
				wing.CFrame = bodyFrame * CFrame.new(sign * 0.3, 0.15, 0) * CFrame.Angles(0, 0, sign * flap) * CFrame.new(sign * 0.5, 0, 0)
				wing.Transparency = transparency
			end
		end
	end

	-- Chuva enquanto o servidor disser (vale para quem chega depois).
	local raining = false
	local function updateRain()
		local rainUntil = glass:GetAttribute(TrapConstants.WindowRainUntilAttribute)
		local now = Workspace:GetServerTimeNow()
		local active = typeof(rainUntil) == "number" and now < rainUntil
		if active == raining then
			return
		end
		raining = active
		if rainFall ~= nil then
			rainFall.Enabled = active
		end
		if puddle ~= nil then
			puddle.Transparency = if active then PUDDLE_TRANSPARENCY else 1
		end
		if active then
			rainSound:Play()
		else
			rainSound:Stop()
		end
	end

	handle.update = function(dt: number)
		clock += dt
		updateFlock()
		updateRain()
		if clock >= crackHideAt then
			clearCracks()
			crackHideAt = math.huge
		end
		if state == TrapConstants.Warning then
			-- O vidro treme só neste cliente (o servidor não mexe nele).
			local shake = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), 0) * SHAKE_AMPLITUDE
			glass.CFrame = restGlass * CFrame.new(shake)
		end
		local flapping = openSince ~= nil and not isBoarded()
		if openSince ~= nil and not flapping then
			openSince = nil
		end
		for index, curtain in ipairs(curtains) do
			local target = 0
			if state == TrapConstants.Warning then
				target = CURTAIN_INFLATE
			elseif flapping then
				local phase = (clock * CURTAIN_FLAP_SPEED) + (index * 1.7)
				target = (CURTAIN_FLAP * 0.6) + (math.sin(phase) * CURTAIN_FLAP * 0.4)
			end
			if target == 0 and curtain.angle == 0 then
				continue
			end
			curtain.angle += (target - curtain.angle) * math.min(1, dt * CURTAIN_EASE)
			if target == 0 and math.abs(curtain.angle) < CURTAIN_REST_EPSILON then
				-- Parada: volta ao lugar e não é mais reescrita a cada quadro.
				curtain.angle = 0
				curtain.part.CFrame = curtain.rest
				continue
			end
			local height = curtain.part.Size.Y / 2
			-- Gira em torno do varão (borda de cima), para dentro da sala.
			curtain.part.CFrame = curtain.rest * CFrame.new(0, height, 0) * CFrame.Angles(curtain.angle, 0, 0) * CFrame.new(0, -height, 0)
		end
	end

	handle.destroy = function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		clearCracks()
		glass.CFrame = restGlass
		for _, curtain in ipairs(curtains) do
			curtain.part.CFrame = curtain.rest
		end
		clearFlock()
		rainSound:Stop()
		if rainCloud ~= nil then
			rainCloud:Destroy()
		end
		if puddle ~= nil then
			puddle:Destroy()
		end
		anchor:Destroy()
	end

	return handle
end

return table.freeze(WindowTrapFx)
