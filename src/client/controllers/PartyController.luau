--!strict

-- Party no cliente (Fase 4.4): painel pelo botão 👥 do cartão de perfil,
-- cartão de convite na lateral e avisos. Quem está competindo não vê o
-- cartão de convite no meio da partida: ele aparece ao voltar ao lobby, se
-- ainda não tiver expirado. Tudo é validado no servidor (PartyService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local SocialConfig = require(ReplicatedStorage.Shared.config.SocialConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local PartyView = require(script.Parent.Parent.ui.PartyView)
local PartyInviteView = require(script.Parent.Parent.ui.PartyInviteView)

type PartyState = PartyView.PartyState
type PartyMember = PartyView.PartyMember
type Candidate = PartyView.Candidate
type PartyViewHandle = PartyView.PartyViewHandle

type PendingInvite = {
	fromUserId: number,
	fromName: string,
	expiresAt: number,
}

local WAIT_TIMEOUT = 15
local MAX_NAME_LENGTH = 40

-- Texto de cada aviso do servidor; `%s` = nome. `banner` = também vira faixa.
local NOTICES: { [string]: { text: string, banner: boolean } } = {
	InviteSent = { text = "Convite enviado para %s.", banner = false },
	Declined = { text = "%s recusou o convite.", banner = false },
	InviteExpired = { text = "Esse convite expirou.", banner = false },
	PartyFull = { text = "A Party está cheia (máximo %d).", banner = false },
	AlreadyTogether = { text = "%s já está na sua Party.", banner = false },
	NotFound = { text = "Esse jogador não está mais no servidor.", banner = false },
	Cooldown = { text = "Espere um pouquinho para chamar de novo.", banner = false },
	Competing = { text = "Espere a partida acabar para mexer na Party.", banner = false },
	MemberJoined = { text = "%s entrou na Party!", banner = true },
	MemberLeft = { text = "%s saiu da Party.", banner = false },
	MemberKicked = { text = "%s foi removido da Party.", banner = false },
	Kicked = { text = "Você foi removido da Party.", banner = true },
	Disbanded = { text = "A Party acabou (ficou só você).", banner = false },
	Deferred = { text = "A partida lotou para a sua Party: vocês entram juntos na próxima!", banner = true },
}

local PartyController = {}

local started = false
local view: PartyViewHandle? = nil
local remote: RemoteEvent? = nil
local sizeChanged = Instance.new("BindableEvent")
local friendCache: { [number]: boolean } = {}

-- Disparado com o tamanho da Party (0 = sem Party).
PartyController.SizeChanged = sizeChanged.Event

local function send(action: string, value: number?)
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireServer(action, value)
	end
end

local function readName(value: unknown): string
	return if typeof(value) == "string" then string.sub(value, 1, MAX_NAME_LENGTH) else "?"
end

local function parseState(raw: unknown): PartyState?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: any }
	if typeof(data.id) ~= "string" or typeof(data.leaderUserId) ~= "number" or typeof(data.members) ~= "table" then
		return nil
	end
	local members: { PartyMember } = {}
	for index, member in ipairs(data.members :: { any }) do
		if index > SocialConfig.PartyMaxSize then
			break
		end
		if typeof(member) == "table" and typeof(member.userId) == "number" then
			table.insert(members, { userId = member.userId, name = readName(member.name) })
		end
	end
	return { id = data.id, leaderUserId = data.leaderUserId, members = members, maxSize = SocialConfig.PartyMaxSize }
end

local function isFriend(localPlayer: Player, userId: number): boolean
	local cached = friendCache[userId]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return localPlayer:IsFriendsWith(userId)
	end)
	local friend = ok and result == true
	friendCache[userId] = friend
	return friend
end

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

function PartyController.open()
	local current = view
	if current == nil then
		return
	end
	if current.isOpen() then
		current.close()
	else
		current.open()
	end
end

-- Abre sem alternar (estação do lobby).
function PartyController.show()
	local current = view
	if current ~= nil and not current.isOpen() then
		current.open()
	end
