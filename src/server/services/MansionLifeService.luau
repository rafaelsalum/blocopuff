--!strict

-- Vida no Casarão (Fase 5C.4, parte 1): o Fantasminha Puff e o remote
-- "MansionLife" (o presente do Barão também avisa por aqui).
--
-- De tempos em tempos, com alguém no lobby, um Fantasminha aparece num
-- cômodo sorteado (ponto livre achado com o índice do RelicSpots). O
-- primeiro jogador do lobby a encostar nele ganha tickets, até o limite do
-- dia; quem já chegou no limite não o consome (os outros ainda podem
-- pegar). Sem ninguém, ele some depois de um tempo.
--
-- Servidor → cliente ("MansionLife"):
--   ("GhostAppeared", cômodo)              para quem está no lobby;
--   ("GhostClaimed", tickets, hoje, limite) para quem pegou;
--   ("GhostCaught", nome)                  para os outros do lobby;
--   ("GhostLimit", limite)                 para quem encostou sem poder;
--   ("BaraoGift", tickets, hoje, limite)   presente do carinho no Barão.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionLifeConfig = require(ReplicatedStorage.Shared.config.MansionLifeConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local MansionGhostModel = require(script.Parent.MansionGhostModel)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RelicSpots = require(script.Parent.RelicSpots)
local TelemetryService = require(script.Parent.TelemetryService)
local DailyRules = require(script.Parent.Parent.data.DailyRules)
local MansionLifeRules = require(script.Parent.Parent.data.MansionLifeRules)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)

type Profile = ProfileSchema.Profile

local CONFIG = MansionLifeConfig.Ghost
local FOLDER_NAME = "MansionLife"
-- Ponto sorteado longe das bordas do cômodo (fração).
local SPOT_MARGIN = 0.15
-- Espaço livre em volta do Fantasminha (com folga) e quantos pontos tentar.
local GHOST_SPACE = Vector3.new(4, 4.2, 4)
local GHOST_OFFSET = Vector3.new(0, -0.2, 0)
local SPOT_TRIES = 24
local POLL = 0.25
-- Espera mínima (s) entre um Fantasminha e o próximo.
local MIN_GAP = 30
-- Folga (studs) da raiz de quem encosta em volta do cômodo do Fantasminha
-- (o toque não atravessa a parede para o cômodo vizinho).
local ROOM_SLACK = 1
local ROOM_HEIGHT = 14

local MansionLifeService = {}

type Ghost = {
	model: Model,
	room: string,
	claimed: boolean,
	-- Quem já ouviu "chegou no limite" neste Fantasminha.
	warned: { [Player]: boolean },
}

local started = false
local remote: RemoteEvent? = nil
local folder: Folder? = nil
local world: Instance? = nil
local lastRoom: string? = nil
local spotIndex: RelicSpots.Index? = nil
local random = Random.new()

local function inLobby(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) ~= true
end

local function lobbyPlayers(): { Player }
	local list: { Player } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if inLobby(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- Avisa um jogador (nada se o remote não existe).
function MansionLifeService.send(player: Player, kind: string, ...: any)
	local currentRemote = remote
	if currentRemote ~= nil and player.Parent == Players then
		currentRemote:FireClient(player, kind, ...)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return root
end

-- Ponto do Fantasminha no cômodo: flutuando num espaço livre, sem
-- encostar em móvel nenhum (sorteia alguns pontos até achar).
local function spotIn(room: string): Vector3?
	local level = RelicSpots.level(room)
	local root = world
	if level == nil or root == nil then
		return nil
	end
	local index = spotIndex
	if index == nil then
		index = RelicSpots.index(root, folder)
		spotIndex = index
	end
	local rect = level.rect
	for _ = 1, SPOT_TRIES do
		local u = SPOT_MARGIN + random:NextNumber() * (1 - SPOT_MARGIN * 2)
		local v = SPOT_MARGIN + random:NextNumber() * (1 - SPOT_MARGIN * 2)
		local position = Vector3.new(rect.minX + u * (rect.maxX - rect.minX), level.floorY + CONFIG.HoverHeight, rect.minZ + v * (rect.maxZ - rect.minZ))
		if RelicSpots.isFree(index :: RelicSpots.Index, position + GHOST_OFFSET, GHOST_SPACE) then
			return position
		end
	end
	return nil
end

local function grant(player: Player, ghost: Ghost)
	local today = DailyRules.dayIndex(os.time())
	local count: number? = nil
	local limited = false
	local saved = false
	local before = 0
	local balance = 0
	PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, PlayerDataService.Events?)
		local nextCount = MansionLifeRules.claimDaily(profile.ghostDay, profile.ghostCount, today, CONFIG.DailyLimit)
		if nextCount == nil then
			limited = true
			return nil, nil
		end
		local updated = ProfileSchema.withTickets(profile, CONFIG.Tickets)
		-- Carteira no teto: não pega (a cota do dia fica e outro pode pegar).
		if updated.tickets <= profile.tickets then
			return nil, nil
		end
		updated.ghostDay = today
		updated.ghostCount = nextCount
		count = nextCount
		saved = canSave
		before = profile.tickets
		balance = updated.tickets
		return updated, nil
	end, true)
	local caught = count
	if caught == nil then
		-- Sem perfil carregado não há aviso: o toque só não conta.
		if limited and not ghost.warned[player] then
			ghost.warned[player] = true
			MansionLifeService.send(player, "GhostLimit", CONFIG.DailyLimit)
		end
		return
	end
	ghost.claimed = true
	MansionLifeService.send(player, "GhostClaimed", balance - before, caught, CONFIG.DailyLimit)
	for _, other in ipairs(lobbyPlayers()) do
		if other ~= player then
			MansionLifeService.send(other, "GhostCaught", player.DisplayName)
		end
	end
	if saved then
		TelemetryService.lobbyEvent(player, "GhostCaught", caught, ghost.room)
		TelemetryService.ticketsEarned(player, before, balance, "Ghost")
	end
