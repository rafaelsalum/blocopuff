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
-- Posições candidatas no lobby. Mais posições que jogadores permitem sempre
-- escolher um lugar livre, longe de quem já está na galeria.
local TELEPORT_SLOT_COUNT = 45
local SLOT_SPREAD_TOLERANCE = 0.85
local ROOT_WAIT_TIMEOUT = 5
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
local playerRemovingConnection: RBXScriptConnection? = nil
local characterConnections: { [Player]: RBXScriptConnection } = {}
local recoveryGeneration = 0
local slotRandom = Random.new()

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

-- Posições dos outros jogadores vivos que estão na galeria agora.
local function getOccupiedPositions(except: { [Player]: boolean }): { Vector3 }
	local arena = currentArena
	local building = currentBuilding
	if arena == nil or building == nil then
		return {}
	end
	local gallery = BuildingLayout.getGallery(arena, building)

	local occupied: { Vector3 } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if not except[player] then
			local _, rootPart = getLivingRoot(player)
			if rootPart ~= nil and rootPart.Position.X >= gallery.innerX and rootPart.Position.Y >= gallery.floorY - 2 then
				table.insert(occupied, rootPart.Position)
			end
		end
	end
	return occupied
end

local function getHorizontalDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Escolhe a posição do lobby mais distante de todos os ocupados (sorteando
-- entre as quase tão boas), garantindo que ninguém nasça em cima de outro.
local function pickFreeSlot(occupied: { Vector3 }): CFrame?
	local slots = getGallerySlots()
	if #slots == 0 then
		return nil
	end
	if #occupied == 0 then
		return slots[slotRandom:NextInteger(1, #slots)]
	end

	local distances: { number } = {}
	local best = 0
	for index, slot in ipairs(slots) do
		local nearest = math.huge
		for _, position in ipairs(occupied) do
			nearest = math.min(nearest, getHorizontalDistance(slot.Position, position))
		end
		distances[index] = nearest
		best = math.max(best, nearest)
	end

	local candidates: { CFrame } = {}
	for index, slot in ipairs(slots) do
		if distances[index] >= best * SLOT_SPREAD_TOLERANCE then
			table.insert(candidates, slot)
		end
	end
	return candidates[slotRandom:NextInteger(1, #candidates)]
end

-- Leva os jogadores para lugares livres do lobby, um de cada vez, contando
-- cada lugar já escolhido como ocupado para o próximo.
local function placeInLobby(players: { Player })
	local moving: { [Player]: boolean } = {}
	for _, player in ipairs(players) do
		moving[player] = true
	end
	local occupied = getOccupiedPositions(moving)

	for _, player in ipairs(players) do
		local slot = pickFreeSlot(occupied)
		if slot == nil then
			return
		end
		moveCharacterTo(player, slot)
		table.insert(occupied, slot.Position)
	end
end

-- Todo personagem nasce no único SpawnLocation do lobby; logo em seguida o
-- servidor o move para um lugar livre, evitando jogadores empilhados.
local function onCharacterAdded(player: Player, character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart", ROOT_WAIT_TIMEOUT)
	if rootPart == nil or character.Parent == nil then
		return
	end
	-- Aguarda o Roblox terminar de posicionar o personagem no SpawnLocation.
	task.wait()
	if player.Character ~= character or isActiveCompetitor(player) then
		return
	end
	placeInLobby({ player })
end

local function watchCharacters(player: Player)
	assignActiveSpawn(player)
	if characterConnections[player] ~= nil then
		return
	end
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

local function unwatchCharacters(player: Player)
	local connection = characterConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		characterConnections[player] = nil
	end
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
						placeInLobby({ player })
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
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	for player in pairs(characterConnections) do
		unwatchCharacters(player)
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
		watchCharacters(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(watchCharacters)
	playerRemovingConnection = Players.PlayerRemoving:Connect(unwatchCharacters)

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
	placeInLobby(players)
end

function LobbyService.getModel(): Model?
	return lobbyModel
end

return table.freeze(LobbyService)
