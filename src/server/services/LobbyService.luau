--!strict

-- O lobby usa diretamente a superfície caminhável da ilha. Este serviço
-- mantém o spawn autoritativo, encontra uma área segura do terreno e adiciona
-- proteções invisíveis na borda. O visual continua sendo somente o da ilha.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

type LobbyConfig = GameConfig.LobbyConfig
type WorldPalette = GameConfig.WorldPalette

local LOBBY_NAME = "Lobby"
local ISLAND_NAME = "SkyIslandLobby"
local ISLAND_SURFACE_NAME = "IslandSurface"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "LobbyService"
local RETURN_HEIGHT_OFFSET = 4
local SPAWN_SIZE = Vector3.new(6, 1, 6)
local SURFACE_SCAN_HEIGHT = 160
local SURFACE_SCAN_DEPTH = 320
local MINIMUM_SURFACE_NORMAL_Y = 0.72
local MAXIMUM_SPAWN_HEIGHT_VARIATION = 3
local SPAWN_CLEARANCE = 5
local BOUNDARY_SEGMENTS = 24
local BOUNDARY_RADIUS_X = 84
local BOUNDARY_RADIUS_Z = 76
local BOUNDARY_HEIGHT = 32
local BOUNDARY_THICKNESS = 3
local RECOVERY_DEPTH = 22
local RECOVERY_INTERVAL = 0.2
local ATTR_IS_PARTICIPANT = StateAttributeNames.PlayerIsParticipant

local SPAWN_CANDIDATE_OFFSETS: { Vector2 } = {
	Vector2.new(42, 22),
	Vector2.new(-42, 22),
	Vector2.new(42, -22),
	Vector2.new(-42, -22),
	Vector2.new(36, 0),
	Vector2.new(-36, 0),
	Vector2.new(0, 32),
	Vector2.new(0, -32),
	Vector2.new(-18, 0),
	Vector2.new(18, 0),
	Vector2.new(0, -18),
	Vector2.new(0, 18),
	Vector2.new(-18, -18),
	Vector2.new(18, -18),
	Vector2.new(-18, 18),
	Vector2.new(18, 18),
	Vector2.new(0, 0),
}

local CLEARANCE_SAMPLE_OFFSETS: { Vector2 } = {
	Vector2.new(0, 0),
	Vector2.new(-SPAWN_CLEARANCE, 0),
	Vector2.new(SPAWN_CLEARANCE, 0),
	Vector2.new(0, -SPAWN_CLEARANCE),
	Vector2.new(0, SPAWN_CLEARANCE),
}

local LobbyService = {}

local currentWorldRoot: Model? = nil
local lobbyModel: Model? = nil
local lobbySpawn: SpawnLocation? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local recoveryGeneration = 0

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function destroyOwnedChild(worldRoot: Model)
	local existing = worldRoot:FindFirstChild(LOBBY_NAME)
	if existing == nil then
		return
	end
	if not isOwned(existing) then
		error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
	end
	existing:Destroy()
end

local function raycastSurface(surface: BasePart, x: number, z: number, config: LobbyConfig): RaycastResult?
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { surface }
	raycastParams.IgnoreWater = true

	local origin = Vector3.new(x, config.Position.Y + SURFACE_SCAN_HEIGHT, z)
	return Workspace:Raycast(origin, Vector3.new(0, -SURFACE_SCAN_DEPTH, 0), raycastParams)
end

local function hasSpawnClearance(
	surface: BasePart,
	details: BasePart?,
	x: number,
	z: number,
	config: LobbyConfig,
	centerPosition: Vector3
): boolean
	for _, offset in ipairs(CLEARANCE_SAMPLE_OFFSETS) do
		local sample = raycastSurface(surface, x + offset.X, z + offset.Y, config)
		if sample == nil or sample.Normal.Y < MINIMUM_SURFACE_NORMAL_Y then
			return false
		end
		if math.abs(sample.Position.Y - centerPosition.Y) > MAXIMUM_SPAWN_HEIGHT_VARIATION then
			return false
		end
	end

	if details ~= nil then
		local detailsParams = RaycastParams.new()
		detailsParams.FilterType = Enum.RaycastFilterType.Include
		detailsParams.FilterDescendantsInstances = { details }
		detailsParams.IgnoreWater = true
		local origin = Vector3.new(x, config.Position.Y + SURFACE_SCAN_HEIGHT, z)
		local detailsHit = Workspace:Raycast(origin, Vector3.new(0, -SURFACE_SCAN_DEPTH, 0), detailsParams)
		if detailsHit ~= nil and detailsHit.Position.Y > centerPosition.Y + 2 then
			return false
		end
	end

	return true
end

