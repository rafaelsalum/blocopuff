--!strict

-- Planta do Mapa do Casarão (Fase 5C.4): o retângulo de cada cômodo visto
-- de cima (X para a direita, Z para baixo) e em que andar ele fica, a partir
-- dos layouts do Casarão, da ala leste, da Sala dos Troféus e das Salas
-- Secretas. Um cômodo pode ter mais de um retângulo (o túnel do Tesouro).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionMapConfig = require(ReplicatedStorage.Shared.config.MansionMapConfig)
local BaronRoomsLayout = require(ReplicatedStorage.Shared.modules.BaronRoomsLayout)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local TrophyRoomLayout = require(ReplicatedStorage.Shared.modules.TrophyRoomLayout)
local TowerHallLayout = require(ReplicatedStorage.Shared.modules.TowerHallLayout)

type MapFloor = MansionMapConfig.MapFloor

export type MapRect = {
	id: string,
	floor: MapFloor,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

type Flat = { minX: number, maxX: number, minZ: number, maxZ: number }

-- Folga abaixo do piso de cada andar (para quem está pulando ou na escada).
local FLOOR_SLACK = 1.5

local MansionMapLayout = {}

local cached: { MapRect }? = nil

local function rect(id: string, floor: MapFloor, flat: Flat): MapRect
	return table.freeze({ id = id, floor = floor, minX = flat.minX, maxX = flat.maxX, minZ = flat.minZ, maxZ = flat.maxZ })
end

function MansionMapLayout.rects(): { MapRect }
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local rects: { MapRect } = {}
	local mansion = MansionLayout.get()
	local wing = MansionWingLayout.get()
	local baron = BaronRoomsLayout.get()
	for _, room in ipairs(MansionMapConfig.Rooms) do
		local id = room.id
		local mansionRoom = mansion.rooms[id]
		local wingRoom = wing.rooms[id]
		if mansionRoom ~= nil then
			table.insert(rects, rect(id, "Main", mansionRoom))
		elseif wingRoom ~= nil then
			table.insert(rects, rect(id, "Main", wingRoom))
		elseif id == "Trophy" then
			table.insert(rects, rect(id, "Main", TrophyRoomLayout.get().room))
		elseif id == "TowerHall" then
			table.insert(rects, rect(id, "Main", TowerHallLayout.get().room))
		elseif id == "Attic" or id == "Cellar" then
			table.insert(rects, rect(id, if id == "Attic" then "Attic" else "Cellar", wing))
		elseif id == "Study" or id == "Treasure" then
			local secret = if id == "Study" then baron.Study else baron.Treasure
			table.insert(rects, rect(id, room.floor, secret.room))
			local tunnel = secret.tunnel
			if tunnel ~= nil then
				table.insert(rects, rect(id, room.floor, tunnel))
			end
		end
	end
	cached = rects
	return rects
end

-- Em que andar do Casarão está `position` (nil: fora do Casarão).
function MansionMapLayout.floorAt(position: Vector3): MapFloor?
	local mansion = MansionLayout.get()
	local wing = MansionWingLayout.get()
	local y = position.Y
	local floor: MapFloor? = nil
	if y >= wing.atticFloorY - FLOOR_SLACK and y <= wing.atticCeilingY then
		floor = "Attic"
	elseif y >= mansion.floorY - FLOOR_SLACK and y <= mansion.ceilingY then
		floor = "Main"
	elseif y >= wing.cellarFloorY - FLOOR_SLACK and y < mansion.floorY - FLOOR_SLACK then
		floor = "Cellar"
	end
	if floor == nil then
		return nil
	end
	for _, entry in ipairs(MansionMapLayout.rects()) do
		if entry.floor == floor and position.X >= entry.minX and position.X <= entry.maxX and position.Z >= entry.minZ and position.Z <= entry.maxZ then
			return floor
		end
	end
	return nil
end

return table.freeze(MansionMapLayout)
