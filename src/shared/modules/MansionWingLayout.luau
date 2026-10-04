--!strict

-- Geometria pura da ala leste do Casarão (Fase 5C.1): fonte única para
-- quem constrói (MansionWing), quem decora (MansionWingDecor), o piano e o
-- cliente (lanterna do Sótão).
--
-- Vista de cima (X para a direita, Z para baixo), encostada na parede leste
-- do Casarão:
--
--   Salão da Coleção ─porta─┐ Biblioteca                  │
--                           ├────porta────────────────────┤
--   Jardim do Barão ──porta─┤ Hall da Escadaria            │
--                           │  ▲ escada para o Sótão (norte)│
--                           │  ▼ escada para o Porão (sul)  │
--                           ├────porta────────────────────┤
--                           │ Sala de Música               │
--
-- O Sótão e o Porão ocupam a ala inteira, um em cima e outro embaixo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionWingConfig = require(ReplicatedStorage.Shared.config.MansionWingConfig)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)

type Rect = MansionLayout.Rect

-- Vão com porta: centro no piso, no meio da espessura da parede.
export type Doorway = {
	name: string,
	center: Vector3,
	along: Vector3,
	normal: Vector3,
	size: Vector2,
	-- Placas dos dois lados (nil: sem placa), para quem está do lado
	-- +normal e do lado -normal.
	labelPositive: string?,
	labelNegative: string?,
}

-- Lance de escada reto ao longo de X: `lowX`/`lowY` é o pé e `highX`/`highY`
-- o topo.
export type Stair = {
	name: string,
	lowX: number,
	highX: number,
	lowY: number,
	highY: number,
	minZ: number,
	maxZ: number,
	steps: number,
}

export type Wing = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	floorY: number,
	ceilingY: number,
	wallThickness: number,
	rooms: { [string]: Rect },
	northPartitionZ: number,
	southPartitionZ: number,
	atticFloorY: number,
	atticCeilingY: number,
	cellarFloorY: number,
	upStairs: Stair,
	downStairs: Stair,
	doorways: { Doorway },
}

local MansionWingLayout = {}

local cached: Wing? = nil

local function rect(name: string, minX: number, maxX: number, minZ: number, maxZ: number): Rect
	return table.freeze({ name = name, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
end

function MansionWingLayout.get(): Wing
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local mansion = MansionLayout.get()
	local config = MansionWingConfig
	local t = GameConfig.Building.WallThickness
	local centerZ = mansion.center.Z
	-- A parede leste do Casarão (de mansion.maxX até +t) separa as duas.
	local minX = mansion.maxX + t
	local maxX = minX + config.Width
	local minZ = mansion.minZ
	local maxZ = mansion.maxZ
	local northZ = minZ + config.LibraryDepth
	local southZ = northZ + config.StairHallDepth
	local atticFloorY = mansion.ceilingY + 1
	local cellarFloorY = mansion.floorY - config.CellarHeight
	local stairLow = minX + config.StairStartInset
	local stairHigh = maxX - config.StairEndInset
	local half = MansionConfig.PartitionThickness / 2
	local innerDoorX = minX + config.InnerDoorInset
	local eastWallX = mansion.maxX + t / 2
	local door = config.DoorSize

	local doorways: { Doorway } = {
		{
			name = "LibraryDoor",
			center = Vector3.new(eastWallX, mansion.floorY, centerZ + config.LibraryDoorOffset),
			along = Vector3.zAxis,
			normal = Vector3.xAxis,
			size = door,
			labelPositive = "✨ SALÃO DA COLEÇÃO",
			labelNegative = "📚 BIBLIOTECA",
		},
		{
			name = "StairHallDoor",
			center = Vector3.new(eastWallX, mansion.floorY, centerZ + config.StairHallDoorOffset),
			along = Vector3.zAxis,
			normal = Vector3.xAxis,
			size = door,
			labelPositive = "🐶 JARDIM DO BARÃO",
			labelNegative = "🪜 ESCADARIA",
		},
		{
			name = "LibraryInnerDoor",
			center = Vector3.new(innerDoorX, mansion.floorY, northZ),
			along = Vector3.xAxis,
			normal = Vector3.zAxis,
			size = door,
			labelPositive = "📚 BIBLIOTECA",
			labelNegative = "🪜 ESCADARIA",
		},
		{
			name = "MusicInnerDoor",
			center = Vector3.new(innerDoorX, mansion.floorY, southZ),
			along = Vector3.xAxis,
			normal = Vector3.zAxis,
			size = door,
			labelPositive = "🪜 ESCADARIA",
			labelNegative = "🎹 SALA DE MÚSICA",
		},
	}

	local wing: Wing = {
		minX = minX,
		maxX = maxX,
		minZ = minZ,
		maxZ = maxZ,
		floorY = mansion.floorY,
		ceilingY = mansion.ceilingY,
		wallThickness = t,
		rooms = table.freeze({
			Library = rect("Library", minX, maxX, minZ, northZ),
			StairHall = rect("StairHall", minX, maxX, northZ, southZ),
			Music = rect("Music", minX, maxX, southZ, maxZ),
		}),
		northPartitionZ = northZ,
		southPartitionZ = southZ,
		atticFloorY = atticFloorY,
		atticCeilingY = atticFloorY + config.AtticHeight,
		cellarFloorY = cellarFloorY,
		-- Sobe de leste (pé) para oeste (topo), junto da parede norte do Hall.
		upStairs = {
			name = "AtticStairs",
			lowX = stairHigh,
			highX = stairLow,
			lowY = mansion.floorY,
			highY = atticFloorY,
			minZ = northZ + half,
			maxZ = northZ + half + config.StairWidth,
			steps = config.UpSteps,
		},
		-- Desce de oeste (topo) para leste (pé), junto da parede sul do Hall.
		downStairs = {
			name = "CellarStairs",
			lowX = stairHigh,
			highX = stairLow,
			lowY = cellarFloorY,
			highY = mansion.floorY,
			minZ = southZ - half - config.StairWidth,
			maxZ = southZ - half,
			steps = config.DownSteps,
		},
		doorways = doorways,
	}
	cached = wing
	return wing
end

local function insideXZ(wing: Wing, position: Vector3): boolean
	return position.X >= wing.minX and position.X <= wing.maxX and position.Z >= wing.minZ and position.Z <= wing.maxZ
end

-- No Sótão (acima do teto do andar principal).
function MansionWingLayout.inAttic(position: Vector3): boolean
	local wing = MansionWingLayout.get()
	return insideXZ(wing, position) and position.Y >= wing.atticFloorY - 0.5 and position.Y <= wing.atticCeilingY
end

-- Altura do degrau `index` (1 = o primeiro a partir do pé) de um lance.
function MansionWingLayout.stepTop(stair: Stair, index: number): number
	return stair.lowY + (stair.highY - stair.lowY) * (index / stair.steps)
end

return table.freeze(MansionWingLayout)