end

local function insideRoom(room: string, position: Vector3): boolean
	local level = RelicSpots.level(room)
	if level == nil then
		return false
	end
	local rect = level.rect
	return position.X >= rect.minX - ROOM_SLACK
		and position.X <= rect.maxX + ROOM_SLACK
		and position.Z >= rect.minZ - ROOM_SLACK
		and position.Z <= rect.maxZ + ROOM_SLACK
		and position.Y >= level.floorY - ROOM_SLACK
		and position.Y <= level.floorY + ROOM_HEIGHT
end

-- Quem está encostando nele (raiz dentro do raio, no mesmo cômodo) pega.
-- Conferido de tempos em tempos pela distância: o Touched não dispara
-- para quem para dentro da esfera ou chega de teleporte.
local function checkTouches(ghost: Ghost)
	local hitbox = ghost.model.PrimaryPart
	if hitbox == nil then
		return
	end
	for _, player in ipairs(lobbyPlayers()) do
		if ghost.claimed then
			return
		end
		local root = rootOf(player)
		if root ~= nil and (root.Position - hitbox.Position).Magnitude <= CONFIG.TouchRadius and insideRoom(ghost.room, root.Position) then
			grant(player, ghost)
		end
	end
end

local function spawnGhost(): Ghost?
	local parent = folder
	local room = MansionLifeRules.pickRoom(CONFIG.Rooms, lastRoom, random:NextNumber())
	if parent == nil or room == nil then
		return nil
	end
	local position = spotIn(room)
	if position == nil then
		warn(`[BlocoPuff] Ghost has no spot in {room}`)
		return nil
	end
	lastRoom = room
	local yaw = random:NextNumber() * math.pi * 2
	local model = MansionGhostModel.build(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
	model:SetAttribute(CONFIG.RoomAttribute, room)
	-- Sempre carregado: o aviso vale para o Casarão inteiro e a nuvenzinha
	-- do cliente só pode sair quando ele some de verdade.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local ghost: Ghost = { model = model, room = room, claimed = false, warned = {} }
	model.Parent = parent
	model:AddTag(CONFIG.Tag)
	for _, player in ipairs(lobbyPlayers()) do
		MansionLifeService.send(player, "GhostAppeared", room)
	end
	return ghost
end

-- Um Fantasminha por vez: espera alguém pegar ou o tempo acabar.
local function haunt()
	task.wait(CONFIG.FirstDelay)
	while started do
		local appearedAt = os.clock()
		if #lobbyPlayers() > 0 then
			local ok, ghostOrFailure = pcall(spawnGhost)
			if not ok then
				warn(`[BlocoPuff] Ghost failed: {ghostOrFailure}`)
			end
			local ghost = if ok then ghostOrFailure :: Ghost? else nil
			if ghost ~= nil then
				local deadline = os.clock() + CONFIG.Lifetime
				while not ghost.claimed and os.clock() < deadline do
					task.wait(POLL)
					checkTouches(ghost)
				end
				ghost.model:Destroy()
			end
		end
		-- O intervalo conta desde que ele apareceu (o tempo vivo entra).
		local alive = os.clock() - appearedAt
		task.wait(math.max(MansionLifeRules.interval(random:NextNumber(), CONFIG.MinInterval, CONFIG.MaxInterval) - alive, MIN_GAP))
	end
end

function MansionLifeService.start(worldRoot: Instance, remotesFolder: Folder)
	if started then
		return
	end
	started = true
	world = worldRoot
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	newFolder.Parent = worldRoot
	folder = newFolder

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = PuffadorConstants.MansionLifeRemoteName
	newRemote.Parent = remotesFolder
	remote = newRemote
	task.spawn(haunt)
end

return table.freeze(MansionLifeService)
