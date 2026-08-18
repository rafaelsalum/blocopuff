--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

type LobbyConfig = GameConfig.LobbyConfig
type WorldPalette = GameConfig.WorldPalette

local LOBBY_NAME = "Lobby"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "LobbyService"

local BARRIER_HEIGHT = 4
local BARRIER_THICKNESS = 1
local CONTAINMENT_HEIGHT = 18
local CONTAINMENT_THICKNESS = 2
local FOUNDATION_DEPTH = 4.5
local FOUNDATION_MARGIN = 4
local LOWER_CORE_DEPTH = 3.5
local CORNER_POST_HEIGHT = 7
local CORNER_POST_SIZE = 2
local SPAWN_SIZE = Vector3.new(8, 1, 8)
local RETURN_HEIGHT_OFFSET = 3

-- Acabamento do modelo oficial "Grass Baseplate" da Roblox, aplicado à
-- plataforma existente para evitar uma segunda superfície de colisão.
local GRASS_BASEPLATE_COLOR = Color3.fromRGB(58, 125, 21)
local GRASS_BASEPLATE_REFLECTANCE = 0.5

local LobbyService = {}

local currentWorldRoot: Model? = nil
local lobbyModel: Model? = nil
local lobbySpawn: SpawnLocation? = nil
local playerAddedConnection: RBXScriptConnection? = nil

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

local function createPart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.Size = size
	part.Position = position
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	return part
end

