--!strict

-- Salas Secretas do Barão (Fase 5C.3, parte 3). O cenário é do
-- BaronRoomsBuilder (montado com a ala leste); aqui ficam:
--   * o acesso: atributos `BaronRoom_<id>` no Player, para o cliente dele
--     abrir a passagem e para os amigos saberem que ele está perto;
--   * o prêmio. Remote "BaronRooms":
--       cliente → ("Claim", id);
--       servidor → ("Claimed", id, tickets, quantas salas já abriu).
--     Só no lobby, para quem tem acesso pelo perfil, dentro da sala, perto
--     do prêmio, com intervalo entre tentativas e uma vez por jogador
--     (perfil `baronRooms`). Amigos que entraram junto não ganham.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaronRoomsConfig = require(ReplicatedStorage.Shared.config.BaronRoomsConfig)
local BaronRoomsLayout = require(ReplicatedStorage.Shared.modules.BaronRoomsLayout)
local BaronRoomsRules = require(ReplicatedStorage.Shared.modules.BaronRoomsRules)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)

type Profile = ProfileSchema.Profile
type ProfileSnapshot = ProfileTypes.ProfileSnapshot

local DIARY = "Diary"

local BaronRoomsService = {}

local started = false
local remote: RemoteEvent? = nil
local lastTry: { [Player]: number } = {}

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function diaryTotal(): number
	return #RelicCatalog.groupIds(DIARY)
end

local function accessFromProfile(profile: Profile, id: string): boolean
	return BaronRoomsRules.hasAccess(id, RelicCatalog.groupCount(profile.relics, DIARY), diaryTotal(), profile.mysteries.Safe ~= nil)
end

local function accessFromSnapshot(snapshot: ProfileSnapshot, id: string): boolean
	local owned: { [string]: boolean } = {}
	for _, relic in ipairs(snapshot.relics) do
		owned[relic.id] = true
	end
	local safeSolved = table.find(snapshot.mysteries, "Safe") ~= nil
	return BaronRoomsRules.hasAccess(id, RelicCatalog.groupCount(owned, DIARY), diaryTotal(), safeSolved)
end

-- Publica (ou tira) o acesso de cada sala no Player.
local function publishAccess(player: Player, snapshot: ProfileSnapshot)
	for _, id in ipairs(BaronRoomsConfig.Ids) do
		local name = BaronRoomsConfig.AccessAttributePrefix .. id
		local value = if accessFromSnapshot(snapshot, id) then true else nil
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end
end

-- Dentro da sala e perto do prêmio.
local function isAtPrize(player: Player, id: string): boolean
	local room = BaronRoomsLayout.room(id)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if room == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = root.Position
	return BaronRoomsRules.inside(position.X, position.Y, position.Z, room.room, BaronRoomsConfig.RoomMargin)
		and (position - room.prize).Magnitude <= BaronRoomsConfig.ServerDistance
end

local function grant(player: Player, id: string)
	local outcome: BaronRoomsRules.Outcome? = nil
	local saved = false
	local before = 0
	local balance = 0
	PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, PlayerDataService.Events?)
		-- O acesso vem do perfil (não do atributo): amigo não ganha.
		if not accessFromProfile(profile, id) then
			return nil, nil
		end
		local rooms, result = BaronRoomsRules.claim(profile.baronRooms, id, BaronRoomsConfig.Ids :: { any }, BaronRoomsConfig.Tickets, os.time())
		if rooms == nil or result == nil then
			return nil, nil
		end
		local updated = ProfileSchema.withTickets(profile, result.tickets)
		updated.baronRooms = rooms
		outcome = result
		saved = canSave
		before = profile.tickets
		balance = updated.tickets
		return updated, nil
	end, true)
	local result = outcome
	if result == nil then
		return
	end
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireClient(player, "Claimed", id, balance - before, result.count)
	end
	if saved then
		TelemetryService.lobbyEvent(player, "BaronRoomClaimed", result.count, id)
		TelemetryService.ticketsEarned(player, before, balance, "BaronRoom")
	end
end

local function onClaim(player: Player, id: unknown)
	if typeof(id) ~= "string" or table.find(BaronRoomsConfig.Ids, id :: any) == nil then
		return
	end
	local clock = os.clock()
	local last = lastTry[player]
	if last ~= nil and clock - last < BaronRoomsConfig.ClaimCooldown then
		return
	end
	lastTry[player] = clock
	if isCompeting(player) or not isAtPrize(player, id :: string) then
		return
	end
	grant(player, id :: string)
end

function BaronRoomsService.start(remotesFolder: Folder)
	if started then
		return
	end
	started = true
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = PuffadorConstants.BaronRoomsRemoteName
	newRemote.Parent = remotesFolder
	remote = newRemote
	newRemote.OnServerEvent:Connect(function(player: Player, action: unknown, id: unknown)
		if action == "Claim" then
			onClaim(player, id)
		end
	end)
	PlayerDataService.addListener(publishAccess)
	for _, player in ipairs(Players:GetPlayers()) do
		local snapshot = PlayerDataService.getSnapshot(player)
		if snapshot ~= nil then
			publishAccess(player, snapshot)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTry[player] = nil
	end)
end

return table.freeze(BaronRoomsService)
