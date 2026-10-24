--!strict

-- Onde fica cada porta trancada do Casarão (Fase 5C.1): o vão, de que lado
-- fica quem está trancado do lado de fora e o cômodo protegido. Fonte única
-- para quem constrói (MansionLocks) e para o cliente (MansionLockController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionLockConfig = require(ReplicatedStorage.Shared.config.MansionLockConfig)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local TrophyRoomLayout = require(ReplicatedStorage.Shared.modules.TrophyRoomLayout)

type Doorway = MansionWingLayout.Doorway
type Box = TrophyRoomLayout.Box

export type LockSpot = {
	info: MansionLockConfig.LockInfo,
	doorway: Doorway,
	-- +1/-1: o lado de fora (de quem chega trancado), em relação à normal.
	outside: number,
	-- O cômodo protegido (quem está dentro sempre consegue sair).
	room: Box,
}

local MansionLockLayout = {}

local cached: { LockSpot }? = nil

local function findDoorway(name: string): Doorway
	local trophy = TrophyRoomLayout.get()
	if trophy.doorway.name == name then
		return trophy.doorway
	end
	for _, doorway in ipairs(MansionWingLayout.get().doorways) do
		if doorway.name == name then
			return doorway
		end
	end
	error(`Unknown lock doorway {name}`)
end

local function roomBox(id: string): (Box, number)
	local wing = MansionWingLayout.get()
	if id == "Music" then
		local music = wing.rooms.Music
		-- A Música fica ao sul da porta (+normal): chega-se pelo norte.
		return table.freeze({ minX = music.minX, minY = wing.floorY, minZ = music.minZ, maxX = music.maxX, maxY = wing.ceilingY, maxZ = music.maxZ }), -1
	elseif id == "Trophy" then
		-- A Sala dos Troféus fica a leste (+normal): chega-se pelo oeste.
		return TrophyRoomLayout.get().room, -1
	end
	error(`Unknown lock room {id}`)
end

function MansionLockLayout.all(): { LockSpot }
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local spots: { LockSpot } = {}
	for _, info in ipairs(MansionLockConfig.Locks) do
		local room, outside = roomBox(info.id)
		table.insert(spots, table.freeze({ info = info, doorway = findDoorway(info.doorway), outside = outside, room = room }))
	end
	cached = spots
	return spots
end

function MansionLockLayout.isInside(spot: LockSpot, position: Vector3, margin: number): boolean
	local room = spot.room
	return position.X >= room.minX - margin
		and position.X <= room.maxX + margin
		and position.Y >= room.minY - margin
		and position.Y <= room.maxY + margin
		and position.Z >= room.minZ - margin
		and position.Z <= room.maxZ + margin
end

return table.freeze(MansionLockLayout)
