--!strict

-- Inicializa o recebimento de avisos para todos os jogadores. A interface de
-- administração só é criada depois que o servidor confirma a permissão.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConstants = require(ReplicatedStorage.Shared.modules.AdminConstants)
local AdminBroadcastView = require(script.Parent.Parent.ui.AdminBroadcastView)
local AdminPanelView = require(script.Parent.Parent.ui.AdminPanelView)

type AdminRequest = AdminConstants.AdminRequest
type AdminResponse = AdminConstants.AdminResponse
type AdminPanelViewHandle = AdminPanelView.AdminPanelViewHandle
type PlayerEntry = AdminPanelView.PlayerEntry

local WAIT_TIMEOUT = 10

local AdminController = {}

local started = false
local connections: { RBXScriptConnection } = {}

local function getRemote(folder: Folder, name: string): Instance?
	local instance = folder:FindFirstChild(name)
	if instance == nil then
		instance = folder:WaitForChild(name, WAIT_TIMEOUT)
	end
	return instance
end

local function buildPlayerEntries(localPlayer: Player): { PlayerEntry }
	local entries: { PlayerEntry } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			table.insert(entries, {
				userId = player.UserId,
				displayName = player.DisplayName,
				username = player.Name,
			})
		end
	end
	table.sort(entries, function(a, b)
		return string.lower(a.displayName) < string.lower(b.displayName)
	end)
	return entries
end

function AdminController.start()
	if started then
		return
	end
	started = true

	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		warn("[BlocoPuff][Admin] LocalPlayer unavailable")
		return
	end
	local playerGuiInstance = localPlayer:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if playerGuiInstance == nil or not playerGuiInstance:IsA("PlayerGui") then
		warn("[BlocoPuff][Admin] PlayerGui unavailable")
		return
	end

	local folderInstance = ReplicatedStorage:WaitForChild(AdminConstants.RemotesContainerName, WAIT_TIMEOUT)
	if folderInstance == nil or not folderInstance:IsA("Folder") then
		warn("[BlocoPuff][Admin] Remote container unavailable")
		return
	end

	local statusInstance = getRemote(folderInstance, AdminConstants.StatusFunctionName)
	local requestInstance = getRemote(folderInstance, AdminConstants.ActionFunctionName)
	local announcementInstance = getRemote(folderInstance, AdminConstants.AnnouncementEventName)
	if
		statusInstance == nil
		or not statusInstance:IsA("RemoteFunction")
		or requestInstance == nil
		or not requestInstance:IsA("RemoteFunction")
		or announcementInstance == nil
		or not announcementInstance:IsA("RemoteEvent")
	then
		warn("[BlocoPuff][Admin] One or more remotes are unavailable")
		return
	end
	local statusFunction = statusInstance :: RemoteFunction
	local requestFunction = requestInstance :: RemoteFunction
	local announcementEvent = announcementInstance :: RemoteEvent

	local broadcastView = AdminBroadcastView.new(playerGuiInstance)
	table.insert(connections, announcementEvent.OnClientEvent:Connect(function(rawPayload: unknown)
		if typeof(rawPayload) ~= "table" then
			return
		end
		local payload = rawPayload :: { [any]: any }
		if type(payload.message) ~= "string" or type(payload.sender) ~= "string" then
			return
		end
		if #payload.message > AdminConstants.MaximumAnnouncementLength or #payload.sender > 50 then
			return
		end
		broadcastView.show(payload.sender, payload.message)
	end))

	local statusOk, isAdminResult = pcall(function()
		return statusFunction:InvokeServer()
	end)
	if not statusOk or isAdminResult ~= true then
		return
	end

	local panelView: AdminPanelViewHandle? = nil
	local requestInFlight = false

	local function sendRequest(request: AdminRequest)
		local currentView = panelView
		if requestInFlight or currentView == nil then
			return
		end
		requestInFlight = true
		currentView.setBusy(true)

		task.spawn(function()
			local ok, rawResponse = pcall(function()
				return requestFunction:InvokeServer(request)
			end)
			requestInFlight = false
			currentView.setBusy(false)

			if not ok or typeof(rawResponse) ~= "table" then
				currentView.setFeedback("O servidor não respondeu à solicitação.", false)
				return
			end

			local result = rawResponse :: { [any]: any }
			if type(result.ok) ~= "boolean" or type(result.message) ~= "string" then
				currentView.setFeedback("O servidor devolveu uma resposta inválida.", false)
				return
			end

			local response = result :: AdminResponse
			currentView.setFeedback(response.message, response.ok)
		end)
	end

	panelView = AdminPanelView.new(playerGuiInstance, {
		onAnnounce = function(message: string)
			sendRequest({
				action = "Announce",
				message = message,
			})
		end,
		onModerate = function(action: string, targetUserIdText: string, reason: string)
			local targetUserId = tonumber(targetUserIdText)
			if targetUserId == nil then
				local currentView = panelView
				if currentView ~= nil then
					currentView.setFeedback("Informe um User ID válido.", false)
				end
				return
			end
			sendRequest({
				action = action,
				targetUserId = targetUserId,
				reason = reason,
			})
		end,
	})

	local function refreshPlayers()
		local currentView = panelView
		if currentView ~= nil then
			currentView.setPlayers(buildPlayerEntries(localPlayer))
		end
	end
	refreshPlayers()
	table.insert(connections, Players.PlayerAdded:Connect(function()
		task.defer(refreshPlayers)
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end))
end

return table.freeze(AdminController)
