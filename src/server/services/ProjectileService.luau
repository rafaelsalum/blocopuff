--!strict

-- Cria, simula e limpa os projéteis visuais do Puffador. Não conhece regras
-- de rodada, participantes ou o RemoteEvent de disparo: apenas recebe uma
-- origem e direção já validadas e devolve efeito visual ao impacto. O acerto
-- percorre o raio da mira; o projétil visível sai do cano e converge nele.
-- Acertos em blocos são repassados ao ArenaService; acertos em personagens
-- só são avisados ao handler registrado (sem dano aqui).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ArenaService = require(script.Parent.ArenaService)

type BlockDestructionContext = ArenaService.BlockDestructionContext
type PuffStyle = PuffTypes.PuffStyle

-- Chamado quando um projétil acerta o personagem de outro jogador. Quem
-- decide o efeito (empurrão, regra do cofre) são os serviços registrados.
export type CharacterHitHandler = (shooter: Player, victim: Player, position: Vector3, direction: Vector3, power: number) -> ()
-- Chamado quando o projétil acerta algo que não é bloco nem personagem
-- (ex.: um quadro na parede).
export type SurfaceHitHandler = (shooter: Player, instance: Instance, position: Vector3) -> ()

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "ProjectileService"

local IMPACT_EFFECT_LIFETIME = 0.35
local IMPACT_EFFECT_START_SIZE = 0.4
local IMPACT_EFFECT_END_SIZE = 2.2

type ProjectileRecord = {
	part: BasePart,
	ownerPlayer: Player,
	ownerUserId: number,
	roundId: number,
	projectileId: number,
	direction: Vector3,
	-- Posição autoritativa, que percorre o raio da mira (câmera → alvo).
	logicPosition: Vector3,
	-- Diferença entre o cano e a origem da mira; some ao longo da
	-- convergência para o projétil visual sair da arma e seguir a mira.
	visualOffset: Vector3,
	raycastParams: RaycastParams,
	spawnClock: number,
	distanceTraveled: number,
	onBlockHit: (() -> ())?,
	-- Blocos quebrados por acerto: 1 no Puffador comum, 2 no Super.
	power: number,
	-- Cores do Puff equipado (só visual).
	style: PuffStyle,
}

local ProjectileService = {}

local projectileContainer: Folder? = nil
local activeProjectiles: { ProjectileRecord } = {}
local nextProjectileSequence = 0
local heartbeatConnection: RBXScriptConnection? = nil
local characterHitHandlers: { [string]: CharacterHitHandler } = {}
local surfaceHitHandlers: { [string]: SurfaceHitHandler } = {}

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function removeProjectileAt(index: number)
	local record = activeProjectiles[index]
	if record == nil then
		return
	end

	table.remove(activeProjectiles, index)
	if record.part.Parent ~= nil then
		record.part:Destroy()
	end
end

local function createImpactEffect(position: Vector3, normal: Vector3, sparkColor: Color3)
	if projectileContainer == nil then
		return
	end

	local effect = Instance.new("Part")
	effect.Name = "PuffadorImpact"
	effect.Shape = Enum.PartType.Ball
	effect.Anchored = true
	effect.CanCollide = false
	effect.CanTouch = false
	effect.CanQuery = false
	effect.CastShadow = false
	effect.Material = Enum.Material.Neon
	effect.Color = PuffadorConstants.ProjectileColor
	effect.Transparency = 0.35
	effect.Size = Vector3.new(IMPACT_EFFECT_START_SIZE, IMPACT_EFFECT_START_SIZE, IMPACT_EFFECT_START_SIZE)
	effect.CFrame = CFrame.new(position, position + normal)
	effect.Parent = projectileContainer

	local growTween = TweenService:Create(
		effect,
		TweenInfo.new(IMPACT_EFFECT_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(IMPACT_EFFECT_END_SIZE, IMPACT_EFFECT_END_SIZE, IMPACT_EFFECT_END_SIZE),
			Transparency = 1,
		}
	)
	growTween:Play()

	Debris:AddItem(effect, IMPACT_EFFECT_LIFETIME)

	for fragmentIndex = 1, 4 do
		local angle = (math.pi * 2 * fragmentIndex) / 4
		local tangent = Vector3.new(math.cos(angle), 0.55, math.sin(angle)).Unit
		local fragment = Instance.new("Part")
		fragment.Name = "PuffadorSpark"
		fragment.Shape = Enum.PartType.Ball
		fragment.Size = Vector3.new(0.24, 0.24, 0.24)
		fragment.Position = position + (normal * 0.12)
		fragment.Anchored = true
		fragment.CanCollide = false
		fragment.CanTouch = false
		fragment.CanQuery = false
		fragment.CastShadow = false
		fragment.Material = Enum.Material.Neon
		fragment.Color = sparkColor
		fragment.Parent = projectileContainer

		TweenService:Create(fragment, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
			Position = fragment.Position + (tangent * 2.4) + (normal * 0.8),
			Transparency = 1,
		}):Play()
		Debris:AddItem(fragment, 0.24)
	end
