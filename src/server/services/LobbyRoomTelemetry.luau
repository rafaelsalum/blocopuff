--!strict

-- Telemetria dos cômodos do lobby (Fase 5C): uma vez por segundo vê em que
-- cômodo cada jogador fora da partida está. A primeira visita de cada
-- cômodo na sessão manda RoomEntered (valor: segundos de sessão; contexto:
-- o cômodo); a primeira entrada numa sala secreta do Barão também manda
-- SecretRoomOpened.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaronRoomsLayout = require(ReplicatedStorage.Shared.modules.BaronRoomsLayout)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local LobbyRooms = require(script.Parent.Parent.data.LobbyRooms)
local TelemetryService = require(script.Parent.TelemetryService)

type Zone = LobbyRooms.Zone

local CHECK_SECONDS = 1
-- Folga abaixo do piso e acima do teto de cada andar.
local FLOOR_SLACK = 1.5

local LobbyRoomTelemetry = {}

local started = false
local visited: { [Player]: { [string]: boolean } } = {}
local joinedAt: { [Player]: number } = {}

type Box = { minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number }

local function boxZone(name: string, box: Box, secret: boolean?): Zone
	return { name = name, minX = box.minX, maxX = box.maxX, minY = box.minY, maxY = box.maxY, minZ = box.minZ, maxZ = box.maxZ, secret = secret }
end

local function rectZone(rect: MansionLayout.Rect, minY: number, maxY: number): Zone
	return { name = rect.name, minX = rect.minX, maxX = rect.maxX, minY = minY, maxY = maxY, minZ = rect.minZ, maxZ = rect.maxZ }
end

-- Salas secretas primeiro, depois Sótão e Porão, depois os térreos.
local function buildZones(): { Zone }
	local zones: { Zone } = {}
	local baron = BaronRoomsLayout.get()
	for _, room in ipairs({ baron.Study, baron.Treasure }) do
		table.insert(zones, boxZone(room.id, room.room, true))
		local tunnel = room.tunnel
		if tunnel ~= nil then
			table.insert(zones, boxZone(room.id, tunnel, true))
		end
	end
	local wing = MansionWingLayout.get()
	local wingBox = { minX = wing.minX, maxX = wing.maxX, minZ = wing.minZ, maxZ = wing.maxZ }
	table.insert(zones, boxZone("Attic", { minX = wingBox.minX, maxX = wingBox.maxX, minZ = wingBox.minZ, maxZ = wingBox.maxZ, minY = wing.atticFloorY - FLOOR_SLACK, maxY = wing.atticCeilingY }))
	table.insert(zones, boxZone("Cellar", { minX = wingBox.minX, maxX = wingBox.maxX, minZ = wingBox.minZ, maxZ = wingBox.maxZ, minY = wing.cellarFloorY - FLOOR_SLACK, maxY = wing.floorY - FLOOR_SLACK }))
	for _, rect in pairs(wing.rooms) do
		table.insert(zones, rectZone(rect, wing.floorY - FLOOR_SLACK, wing.ceilingY))
	end
	local mansion = MansionLayout.get()
	for _, rect in pairs(mansion.rooms) do
		table.insert(zones, rectZone(rect, mansion.floorY - FLOOR_SLACK, mansion.ceilingY))
	end
	return zones
end

local function inMatch(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function check(zones: { Zone })
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") and not inMatch(player) then
			local position = root.Position
			local zone = LobbyRooms.zoneAt(zones, position.X, position.Y, position.Z)
			local seen = visited[player]
			if zone ~= nil and seen ~= nil and LobbyRooms.firstVisit(seen, zone.name) then
				local seconds = math.floor(now - (joinedAt[player] or now))
				TelemetryService.lobbyEvent(player, "RoomEntered", seconds, zone.name)
				if zone.secret then
					TelemetryService.lobbyEvent(player, "SecretRoomOpened", seconds, zone.name)
				end
			end
		end
	end
end

local function track(player: Player)
	visited[player] = {}
	joinedAt[player] = os.clock()
end

function LobbyRoomTelemetry.start()
	if started then
		return
	end
	started = true
	local zones = buildZones()
	for _, player in ipairs(Players:GetPlayers()) do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		visited[player] = nil
		joinedAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local ok, failure = pcall(check, zones)
			if not ok then
				warn("[BlocoPuff] Lobby room telemetry failed:", failure)
			end
		end
	end)
end

return table.freeze(LobbyRoomTelemetry)
