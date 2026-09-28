--!strict

-- Geometria pura do Casarão (lobby principal). Fonte única das medidas para
-- quem constrói (MansionService), quem posiciona jogadores (LobbyService) e
-- quem coloca estações (LobbyStationsService, TrainingService, segredos).
--
-- Planta (vista de cima, X para a direita, Z para baixo):
--
--   galeria | ┌───────────── Salão da Coleção (norte) ─────────────┐
--   (arena) | ├──── arco ──────────────────────────── arco ─────────┤
--    porta ─┼─│  Salão Principal (nascimento)  │ arco │  Jardim do  │
--    porta ─┼─│   estátua no meio              │      │  Barão/Loja │
--    porta ─┼─├──── arco ──────────────────────────── arco ─────────┤
--           | └── Ponto de Encontro (desafios) ──┴── Treino (sul) ──┘

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)

export type Rect = {
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

-- Divisória interna com os vãos (arcos) ao longo dela.
export type Partition = {
	name: string,
	-- "X": corre ao longo de X (em Z fixo); "Z": ao longo de Z (em X fixo).
	axis: "X" | "Z",
	fixed: number,
	from: number,
	to: number,
	arches: { number },
}

export type Mansion = {
	floorY: number,
	ceilingY: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	center: Vector3,
	rooms: { [string]: Rect },
	partitions: { Partition },
	-- Posição Z (mundo) de cada porta entre a galeria e o Salão Principal.
	passages: { number },
	-- X da face da parede da galeria voltada para o Casarão.
	galleryWallX: number,
}

local MansionLayout = {}

local cached: Mansion? = nil

local function rect(name: string, minX: number, maxX: number, minZ: number, maxZ: number): Rect
	return table.freeze({ name = name, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
end

function MansionLayout.get(): Mansion
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local arena = GameConfig.Arena
	local building = GameConfig.Building
	local gallery = BuildingLayout.getGallery(arena, building)
	local config = MansionConfig
	local wallX = gallery.innerX + building.GalleryDepth + building.WallThickness
	local minX = wallX
	local maxX = minX + config.Width
	local centerZ = gallery.center.Z
	local minZ = centerZ - config.Depth / 2
	local maxZ = centerZ + config.Depth / 2
	local northWall = minZ + config.WingDepth
	local southWall = maxZ - config.WingDepth
	local hallEast = minX + config.HallWidth
	local meetingEast = hallEast - 5
	local leftArch = minX + config.HallWidth / 2
	local rightArch = hallEast + (maxX - hallEast) / 2

	local passages: { number } = {}
	for _, offset in ipairs(config.PassageOffsets) do
		table.insert(passages, centerZ + offset)
	end

	local mansion: Mansion = {
		floorY = gallery.floorY,
		ceilingY = gallery.floorY + config.CeilingHeight,
		minX = minX,
		maxX = maxX,
		minZ = minZ,
		maxZ = maxZ,
		center = Vector3.new((minX + maxX) / 2, gallery.floorY, centerZ),
		rooms = table.freeze({
			GrandHall = rect("GrandHall", minX, hallEast, northWall, southWall),
			Collection = rect("Collection", minX, maxX, minZ, northWall),
			Garden = rect("Garden", hallEast, maxX, northWall, southWall),
			Meeting = rect("Meeting", minX, meetingEast, southWall, maxZ),
			Training = rect("Training", meetingEast, maxX, southWall, maxZ),
		}),
		partitions = table.freeze({
			{ name = "NorthPartition", axis = "X", fixed = northWall, from = minX, to = maxX, arches = { leftArch, rightArch } },
			{ name = "SouthPartition", axis = "X", fixed = southWall, from = minX, to = maxX, arches = { leftArch, rightArch } },
			{ name = "HallPartition", axis = "Z", fixed = hallEast, from = northWall, to = southWall, arches = { centerZ } },
		} :: { Partition }),
		passages = passages,
		galleryWallX = wallX,
	}
	cached = mansion
	return mansion
end

function MansionLayout.room(name: string): Rect
	local room = MansionLayout.get().rooms[name]
	assert(room ~= nil, `Unknown mansion room {name}`)
	return room
end

-- Centro de uma sala, no nível do piso.
function MansionLayout.roomCenter(name: string): Vector3
	local room = MansionLayout.room(name)
	return Vector3.new((room.minX + room.maxX) / 2, MansionLayout.get().floorY, (room.minZ + room.maxZ) / 2)
end

-- Dentro do Casarão (qualquer sala), com folga de altura.
function MansionLayout.contains(position: Vector3): boolean
	local mansion = MansionLayout.get()
	return position.X >= mansion.minX
		and position.X <= mansion.maxX
		and position.Z >= mansion.minZ
		and position.Z <= mansion.maxZ
		and position.Y >= mansion.floorY - 2
		and position.Y <= mansion.ceilingY
end

-- Lugares para colocar gente no Salão Principal, em grade, longe das
-- paredes e da estátua do meio.
local SPAWN_INSET = 5
local SPAWN_SPACING = 6
local STATUE_CLEARANCE = 7
local SPAWN_HEIGHT = 5

function MansionLayout.spawnCFrames(): { CFrame }
	local mansion = MansionLayout.get()
	local hall = mansion.rooms.GrandHall
	local center = MansionLayout.roomCenter("GrandHall")
	local slots: { CFrame } = {}
	local x = hall.minX + SPAWN_INSET
	while x <= hall.maxX - SPAWN_INSET do
		local z = hall.minZ + SPAWN_INSET
		while z <= hall.maxZ - SPAWN_INSET do
			local position = Vector3.new(x, mansion.floorY + SPAWN_HEIGHT, z)
			if Vector2.new(x - center.X, z - center.Z).Magnitude > STATUE_CLEARANCE then
				-- Olhando para o meio do salão.
				table.insert(slots, CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)))
			end
			z += SPAWN_SPACING
		end
		x += SPAWN_SPACING
	end
	return slots
end

return table.freeze(MansionLayout)