local function createContainmentPart(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.Position = position
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function assignLobbySpawn(player: Player)
	if lobbySpawn ~= nil and lobbySpawn.Parent ~= nil then
		player.RespawnLocation = lobbySpawn
	end
end

function LobbyService.destroy()
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
		local existing = currentWorldRoot:FindFirstChild(LOBBY_NAME)
		if existing ~= nil and isOwned(existing) then
			existing:Destroy()
		end
	end

	lobbyModel = nil
	lobbySpawn = nil
	currentWorldRoot = nil
end

function LobbyService.create(worldRoot: Model, config: LobbyConfig, palette: WorldPalette): Model
	LobbyService.destroy()
	destroyOwnedChild(worldRoot)

	currentWorldRoot = worldRoot

	local newLobby = Instance.new("Model")
	newLobby.Name = LOBBY_NAME
	newLobby:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newLobby.Parent = worldRoot

	local platform = createPart("Platform", config.PlatformSize, config.Position, palette.LightBlue, newLobby)
	platform.Color = GRASS_BASEPLATE_COLOR
	platform.Material = Enum.Material.Slate
	platform.Reflectance = GRASS_BASEPLATE_REFLECTANCE
	platform.TopSurface = Enum.SurfaceType.Studs
	platform.BottomSurface = Enum.SurfaceType.Inlet
	local platformTop = config.Position.Y + (config.PlatformSize.Y / 2)

	local foundationColor = palette.Purple:Lerp(Color3.fromRGB(78, 82, 105), 0.42)
	local foundation = createPart(
		"Foundation",
		Vector3.new(
			config.PlatformSize.X + FOUNDATION_MARGIN,
			FOUNDATION_DEPTH,
			config.PlatformSize.Z + FOUNDATION_MARGIN
		),
		Vector3.new(config.Position.X, config.Position.Y - (config.PlatformSize.Y / 2) - (FOUNDATION_DEPTH / 2), config.Position.Z),
		foundationColor,
		newLobby
	)
	foundation.CastShadow = true

	local lowerCore = createPart(
		"LowerCore",
		Vector3.new(config.PlatformSize.X - 8, LOWER_CORE_DEPTH, config.PlatformSize.Z - 8),
		Vector3.new(config.Position.X, foundation.Position.Y - (FOUNDATION_DEPTH / 2) - (LOWER_CORE_DEPTH / 2), config.Position.Z),
		palette.Purple:Lerp(Color3.fromRGB(58, 61, 82), 0.55),
		newLobby
	)
	lowerCore.CastShadow = true
	platform.CastShadow = true

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = SPAWN_SIZE
	spawn.Position = Vector3.new(config.Position.X, platformTop + (SPAWN_SIZE.Y / 2), config.Position.Z)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = palette.Pink
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Parent = newLobby
	lobbySpawn = spawn

	for _, player in ipairs(Players:GetPlayers()) do
		assignLobbySpawn(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(assignLobbySpawn)

	local barriers = Instance.new("Folder")
	barriers.Name = "Barriers"
	barriers.Parent = newLobby

	local barrierY = platformTop + (BARRIER_HEIGHT / 2)
	local halfWidth = config.PlatformSize.X / 2
	local halfDepth = config.PlatformSize.Z / 2
	local halfThickness = BARRIER_THICKNESS / 2

	local northBarrier = createPart(
		"North",
		Vector3.new(config.PlatformSize.X, BARRIER_HEIGHT, BARRIER_THICKNESS),
		Vector3.new(config.Position.X, barrierY, config.Position.Z - halfDepth + halfThickness),
		palette.Purple,
		barriers
	)
	local southBarrier = createPart(
		"South",
		Vector3.new(config.PlatformSize.X, BARRIER_HEIGHT, BARRIER_THICKNESS),
		Vector3.new(config.Position.X, barrierY, config.Position.Z + halfDepth - halfThickness),
		palette.Purple,
		barriers
	)
	local westBarrier = createPart(
		"West",
		Vector3.new(BARRIER_THICKNESS, BARRIER_HEIGHT, config.PlatformSize.Z),
		Vector3.new(config.Position.X - halfWidth + halfThickness, barrierY, config.Position.Z),
		palette.Purple,
		barriers
	)
	local eastBarrier = createPart(
		"East",
		Vector3.new(BARRIER_THICKNESS, BARRIER_HEIGHT, config.PlatformSize.Z),
		Vector3.new(config.Position.X + halfWidth - halfThickness, barrierY, config.Position.Z),
		palette.Purple,
		barriers
	)

	for _, barrier in ipairs({ northBarrier, southBarrier, westBarrier, eastBarrier }) do
		barrier.Color = barrier.Color:Lerp(Color3.fromRGB(75, 78, 103), 0.24)
		barrier.Transparency = 0.08
	end

	local cornerPosts = Instance.new("Folder")
	cornerPosts.Name = "CornerPosts"
	cornerPosts.Parent = newLobby
	local postY = platformTop + (CORNER_POST_HEIGHT / 2)
	local postInset = CORNER_POST_SIZE / 2
	for index, offset in ipairs({
		Vector3.new(-halfWidth + postInset, 0, -halfDepth + postInset),
		Vector3.new(halfWidth - postInset, 0, -halfDepth + postInset),
		Vector3.new(halfWidth - postInset, 0, halfDepth - postInset),
		Vector3.new(-halfWidth + postInset, 0, halfDepth - postInset),
	}) do
		local post = createPart(
			string.format("Post%02d", index),
			Vector3.new(CORNER_POST_SIZE, CORNER_POST_HEIGHT, CORNER_POST_SIZE),
			Vector3.new(config.Position.X, postY, config.Position.Z) + offset,
			foundationColor,
			cornerPosts
		)
		post.CastShadow = true
	end

	-- A cerca baixa comunica visualmente o limite, enquanto estas paredes
	-- invisíveis altas garantem que um salto normal não saia do lobby. Elas
	-- não participam de raycasts nem de eventos de toque.
	local containment = Instance.new("Folder")
	containment.Name = "Containment"
	containment.Parent = newLobby
	local containmentY = platformTop + (CONTAINMENT_HEIGHT / 2)
	local containmentHalfThickness = CONTAINMENT_THICKNESS / 2
	createContainmentPart(
		"North",
		Vector3.new(config.PlatformSize.X, CONTAINMENT_HEIGHT, CONTAINMENT_THICKNESS),
		Vector3.new(config.Position.X, containmentY, config.Position.Z - halfDepth + containmentHalfThickness),
		containment
	)
	createContainmentPart(
		"South",
		Vector3.new(config.PlatformSize.X, CONTAINMENT_HEIGHT, CONTAINMENT_THICKNESS),
		Vector3.new(config.Position.X, containmentY, config.Position.Z + halfDepth - containmentHalfThickness),
		containment
	)
	createContainmentPart(
		"West",
		Vector3.new(CONTAINMENT_THICKNESS, CONTAINMENT_HEIGHT, config.PlatformSize.Z),
		Vector3.new(config.Position.X - halfWidth + containmentHalfThickness, containmentY, config.Position.Z),
		containment
	)
	createContainmentPart(
		"East",
		Vector3.new(CONTAINMENT_THICKNESS, CONTAINMENT_HEIGHT, config.PlatformSize.Z),
		Vector3.new(config.Position.X + halfWidth - containmentHalfThickness, containmentY, config.Position.Z),
		containment
	)

	lobbyModel = newLobby
	return newLobby
end

function LobbyService.getModel(): Model?
	return lobbyModel
end

function LobbyService.getReturnCFrame(): CFrame?
	if lobbySpawn == nil or lobbySpawn.Parent == nil then
		return nil
	end

	local spawnTop = lobbySpawn.Position.Y + (lobbySpawn.Size.Y / 2)
	return CFrame.new(lobbySpawn.Position.X, spawnTop + RETURN_HEIGHT_OFFSET, lobbySpawn.Position.Z)
end

return table.freeze(LobbyService)
