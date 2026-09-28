--!strict

-- Fila da partida: quem está no mirante (a galeria envidraçada) está na
-- fila. A Party entra junto: basta um membro no mirante para o grupo todo
-- contar (os demais vão direto para a arena quando a partida começa). O
-- RoundService só começa a contagem com GameConfig.MinimumPlayers na fila
-- e só escala quem está nela (PartySelection com `eligible`).
--
-- Pedidos do cliente (remote "MatchQueue"):
--   "Join" → botão JOGAR: leva ao mirante (fora da partida, vivo).
-- Mensagens ao cliente: ("Lonely") → sozinho na fila há um tempo, sugere
-- chamar um amigo (uma vez por espera).
--
-- O atributo "InMatchQueue" do jogador diz ao HUD se ele está na fila.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local QueueConfig = require(ReplicatedStorage.Shared.config.QueueConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local LobbyService = require(script.Parent.LobbyService)
local PartyService = require(script.Parent.PartyService)
local TelemetryService = require(script.Parent.TelemetryService)

local FOLDER_NAME = "MatchQueue"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "MatchQueueService"
local ATTR_IN_QUEUE = StateAttributeNames.PlayerInMatchQueue
local SIGN_DISTANCE = 45
local SIGN_INSET = 3.5
local MAT_COLOR = Color3.fromRGB(79, 214, 160)

local MatchQueueService = {}

local started = false
local remote: RemoteEvent? = nil
-- Quem está fisicamente no mirante agora.
local inZone: { [Player]: boolean } = {}
-- Fila efetiva: no mirante ou com alguém da Party lá.
local queued: { [Player]: boolean } = {}
local queuedCount = 0
local open = true
local aloneSince: number? = nil
local lonelyHinted = false
local lastJoin: { [Player]: number } = {}
local accumulator = 0

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function livingRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

-- Sozinho no mirante por QueueConfig.LonelyHintSeconds: avisa uma vez.
local function updateLonely(clock: number)
	local only: Player? = nil
	if open and queuedCount == 1 then
		for player in pairs(queued) do
			only = player
		end
	end
	if only == nil or not inZone[only] then
		aloneSince = nil
		lonelyHinted = false
		return
	end
	local since = aloneSince
	if since == nil then
		aloneSince = clock
		return
	end
	local currentRemote = remote
	if not lonelyHinted and clock - since >= QueueConfig.LonelyHintSeconds and currentRemote ~= nil then
		lonelyHinted = true
		currentRemote:FireClient(only, "Lonely")
		TelemetryService.lobbyEvent(only, "QueueLonely", math.floor(clock - since))
	end
end

local function refresh()
	local arena = GameConfig.Arena
	local building = GameConfig.Building
	local nextZone: { [Player]: boolean } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = livingRoot(player)
		if root ~= nil and not isCompeting(player) and BuildingLayout.isInsideGallery(arena, building, root.Position, QueueConfig.ZoneHeight) then
			nextZone[player] = true
		end
	end

	local nextQueued: { [Player]: boolean } = {}
	local count = 0
	for player in pairs(nextZone) do
		for _, member in ipairs(PartyService.groupOf(player)) do
			if not nextQueued[member] and member.Parent ~= nil and not isCompeting(member) then
				nextQueued[member] = true
				count += 1
			end
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local value = nextQueued[player] == true
		if player:GetAttribute(ATTR_IN_QUEUE) ~= value then
			player:SetAttribute(ATTR_IN_QUEUE, value)
		end
	end
	inZone = nextZone
	queued = nextQueued
	queuedCount = count
	updateLonely(os.clock())
end

local function onRequest(player: Player, action: unknown)
	if action ~= "Join" then
		return
	end
	local clock = os.clock()
	local last = lastJoin[player]
	if last ~= nil and clock - last < QueueConfig.JoinCooldown then
		return
	end
	lastJoin[player] = clock
	if isCompeting(player) or livingRoot(player) == nil or inZone[player] then
		return
	end
	LobbyService.placeInMirante({ player })
	TelemetryService.lobbyEvent(player, "QueueJoinButton", 1)
end

local function createSign(parent: Instance, name: string, position: Vector3, title: string, subtitle: string)
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = parent
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(9, 0, 2.2, 0)
	gui.MaxDistance = SIGN_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = anchor
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 0.6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 209, 102)
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = gui
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Position = UDim2.fromScale(0, 0.6)
	subtitleLabel.Size = UDim2.fromScale(1, 0.4)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(255, 248, 238)
	subtitleLabel.TextScaled = true
	subtitleLabel.TextStrokeTransparency = 0.3
	subtitleLabel.Parent = gui
end

-- Faixa verde no chão logo na entrada de cada porta e uma placa acima.
local function buildMarkers(worldRoot: Model)
	local existing = worldRoot:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	folder.Parent = worldRoot

	local gallery = BuildingLayout.getGallery(GameConfig.Arena, GameConfig.Building)
	local eastX = gallery.innerX + GameConfig.Building.GalleryDepth
	for index, z in ipairs(MansionLayout.get().passages) do
		local mat = Instance.new("Part")
		mat.Name = `QueueMat{index}`
		mat.Anchored = true
		mat.CanCollide = false
		mat.CanQuery = false
		mat.CanTouch = false
		mat.Size = Vector3.new(1.2, 0.14, 8)
		mat.Position = Vector3.new(eastX - 1.2, gallery.floorY + 0.07, z)
		mat.Color = MAT_COLOR
		mat.Material = Enum.Material.Neon
		mat.Parent = folder
		createSign(folder, `QueueSign{index}`, Vector3.new(eastX - SIGN_INSET, gallery.floorY + 7.5, z), "🏟 FILA DA PARTIDA", "Fique no mirante para jogar")
	end
end

-- Quantos estão na fila (inclui membros de Party de quem está no mirante).
function MatchQueueService.count(): number
	return queuedCount
end

-- Está fisicamente no mirante (a Party é resolvida pela PartySelection).
function MatchQueueService.isInZone(player: Player): boolean
	return inZone[player] == true
end

-- Na espera (WaitingForPlayers/Countdown) o aviso de "sozinho" vale; na
-- partida, não.
function MatchQueueService.setOpen(value: boolean)
	open = value
end

-- Recalcula na hora (antes de decidir contagem e seleção).
function MatchQueueService.refresh()
	refresh()
end

function MatchQueueService.start(worldRoot: Model, remotesFolder: Folder)
	if started then
		return
	end
	started = true
	buildMarkers(worldRoot)
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = PuffadorConstants.MatchQueueRemoteName
	newRemote.Parent = remotesFolder
	remote = newRemote
	newRemote.OnServerEvent:Connect(onRequest)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < QueueConfig.CheckInterval then
			return
		end
		accumulator = 0
		refresh()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastJoin[player] = nil
		inZone[player] = nil
		if queued[player] then
			queued[player] = nil
			queuedCount = math.max(0, queuedCount - 1)
		end
	end)
end

return table.freeze(MatchQueueService)
