--!strict

-- Geometria das Salas Secretas do Barão (Fase 5C.3, parte 3), derivada da
-- ala leste (MansionWingLayout). Fonte única para quem constrói (paredes
-- com vão, salas e prêmios), para o servidor (está dentro da sala?) e para
-- o cliente (passagem aberta para quem tem acesso).
--
--   * Study: atrás da EastShelf2 da Biblioteca, vão na parede leste do
--     andar principal e o Gabinete encostado do lado de fora.
--   * Treasure: atrás do CellarTunnel do Porão, vão na parede leste do
--     Porão, um túnel e a sala do tesouro no fim dele.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaronRoomsRules = require(ReplicatedStorage.Shared.modules.BaronRoomsRules)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)

type Box = BaronRoomsRules.Box

export type Passage = {
	-- Vão na parede leste da ala (atravessa a espessura toda).
	hole: Box,
	-- Centro do vão no piso, do lado de dentro da ala (para "dono perto").
	entry: Vector3,
}

export type Room = {
	id: string,
	passage: Passage,
	-- Interior da sala do prêmio.
	room: Box,
	-- Corredor entre o vão e a sala (nil: a sala encosta na parede).
	tunnel: Box?,
	-- Onde fica o prêmio (no piso).
	prize: Vector3,
	floorY: number,
	ceilingY: number,
}

export type Layout = {
	Study: Room,
	Treasure: Room,
	-- Estante giratória: centro da base, largura e dobradiça (canto da
	-- frente, lado sul) no piso.
	shelfZ: number,
	shelfHinge: Vector3,
}

-- Medidas (studs).
local STUDY_HOLE_WIDTH = 5
local STUDY_HOLE_HEIGHT = 10
local STUDY_SIZE = 18
local TUNNEL_WIDTH = 6
local TUNNEL_HEIGHT = 8.5
local TUNNEL_LENGTH = 24
local TREASURE_SIZE = 18
local TREASURE_HEIGHT = 12
-- Mesmos números do MansionWingDecor (EastShelf2 e CellarTunnel).
local SHELF_OFFSET = 18
local SHELF_WIDTH = 8
local SHELF_DEPTH = 2
local TUNNEL_OFFSET = 22

local BaronRoomsLayout = {}

local cached: Layout? = nil

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return table.freeze({ minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ })
end

function BaronRoomsLayout.get(): Layout
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local wing = MansionWingLayout.get()
	local t = wing.wallThickness
	local wallX0, wallX1 = wing.maxX, wing.maxX + t
	local library = wing.rooms.Library

	-- Gabinete: o vão fica atrás da metade norte da estante; ao girar (na
	-- dobradiça do lado sul) ela libera essa parte.
	local shelfZ = library.minZ + SHELF_OFFSET
	local studyHoleMinZ = shelfZ - SHELF_WIDTH / 2 + 0.5
	local studyHole = box(wallX0, wing.floorY, studyHoleMinZ, wallX1, wing.floorY + STUDY_HOLE_HEIGHT, studyHoleMinZ + STUDY_HOLE_WIDTH)
	local studyCenterZ = (studyHole.minZ + studyHole.maxZ) / 2
	local studyRoom = box(wallX1, wing.floorY, studyCenterZ - STUDY_SIZE / 2, wallX1 + STUDY_SIZE, wing.ceilingY, studyCenterZ + STUDY_SIZE / 2)
	local study: Room = table.freeze({
		id = "Study",
		passage = table.freeze({
			hole = studyHole,
			entry = Vector3.new(wallX0 - SHELF_DEPTH - 2, wing.floorY, studyCenterZ),
		}),
		room = studyRoom,
		tunnel = nil,
		prize = Vector3.new(studyRoom.maxX - 4, wing.floorY, studyCenterZ),
		floorY = wing.floorY,
		ceilingY = wing.ceilingY,
	})

	-- Tesouro: túnel reto para leste e a sala no fim.
	local cellarY = wing.cellarFloorY
	local tunnelZ = wing.minZ + TUNNEL_OFFSET
	local halfTunnel = TUNNEL_WIDTH / 2
	local tunnelHole = box(wallX0, cellarY, tunnelZ - halfTunnel, wallX1, cellarY + TUNNEL_HEIGHT, tunnelZ + halfTunnel)
	local tunnel = box(wallX1, cellarY, tunnelZ - halfTunnel, wallX1 + TUNNEL_LENGTH, cellarY + TUNNEL_HEIGHT, tunnelZ + halfTunnel)
	local treasureRoom = box(tunnel.maxX, cellarY, tunnelZ - TREASURE_SIZE / 2, tunnel.maxX + TREASURE_SIZE, cellarY + TREASURE_HEIGHT, tunnelZ + TREASURE_SIZE / 2)
	local treasure: Room = table.freeze({
		id = "Treasure",
		passage = table.freeze({
			hole = tunnelHole,
			entry = Vector3.new(wallX0 - 3, cellarY, tunnelZ),
		}),
		room = treasureRoom,
		tunnel = tunnel,
		prize = Vector3.new(treasureRoom.maxX - 4, cellarY, tunnelZ),
		floorY = cellarY,
		ceilingY = treasureRoom.maxY,
	})

	local layout: Layout = table.freeze({
		Study = study,
		Treasure = treasure,
		shelfZ = shelfZ,
		shelfHinge = Vector3.new(wallX0 - SHELF_DEPTH, wing.floorY, shelfZ + SHELF_WIDTH / 2),
	})
	cached = layout
	return layout
end

function BaronRoomsLayout.room(id: string): Room?
	local layout = BaronRoomsLayout.get()
	if id == "Study" then
		return layout.Study
	elseif id == "Treasure" then
		return layout.Treasure
	end
	return nil
end

-- Dentro da sala ou do túnel dela (com folga).
function BaronRoomsLayout.isInside(room: Room, position: Vector3, margin: number): boolean
	if BaronRoomsRules.inside(position.X, position.Y, position.Z, room.room, margin) then
		return true
	end
	local tunnel = room.tunnel
	if tunnel ~= nil and BaronRoomsRules.inside(position.X, position.Y, position.Z, tunnel, margin) then
		return true
	end
	-- No próprio vão da parede também conta (ninguém fica preso nele).
	return BaronRoomsRules.inside(position.X, position.Y, position.Z, room.passage.hole, margin)
end

return table.freeze(BaronRoomsLayout)
