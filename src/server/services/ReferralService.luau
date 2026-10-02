--!strict

-- Convite com recompensa (Fase 5B). Regras em ReferralRules; valores em
-- ReferralConfig.
--
--   * Quem convidou: `GetJoinData().ReferredByPlayerId`, preenchido pelo
--     próprio Roblox nos convites (o LaunchData não vale: qualquer um monta
--     o link). Fica no perfil só de quem nunca jogou, e nunca é trocado.
--   * Convidado: ao terminar a primeira partida (stats.matches >= 1) ganha
--     os tickets uma vez (referralPaid), com o perfil salvo nesta sessão.
--   * Quem convidou: no mesmo servidor, ganha na hora. Fora dele, o amigo
--     vai para uma lista no DataStore (UpdateAsync, sem repetir) e um aviso
--     pelo MessagingService chama o servidor onde ele estiver; senão ele
--     recebe ao entrar no jogo. Uma vez por amigo (referralFriends), com
--     limite por dia e no total. Amigos além do limite do dia não rendem.
--   * DataStore e MessagingService sempre em pcall (o Studio pode não ter
--     acesso às APIs): sem eles, só o prêmio no mesmo servidor funciona.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local ReferralConfig = require(ReplicatedStorage.Shared.config.ReferralConfig)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local ReferralRules = require(script.Parent.Parent.data.ReferralRules)
local DailyRules = require(script.Parent.Parent.data.DailyRules)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)

type Profile = ProfileSchema.Profile
type ProfileSnapshot = ProfileTypes.ProfileSnapshot

local PENDING_ATTEMPTS = 3
local PENDING_RETRY_DELAY = 5
local MAX_USER_ID = 2 ^ 53

local ReferralService = {}

local started = false
local remote: RemoteEvent? = nil
local store: DataStore? = nil
-- Quem convidou cada jogador desta sessão (lido ao entrar), até ser gravado.
local joinInviter: { [Player]: number } = {}
-- Já conferiu a lista de amigos pendentes nesta sessão.
local pendingChecked: { [Player]: boolean } = {}
local claiming: { [Player]: boolean } = {}
local lastInviteReport: { [Player]: number } = {}

local function validUserId(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value or value <= 0 or value >= MAX_USER_ID or math.floor(value) ~= value then
		return nil
	end
	return value
end

local function readJoinInviter(player: Player): number
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return 0
	end
	-- ReferredByPlayerId ainda falta nas definições de tipo do Roblox.
	local data = joinData :: { [string]: any }
	-- Só o campo preenchido pelo Roblox: o LaunchData vem num link que
	-- qualquer um monta (contas descartáveis "convidadas" por qualquer id).
	return validUserId(data.ReferredByPlayerId) or 0
end

local function notify(player: Player, kind: string, tickets: number, friends: number?)
	local current = remote
	if current ~= nil and player.Parent ~= nil then
		current:FireClient(player, { kind = kind, tickets = tickets, friends = friends })
	end
end

local function pendingKey(inviterId: number): string
	return `{ReferralConfig.KeyPrefix}{inviterId}`
end

-- Credita amigos a quem convidou, se o perfil dele está aqui e é salvo.
-- nil: não deu para creditar agora (guardar para depois).
local function grantInviter(inviter: Player, candidates: { number }): number?
	local saveable = false
	local before = 0
	local balance = 0
	local granted: { number } = {}
	PlayerDataService.update(inviter, function(profile: Profile, canSave: boolean): (Profile?, any)
		saveable = canSave
		if not canSave then
			return nil, nil
		end
		local state = { day = profile.referralDay, dayCount = profile.referralDayCount, friends = profile.referralFriends }
		local newFriends, newState = ReferralRules.inviterGrant(state, DailyRules.dayIndex(os.time()), candidates, ReferralConfig)
		granted = newFriends
		if #newFriends == 0 then
			return nil, nil
		end
		local updated = ProfileSchema.withTickets(profile, #newFriends * ReferralConfig.InviterTickets)
		updated.referralDay = newState.day
		updated.referralDayCount = newState.dayCount
		updated.referralFriends = newState.friends
		before = profile.tickets
		balance = updated.tickets
		return updated, nil
	end, true)
	if not saveable then
		return nil
	end
	if #granted > 0 then
		local tickets = #granted * ReferralConfig.InviterTickets
		notify(inviter, "Inviter", tickets, #granted)
		TelemetryService.lobbyEvent(inviter, "ReferralInviterPaid", #granted, `Total{#granted}`)
		TelemetryService.ticketsEarned(inviter, before, balance, "Referral")
	end
	return #granted
end

-- Guarda amigos para quem convidou receber depois. Com `ping`, avisa o
-- servidor onde ele estiver (nunca ao devolver uma lista já pega: o aviso
-- voltaria para este mesmo servidor).
local function storePending(inviterId: number, inviteeIds: { number }, ping: boolean)
	local current = store
	if current == nil or #inviteeIds == 0 then
		return
	end
	local ok, failure = false, nil
	for attempt = 1, PENDING_ATTEMPTS do
		ok, failure = pcall(function()
			current:UpdateAsync(pendingKey(inviterId), function(stored: unknown)
				local list = ReferralRules.readPending(stored, ReferralConfig.PendingKeep)
				for _, inviteeId in ipairs(inviteeIds) do
					list = ReferralRules.addPending(list, inviteeId, ReferralConfig.PendingKeep)
				end
				return list
			end)
		end)
		if ok then
			break
		elseif attempt < PENDING_ATTEMPTS then
			task.wait(PENDING_RETRY_DELAY * attempt)
		end
	end
	if not ok then
		warn(string.format("[BlocoPuff] Referral pending save failed: %s", tostring(failure)))
		return
	end
	if ping then
		pcall(function()
			MessagingService:PublishAsync(ReferralConfig.MessageTopic, inviterId)
		end)
	end
end

local function creditInviter(inviterId: number, inviteeId: number)
	local inviter = Players:GetPlayerByUserId(inviterId)
	if inviter ~= nil and PlayerDataService.isLoaded(inviter) and grantInviter(inviter, { inviteeId }) ~= nil then
		return
	end
	storePending(inviterId, { inviteeId }, true)
end

-- Pega (e apaga) a lista de amigos pendentes de quem convidou e credita.
local function claimPending(player: Player)
	local current = store
	if current == nil or claiming[player] then
		return
	end
	claiming[player] = true
	local taken: { number } = {}
	local ok, failure = pcall(function()
		current:UpdateAsync(pendingKey(player.UserId), function(stored: unknown)
			taken = ReferralRules.readPending(stored, ReferralConfig.PendingKeep)
			return if #taken > 0 then {} else nil
		end)
	end)
	claiming[player] = nil
	if not ok then
		warn(string.format("[BlocoPuff] Referral pending claim failed: %s", tostring(failure)))
		return
	end
	if #taken == 0 then
		return
	end
	-- Saiu ou perfil não salvo nesta sessão: devolve para a próxima.
	if player.Parent == nil or not PlayerDataService.isLoaded(player) or grantInviter(player, taken) == nil then
		storePending(player.UserId, taken, false)
	end
end

local function recordInviter(player: Player)
	local inviterId = joinInviter[player]
	if inviterId == nil then
		return
	end
	joinInviter[player] = nil
	local recorded = PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, any)
		if not canSave or not ReferralRules.canRecordInviter(profile.stats.matches, profile.referredBy, inviterId, player.UserId) then
			return nil, nil
		end
		local updated = table.clone(profile)
		updated.referredBy = inviterId
		return updated, nil
	end, true)
	if recorded then
		TelemetryService.lobbyEvent(player, "ReferralJoined", 1)
	end
end

local function payInvitee(player: Player)
	local inviterId = 0
	local before = 0
	local balance = 0
	local paid = PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, any)
		if not canSave or profile.referredBy <= 0 or profile.referralPaid >= 1 or profile.stats.matches < 1 then
			return nil, nil
		end
		inviterId = profile.referredBy
		local updated = ProfileSchema.withTickets(profile, ReferralConfig.InviteeTickets)
		updated.referralPaid = 1
		before = profile.tickets
		balance = updated.tickets
		return updated, nil
	end, true)
	if not paid then
		return
	end
	notify(player, "Invitee", ReferralConfig.InviteeTickets)
	TelemetryService.lobbyEvent(player, "ReferralInviteePaid", ReferralConfig.InviteeTickets)
	TelemetryService.ticketsEarned(player, before, balance, "Referral")
	task.spawn(creditInviter, inviterId, player.UserId)