end

function PartyController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		warn("[BlocoPuff] Party controller not started: PlayerGui unavailable")
		return
	end
	NotificationManager.init(playerGui)

	local newView = PartyView.new(playerGui, {
		invite = function(userId: number)
			send("Invite", userId)
		end,
		kick = function(userId: number)
			send("Kick", userId)
		end,
		leave = function()
			send("Leave")
		end,
		inviteFriends = function()
			task.spawn(function()
				local ok, canSend = pcall(function()
					return SocialService:CanSendGameInviteAsync(player)
				end)
				if ok and canSend then
					pcall(function()
						SocialService:PromptGameInvite(player)
					end)
				else
					local current = view
					if current ~= nil then
						current.setStatus(Lang.t("Convites de amigos não estão disponíveis agora."))
					end
				end
			end)
		end,
	})
	view = newView

	local pendingInvite: PendingInvite? = nil
	local inviteView = PartyInviteView.new(playerGui, function(fromUserId: number)
		pendingInvite = nil
		send("Accept", fromUserId)
	end, function(fromUserId: number)
		pendingInvite = nil
		send("Decline", fromUserId)
	end)

	local function showPendingInvite()
		local invite = pendingInvite
		if invite == nil or isCompeting(player) then
			return
		end
		local remaining = invite.expiresAt - os.clock()
		if remaining <= 1 then
			pendingInvite = nil
			return
		end
		inviteView.show(invite.fromUserId, invite.fromName, remaining)
	end

	-- Lista de quem dá para chamar (amigos primeiro).
	local function refreshCandidates()
		task.spawn(function()
			local list: { Candidate } = {}
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					table.insert(list, { userId = other.UserId, name = other.DisplayName, friend = isFriend(player, other.UserId) })
				end
			end
			table.sort(list, function(a, b)
				if a.friend ~= b.friend then
					return a.friend
				end
				return a.name < b.name
			end)
			newView.setCandidates(list)
		end)
	end
	Players.PlayerAdded:Connect(refreshCandidates)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshCandidates)
	end)
	refreshCandidates()

	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		if isCompeting(player) then
			newView.close()
			inviteView.hide()
		else
			showPendingInvite()
		end
	end)
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsEliminated):Connect(showPendingInvite)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.PartyRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Party controller: remote not found")
			return
		end
		remote = instance
		instance.OnClientEvent:Connect(function(kind: unknown, payload: unknown, name: unknown)
			if kind == "State" then
				local state = parseState(payload)
				newView.setState(state, player.UserId)
				sizeChanged:Fire(if state ~= nil then #state.members else 0)
			elseif kind == "Invite" and typeof(payload) == "table" then
				local data = payload :: { [string]: any }
				if typeof(data.fromUserId) ~= "number" then
					return
				end
				local lifetime = if typeof(data.lifetime) == "number" then math.clamp(data.lifetime, 1, 120) else SocialConfig.InviteLifetime
				pendingInvite = { fromUserId = data.fromUserId, fromName = readName(data.fromName), expiresAt = os.clock() + lifetime }
				showPendingInvite()
			elseif kind == "Notice" and typeof(payload) == "string" then
				local entry = NOTICES[payload]
				if entry == nil then
					return
				end
				local text = if string.find(entry.text, "%%s")
					then Lang.t(entry.text, readName(name))
					elseif string.find(entry.text, "%%d") then Lang.t(entry.text, SocialConfig.PartyMaxSize)
					else Lang.t(entry.text)
				newView.setStatus(text)
				if entry.banner then
					NotificationManager.notify({
						channel = "Banner",
						category = "Social",
						priority = "Normal",
						key = `party-{payload}`,
						icon = "👥",
						title = Lang.t("PARTY"),
						subtitle = text,
						tone = "Info",
						duration = 3.5,
						maxWait = 8,
					})
				end
			end
		end)
		instance:FireServer("Sync")
	end)
end

return table.freeze(PartyController)
