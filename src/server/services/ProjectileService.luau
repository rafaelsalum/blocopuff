--!strict

-- Cria, simula e limpa os projéteis visuais do Puffador. Não conhece regras
-- de rodada, participantes ou o RemoteEvent de disparo: apenas recebe uma
-- origem e direção já validadas e devolve efeito visual ao impacto.
-- Nenhum dano, impulso ou destruição de blocos ocorre aqui.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ArenaService = require(script.Parent.ArenaService)

type BlockDestructionContext = ArenaService.BlockDestructionContext

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
	raycastParams: RaycastParams,
	spawnClock: number,
	distanceTraveled: number,
	onBlockHit: (() -> ())?,
}

local ProjectileService = {}

local projectileContainer: Folder? = nil
local activeProjectiles: { ProjectileRecord } = {}
local nextProjectileSequence = 0
local heartbeatConnection: RBXScriptConnection? = nil

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

local function createImpactEffect(position: Vector3, normal: Vector3)
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
		fragment.Color = PuffadorConstants.PuffadorAccentColor
		fragment.Parent = projectileContainer

		TweenService:Create(fragment, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
			Position = fragment.Position + (tangent * 2.4) + (normal * 0.8),
			Transparency = 1,
		}):Play()
		Debris:AddItem(fragment, 0.24)
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
			local previousPosition = record.part.Position

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
				local destroyedBlock = ArenaService.tryDestroyBlock(raycastResult.Instance, context)
				if destroyedBlock and record.onBlockHit ~= nil then
					record.onBlockHit()
				end
				createImpactEffect(raycastResult.Position, raycastResult.Normal)
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
			record.part.Position = previousPosition + displacement
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

function ProjectileService.spawn(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	roundId: number,
	onBlockHit: (() -> ())?
)
	if projectileContainer == nil then
		return
	end

	local config = GameConfig.Puffador
	local diameter = config.ProjectileRadius * 2

	local part = Instance.new("Part")
	part.Name = PuffadorConstants.ProjectileName
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.Color = PuffadorConstants.ProjectileColor
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
		ColorSequenceKeypoint.new(0, PuffadorConstants.PuffadorAccentColor),
		ColorSequenceKeypoint.new(1, PuffadorConstants.PuffadorPrimaryColor),
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
	glow.Color = PuffadorConstants.PuffadorAccentColor
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
		raycastParams = raycastParams,
		spawnClock = os.clock(),
		distanceTraveled = 0,
		onBlockHit = onBlockHit,
	}

	table.insert(activeProjectiles, record)
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
