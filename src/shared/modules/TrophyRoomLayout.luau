--!strict

-- Geometria da Sala dos Troféus do Vovô Puff (Fase 5C.1, porta de nível):
-- uma sala encostada do lado de fora da parede leste da ala, no meio da
-- Escadaria (entre as duas escadas), com uma porta dupla no vão. Fonte
-- única para quem constrói (TrophyRoomBuilder, MansionWing), para a
-- telemetria e o mapa (está dentro?) e para o cliente (a tranca).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionWingConfig = require(ReplicatedStorage.Shared.config.MansionWingConfig)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)

type Doorway = MansionWingLayout.Doorway

export type Box = {
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

export type Layout = {
	doorway: Doorway,
	-- Vão na parede leste da ala (atravessa a espessura toda).
	hole: Box,
	-- Interior da sala.
	room: Box,
	floorY: number,
	ceilingY: number,
}

-- Medidas (studs).
local ROOM_DEPTH = 20
local ROOM_WIDTH = 22

local TrophyRoomLayout = {}

local cached: Layout? = nil

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return table.freeze({ minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ })
end

function TrophyRoomLayout.get(): Layout
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local wing = MansionWingLayout.get()
	local t = wing.wallThickness
	local hall = wing.rooms.StairHall
	local centerZ = (hall.minZ + hall.maxZ) / 2
	local door = MansionWingConfig.DoorSize
	local wallX0, wallX1 = wing.maxX, wing.maxX + t
	local layout: Layout = table.freeze({
		doorway = table.freeze({
			name = "TrophyDoor",
			center = Vector3.new(wing.maxX + t / 2, wing.floorY, centerZ),
			along = Vector3.zAxis,
			normal = Vector3.xAxis,
			size = door,
			-- Cada placa diz o cômodo do outro lado.
			labelPositive = "🪜 ESCADARIA",
			labelNegative = "🏆 SALA DOS TROFÉUS",
		}),
		hole = box(wallX0, wing.floorY, centerZ - door.X / 2, wallX1, wing.floorY + door.Y, centerZ + door.X / 2),
		room = box(wallX1, wing.floorY, centerZ - ROOM_WIDTH / 2, wallX1 + ROOM_DEPTH, wing.ceilingY, centerZ + ROOM_WIDTH / 2),
		floorY = wing.floorY,
		ceilingY = wing.ceilingY,
	})
	cached = layout
	return layout
end

-- Dentro da sala (com `margin` de folga).
function TrophyRoomLayout.isInside(position: Vector3, margin: number): boolean
	local room = TrophyRoomLayout.get().room
	return position.X >= room.minX - margin
		and position.X <= room.maxX + margin
		and position.Y >= room.minY - margin
		and position.Y <= room.maxY + margin
		and position.Z >= room.minZ - margin
		and position.Z <= room.maxZ + margin
end

return table.freeze(TrophyRoomLayout)
