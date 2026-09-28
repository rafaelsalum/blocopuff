--!strict

-- Party (Fase 4.4): grupo de até SocialConfig.PartyMaxSize jogadores do
-- mesmo servidor que entra junto nas partidas (ver PartySelection).
--
-- Pedidos do cliente (remote "Party"):
--   "Invite", userId  → convida alguém do servidor (expira);
--   "Accept", userId  → aceita o convite de `userId` (sai da Party antiga);
--   "Decline", userId → recusa;
--   "Leave"           → sai da Party;
--   "Kick", userId    → o líder tira alguém.
-- Mensagens ao cliente: ("State", estado | nil), ("Invite", convite) e
-- ("Notice", código, nome?). O atributo "PartyId" do jogador deixa todos os
-- clientes saberem quem está junto (espectador segue a Party primeiro).
--
-- Tudo é validado aqui: quem convida existe, o convite não expirou, a Party
-- tem vaga. Nada disso dá vantagem na partida: é só com quem você entra.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocialConfig = require(ReplicatedStorage.Shared.config.SocialConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local TelemetryService = require(script.Parent.TelemetryService)

type Party = {
	id: string,
	leader: Player,
	members: { Player },
}

export type PartyMember = {
	userId: number,
	name: string,
}

export type PartyState = {
	id: string,
	leaderUserId: number,
	members: { PartyMember },
	maxSize: number,
}

local PartyService = {}

local started = false
local remote: RemoteEvent? = nil
local parties: { [string]: Party } = {}
local partyOf: { [Player]: string } = {}
-- invites[convidado][quem convidou] = os.clock() em que expira.
local invites: { [Player]: { [Player]: number } } = {}
local lastInvite: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}
-- Parties que jogaram a última partida juntas (telemetria de replay).
local lastRoundParties: { [string]: boolean } = {}

local REQUEST_COOLDOWN = 0.3

local function notice(player: Player, code: string, name: string?)
	local currentRemote = remote
	if currentRemote ~= nil and player.Parent ~= nil then
		currentRemote:FireClient(player, "Notice", code, name)
	end
end

local function stateOf(party: Party): PartyState
	local members: { PartyMember } = {}
	for _, member in ipairs(party.members) do
		table.insert(members, { userId = member.UserId, name = member.DisplayName })
	end
	return { id = party.id, leaderUserId = party.leader.UserId, members = members, maxSize = SocialConfig.PartyMaxSize }
end

local function sendState(player: Player, party: Party?)
	local currentRemote = remote
	if currentRemote == nil or player.Parent == nil then
		return
	end
	currentRemote:FireClient(player, "State", if party ~= nil then stateOf(party) else nil)
end

local function broadcast(party: Party)
	for _, member in ipairs(party.members) do
		sendState(member, party)
	end
end

local function setAttribute(player: Player, partyId: string?)
	if player.Parent ~= nil then
		player:SetAttribute(StateAttributeNames.PlayerPartyId, partyId)
	end
end

