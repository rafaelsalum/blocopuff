--!strict

-- Fila da partida: quem está no mirante (a galeria envidraçada) está na
-- fila e leva a Ficha da Partida (Fase 5C.1): pode sair do mirante e
-- explorar o Casarão sem perder a vaga. A ficha só volta com "Leave" (botão
-- SAIR DA FILA), ao ficar parado fora do mirante por
-- QueueConfig.TicketAfkSeconds ou ao entrar numa partida. A Party entra
-- junto: basta um membro na fila (mirante ou ficha) para o grupo todo
-- contar (os demais vão direto para a arena quando a partida começa). O
-- RoundService só começa a contagem com GameConfig.MinimumPlayers na fila
-- e só escala quem está nela (PartySelection com `hasPlace`).
--
-- Entrar no mirante é livre (é só passar pela porta); nos últimos
-- QueueConfig.BoardingLockSeconds da contagem as portas fecham com uma
-- barreira de luz ("embarque encerrado") e reabrem quando a partida começa
-- ou a contagem é cancelada. O visual (portais, barreiras, painéis) é do
-- QueueVisuals; o aquecimento com balões, do WarmupService.
--
-- Pedidos do cliente (remote "MatchQueue"):
--   "Join"  → botão JOGAR: entrega a ficha ali mesmo (fora da partida,
--             vivo, com o embarque aberto), sem teletransporte;
--   "Leave" → botão SAIR DA FILA: devolve a ficha (no mirante não adianta:
--             quem está lá está na fila).
-- Mensagens ao cliente: ("Lonely") → sozinho na fila há um tempo, sugere
-- chamar um amigo (uma vez por espera, só sem bots); ("BotsArriving") → os
-- bots RoboPuff chegaram para completar a partida; ("GatesClosed") → para quem está na
-- fila quando o embarque fecha; ("BoardingClosed") → JOGAR recusado porque
-- o embarque já fechou; ("TicketCall", segundos) → faltam
-- QueueConfig.TicketCallSeconds e o jogador está fora do mirante;
-- ("TicketExpired") → a ficha voltou por ficar parado; ("StillInParty") →
-- devolveu a ficha, mas a Party ainda segura a vaga dele.
--
-- O atributo "InMatchQueue" do jogador diz ao HUD se ele está na fila e
-- "QueuePlace" onde está a vaga (mirante, ficha ou Party).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local QueueConfig = require(ReplicatedStorage.Shared.config.QueueConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PartyService = require(script.Parent.PartyService)
local TelemetryService = require(script.Parent.TelemetryService)
local QueueVisuals = require(script.Parent.QueueVisuals)

type QueueVisualsHandle = QueueVisuals.QueueVisualsHandle

local ATTR_IN_QUEUE = StateAttributeNames.PlayerInMatchQueue
local ATTR_QUEUE_PLACE = StateAttributeNames.PlayerQueuePlace

-- Última posição em que o dono da ficha foi visto se mexendo (AFK).
type Stillness = { position: Vector3, since: number }

local MatchQueueService = {}

local started = false
local remote: RemoteEvent? = nil
-- Quem está fisicamente no mirante agora.
local inZone: { [Player]: boolean } = {}
-- Fila efetiva: no mirante ou com alguém da Party lá.
local queued: { [Player]: boolean } = {}
-- Ficha da Partida: vaga guardada mesmo fora do mirante.
local tickets: { [Player]: boolean } = {}
local stillness: { [Player]: Stillness } = {}
-- Quem já recebeu o chamado dos últimos segundos nesta contagem.
local ticketCalled: { [Player]: boolean } = {}
local queuedCount = 0
local open = true
local aloneSince: number? = nil
local lonelyHinted = false
local lastJoin: { [Player]: number } = {}
local accumulator = 0
local visuals: QueueVisualsHandle? = nil
local gatesClosed = false
local countdownRemaining: number? = nil
-- Primeiro valor da contagem atual: o embarque nunca fecha logo no início
-- (a contagem do Studio é curta).
local countdownStart: number? = nil
local warmupLine = ""
local lastBoardKey = ""
-- Bots RoboPuff esperando no mirante (BotFillService): aparecem no painel,
-- mas não estão em `queued` nem em `queuedCount` (que são só de jogadores).
local botCount = 0

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
	if open and queuedCount == 1 and botCount == 0 then
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

-- Redesenha os painéis do mirante só quando algo visível mudou.
local function updateBoard()
	local current = visuals
	if current == nil then
		return
	end
	local userIds: { number } = {}
	for player in pairs(queued) do
		table.insert(userIds, player.UserId)
	end
	table.sort(userIds)
	local remaining = countdownRemaining
	local key = `{queuedCount}|{botCount}|{tostring(remaining)}|{gatesClosed}|{table.concat(userIds, ",")}|{warmupLine}`
	if key == lastBoardKey then
		return
	end
	lastBoardKey = key
	current.setBoard({
		count = queuedCount + botCount,
		bots = botCount,
		minimum = GameConfig.MinimumPlayers,
		maximum = GameConfig.MaximumPlayers,
		remaining = remaining,
		gatesClosed = gatesClosed,
		userIds = userIds,
		warmup = warmupLine,
	})
end

local function giveTicket(player: Player, clock: number)
	tickets[player] = true
	local root = livingRoot(player)
	if root ~= nil then
		stillness[player] = { position = root.Position, since = clock }
	end
end

local function dropTicket(player: Player)
	tickets[player] = nil
	stillness[player] = nil
end

-- Mirante dá a ficha; partida a consome; parado fora do mirante por muito
-- tempo, ela volta (com aviso).
local function updateTickets(zone: { [Player]: boolean }, clock: number)
	for _, player in ipairs(Players:GetPlayers()) do
		if isCompeting(player) then
			dropTicket(player)
		elseif zone[player] then
			giveTicket(player, clock)
		elseif tickets[player] then
			local root = livingRoot(player)
			local still = stillness[player]
			if root == nil then
				-- Renascendo: não conta como parado.
				stillness[player] = nil
			elseif still == nil or Vector2.new(root.Position.X - still.position.X, root.Position.Z - still.position.Z).Magnitude > QueueConfig.TicketAfkMove then
				stillness[player] = { position = root.Position, since = clock }
			elseif clock - still.since >= QueueConfig.TicketAfkSeconds then
				dropTicket(player)
				local currentRemote = remote
				if currentRemote ~= nil then
					currentRemote:FireClient(player, "TicketExpired")
				end
				TelemetryService.lobbyEvent(player, "QueueTicketExpired", 1)
			end
		end
	end
end

-- Faltando QueueConfig.TicketCallSeconds (ou já menos, se a contagem
-- começou curta), chama quem está na fila fora do mirante, uma vez por
-- contagem (inclusive quem pegou a ficha ou saiu do mirante depois).
local function callTickets()
	local remaining = countdownRemaining
	local currentRemote = remote
	if remaining == nil or remaining > QueueConfig.TicketCallSeconds or currentRemote == nil then
		return
	end
	for player in pairs(queued) do
		if not inZone[player] and not ticketCalled[player] then
			ticketCalled[player] = true
			currentRemote:FireClient(player, "TicketCall", remaining)
		end
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

	updateTickets(nextZone, os.clock())

	-- Quem segura a vaga (mirante ou ficha); a Party vem junto.
	local nextQueued: { [Player]: boolean } = {}
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if nextZone[player] or tickets[player] then
			for _, member in ipairs(PartyService.groupOf(player)) do
				if not nextQueued[member] and member.Parent ~= nil and not isCompeting(member) then
					nextQueued[member] = true
					count += 1
				end
			end
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local value = nextQueued[player] == true
		-- O lugar primeiro: o HUD lê os dois juntos.
		local place = if not value then "" elseif nextZone[player] then "Mirante" elseif tickets[player] then "Ticket" else "Party"
		if player:GetAttribute(ATTR_QUEUE_PLACE) ~= place then
			player:SetAttribute(ATTR_QUEUE_PLACE, place)
		end
		if player:GetAttribute(ATTR_IN_QUEUE) ~= value then
			player:SetAttribute(ATTR_IN_QUEUE, value)
		end
	end
	inZone = nextZone
	queued = nextQueued
	queuedCount = count
	callTickets()
	updateLonely(os.clock())
	updateBoard()
end

local function onLeave(player: Player)
	if not tickets[player] or inZone[player] then
		return
	end
	dropTicket(player)
	refresh()
	TelemetryService.lobbyEvent(player, "QueueLeaveButton", 1)
	-- A Party ainda segura a vaga dele.
	local currentRemote = remote
	if queued[player] and currentRemote ~= nil then
		currentRemote:FireClient(player, "StillInParty")
	end
end

local function onRequest(player: Player, action: unknown)
	if action == "Leave" then
		onLeave(player)
		return
	end
	if action ~= "Join" then
		return
	end
	local clock = os.clock()
	local last = lastJoin[player]
	if last ~= nil and clock - last < QueueConfig.JoinCooldown then
		return
	end
	lastJoin[player] = clock
	if isCompeting(player) or livingRoot(player) == nil or inZone[player] or tickets[player] then
		return
	end
	local currentRemote = remote
	if gatesClosed then
		if currentRemote ~= nil then
			currentRemote:FireClient(player, "BoardingClosed")
		end
		return
	end
	giveTicket(player, clock)
	refresh()
	TelemetryService.lobbyEvent(player, "QueueJoinButton", 1)
end

-- Quantos jogadores estão na fila (inclui membros de Party de quem está no
-- mirante). Os bots ficam de fora: o BotFillService conta os dele.
function MatchQueueService.count(): number
	return queuedCount
end

-- Bots RoboPuff esperando no mirante (só para o painel e o aviso de
-- "sozinho").
function MatchQueueService.setBotCount(count: number)
	botCount = math.max(0, count)
	updateBoard()
end

-- Jogadores na fila agora (telemetria dos bots).
function MatchQueueService.queuedPlayers(): { Player }
	local list: { Player } = {}
	for player in pairs(queued) do
		table.insert(list, player)
	end
	return list
end

-- Mensagem para todos os jogadores na fila.
function MatchQueueService.notifyQueued(kind: string)
	local currentRemote = remote
	if currentRemote == nil then
		return
	end
	for player in pairs(queued) do
		currentRemote:FireClient(player, kind)
	end
end

-- Está fisicamente no mirante (aquecimento).
function MatchQueueService.isInZone(player: Player): boolean
	return inZone[player] == true
end

-- Segura uma vaga: no mirante ou com a Ficha da Partida (a Party é
-- resolvida pela PartySelection).
function MatchQueueService.hasPlace(player: Player): boolean
	return inZone[player] == true or tickets[player] == true
end



-- Na espera (WaitingForPlayers/Countdown) o aviso de "sozinho" vale; na
-- partida, não.
function MatchQueueService.setOpen(value: boolean)
	open = value
end

local function setGatesClosed(closed: boolean)
	if gatesClosed == closed then
		return
	end
	gatesClosed = closed
	local current = visuals
	if current ~= nil then
		current.setGatesClosed(closed)
	end
	local currentRemote = remote
	if closed and currentRemote ~= nil then
		for player in pairs(queued) do
			currentRemote:FireClient(player, "GatesClosed")
		end
	end
	updateBoard()
end

-- Chamado pelo RoundService a cada segundo da contagem (nil quando ela
-- acaba, é cancelada ou a partida começa): mostra o tempo nos painéis e
-- fecha o embarque nos últimos segundos.
function MatchQueueService.setCountdown(remaining: number?)
	countdownRemaining = remaining
	if remaining == nil then
		countdownStart = nil
		ticketCalled = {}
	else
		if countdownStart == nil then
			countdownStart = remaining
		end
		callTickets()
	end
	local start = countdownStart
	setGatesClosed(remaining ~= nil and start ~= nil and remaining < start and remaining <= QueueConfig.BoardingLockSeconds)
	updateBoard()
end

-- Embarque aberto: dá para entrar, sair e aquecer.
function MatchQueueService.isBoardingOpen(): boolean
	return not gatesClosed
end

-- Linha do aquecimento nos painéis (WarmupService).
function MatchQueueService.setWarmupLine(text: string)
	warmupLine = text
	updateBoard()
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
	visuals = QueueVisuals.build(worldRoot)
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
		dropTicket(player)
		ticketCalled[player] = nil
		if queued[player] then
			queued[player] = nil
			queuedCount = math.max(0, queuedCount - 1)
		end
	end)
end

return table.freeze(MatchQueueService)
