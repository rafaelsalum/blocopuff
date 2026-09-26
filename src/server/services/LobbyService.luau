--!strict

-- O lobby é a galeria envidraçada dentro do próprio prédio: todos nascem e
-- aguardam ali, vendo a arena. Ao iniciar a partida, só os participantes
-- descem para o piso de cima; eliminados renascem na galeria e, ao final,
-- os participantes restantes voltam para ela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

type ArenaConfig = GameConfig.ArenaConfig
type BuildingConfig = GameConfig.BuildingConfig

local LOBBY_NAME = "Lobby"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "LobbyService"
local SPAWN_SIZE = Vector3.new(6, 1, 6)
local TELEPORT_SLOT_COUNT = 16
local RECOVERY_INTERVAL = 0.2
local ATTR_IS_PARTICIPANT = StateAttributeNames.PlayerIsParticipant
local ATTR_IS_ELIMINATED = StateAttributeNames.PlayerIsEliminated

local LobbyService = {}

local currentWorldRoot: Model? = nil
local currentArena: ArenaConfig? = nil
local currentBuilding: BuildingConfig? = nil
local lobbyModel: Model? = nil
local gallerySpawn: SpawnLocation? = nil
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

local function createSpawn(parent: Instance, name: string, surfacePosition: Vector3): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.Size = SPAWN_SIZE
	spawn.Position = surfacePosition + Vector3.new(0, SPAWN_SIZE.Y / 2, 0)
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Parent = parent
	return spawn
end

local function getActiveSpawn(): SpawnLocation?
	local spawn = gallerySpawn
	if spawn ~= nil and spawn.Parent ~= nil then
		return spawn
	end
	return nil
end

local function assignActiveSpawn(player: Player)
	player.RespawnLocation = getActiveSpawn()
end

local function getLivingRoot(player: Player): (Model?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or rootPart == nil or not rootPart:IsA("BasePart") then
		return nil, nil
	end
	return character, rootPart
end

local function moveCharacterTo(player: Player, cframe: CFrame)
	local character, rootPart = getLivingRoot(player)
	if character == nil or rootPart == nil then
		return
	end

	local ok = pcall(function()
		character:PivotTo(cframe)
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end)
	if not ok then
		warn(string.format("[BlocoPuff] Failed to move %s inside the building", player.Name))
	end
end

local function getGallerySlots(): { CFrame }
	if currentArena == nil or currentBuilding == nil then
		return {}
	end
	return BuildingLayout.getGallerySpawnCFrames(currentArena, currentBuilding, TELEPORT_SLOT_COUNT)
end

local function isActiveCompetitor(player: Player): boolean
	return player:GetAttribute(ATTR_IS_PARTICIPANT) == true and player:GetAttribute(ATTR_IS_ELIMINATED) == false
end

-- Rede de segurança: quem não está competindo e acaba abaixo do piso mais
-- baixo volta para o ponto de nascimento atual em vez de ficar preso no poço.
local function recoverFallenSpectators(generation: number)
	while generation == recoveryGeneration do
		local arena = currentArena
		local spawn = getActiveSpawn()
		if arena ~= nil and spawn ~= nil then
			local recoveryY = BuildingLayout.getEliminationY(arena, GameConfig.EliminationZone.DepthBelowArena)
			for _, player in ipairs(Players:GetPlayers()) do
				if not isActiveCompetitor(player) then
					local _, rootPart = getLivingRoot(player)
					if rootPart ~= nil and rootPart.Position.Y < recoveryY then
						moveCharacterTo(player, CFrame.new(spawn.Position + Vector3.new(0, 4, 0)))
					end
				end
			end
		end
		task.wait(RECOVERY_INTERVAL)
	end
end

function LobbyService.destroy()
	recoveryGeneration += 1
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.RespawnLocation ~= nil and player.RespawnLocation == gallerySpawn then
			player.RespawnLocation = nil
		end
	end

	if lobbyModel ~= nil and lobbyModel.Parent ~= nil and isOwned(lobbyModel) then
		lobbyModel:Destroy()
	elseif currentWorldRoot ~= nil then
		destroyOwnedChild(currentWorldRoot)
	end

	lobbyModel = nil
	gallerySpawn = nil
	currentWorldRoot = nil
	currentArena = nil
	currentBuilding = nil
end

function LobbyService.create(worldRoot: Model, arena: ArenaConfig, building: BuildingConfig): Model
	LobbyService.destroy()
	destroyOwnedChild(worldRoot)
	currentWorldRoot = worldRoot
	currentArena = arena
	currentBuilding = building

	local model = Instance.new("Model")
	model.Name = LOBBY_NAME
	model:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	model.Parent = worldRoot

	local gallery = BuildingLayout.getGallery(arena, building)
	local spawn = createSpawn(model, "GallerySpawn", gallery.center)
	spawn.Enabled = true
	gallerySpawn = spawn

	lobbyModel = model
	for _, player in ipairs(Players:GetPlayers()) do
		assignActiveSpawn(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(assignActiveSpawn)

	recoveryGeneration += 1
	local generation = recoveryGeneration
	task.spawn(function()
		recoverFallenSpectators(generation)
	end)

	return model
end

-- Chamado quando a partida termina, antes de restaurar os pisos: quem
-- ainda está na arena volta para a galeria.
function LobbyService.returnToLobby(players: { Player })
	local slots = getGallerySlots()
	if #slots == 0 then
		return
	end
	for index, player in ipairs(players) do
		moveCharacterTo(player, slots[((index - 1) % #slots) + 1])
	end
end

function LobbyService.getModel(): Model?
	return lobbyModel
end

return table.freeze(LobbyService)
