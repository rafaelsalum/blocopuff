--!strict

-- Serviço autoritativo do painel administrativo. Nenhuma ação recebida do
-- cliente é executada antes de autenticação, validação, limitação de frequência
-- e, quando houver texto, filtragem pelo TextService.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local AdminConstants = require(ReplicatedStorage.Shared.modules.AdminConstants)
local AdminConfig = require(script.Parent.Parent.config.AdminConfig)

type AdminRequest = AdminConstants.AdminRequest
type AdminResponse = AdminConstants.AdminResponse
type AnnouncementPayload = AdminConstants.AnnouncementPayload

type BanRecord = {
	reason: string,
	moderatorUserId: number,
	createdAt: number,
}

type ModerationPayload = {
	action: string,
	targetUserId: number,
	reason: string,
}

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "BlocoPuffAdminService"
local DEFAULT_KICK_REASON = "Removido por um administrador do BlocoPuff."
local DEFAULT_BAN_REASON = "Banido por um administrador do BlocoPuff."
local ANNOUNCEMENT_LIFETIME = 60

local AdminService = {}

local banStore = DataStoreService:GetDataStore(AdminConstants.BanStoreName)
local started = false
local actionFunction: RemoteFunction? = nil
local announcementEvent: RemoteEvent? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local announcementSubscription: RBXScriptConnection? = nil
local moderationSubscription: RBXScriptConnection? = nil
local lastActionAt: { [Player]: number } = {}
local lastAnnouncementAt: { [Player]: number } = {}
local deliveredAnnouncements: { [string]: boolean } = {}

local function response(ok: boolean, message: string): AdminResponse
	return {
		ok = ok,
		message = message,
	}
end

local function isAdminUserId(userId: number): boolean
	return AdminConfig.AdminUserIds[userId] == true
end

local function isAdmin(player: Player): boolean
	return isAdminUserId(player.UserId)
end

local function trimText(value: string): string
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local function isValidUserId(value: unknown): boolean
	return typeof(value) == "number"
		and value == value
		and value > 0
		and value < math.huge
		and value == math.floor(value)
end