end

local function onProfile(player: Player, snapshot: ProfileSnapshot)
	if player.Parent == nil then
		return
	end
	recordInviter(player)
	if snapshot.stats.matches >= 1 then
		payInvitee(player)
	end
	if snapshot.saved and not pendingChecked[player] then
		pendingChecked[player] = true
		task.spawn(claimPending, player)
	end
end

local function onClientReport(player: Player, action: unknown)
	local clock = os.clock()
	local last = lastInviteReport[player]
	if last ~= nil and clock - last < ReferralConfig.InviteCooldown then
		return
	end
	lastInviteReport[player] = clock
	if action == "Sent" or action == "Unavailable" then
		TelemetryService.lobbyEvent(player, `Invite{action}`, 1)
	end
end

function ReferralService.start(remotesFolder: Folder?)
	if started then
		return
	end
	started = true

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(ReferralConfig.StoreName)
	end)
	if ok then
		store = result
	else
		warn(string.format("[BlocoPuff] Referral rewards across servers disabled: %s", tostring(result)))
	end

	if remotesFolder ~= nil then
		local event = Instance.new("RemoteEvent")
		event.Name = PuffadorConstants.ReferralRemoteName
		event.Parent = remotesFolder
		event.OnServerEvent:Connect(onClientReport)
		remote = event
	end

	-- Fora do caminho de início do servidor (a inscrição pode demorar).
	task.spawn(function()
		local subscribed, failure = pcall(function()
			MessagingService:SubscribeAsync(ReferralConfig.MessageTopic, function(message)
				local inviterId = validUserId(message.Data)
				local inviter = if inviterId ~= nil then Players:GetPlayerByUserId(inviterId) else nil
				if inviter ~= nil and PlayerDataService.isLoaded(inviter) then
					task.spawn(claimPending, inviter)
				end
			end)
		end)
		if not subscribed then
			warn(string.format("[BlocoPuff] Referral messages disabled: %s", tostring(failure)))
		end
	end)

	local function onPlayerAdded(player: Player)
		local inviterId = readJoinInviter(player)
		if inviterId > 0 and inviterId ~= player.UserId then
			joinInviter[player] = inviterId
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		joinInviter[player] = nil
		pendingChecked[player] = nil
		lastInviteReport[player] = nil
	end)

	PlayerDataService.addListener(onProfile)
	for _, player in ipairs(Players:GetPlayers()) do
		local snapshot = PlayerDataService.getSnapshot(player)
		if snapshot ~= nil then
			task.spawn(onProfile, player, snapshot)
		end
	end
end

return table.freeze(ReferralService)
