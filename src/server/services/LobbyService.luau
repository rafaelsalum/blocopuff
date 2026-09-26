--!strict

-- O lobby é o próprio piso de cima da arena, dentro do prédio: o jogador já
-- nasce onde a partida acontece. Durante uma partida, quem não participa (ou
-- foi eliminado) renasce na galeria envidraçada e assiste sem interferir.
-- Ao final, todos voltam ao piso de cima já restaurado.

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
local floorSpawn: SpawnLocation? = nil
local gallerySpawn: SpawnLocation? = nil
local matchInProgress = false
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
	local spawn = if matchInProgress then gallerySpawn else floorSpawn
	if spawn ~= nil and spawn.Parent ~= nil then
		return spawn
	end
	return nil
end

local function assignActiveSpawn(player: Player)
	player.RespawnLocation = getActiveSpawn()
end

local function refreshSpawns()
	if floorSpawn ~= nil then
		floorSpawn.Enabled = not matchInProgress
	end
	if gallerySpawn ~= nil then
		gallerySpawn.Enabled = matchInProgress
	end
	for _, player in ipairs(Players:GetPlayers()) do
		assignActiveSpawn(player)
	end
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

local function getFloorSlots(): { CFrame }
	if currentArena == nil then
		return {}
	end
	return BuildingLayout.getFloorSpawnCFrames(currentArena, currentArena.FloorCount, TELEPORT_SLOT_COUNT)
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
		if player.RespawnLocation ~= nil and (player.RespawnLocation == floorSpawn or player.RespawnLocation == gallerySpawn) then
			player.RespawnLocation = nil
		end
	end

	if lobbyModel ~= nil and lobbyModel.Parent ~= nil and isOwned(lobbyModel) then
		lobbyModel:Destroy()
	elseif currentWorldRoot ~= nil then
		destroyOwnedChild(currentWorldRoot)
	end

	lobbyModel = nil
	floorSpawn = nil
	gallerySpawn = nil
	matchInProgress = false
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

	local topSurfaceY = BuildingLayout.getFloorSurfaceY(arena, arena.FloorCount)
	floorSpawn = createSpawn(model, "FloorSpawn", Vector3.new(arena.Position.X, topSurfaceY, arena.Position.Z))
	local gallery = BuildingLayout.getGallery(arena, building)
	gallerySpawn = createSpawn(model, "GallerySpawn", gallery.center)

	lobbyModel = model
	matchInProgress = false
	refreshSpawns()
	playerAddedConnection = Players.PlayerAdded:Connect(assignActiveSpawn)

	recoveryGeneration += 1
	local generation = recoveryGeneration
	task.spawn(function()
		recoverFallenSpectators(generation)
	end)

	return model
end

-- Chamado antes de posicionar os participantes: libera o piso de cima para
-- a partida, levando todos os demais jogadores para a galeria.
function LobbyService.beginMatch(participants: { Player })
	matchInProgress = true
	refreshSpawns()

	local isParticipant: { [Player]: boolean } = {}
	for _, player in ipairs(participants) do
		isParticipant[player] = true
	end

	local slots = getGallerySlots()
	if #slots == 0 then
		return
	end
	local slotIndex = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if not isParticipant[player] then
			slotIndex += 1
			moveCharacterTo(player, slots[((slotIndex - 1) % #slots) + 1])
		end
	end
end

-- Chamado depois que a arena foi restaurada: todos voltam ao piso de cima.
function LobbyService.endMatch()
	matchInProgress = false
	refreshSpawns()

	local slots = getFloorSlots()
	if #slots == 0 then
		return
	end
	for index, player in ipairs(Players:GetPlayers()) do
		moveCharacterTo(player, slots[((index - 1) % #slots) + 1])
	end
end

function LobbyService.getModel(): Model?
	return lobbyModel
end

return table.freeze(LobbyService)
