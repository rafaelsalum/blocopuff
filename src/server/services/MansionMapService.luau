--!strict

-- Mapa do Casarão (Fase 5C.4) no servidor: o LobbyRoomTelemetry diz em que
-- cômodo cada jogador fora da partida está (uma vez por segundo); a
-- primeira vez em cada cômodo fica salva no perfil (rooms: id → os.time()),
-- e quem conhece todos os cômodos que contam ganha a conquista Explorador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionMapConfig = require(ReplicatedStorage.Shared.config.MansionMapConfig)
local MansionMapRules = require(ReplicatedStorage.Shared.modules.MansionMapRules)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SecretAchievementService = require(script.Parent.SecretAchievementService)
local TelemetryService = require(script.Parent.TelemetryService)

type Profile = ProfileSchema.Profile
type ProfileSnapshot = ProfileTypes.ProfileSnapshot

local MansionMapService = {}

local started = false
-- Cômodos que cada jogador já tem no perfil (nil: perfil ainda não chegou).
local known: { [Player]: { [string]: boolean } } = {}

local function onProfile(player: Player, snapshot: ProfileSnapshot)
	local set: { [string]: boolean } = {}
	for _, id in ipairs(snapshot.rooms) do
		set[id] = true
	end
	known[player] = set
	-- Quem completou antes da conquista existir também ganha.
	if MansionMapRules.complete(MansionMapConfig.Rooms, set) then
		SecretAchievementService.explored(player)
	end
end

-- `player` está agora no cômodo `roomId` (nome da zona do LobbyRoomTelemetry).
function MansionMapService.seen(player: Player, roomId: string)
	local set = known[player]
	if set == nil or set[roomId] or not MansionMapRules.isRoom(MansionMapConfig.Rooms, roomId) then
		return
	end
	-- Marca já: o próximo segundo não tenta de novo enquanto salva.
	set[roomId] = true
	local count = 0
	local saved = false
	PlayerDataService.update(player, function(profile: Profile, canSave: boolean)
		if profile.rooms[roomId] ~= nil then
			return nil, nil
		end
		local updated = table.clone(profile)
		local rooms = table.clone(profile.rooms)
		rooms[roomId] = os.time()
		updated.rooms = rooms
		count = MansionMapRules.progress(MansionMapConfig.Rooms, rooms)
		saved = canSave
		return updated, nil
	end)
	if saved then
		TelemetryService.lobbyEvent(player, "MapRoomDiscovered", count, roomId)
	end
end

function MansionMapService.start()
	if started then
		return
	end
	started = true
	PlayerDataService.addListener(onProfile)
	for _, player in ipairs(Players:GetPlayers()) do
		local snapshot = PlayerDataService.getSnapshot(player)
		if snapshot ~= nil then
			onProfile(player, snapshot)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		known[player] = nil
	end)
end

return table.freeze(MansionMapService)
