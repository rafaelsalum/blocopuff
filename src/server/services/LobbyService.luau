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
local SPAWN_SIZE = Vector3.new(8, 1, 8)
local RETURN_HEIGHT_OFFSET = 3

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

	createPart("Platform", config.PlatformSize, config.Position, palette.LightBlue, newLobby)
	local platformTop = config.Position.Y + (config.PlatformSize.Y / 2)

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
		barrier.Transparency = 0.15
	end

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