local function removeFromParty(player: Player, reason: string)
	local partyId = partyOf[player]
	if partyId == nil then
		return
	end
	partyOf[player] = nil
	setAttribute(player, nil)
	sendState(player, nil)
	local party = parties[partyId]
	if party == nil then
		return
	end
	local index = table.find(party.members, player)
	if index ~= nil then
		table.remove(party.members, index)
	end
	TelemetryService.lobbyEvent(player, "PartyLeft", #party.members, reason)
	if #party.members <= 1 then
		-- Party de uma pessoa só deixa de existir.
		for _, member in ipairs(party.members) do
			partyOf[member] = nil
			setAttribute(member, nil)
			sendState(member, nil)
			notice(member, "Disbanded")
		end
		parties[partyId] = nil
		lastRoundParties[partyId] = nil
		return
	end
	if party.leader == player then
		party.leader = party.members[1]
	end
	for _, member in ipairs(party.members) do
		notice(member, if reason == "Kick" then "MemberKicked" else "MemberLeft", player.DisplayName)
	end
	broadcast(party)
end

local function addToParty(party: Party, player: Player)
	table.insert(party.members, player)
	partyOf[player] = party.id
	setAttribute(player, party.id)
	for _, member in ipairs(party.members) do
		if member ~= player then
			notice(member, "MemberJoined", player.DisplayName)
		end
	end
	broadcast(party)
end

local function playerByUserId(value: unknown): Player?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	return Players:GetPlayerByUserId(math.floor(value))
end

local function invite(inviter: Player, target: Player?)
	if target == inviter then
		return
	end
	if target == nil then
		notice(inviter, "NotFound")
		return
	end
	local clock = os.clock()
	local last = lastInvite[inviter]
	if last ~= nil and clock - last < SocialConfig.InviteCooldown then
		notice(inviter, "Cooldown")
		return
	end
	lastInvite[inviter] = clock
	local partyId = partyOf[inviter]
	local party = if partyId ~= nil then parties[partyId] else nil
	if party ~= nil and table.find(party.members, target) ~= nil then
		notice(inviter, "AlreadyTogether", target.DisplayName)
		return
	end
	if party ~= nil and #party.members >= SocialConfig.PartyMaxSize then
		notice(inviter, "PartyFull")
		return
	end
	local pending = invites[target] or {}
	invites[target] = pending
	pending[inviter] = clock + SocialConfig.InviteLifetime
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireClient(target, "Invite", {
			fromUserId = inviter.UserId,
			fromName = inviter.DisplayName,
			lifetime = SocialConfig.InviteLifetime,
		})
	end
	notice(inviter, "InviteSent", target.DisplayName)
	TelemetryService.lobbyEvent(inviter, "PartyInvite", if party ~= nil then #party.members else 1)
end

local function accept(player: Player, inviter: Player?)
	local pending = invites[player]
	local expiresAt = if pending ~= nil and inviter ~= nil then pending[inviter] else nil
	if inviter == nil or pending == nil or expiresAt == nil then
		notice(player, "InviteExpired")
		return
	end
	pending[inviter] = nil
	if os.clock() > expiresAt or inviter.Parent == nil then
		notice(player, "InviteExpired")
		return
	end
	local partyId = partyOf[inviter]
	local party = if partyId ~= nil then parties[partyId] else nil
	if party ~= nil and table.find(party.members, player) ~= nil then
		return
	end
	if party ~= nil and #party.members >= SocialConfig.PartyMaxSize then
		notice(player, "PartyFull")
		return
	end
	-- Sai da Party antiga (se tinha) antes de entrar na nova.
	removeFromParty(player, "Switch")
	if party == nil then
		local newParty: Party = { id = HttpService:GenerateGUID(false), leader = inviter, members = {} }
		parties[newParty.id] = newParty
		table.insert(newParty.members, inviter)
		partyOf[inviter] = newParty.id
		setAttribute(inviter, newParty.id)
		party = newParty
		TelemetryService.lobbyEvent(inviter, "PartyCreated", 2)
	end
	local joined = party :: Party
	addToParty(joined, player)
	TelemetryService.lobbyEvent(player, "PartyJoined", #joined.members)
end

-- Quem está competindo não chama, aceita nem remove ninguém até a partida
-- acabar (sair da Party continua liberado). Convidar quem está competindo
-- pode: o cartão aparece para ele ao voltar ao lobby.
local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function onRequest(player: Player, action: unknown, value: unknown)
	local clock = os.clock()
	local last = lastRequest[player]
	if last ~= nil and clock - last < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = clock
	if (action == "Invite" or action == "Accept" or action == "Kick") and isCompeting(player) then
		notice(player, "Competing")
		return
	end
	if action == "Invite" then
		invite(player, playerByUserId(value))
	elseif action == "Accept" then
		accept(player, playerByUserId(value))
	elseif action == "Decline" then
		local inviter = playerByUserId(value)
		local pending = invites[player]
		if inviter ~= nil and pending ~= nil and pending[inviter] ~= nil then
			pending[inviter] = nil
			notice(inviter, "Declined", player.DisplayName)
		end
	elseif action == "Leave" then
		removeFromParty(player, "Leave")
	elseif action == "Kick" then
		local target = playerByUserId(value)
		local partyId = partyOf[player]
		local party = if partyId ~= nil then parties[partyId] else nil
		if target ~= nil and target ~= player and party ~= nil and party.leader == player and partyOf[target] == partyId then
			notice(target, "Kicked")
			removeFromParty(target, "Kick")
		end
	elseif action == "Sync" then
		local partyId = partyOf[player]
		sendState(player, if partyId ~= nil then parties[partyId] else nil)
	end
end

-- Membros da Party do jogador que estão no servidor (inclui ele mesmo).
function PartyService.groupOf(player: Player): { Player }
	local partyId = partyOf[player]
	local party = if partyId ~= nil then parties[partyId] else nil
	if party == nil then
		return { player }
	end
	return table.clone(party.members)
end

-- Chamado pelo RoundService depois da seleção: avisa quem ficou de fora
-- por falta de vaga e registra Parties jogando (e repetindo) juntas.
function PartyService.roundSelected(selected: { Player }, deferredParties: { { Player } })
	for _, group in ipairs(deferredParties) do
		for _, member in ipairs(group) do
			notice(member, "Deferred")
		end
		TelemetryService.lobbyEvent(group[1], "PartyDeferred", #group)
	end
	local playing: { [string]: number } = {}
	for _, player in ipairs(selected) do
		local partyId = partyOf[player]
		if partyId ~= nil then
			playing[partyId] = (playing[partyId] or 0) + 1
		end
	end
	local nextRound: { [string]: boolean } = {}
	for partyId, count in pairs(playing) do
		local party = parties[partyId]
		if party ~= nil and count > 1 then
			nextRound[partyId] = true
			TelemetryService.lobbyEvent(party.leader, "PartyMatch", count)
			if lastRoundParties[partyId] then
				TelemetryService.lobbyEvent(party.leader, "PartyReplay", count)
			end
		end
	end
	lastRoundParties = nextRound
end

function PartyService.start(remotesFolder: Folder)
	if started then
		return
	end
	started = true
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = PuffadorConstants.PartyRemoteName
	newRemote.Parent = remotesFolder
	remote = newRemote
	newRemote.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player: Player)
		removeFromParty(player, "LeftGame")
		invites[player] = nil
		lastInvite[player] = nil
		lastRequest[player] = nil
		for _, pending in pairs(invites) do
			pending[player] = nil
		end
	end)
end

return table.freeze(PartyService)