end

-- Avisa os handlers do que foi atingido: personagem de outro jogador ou,
-- se não for personagem, a superfície.
local function notifyHit(record: ProjectileRecord, hitInstance: Instance, position: Vector3)
	local model = hitInstance:FindFirstAncestorOfClass("Model")
	while model ~= nil do
		local victim = Players:GetPlayerFromCharacter(model)
		if victim ~= nil then
			if victim ~= record.ownerPlayer then
				for _, handler in pairs(characterHitHandlers) do
					task.spawn(handler, record.ownerPlayer, victim, position, record.direction, record.power)
				end
			end
			return
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	for _, handler in pairs(surfaceHitHandlers) do
		task.spawn(handler, record.ownerPlayer, hitInstance, position)
	end
end

local function updateProjectiles(deltaTime: number)
	if #activeProjectiles == 0 then
		return
	end

	local config = GameConfig.Puffador

	for index = #activeProjectiles, 1, -1 do
		local record = activeProjectiles[index]

		local ok, keepAlive = pcall(function(): boolean
			if record.part.Parent == nil then
				return false
			end

			local displacement = record.direction * config.ProjectileSpeed * deltaTime
			local previousPosition = record.logicPosition

			local raycastResult = Workspace:Raycast(previousPosition, displacement, record.raycastParams)
			if raycastResult ~= nil then
				local context: BlockDestructionContext = {
					position = raycastResult.Position,
					normal = raycastResult.Normal,
					ownerPlayer = record.ownerPlayer,
					ownerUserId = record.ownerUserId,
					roundId = record.roundId,
					projectileId = record.projectileId,
				}
				local hitInstance = raycastResult.Instance
				local destroyedBlock = ArenaService.tryDestroyBlock(hitInstance, context)
				if destroyedBlock then
					if record.onBlockHit ~= nil then
						record.onBlockHit()
					end
					for _ = 2, record.power do
						local neighbor = ArenaService.getNeighborBlock(hitInstance, raycastResult.Position)
						if neighbor == nil or not ArenaService.tryDestroyBlock(neighbor, context) then
							break
						end
						if record.onBlockHit ~= nil then
							record.onBlockHit()
						end
					end
				else
					notifyHit(record, hitInstance, raycastResult.Position)
				end
				createImpactEffect(raycastResult.Position, raycastResult.Normal, record.style.spark)
				return false
			end

			local newDistance = record.distanceTraveled + displacement.Magnitude
			if newDistance >= config.MaximumRange then
				return false
			end

			if os.clock() - record.spawnClock >= config.ProjectileLifetime then
				return false
			end

			record.distanceTraveled = newDistance
			record.logicPosition = previousPosition + displacement
			local convergence = math.clamp(1 - (newDistance / config.ProjectileConvergeDistance), 0, 1)
			record.part.Position = record.logicPosition + (record.visualOffset * convergence)
			return true
		end)

		if not ok or keepAlive ~= true then
			removeProjectileAt(index)
		end
	end
end

function ProjectileService.start(worldRoot: Model)
	if projectileContainer ~= nil then
		return
	end

	local existing = worldRoot:FindFirstChild(PuffadorConstants.ProjectilesContainerName)
	if existing ~= nil then
		if not isOwned(existing) then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end

	local container = Instance.new("Folder")
	container.Name = PuffadorConstants.ProjectilesContainerName
	container:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	container.Parent = worldRoot

	projectileContainer = container
	nextProjectileSequence = 0
	table.clear(activeProjectiles)

	heartbeatConnection = RunService.Heartbeat:Connect(updateProjectiles)