local function findSafeIslandSurface(worldRoot: Model, config: LobbyConfig): Vector3
	local island = worldRoot:FindFirstChild(ISLAND_NAME)
	if island == nil or not island:IsA("Model") then
		error("Cannot create lobby: walkable sky island is unavailable")
	end

	local surface = island:FindFirstChild(ISLAND_SURFACE_NAME)
	if surface == nil or not surface:IsA("BasePart") then
		error("Cannot create lobby: island surface is unavailable")
	end
	local detailsInstance = island:FindFirstChild("TopDetails")
	local details = if detailsInstance ~= nil and detailsInstance:IsA("BasePart") then detailsInstance else nil

	for _, offset in ipairs(SPAWN_CANDIDATE_OFFSETS) do
		local x = config.Position.X + offset.X
		local z = config.Position.Z + offset.Y
		local result = raycastSurface(surface, x, z, config)
		if
			result ~= nil
			and result.Normal.Y >= MINIMUM_SURFACE_NORMAL_Y
			and hasSpawnClearance(surface, details, x, z, config, result.Position)
		then
			return result.Position
		end
	end

	error("Cannot create lobby: no safe walkable point was found on the island")
end

local function createBoundary(parent: Instance, center: Vector3)
	for index = 1, BOUNDARY_SEGMENTS do
		local firstAngle = ((index - 1) / BOUNDARY_SEGMENTS) * math.pi * 2
		local secondAngle = (index / BOUNDARY_SEGMENTS) * math.pi * 2
		local firstPoint = Vector3.new(
			center.X + math.cos(firstAngle) * BOUNDARY_RADIUS_X,
			center.Y + BOUNDARY_HEIGHT / 2,
			center.Z + math.sin(firstAngle) * BOUNDARY_RADIUS_Z
		)
		local secondPoint = Vector3.new(
			center.X + math.cos(secondAngle) * BOUNDARY_RADIUS_X,
			center.Y + BOUNDARY_HEIGHT / 2,
			center.Z + math.sin(secondAngle) * BOUNDARY_RADIUS_Z
		)
		local midpoint = (firstPoint + secondPoint) / 2
		local segment = Instance.new("Part")
		segment.Name = string.format("Boundary%02d", index)
		segment.Anchored = true
		segment.CanCollide = true
		segment.CanTouch = false
		segment.CanQuery = false
		segment.CastShadow = false
		segment.Transparency = 1
		segment.Size = Vector3.new(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, (secondPoint - firstPoint).Magnitude + 1)
		segment.CFrame = CFrame.lookAt(midpoint, secondPoint)
		segment.Parent = parent
	end
end

local function recoverFallenLobbyPlayers(generation: number)
	while generation == recoveryGeneration do
		local spawn = lobbySpawn
		if spawn ~= nil and spawn.Parent ~= nil then
			local recoveryY = spawn.Position.Y - RECOVERY_DEPTH
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute(ATTR_IS_PARTICIPANT) ~= true then
					local character = player.Character
					local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
					local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
					if
						rootPart ~= nil
						and rootPart:IsA("BasePart")
						and humanoid ~= nil
						and humanoid.Health > 0
						and rootPart.Position.Y < recoveryY
					then
						rootPart.AssemblyLinearVelocity = Vector3.zero
						rootPart.AssemblyAngularVelocity = Vector3.zero
						character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, RETURN_HEIGHT_OFFSET, 0)))
					end
				end
			end
		end
		task.wait(RECOVERY_INTERVAL)
	end
end

local function assignLobbySpawn(player: Player)
	if lobbySpawn ~= nil and lobbySpawn.Parent ~= nil then
		player.RespawnLocation = lobbySpawn
	end
end

function LobbyService.destroy()
	recoveryGeneration += 1
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end

	if lobbySpawn ~= nil then
		for _, player in ipairs(Players:GetPlayers()) do
			if player.RespawnLocation == lobbySpawn then
				player.RespawnLocation = nil
			end
		end
	end

	if lobbyModel ~= nil and lobbyModel.Parent ~= nil and isOwned(lobbyModel) then
		lobbyModel:Destroy()
	elseif currentWorldRoot ~= nil then
		destroyOwnedChild(currentWorldRoot)
	end

	lobbyModel = nil
	lobbySpawn = nil
	currentWorldRoot = nil
end

function LobbyService.create(worldRoot: Model, config: LobbyConfig, _palette: WorldPalette): Model
	LobbyService.destroy()
	destroyOwnedChild(worldRoot)
	currentWorldRoot = worldRoot

	local surfacePosition = findSafeIslandSurface(worldRoot, config)
	local model = Instance.new("Model")
	model.Name = LOBBY_NAME
	model:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	model.Parent = worldRoot

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.Size = SPAWN_SIZE
	spawn.Position = surfacePosition + Vector3.new(0, SPAWN_SIZE.Y / 2, 0)
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Parent = model
	createBoundary(model, Vector3.new(config.Position.X, surfacePosition.Y - 2, config.Position.Z))

	lobbyModel = model
	lobbySpawn = spawn

	for _, player in ipairs(Players:GetPlayers()) do
		assignLobbySpawn(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(assignLobbySpawn)
	recoveryGeneration += 1
	local generation = recoveryGeneration
	task.spawn(function()
		recoverFallenLobbyPlayers(generation)
	end)

	return model
end

function LobbyService.getModel(): Model?
	return lobbyModel
end

function LobbyService.getReturnCFrame(): CFrame?
	if lobbySpawn == nil or lobbySpawn.Parent == nil then
		return nil
	end
	return CFrame.new(lobbySpawn.Position + Vector3.new(0, RETURN_HEIGHT_OFFSET, 0))
end

return table.freeze(LobbyService)
