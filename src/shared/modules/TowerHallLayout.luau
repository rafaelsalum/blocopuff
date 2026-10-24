--!strict

-- Geometria do Saguão da Torre (Fase 5C): sala encostada do lado de fora da
-- parede norte do Salão da Coleção, a oeste do janelão (a vista fica
-- livre), com uma porta dupla para a Coleção (entre dois pedestais da
-- vitrine de Puffs) e outra no fundo para a ponte coberta que desce até a
-- ilha da Torre do Relógio. O portão da muralha da ilha fica virado para
-- essa porta. Fonte única para quem constrói (TowerHallBuilder,
-- MansionService, TowerIsland, TowerDecor), para a telemetria e o mapa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionWingConfig = require(ReplicatedStorage.Shared.config.MansionWingConfig)
local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local TowerPathRules = require(ReplicatedStorage.Shared.modules.TowerPathRules)

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
	-- Porta da Coleção (na parede norte do Casarão) e porta da ponte.
	doorway: Doorway,
	exit: Doorway,
	-- Vão da porta da Coleção (atravessa a parede norte do Casarão).
	hole: Box,
	-- Interior da sala.
	room: Box,
	floorY: number,
	ceilingY: number,
	-- Ponte: da soleira da porta do fundo até o portão da ilha.
	bridgeFrom: Vector3,
	bridgeTo: Vector3,
	-- Ângulo do portão na muralha da ilha (0 = +X, cresce para +Z).
	gateAngle: number,
}

-- Medidas (studs). A porta da Coleção fica entre os pedestais 7 e 8 da
-- vitrine de Puffs; a sala vai de oeste do janelão até perto dele.
local DOOR_X = 149.5
local EXIT_X = 147
local ROOM_MIN_X = 131
local ROOM_MAX_X = 163
local ROOM_DEPTH = 26

local TowerHallLayout = {}

local cached: Layout? = nil

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return table.freeze({ minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ })
end

function TowerHallLayout.get(): Layout
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local mansion = MansionLayout.get()
	local t = GameConfig.Building.WallThickness
	local door = MansionWingConfig.DoorSize
	local floorY = mansion.floorY
	-- Face de fora da parede norte do Casarão (o fundo da sala de cá).
	local wallOuterZ = mansion.minZ - t
	local roomMinZ = wallOuterZ - ROOM_DEPTH
	local exitOuterZ = roomMinZ - t
	local tower = RaceConfig.Tower
	local bridgeFrom = Vector3.new(EXIT_X, floorY, exitOuterZ)
	local gateAngle, gateX, gateZ = TowerPathRules.gate(tower.Center.X, tower.Center.Z, tower.IslandRadius, bridgeFrom.X, bridgeFrom.Z)
	local layout: Layout = table.freeze({
		doorway = table.freeze({
			name = "TowerHallDoor",
			center = Vector3.new(DOOR_X, floorY, mansion.minZ - t / 2),
			along = Vector3.xAxis,
			normal = -Vector3.zAxis,
			size = door,
			-- Cada placa diz o cômodo do outro lado.
			labelPositive = "✨ SALÃO DA COLEÇÃO",
			labelNegative = "🕰️ SAGUÃO DA TORRE",
		}),
		exit = table.freeze({
			name = "TowerBridgeDoor",
			center = Vector3.new(EXIT_X, floorY, roomMinZ - t / 2),
			along = Vector3.xAxis,
			normal = -Vector3.zAxis,
			size = door,
			labelPositive = "🕰️ SAGUÃO DA TORRE",
			labelNegative = "🌉 PONTE DA TORRE",
		}),
		hole = box(DOOR_X - door.X / 2, floorY, wallOuterZ, DOOR_X + door.X / 2, floorY + door.Y, mansion.minZ),
		room = box(ROOM_MIN_X, floorY, roomMinZ, ROOM_MAX_X, mansion.ceilingY, wallOuterZ),
		floorY = floorY,
		ceilingY = mansion.ceilingY,
		bridgeFrom = bridgeFrom,
		bridgeTo = Vector3.new(gateX, tower.Center.Y, gateZ),
		gateAngle = gateAngle,
	})
	cached = layout
	return layout
end

-- Dentro da sala (com `margin` de folga).
function TowerHallLayout.isInside(position: Vector3, margin: number): boolean
	local room = TowerHallLayout.get().room
	return position.X >= room.minX - margin
		and position.X <= room.maxX + margin
		and position.Y >= room.minY - margin
		and position.Y <= room.maxY + margin
		and position.Z >= room.minZ - margin
		and position.Z <= room.maxZ + margin
end

return table.freeze(TowerHallLayout)