end

-- `origin` é o cano (visual); `aimOrigin` é a origem validada do raio da
-- mira, por onde o acerto é decidido. `style` (Puff equipado) muda só o
-- rastro, o brilho e as faíscas: tamanho, velocidade, alcance e acerto são
-- iguais para todos, e o miolo do projétil continua bem visível.
function ProjectileService.spawn(
	player: Player,
	origin: Vector3,
	aimOrigin: Vector3,
	direction: Vector3,
	roundId: number,
	onBlockHit: (() -> ())?,
	power: number?,
	color: Color3?,
	style: PuffStyle?
)
	if projectileContainer == nil then
		return
	end

	local config = GameConfig.Puffador
	local diameter = config.ProjectileRadius * 2
	local puffStyle = style or PuffCatalog.styleFor(PuffCatalog.DefaultId)

	local part = Instance.new("Part")
	part.Name = PuffadorConstants.ProjectileName
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.Color = if color ~= nil then color else PuffadorConstants.ProjectileColor
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Position = origin

	nextProjectileSequence += 1
	local projectileId = nextProjectileSequence

	part:SetAttribute(PuffadorConstants.OwnerUserIdAttribute, player.UserId)
	part:SetAttribute(PuffadorConstants.RoundIdAttribute, roundId)
	part:SetAttribute(PuffadorConstants.ProjectileIdAttribute, projectileId)
	CollectionService:AddTag(part, PuffadorConstants.ProjectileTag)

	part.Parent = projectileContainer

	local trailFront = Instance.new("Attachment")
	trailFront.Name = "TrailFront"
	trailFront.Position = Vector3.new(0, config.ProjectileRadius * 0.55, 0)
	trailFront.Parent = part

	local trailBack = Instance.new("Attachment")
	trailBack.Name = "TrailBack"
	trailBack.Position = Vector3.new(0, -config.ProjectileRadius * 0.55, 0)
	trailBack.Parent = part

	local trail = Instance.new("Trail")
	trail.Name = "PuffTrail"
	trail.Attachment0 = trailFront
	trail.Attachment1 = trailBack
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, puffStyle.trailStart),
		ColorSequenceKeypoint.new(1, puffStyle.trailEnd),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.18
	trail.LightEmission = 0.75
	trail.FaceCamera = true
	trail.Parent = part

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = puffStyle.glow
	glow.Brightness = 1.2
	glow.Range = 7
	glow.Parent = part

	local filterInstances: { Instance } = { projectileContainer }
	local character = player.Character
	if character ~= nil then
		table.insert(filterInstances, character)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = filterInstances
	raycastParams.IgnoreWater = true

	local record: ProjectileRecord = {
		part = part,
		ownerPlayer = player,
		ownerUserId = player.UserId,
		roundId = roundId,
		projectileId = projectileId,
		direction = direction,
		logicPosition = aimOrigin,
		visualOffset = origin - aimOrigin,
		raycastParams = raycastParams,
		spawnClock = os.clock(),
		distanceTraveled = 0,
		onBlockHit = onBlockHit,
		power = math.clamp(math.floor(power or 1), 1, 4),
		style = puffStyle,
	}

	table.insert(activeProjectiles, record)
end

-- Registra (ou remove, com nil) um handler de acerto em personagem por chave.
function ProjectileService.setCharacterHitHandler(key: string, handler: CharacterHitHandler?)
	characterHitHandlers[key] = handler
end

function ProjectileService.setSurfaceHitHandler(key: string, handler: SurfaceHitHandler?)
	surfaceHitHandlers[key] = handler
end

function ProjectileService.clearAll()
	for index = #activeProjectiles, 1, -1 do
		removeProjectileAt(index)
	end
end

function ProjectileService.clearForPlayer(player: Player)
	for index = #activeProjectiles, 1, -1 do
		local record = activeProjectiles[index]
		if record.ownerPlayer == player then
			removeProjectileAt(index)
		end
	end
end

function ProjectileService.stop()
	table.clear(characterHitHandlers)
	table.clear(surfaceHitHandlers)
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	ProjectileService.clearAll()

	if projectileContainer ~= nil and projectileContainer.Parent ~= nil and isOwned(projectileContainer) then
		projectileContainer:Destroy()
	end
	projectileContainer = nil
end

return table.freeze(ProjectileService)
