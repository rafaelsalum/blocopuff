--!strict

-- Desenho da Janela Ventania num cliente (Fase 5, 5.2). Lê os atributos
-- que o servidor põe no vidro (TrapConstants) e mostra:
--   * pronta: um brilho leve no vidro (dá para atirar);
--   * trinca (tiro de perto): estalo e rachaduras que somem;
--   * aviso: rachaduras, vidro tremendo, cortinas inflando e vento rasteiro
--     no chão, no caminho da rajada;
--   * rajada: confete de vidro, vento entrando e cortinas batendo até a
--     janela ser pregada com tábuas.
-- O vidro some e as tábuas aparecem pelo servidor (vale para todos, mesmo
-- quem chega depois); aqui só ficam os efeitos passageiros. Nada colide nem
-- participa de raycasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)

local CONFIG = TrapConfig.Window
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
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

export type Handle = {
	update: (dt: number) -> (),
	destroy: () -> (),
}

type Curtain = {
	part: BasePart,
	rest: CFrame,
	angle: number,
}

local WindowTrapFx = {}

local function newSound(parent: Instance, soundId: string, speed: number, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.RollOffMaxDistance = 160
	sound.Parent = parent
	return sound
end

local function newEmitter(parent: Attachment, texture: string, color: Color3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.Enabled = false
	emitter.LightEmission = 0.4
	emitter.Parent = parent
	return emitter
end

function WindowTrapFx.new(glass: BasePart, effectsFolder: Folder): Handle
	local model = glass.Parent
	local restGlass = glass.CFrame
	local inwardValue = glass:GetAttribute(TrapConstants.InwardAttribute)
	local inward = if typeof(inwardValue) == "Vector3" and inwardValue.Magnitude > 1e-3 then inwardValue.Unit else glass.CFrame.LookVector

	-- Pontos de emissão: no vidro (brilho e confete) e no chão junto da
	-- parede, virado para dentro (vento).
	local anchor = Instance.new("Part")
	anchor.Name = "WindowTrapFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.lookAt(glass.Position, glass.Position + inward)
	anchor.Parent = effectsFolder

	local glassPoint = Instance.new("Attachment")
	glassPoint.Parent = anchor
	local floorPoint = Instance.new("Attachment")
	floorPoint.Parent = anchor
	local floor = glass:GetAttribute(TrapConstants.FloorAttribute)
	if typeof(floor) == "number" then
		local floorY = BuildingLayout.getFloorSurfaceY(GameConfig.Arena, floor)
		floorPoint.WorldPosition = Vector3.new(glass.Position.X, floorY + FLOOR_STREAK_HEIGHT, glass.Position.Z) + (inward * 0.5)
	end

	local sparkle = newEmitter(glassPoint, SPARKLE_TEXTURE, GLASS_COLOR)
	sparkle.Rate = 1.2
	sparkle.Lifetime = NumberRange.new(0.8, 1.2)
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Speed = NumberRange.new(0)
	sparkle.SpreadAngle = Vector2.new(0, 0)

	local shards = newEmitter(glassPoint, SPARKLE_TEXTURE, GLASS_COLOR)
	shards.Lifetime = NumberRange.new(0.6, 1.1)
	shards.Size = NumberSequence.new(0.45, 0.1)
	shards.Speed = NumberRange.new(16, 30)
	shards.SpreadAngle = Vector2.new(55, 55)
	shards.Acceleration = Vector3.new(0, -40, 0)
	shards.RotSpeed = NumberRange.new(-360, 360)
	shards.EmissionDirection = Enum.NormalId.Front

	local streaks = newEmitter(floorPoint, SMOKE_TEXTURE, Color3.new(1, 1, 1))
	streaks.Rate = 26
	streaks.Lifetime = NumberRange.new(0.7, 1)
	streaks.Size = NumberSequence.new(0.6, 1.4)
	streaks.Transparency = NumberSequence.new(0.6, 1)
	streaks.Speed = NumberRange.new(CONFIG.ConeLength * 0.9, CONFIG.ConeLength * 1.2)
	streaks.SpreadAngle = Vector2.new(CONFIG.ConeHalfAngle, 4)
	streaks.EmissionDirection = Enum.NormalId.Front

	local gust = newEmitter(glassPoint, SMOKE_TEXTURE, Color3.fromRGB(235, 245, 255))
	gust.Lifetime = NumberRange.new(0.5, 0.8)
	gust.Size = NumberSequence.new(1.5, 5)
	gust.Transparency = NumberSequence.new(0.45, 1)
	gust.Speed = NumberRange.new(40, 55)
	gust.SpreadAngle = Vector2.new(CONFIG.ConeHalfAngle, CONFIG.ConeHalfAngle * 0.6)
	gust.EmissionDirection = Enum.NormalId.Front

	local crackSound = newSound(anchor, CONFIG.CrackSoundId, 0.7, 0.8)
	local shatterSound = newSound(anchor, CONFIG.ShatterSoundId, 1.7, 1)
	local gustSound = newSound(anchor, CONFIG.GustSoundId, 0.6, 1)

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
		sparkle.Enabled = state == TrapConstants.Ready
		streaks.Enabled = state == TrapConstants.Warning
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
				gust:Emit(70)
				shatterSound:Play()
				gustSound:Play()
				openSince = clock
			end
		else
			clearCracks()
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
	applyState(nil, true)

	local handle = {} :: Handle

	handle.update = function(dt: number)
		clock += dt
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
		anchor:Destroy()
	end

	return handle
end

return table.freeze(WindowTrapFx)
