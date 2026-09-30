--!strict

-- Desenha os disparos do Puffador no cliente, a cada quadro: miolo, rastro
-- e partículas do Puff equipado, com a espiral/zigue-zague do formato e a
-- explosão no impacto. Só visual: quem decide o acerto é o servidor
-- (ProjectileService), que avisa onde cada disparo parou.
--
-- Pensado para rodar leve em celular:
--   * peças reaproveitadas (pool por Puff), nada criado por quadro;
--   * um raio (Raycast) por disparo por quadro para parar na parede;
--   * detalhe pela distância da câmera: perto tem tudo, no meio metade
--     das partículas, longe só o rastro, muito longe nem desenha;
--   * limite de disparos com partículas ao mesmo tempo e metade das
--     partículas nos gráficos baixos (1 a 3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local PuffEffects = require(ReplicatedStorage.Shared.modules.PuffEffects)

type PuffStyle = PuffTypes.PuffStyle

export type ShotSpec = {
	ownerUserId: number,
	origin: Vector3,
	aimOrigin: Vector3,
	direction: Vector3,
	puffId: string,
	color: Color3,
}

type Visual = {
	part: BasePart,
	trail: Trail,
	light: PointLight,
	emitters: { ParticleEmitter },
	baseRates: { number },
	puffId: string,
}

type Burst = {
	anchor: BasePart,
	emitters: { ParticleEmitter },
	puffId: string,
}

export type Shot = {
	id: number?,
	visual: Visual,
	style: PuffStyle,
	aimOrigin: Vector3,
	direction: Vector3,
	visualOffset: Vector3,
	distance: number,
	-- Até onde o disparo pode ir (alcance ou o ponto que o servidor avisou).
	limit: number,
	impactPosition: Vector3?,
	impactNormal: Vector3?,
	elapsed: number,
	particles: boolean,
	raycastParams: RaycastParams,
	-- Parou: fica visível mais um quadro (o rastro chega no ponto) e depois
	-- espera as partículas sumirem antes de voltar ao pool.
	stopping: boolean,
	lingering: number?,
}

local FOLDER_NAME = "PuffShotVisuals"
-- Disparo passa voando (220 studs/s): mais partículas e maiores que na vitrine.
local PARTICLE_RATE_SCALE = 2.5
local PARTICLE_SIZE_SCALE = 2.2
local TRAIL_WIDTH_SCALE = 1.5
local LINGER_SECONDS = 1
local POOL_LIMIT = 6
local BURST_POOL_LIMIT = 3
local NEAR_DISTANCE = 70
local MID_DISTANCE = 160
local DRAW_DISTANCE = 400
local IMPACT_DISTANCE = 250
local MAX_PARTICLE_SHOTS = 14
local LOW_QUALITY_LEVEL = 3
local QUALITY_CHECK_SECONDS = 5
local IMPACT_BURST_AMOUNT = 12
local IMPACT_SPARKS = 10
local BURST_SECONDS = 1.2
local IMPACT_FLASH_SECONDS = 0.3
local IMPACT_FLASH_START = 0.5
local IMPACT_FLASH_END = 2.6

local PuffShotRenderer = {}

local started = false
local folder: Folder? = nil
local active: { Shot } = {}
local byId: { [number]: Shot } = {}
local pool: { [string]: { Visual } } = {}
local burstPool: { [string]: { Burst } } = {}
local particleShots = 0
local lowQuality = false
local qualityClock = math.huge

local function getFolder(): Folder
	local current = folder
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	folder = created
	return created
end

local function refreshQuality()
	local ok, level = pcall(function(): EnumItem
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	local savedLow = ok and level ~= Enum.SavedQualitySetting.Automatic and level.Value <= LOW_QUALITY_LEVEL
	-- Celular quase sempre fica no Automático: conta como gráfico baixo.
	local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	lowQuality = savedLow or mobile
end

local function cameraPosition(): Vector3?
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.CFrame.Position else nil
end

local function newPart(name: string, diameter: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function buildVisual(puffId: string, style: PuffStyle): Visual
	local config = GameConfig.Puffador
	local part = newPart(PuffadorConstants.ProjectileName, config.ProjectileRadius * 2)

	local offset = config.ProjectileRadius * 0.55 * TRAIL_WIDTH_SCALE
	local front = Instance.new("Attachment")
	front.Name = "TrailFront"
	front.Position = Vector3.new(0, offset, 0)
	front.Parent = part
	local back = Instance.new("Attachment")
	back.Name = "TrailBack"
	back.Position = Vector3.new(0, -offset, 0)
	back.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = front
	trail.Attachment1 = back
	trail.Color = PuffEffects.trailColor(style)
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.WidthScale = NumberSequence.new(1, 0.25)
	trail.Lifetime = PuffEffects.trailLifetime(style)
	trail.LightEmission = 0.75
	trail.FaceCamera = true
	trail.Parent = part

	local emitters = PuffEffects.attach(part, style, PARTICLE_RATE_SCALE, PARTICLE_SIZE_SCALE)
	local baseRates: { number } = {}
	for index, emitter in ipairs(emitters) do
		baseRates[index] = emitter.Rate
	end

	local light = Instance.new("PointLight")
	light.Color = style.glow
	light.Brightness = 1.4
	light.Range = 8
	light.Shadows = false
	light.Parent = part

	return { part = part, trail = trail, light = light, emitters = emitters, baseRates = baseRates, puffId = puffId }
end

local function acquireVisual(puffId: string, style: PuffStyle): Visual
	local list = pool[puffId]
	local visual = if list ~= nil then table.remove(list) else nil
	return visual or buildVisual(puffId, style)
end

local function releaseVisual(visual: Visual)
	-- Pasta apagada por fora (a peça foi junto): não volta ao pool.
	if visual.part.Parent == nil then
		visual.part:Destroy()
		return
	end
	visual.part.Parent = nil
	local list = pool[visual.puffId]
	if list == nil then
		list = {}
		pool[visual.puffId] = list
	end
	if #list < POOL_LIMIT then
		table.insert(list, visual)
	else
		visual.part:Destroy()
	end
end

-- Explosão de partículas do Puff (e faíscas) no ponto do impacto.
local function buildBurst(puffId: string, style: PuffStyle): Burst
	local anchor = newPart("PuffBurst", 0.2)
	anchor.Transparency = 1
	local emitters = PuffEffects.attach(anchor, style, 0, PARTICLE_SIZE_SCALE)
	for _, emitter in ipairs(emitters) do
		emitter.Speed = NumberRange.new(emitter.Speed.Min + 4, emitter.Speed.Max + 8)
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.25, 0.45)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 5
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Transparency = NumberSequence.new(0, 1)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(style.spark, style.glow)
	sparks.LockedToPart = false
	sparks.Parent = anchor
	table.insert(emitters, sparks)
	return { anchor = anchor, emitters = emitters, puffId = puffId }
end

local function playImpact(position: Vector3, normal: Vector3, puffId: string, style: PuffStyle, rich: boolean)
	local parent = getFolder()
	local flash = newPart("PuffImpact", IMPACT_FLASH_START)
	flash.Color = style.glow:Lerp(PuffadorConstants.ProjectileColor, 0.5)
	flash.Transparency = 0.3
	flash.CFrame = CFrame.new(position)
	flash.Parent = parent
	local tween = TweenService:Create(flash, TweenInfo.new(IMPACT_FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(IMPACT_FLASH_END, IMPACT_FLASH_END, IMPACT_FLASH_END),
		Transparency = 1,
	})
	tween.Completed:Once(function()
		flash:Destroy()
	end)
	tween:Play()

	local list = burstPool[puffId]
	local burst = if list ~= nil then table.remove(list) else nil
	local current = burst or buildBurst(puffId, style)
	current.anchor.Position = position + (normal * 0.3)
	current.anchor.Parent = parent
	local scale = if rich then 1 else 0.5
	for _, emitter in ipairs(current.emitters) do
		local amount = if emitter.Name == "Sparks" then IMPACT_SPARKS else IMPACT_BURST_AMOUNT
		emitter:Emit(math.max(1, math.floor(amount * scale)))
	end
	task.delay(BURST_SECONDS, function()
		if current.anchor.Parent == nil then
			current.anchor:Destroy()
			return
		end
		current.anchor.Parent = nil
		local target = burstPool[puffId]
		if target == nil then
			target = {}
			burstPool[puffId] = target
		end
		if #target < BURST_POOL_LIMIT then
			table.insert(target, current)
		else
			current.anchor:Destroy()
		end
	end)
end

local function positionAt(shot: Shot, distance: number): Vector3
	local convergence = math.clamp(1 - (distance / GameConfig.Puffador.ProjectileConvergeDistance), 0, 1)
	return shot.aimOrigin
		+ (shot.direction * distance)
		+ (shot.visualOffset * convergence)
		+ PuffEffects.motionOffset(shot.style, shot.direction, distance)
end

-- Para o disparo em `distance`. O miolo continua visível neste quadro (o
-- rastro chega até o ponto); no próximo, some e o resto se apaga sozinho.
-- `stay` deixa o miolo onde está (disparo previsto que já passou do ponto).
local function stopShot(shot: Shot, distance: number, impactPosition: Vector3?, impactNormal: Vector3?, stay: boolean?)
	shot.distance = distance
	shot.stopping = true
	if not stay then
		shot.visual.part.Position = impactPosition or positionAt(shot, distance)
	end
	if impactPosition ~= nil and impactNormal ~= nil then
		local camera = cameraPosition()
		local far = if camera ~= nil then (impactPosition - camera).Magnitude else 0
		if far <= IMPACT_DISTANCE then
			playImpact(impactPosition, impactNormal, shot.visual.puffId, shot.style, far <= MID_DISTANCE and not lowQuality)
		end
	end
end

local function fadeOut(shot: Shot)
	local visual = shot.visual
	visual.part.Transparency = 1
	visual.trail.Enabled = false
	visual.light.Enabled = false
	for _, emitter in ipairs(visual.emitters) do
		emitter.Enabled = false
	end
	if shot.particles then
		particleShots -= 1
		shot.particles = false
	end
	local id = shot.id
	if id ~= nil and byId[id] == shot then
		byId[id] = nil
	end
	shot.stopping = false
	shot.lingering = LINGER_SECONDS
end

local function stepShot(shot: Shot, deltaTime: number): boolean
	local lingering = shot.lingering
	if lingering ~= nil then
		lingering -= deltaTime
		shot.lingering = lingering
		if lingering <= 0 then
			releaseVisual(shot.visual)
			return false
		end
		return true
	end
	if shot.stopping then
		fadeOut(shot)
		return true
	end

	local config = GameConfig.Puffador
	shot.elapsed += deltaTime
	local previous = shot.distance
	local step = config.ProjectileSpeed * deltaTime
	local from = shot.aimOrigin + (shot.direction * previous)
	local result = Workspace:Raycast(from, shot.direction * step, shot.raycastParams)
	if result ~= nil then
		local hitDistance = previous + (result.Position - from).Magnitude
		if hitDistance <= shot.limit then
			stopShot(shot, hitDistance, result.Position, result.Normal)
			return true
		end
	end
	local distance = previous + step
	if distance >= shot.limit then
		stopShot(shot, shot.limit, shot.impactPosition, shot.impactNormal)
		return true
	end
	if shot.elapsed >= config.ProjectileLifetime then
		stopShot(shot, distance, nil, nil)
		return true
	end
	shot.distance = distance
	shot.visual.part.Position = positionAt(shot, distance)
	return true
end

local function onHeartbeat(deltaTime: number)
	qualityClock += deltaTime
	if qualityClock >= QUALITY_CHECK_SECONDS then
		qualityClock = 0
		refreshQuality()
	end
	for index = #active, 1, -1 do
		local shot = active[index]
		local ok, alive = pcall(stepShot, shot, deltaTime)
		if not ok then
			warn(`[BlocoPuff] Shot visual failed: {alive}`)
			shot.visual.part:Destroy()
			if shot.particles then
				particleShots -= 1
			end
			local id = shot.id
			if id ~= nil and byId[id] == shot then
				byId[id] = nil
			end
			table.remove(active, index)
		elseif not alive then
			table.remove(active, index)
		end
	end
end

-- Começa a desenhar um disparo. `always` desenha mesmo longe (o disparo do
-- próprio jogador). Devolve nil quando está longe demais para valer a pena.
function PuffShotRenderer.spawn(spec: ShotSpec, always: boolean): Shot?
	local camera = cameraPosition()
	local far = if camera ~= nil then (spec.origin - camera).Magnitude else 0
	if far > DRAW_DISTANCE and not always then
		return nil
	end
	local definition = PuffCatalog.get(spec.puffId)
	local puffId = if definition ~= nil then definition.id else PuffCatalog.DefaultId
	local style = PuffCatalog.styleFor(puffId)
	local visual = acquireVisual(puffId, style)

	local rateFactor = if far <= NEAR_DISTANCE then 1 elseif far <= MID_DISTANCE then 0.5 else 0
	if lowQuality then
		rateFactor *= 0.5
	end
	local particles = rateFactor > 0 and #visual.emitters > 0 and particleShots < MAX_PARTICLE_SHOTS
	for index, emitter in ipairs(visual.emitters) do
		emitter.Rate = visual.baseRates[index] * rateFactor
		emitter.Enabled = particles
	end
	if particles then
		particleShots += 1
	end

	local part = visual.part
	part.Color = spec.color
	part.Transparency = 0
	part.Position = spec.origin
	part.Parent = getFolder()
	visual.trail:Clear()
	visual.trail.Enabled = true
	visual.light.Enabled = far <= NEAR_DISTANCE and not lowQuality

	local exclude: { Instance } = {}
	local owner = Players:GetPlayerByUserId(spec.ownerUserId)
	if owner ~= nil and owner.Character ~= nil then
		table.insert(exclude, owner.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	local shot: Shot = {
		id = nil,
		visual = visual,
		style = style,
		aimOrigin = spec.aimOrigin,
		direction = spec.direction,
		visualOffset = spec.origin - spec.aimOrigin,
		distance = 0,
		limit = GameConfig.Puffador.MaximumRange,
		impactPosition = nil,
		impactNormal = nil,
		elapsed = 0,
		particles = particles,
		raycastParams = params,
		stopping = false,
		lingering = nil,
	}
	table.insert(active, shot)
	return shot
end

-- Liga o disparo ao id do servidor (para receber onde ele parou).
function PuffShotRenderer.bind(shot: Shot, id: number, color: Color3)
	shot.id = id
	if shot.lingering == nil then
		byId[id] = shot
		shot.visual.part.Color = color
	end
end

-- O servidor avisou onde o disparo parou (e o impacto, se acertou algo).
function PuffShotRenderer.ended(id: number, distance: number, impactPosition: Vector3?, impactNormal: Vector3?)
	local shot = byId[id]
	if shot == nil or shot.stopping or shot.lingering ~= nil then
		return
	end
	local limit = math.min(shot.limit, math.max(0, distance))
	if shot.distance >= limit then
		-- O previsto já passou do ponto em que o servidor parou (acertou
		-- algo que o raio daqui não viu): para onde está, sem voltar.
		stopShot(shot, shot.distance, impactPosition, impactNormal, true)
		return
	end
	shot.limit = limit
	shot.impactPosition = impactPosition
	shot.impactNormal = impactNormal
end

-- Para tudo sem explosão (fim de rodada).
function PuffShotRenderer.clear()
	for _, shot in ipairs(active) do
		if shot.lingering == nil and not shot.stopping then
			stopShot(shot, shot.distance, nil, nil)
		end
	end
end

function PuffShotRenderer.start()
	if started then
		return
	end
	started = true
	refreshQuality()
	qualityClock = 0
	RunService.Heartbeat:Connect(onHeartbeat)
end

return table.freeze(PuffShotRenderer)
