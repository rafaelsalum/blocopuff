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

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "ProjectileService"

local IMPACT_EFFECT_LIFETIME = 0.35
local IMPACT_EFFECT_START_SIZE = 0.4
local IMPACT_EFFECT_END_SIZE = 2.2

type ProjectileRecord = {
	part: BasePart,
	ownerPlayer: Player,
	direction: Vector3,
	raycastParams: RaycastParams,
	spawnClock: number,
	distanceTraveled: number,
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
	effect.Material = Enum.Material.SmoothPlastic
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

function ProjectileService.spawn(player: Player, origin: Vector3, direction: Vector3, roundId: number)
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
	part.Material = Enum.Material.SmoothPlastic
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
		direction = direction,
		raycastParams = raycastParams,
		spawnClock = os.clock(),
		distanceTraveled = 0,
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