local function filterText(rawText: string, authorUserId: number): (string?, string?)
	local ok, filteredOrError = pcall(function(): string
		local result = TextService:FilterStringAsync(rawText, authorUserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)

	if not ok or type(filteredOrError) ~= "string" then
		warn(string.format("[BlocoPuff][Admin] Text filtering failed: %s", tostring(filteredOrError)))
		return nil, "Não foi possível filtrar o texto. Tente novamente."
	end

	local filtered = trimText(filteredOrError)
	if filtered == "" then
		return nil, "O texto ficou vazio após a filtragem."
	end

	return filtered, nil
end

local function createRemotes(): (RemoteFunction, RemoteEvent)
	local existing = ReplicatedStorage:FindFirstChild(AdminConstants.RemotesContainerName)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
			error(`Cannot replace {existing:GetFullName()}: it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = AdminConstants.RemotesContainerName
	folder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	folder.Parent = ReplicatedStorage

	local statusFunction = Instance.new("RemoteFunction")
	statusFunction.Name = AdminConstants.StatusFunctionName
	statusFunction.Parent = folder

	local requestFunction = Instance.new("RemoteFunction")
	requestFunction.Name = AdminConstants.ActionFunctionName
	requestFunction.Parent = folder

	local newAnnouncementEvent = Instance.new("RemoteEvent")
	newAnnouncementEvent.Name = AdminConstants.AnnouncementEventName
	newAnnouncementEvent.Parent = folder

	statusFunction.OnServerInvoke = function(player: Player): boolean
		return isAdmin(player)
	end

	return requestFunction, newAnnouncementEvent
end

local function markAnnouncementDelivered(messageId: string)
	deliveredAnnouncements[messageId] = true
	task.delay(ANNOUNCEMENT_LIFETIME, function()
		deliveredAnnouncements[messageId] = nil
	end)
end

local function deliverAnnouncement(payload: AnnouncementPayload)
	if deliveredAnnouncements[payload.id] then
		return
	end
	markAnnouncementDelivered(payload.id)

	local remote = announcementEvent
	if remote ~= nil then
		remote:FireAllClients(payload)
	end
end

local function parseAnnouncementPayload(rawPayload: unknown): AnnouncementPayload?
	if typeof(rawPayload) ~= "table" then
		return nil
	end

	local payload = rawPayload :: { [any]: any }
	if type(payload.id) ~= "string" or #payload.id > 80 then
		return nil
	end
	if type(payload.message) ~= "string" or #payload.message > AdminConstants.MaximumAnnouncementLength then
		return nil
	end
	if type(payload.sender) ~= "string" or #payload.sender > 50 then
		return nil
	end

	return {
		id = payload.id,
		message = payload.message,
		sender = payload.sender,
	}
end

local function publishAnnouncement(payload: AnnouncementPayload): boolean
	local ok, publishError = pcall(function()
		MessagingService:PublishAsync(AdminConstants.AnnouncementTopic, payload)
	end)
	if not ok then
		warn(string.format("[BlocoPuff][Admin] Announcement sync failed: %s", tostring(publishError)))
	end
	return ok
end

local function publishModeration(payload: ModerationPayload): boolean
	local ok, publishError = pcall(function()
		MessagingService:PublishAsync(AdminConstants.ModerationTopic, payload)
	end)
	if not ok then
		warn(string.format("[BlocoPuff][Admin] Moderation sync failed: %s", tostring(publishError)))
	end
	return ok
end

local function getKickMessage(prefix: string, reason: string): string
	return string.format("%s\nMotivo: %s", prefix, reason)
end

local function kickConnectedPlayer(targetUserId: number, prefix: string, reason: string)
	local target = Players:GetPlayerByUserId(targetUserId)
	if target ~= nil and not isAdmin(target) then
		target:Kick(getKickMessage(prefix, reason))
	end
end

local function parseModerationPayload(rawPayload: unknown): ModerationPayload?
	if typeof(rawPayload) ~= "table" then
		return nil
	end

	local payload = rawPayload :: { [any]: any }
	if (payload.action ~= "Kick" and payload.action ~= "Ban") or not isValidUserId(payload.targetUserId) then
		return nil
	end
	if type(payload.reason) ~= "string" or #payload.reason > AdminConstants.MaximumReasonLength then
		return nil
	end

	return {
		action = payload.action,
		targetUserId = payload.targetUserId,
		reason = payload.reason,
	}
end

local function handleAnnouncement(player: Player, request: AdminRequest): AdminResponse
	local rawMessage = request.message
	if type(rawMessage) ~= "string" then
		return response(false, "Digite uma mensagem para o aviso.")
	end

	local message = trimText(rawMessage)
	if message == "" then
		return response(false, "Digite uma mensagem para o aviso.")
	end
	if #message > AdminConstants.MaximumAnnouncementLength then
		return response(false, string.format("O aviso deve ter até %d caracteres.", AdminConstants.MaximumAnnouncementLength))
	end

	local now = os.clock()
	local previous = lastAnnouncementAt[player]
	if previous ~= nil and now - previous < AdminConfig.AnnouncementCooldown then
		return response(false, "Aguarde alguns segundos antes de enviar outro aviso.")
	end

	local filtered, filterError = filterText(message, player.UserId)
	if filtered == nil then
		return response(false, filterError or "Não foi possível filtrar o aviso.")
	end

	lastAnnouncementAt[player] = now
	local payload: AnnouncementPayload = {
		id = HttpService:GenerateGUID(false),
		message = filtered,
		sender = player.DisplayName,
	}
	deliverAnnouncement(payload)
	local synced = publishAnnouncement(payload)

	print(string.format("[BlocoPuff][Admin] moderator=%d action=Announce", player.UserId))
	return response(
		true,
		if synced then "Aviso enviado para todos os servidores." else "Aviso enviado neste servidor."
	)
end

local function getValidatedTarget(request: AdminRequest): (number?, AdminResponse?)
	if not isValidUserId(request.targetUserId) then
		return nil, response(false, "Informe um User ID válido.")
	end

	local targetUserId = request.targetUserId :: number
	if isAdminUserId(targetUserId) then
		return nil, response(false, "Uma conta administrativa protegida não pode ser moderada.")
	end

	return targetUserId, nil
end

local function getFilteredReason(player: Player, request: AdminRequest, fallback: string): (string?, AdminResponse?)
	local rawReason = if type(request.reason) == "string" then trimText(request.reason) else ""
	if rawReason == "" then
		return fallback, nil
	end
	if #rawReason > AdminConstants.MaximumReasonLength then
		return nil, response(false, string.format("O motivo deve ter até %d caracteres.", AdminConstants.MaximumReasonLength))
	end

	local filtered, filterError = filterText(rawReason, player.UserId)
	if filtered == nil then
		return nil, response(false, filterError or "Não foi possível filtrar o motivo.")
	end
	return filtered, nil
end

local function handleKick(player: Player, request: AdminRequest): AdminResponse
	local targetUserId, targetError = getValidatedTarget(request)
	if targetUserId == nil then
		return targetError :: AdminResponse
	end

	local reason, reasonError = getFilteredReason(player, request, DEFAULT_KICK_REASON)
	if reason == nil then
		return reasonError :: AdminResponse
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if target == nil then
		return response(false, "O jogador não está neste servidor. Use banimento para removê-lo de outros servidores.")
	end

	kickConnectedPlayer(targetUserId, "Você foi removido desta sessão.", reason)
	print(string.format("[BlocoPuff][Admin] moderator=%d action=Kick target=%d", player.UserId, targetUserId))
	return response(true, "Jogador removido desta sessão.")
end

local function handleBan(player: Player, request: AdminRequest): AdminResponse
	local targetUserId, targetError = getValidatedTarget(request)
	if targetUserId == nil then
		return targetError :: AdminResponse
	end

	local reason, reasonError = getFilteredReason(player, request, DEFAULT_BAN_REASON)
	if reason == nil then
		return reasonError :: AdminResponse
	end

	local record: BanRecord = {
		reason = reason,
		moderatorUserId = player.UserId,
		createdAt = os.time(),
	}
	local ok, storeError = pcall(function()
		banStore:SetAsync(`User_{targetUserId}`, record)
	end)
	if not ok then
		warn(string.format("[BlocoPuff][Admin] Ban persistence failed: %s", tostring(storeError)))
		return response(false, "Não foi possível salvar o banimento.")
	end

	kickConnectedPlayer(targetUserId, "Você foi banido do BlocoPuff.", reason)
	local synced = publishModeration({
		action = "Ban",
		targetUserId = targetUserId,
		reason = reason,
	})
	print(string.format("[BlocoPuff][Admin] moderator=%d action=Ban target=%d", player.UserId, targetUserId))
	return response(
		true,
		if synced then "Banimento salvo e sincronizado." else "Banimento salvo; sincronização imediata indisponível."
	)
end

local function handleUnban(player: Player, request: AdminRequest): AdminResponse
	local targetUserId, targetError = getValidatedTarget(request)
	if targetUserId == nil then
		return targetError :: AdminResponse
	end

	local ok, storeError = pcall(function()
		banStore:RemoveAsync(`User_{targetUserId}`)
	end)
	if not ok then
		warn(string.format("[BlocoPuff][Admin] Unban persistence failed: %s", tostring(storeError)))
		return response(false, "Não foi possível remover o banimento.")
	end

	print(string.format("[BlocoPuff][Admin] moderator=%d action=Unban target=%d", player.UserId, targetUserId))
	return response(true, "Banimento removido.")
end

local function onAdminRequest(player: Player, rawRequest: unknown): AdminResponse
	if not isAdmin(player) then
		warn(string.format("[BlocoPuff][Admin] Unauthorized request from %d", player.UserId))
		return response(false, "Acesso administrativo negado.")
	end
	if typeof(rawRequest) ~= "table" then
		return response(false, "Solicitação inválida.")
	end

	local now = os.clock()
	local previous = lastActionAt[player]
	if previous ~= nil and now - previous < AdminConfig.ActionCooldown then
		return response(false, "Aguarde antes de executar outra ação.")
	end
	lastActionAt[player] = now

	local request = rawRequest :: AdminRequest
	if type(request.action) ~= "string" then
		return response(false, "Ação inválida.")
	end

	if request.action == "Announce" then
		return handleAnnouncement(player, request)
	elseif request.action == "Kick" then
		return handleKick(player, request)
	elseif request.action == "Ban" then
		return handleBan(player, request)
	elseif request.action == "Unban" then
		return handleUnban(player, request)
	end

	return response(false, "Ação administrativa não reconhecida.")
end

local function checkBan(player: Player)
	if isAdmin(player) then
		return
	end

	local ok, rawRecord = pcall(function()
		return banStore:GetAsync(`User_{player.UserId}`)
	end)
	if not ok then
		warn(string.format("[BlocoPuff][Admin] Ban lookup failed for %d: %s", player.UserId, tostring(rawRecord)))
		return
	end
	if rawRecord == nil or rawRecord == false then
		return
	end

	local reason = DEFAULT_BAN_REASON
	if typeof(rawRecord) == "table" then
		local record = rawRecord :: { [any]: any }
		if type(record.reason) == "string" and #record.reason <= AdminConstants.MaximumReasonLength then
			reason = record.reason
		end
	end
	player:Kick(getKickMessage("Você está banido do BlocoPuff.", reason))
end

local function subscribeToTopics()
	local announcementOk, announcementResult = pcall(function()
		return MessagingService:SubscribeAsync(AdminConstants.AnnouncementTopic, function(message)
			local payload = parseAnnouncementPayload(message.Data)
			if payload ~= nil then
				deliverAnnouncement(payload)
			end
		end)
	end)
	if announcementOk and typeof(announcementResult) == "RBXScriptConnection" then
		announcementSubscription = announcementResult
	else
		warn(string.format("[BlocoPuff][Admin] Announcement subscription unavailable: %s", tostring(announcementResult)))
	end

	local moderationOk, moderationResult = pcall(function()
		return MessagingService:SubscribeAsync(AdminConstants.ModerationTopic, function(message)
			local payload = parseModerationPayload(message.Data)
			if payload ~= nil then
				kickConnectedPlayer(payload.targetUserId, "Você foi banido do BlocoPuff.", payload.reason)
			end
		end)
	end)
	if moderationOk and typeof(moderationResult) == "RBXScriptConnection" then
		moderationSubscription = moderationResult
	else
		warn(string.format("[BlocoPuff][Admin] Moderation subscription unavailable: %s", tostring(moderationResult)))
	end
end

function AdminService.start()
	if started then
		return
	end
	started = true

	actionFunction, announcementEvent = createRemotes()
	local remote = actionFunction :: RemoteFunction
	remote.OnServerInvoke = onAdminRequest

	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		task.spawn(checkBan, player)
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		lastActionAt[player] = nil
		lastAnnouncementAt[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(checkBan, player)
	end

	subscribeToTopics()
end

function AdminService.stop()
	if not started then
		return
	end
	started = false

	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	if announcementSubscription ~= nil then
		announcementSubscription:Disconnect()
		announcementSubscription = nil
	end
	if moderationSubscription ~= nil then
		moderationSubscription:Disconnect()
		moderationSubscription = nil
	end

	local folder = ReplicatedStorage:FindFirstChild(AdminConstants.RemotesContainerName)
	if folder ~= nil and folder:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME then
		folder:Destroy()
	end
	actionFunction = nil
	announcementEvent = nil
	table.clear(lastActionAt)
	table.clear(lastAnnouncementAt)
	table.clear(deliveredAnnouncements)
end

return table.freeze(AdminService)
