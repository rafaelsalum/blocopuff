--!strict

-- Acabamento do Casarão-lobby na Ala do Assassinato (os outros andares do
-- Casarão): papel de parede, lambri, rodapé, sanca, quadros e arandelas
-- (BuildingDecor.decorateStory), molduras e placas com o nome do cômodo sobre
-- as portas (MansionPlaque), teto de gesso com vigas e o lustre de latão do
-- lobby no meio de cada cômodo. Nada aqui colide nem entra em raycast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MurderMansionPlan = require(script.Parent.Parent.data.MurderMansionPlan)
local BuildingDecor = require(script.Parent.BuildingDecor)
local MansionPlaque = require(script.Parent.MansionPlaque)

type Plan = MurderMansionPlan.Plan
type Room = MurderMansionPlan.Room
type DoorGap = BuildingDecor.DoorGap
type ToWorld = (number, number, number) -> Vector3

local SEED = 8191
-- Metade da espessura das paredes (MurderMansionBuilder): a face interna.
local HALF_WALL = 0.5
-- Espessura da laje entre os andares e do forro de gesso.
local SLAB_THICKNESS = 1
local CEILING_THICKNESS = 0.2
local BEAM_SIZE = 1
local BEAM_SPACING = 14
-- Pé-direito de 14: o lustre desce menos que no lobby (24).
local CHANDELIER_DROP = 3
local CHANDELIER_RADIUS = 2.2
-- Arandelas só nas paredes norte e sul, fracas (só acento, como no lobby).
local SCONCE_RANGE = 14
local SCONCE_BRIGHTNESS = 0.45
-- Placa logo acima da moldura da porta, abaixo da sanca.
local PLAQUE_LIFT = 2.3
-- Abertura da passagem secreta (MurderMansionBuilder).
local PASSAGE_GAP_HEIGHT = 8

local WALLPAPER = MansionConfig.WallpaperColors
local ROOM_STYLE: { [string]: { color: Color3, label: string } } = {
	library = { color = WALLPAPER.Collection, label = "📚 BIBLIOTECA" },
	dining = { color = WALLPAPER.GrandHall, label = "🍷 SALA DE JANTAR" },
	kitchen = { color = WALLPAPER.Meeting, label = "🍳 COZINHA" },
	ballroom = { color = WALLPAPER.Training, label = "💃 SALÃO DE BAILE" },
	hall = { color = WALLPAPER.GrandHall, label = "🚪 HALL DE ENTRADA" },
	lounge = { color = WALLPAPER.Garden, label = "☕ SALA DE ESTAR" },
	baronBedroom = { color = WALLPAPER.GrandHall, label = "🌙 QUARTO DO BARÃO" },
	portraits = { color = WALLPAPER.Meeting, label = "👑 CORREDOR DOS RETRATOS" },
	guestBedroom = { color = WALLPAPER.Training, label = "🧳 QUARTO DE HÓSPEDES" },
	music = { color = WALLPAPER.Collection, label = "🎹 SALA DE MÚSICA" },
	games = { color = WALLPAPER.Garden, label = "🎲 SALA DE JOGOS" },
	greenhouse = { color = WALLPAPER.Garden, label = "🌿 ESTUFA" },
}

type Face = {
	name: string,
	-- Centro da face interna (y = 0).
	origin: Vector3,
	inward: Vector3,
	length: number,
}

local MurderMansionDecor = {}

local function styleOf(room: Room): { color: Color3, label: string }
	return ROOM_STYLE[room.id] or { color = WALLPAPER.GrandHall, label = room.name }
end

local function faces(room: Room, toWorld: ToWorld): { [string]: Face }
	local midX = (room.minX + room.maxX) / 2
	local midZ = (room.minZ + room.maxZ) / 2
	local width = room.maxX - room.minX - HALF_WALL * 2
	local depth = room.maxZ - room.minZ - HALF_WALL * 2
	local function at(x: number, z: number): Vector3
		local world = toWorld(x, z, 0)
		return Vector3.new(world.X, 0, world.Z)
	end
	return {
		N = { name = `{room.id}North`, origin = at(midX, room.minZ + HALF_WALL), inward = Vector3.zAxis, length = width },
		S = { name = `{room.id}South`, origin = at(midX, room.maxZ - HALF_WALL), inward = -Vector3.zAxis, length = width },
		W = { name = `{room.id}West`, origin = at(room.minX + HALF_WALL, midZ), inward = Vector3.xAxis, length = depth },
		E = { name = `{room.id}East`, origin = at(room.maxX - HALF_WALL, midZ), inward = -Vector3.xAxis, length = depth },
	}
end

-- Lado do cômodo em que está o ponto (x, z) da planta, na borda dele.
local function sideAt(room: Room, x: number, z: number): string?
	if math.abs(z - room.minZ) < 0.01 then
		return "N"
	elseif math.abs(z - room.maxZ) < 0.01 then
		return "S"
	elseif math.abs(x - room.minX) < 0.01 then
		return "W"
	elseif math.abs(x - room.maxX) < 0.01 then
		return "E"
	end
	return nil
end

local function byId(plan: Plan): { [string]: Room }
	local rooms: { [string]: Room } = {}
	for _, room in ipairs(plan.rooms) do
		rooms[room.id] = room
	end
	return rooms
end

-- Vãos de cada face do cômodo: portas (com moldura e a placa do cômodo do
-- outro lado) e a abertura da passagem secreta (sem moldura: as estantes de
-- MurderMansionProps fazem o batente).
local function openings(plan: Plan, room: Room, rooms: { [string]: Room }): { [string]: { { x: number, z: number, gap: DoorGap, label: string? } } }
	local result: { [string]: { { x: number, z: number, gap: DoorGap, label: string? } } } = { N = {}, S = {}, W = {}, E = {} }
	for _, door in ipairs(plan.doors) do
		local other = if door.from == room.id then door.to elseif door.to == room.id then door.from else nil
		local side = if other ~= nil then sideAt(room, door.x, door.z) else nil
		if other ~= nil and side ~= nil then
			table.insert(result[side], {
				x = door.x,
				z = door.z,
				gap = { offset = 0, frame = true, width = plan.doorWidth, height = plan.doorHeight },
				label = styleOf(rooms[other]).label,
			})
		end
	end
	for _, passage in ipairs(plan.passages) do
		for _, entry in ipairs({ { passage.fromRoom, passage.fromX }, { passage.toRoom, passage.toX } }) do
			if entry[1] == room.id then
				table.insert(result.N, {
					x = entry[2] :: number,
					z = passage.wallZ,
					gap = { offset = 0, frame = false, width = passage.gapWidth, height = PASSAGE_GAP_HEIGHT },
					label = nil,
				})
			end
		end
	end
	return result
end

local function decorateWalls(parent: Instance, plan: Plan, room: Room, rooms: { [string]: Room }, toWorld: ToWorld, style: GameConfig.BuildingConfig, rng: Random)
	local floorY = toWorld(0, 0, room.level).Y
	local ceilingY = floorY + (if room.level == 0 then plan.floorHeight - SLAB_THICKNESS else plan.wallHeight)
	local roomFaces = faces(room, toWorld)
	local roomOpenings = openings(plan, room, rooms)
	for side, face in pairs(roomFaces) do
		local along = face.inward:Cross(Vector3.yAxis)
		local gaps: { DoorGap } = {}
		for _, opening in ipairs(roomOpenings[side]) do
			local point = toWorld(opening.x, opening.z, 0)
			local offset = (Vector3.new(point.X, 0, point.Z) - face.origin):Dot(along)
			table.insert(gaps, {
				offset = offset,
				frame = opening.gap.frame,
				width = opening.gap.width,
				height = opening.gap.height,
			})
			local label = opening.label
			if label ~= nil then
				local height = (opening.gap.height or plan.doorHeight) + PLAQUE_LIFT
				local position = face.origin + along * offset + face.inward * 0.55 + Vector3.new(0, floorY + height, 0)
				MansionPlaque.create(parent, `{face.name}Plaque`, CFrame.fromMatrix(position, along, Vector3.yAxis), label, style)
			end
		end
		local lamps = side == "N" or side == "S"
		BuildingDecor.decorateStory(parent, {
			name = face.name,
			origin = face.origin,
			inward = face.inward,
			length = face.length,
			bottomY = floorY,
			topY = ceilingY,
		}, floorY, ceilingY, style, {
			wallpaperColor = styleOf(room).color,
			lamps = lamps,
			art = true,
			windows = false,
			door = false,
			gaps = gaps,
			lampRange = SCONCE_RANGE,
			lampBrightness = SCONCE_BRIGHTNESS,
		}, rng)
	end
	return ceilingY
end

-- Faixas do forro do térreo, sem o vão da escada que sobe deste cômodo (o
-- mesmo recorte da laje de cima em MurderMansionBuilder).
local function ceilingAreas(plan: Plan, room: Room): { MurderMansionPlan.Area }
	local inner: MurderMansionPlan.Area = {
		minX = room.minX + HALF_WALL,
		maxX = room.maxX - HALF_WALL,
		minZ = room.minZ + HALF_WALL,
		maxZ = room.maxZ - HALF_WALL,
	}
	if room.level ~= 0 then
		return { inner }
	end
	for _, stair in ipairs(plan.stairs) do
		if stair.lowerRoom == room.id then
			local holeMin = stair.x - stair.width / 2
			local holeMax = stair.x + stair.width / 2
			local landingMaxZ = math.min(stair.topZ, stair.bottomZ)
			return {
				{ minX = math.max(inner.minX, holeMax), maxX = inner.maxX, minZ = inner.minZ, maxZ = inner.maxZ },
				{ minX = inner.minX, maxX = math.min(inner.maxX, holeMin), minZ = inner.minZ, maxZ = inner.maxZ },
				{ minX = math.max(inner.minX, holeMin), maxX = math.min(inner.maxX, holeMax), minZ = inner.minZ, maxZ = landingMaxZ },
			}
		end
	end
	return { inner }
end

local function decorateCeiling(parent: Instance, plan: Plan, room: Room, toWorld: ToWorld, ceilingY: number, style: GameConfig.BuildingConfig)
	for index, area in ipairs(ceilingAreas(plan, room)) do
		local width = area.maxX - area.minX
		local depth = area.maxZ - area.minZ
		if width > 0.1 and depth > 0.1 then
			local center = toWorld((area.minX + area.maxX) / 2, (area.minZ + area.maxZ) / 2, 0)
			BuildingDecor.createPart(parent, `{room.id}Ceiling{index}`, Vector3.new(width, CEILING_THICKNESS, depth), CFrame.new(center.X, ceilingY - CEILING_THICKNESS / 2, center.Z), MansionConfig.CeilingColor, {
				material = Enum.Material.Plaster,
			})
		end
	end
	local width = room.maxX - room.minX
	local beamCount = math.max(1, math.floor(width / BEAM_SPACING))
	local depth = room.maxZ - room.minZ - HALF_WALL * 2
	for index = 1, beamCount do
		local x = room.minX + index * (width / (beamCount + 1))
		local center = toWorld(x, (room.minZ + room.maxZ) / 2, 0)
		BuildingDecor.createPart(parent, `{room.id}Beam{index}`, Vector3.new(BEAM_SIZE, BEAM_SIZE, depth), CFrame.new(center.X, ceilingY - CEILING_THICKNESS - BEAM_SIZE / 2, center.Z), style.CeilingBeamColor, {
			material = Enum.Material.Wood,
		})
	end
	local middle = toWorld((room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2, 0)
	BuildingDecor.createChandelier(parent, `{room.id}Chandelier`, Vector3.new(middle.X, ceilingY - CEILING_THICKNESS, middle.Z), CHANDELIER_DROP, CHANDELIER_RADIUS, style, MansionConfig.ChandelierRange, MansionConfig.ChandelierBrightness, false)
end

function MurderMansionDecor.decorate(parent: Instance, plan: Plan, toWorld: ToWorld)
	local style = GameConfig.Building
	local rng = Random.new(SEED)
	local rooms = byId(plan)
	local folder = Instance.new("Model")
	folder.Name = "MansionFinish"
	for _, room in ipairs(plan.rooms) do
		local ceilingY = decorateWalls(folder, plan, room, rooms, toWorld, style, rng)
		decorateCeiling(folder, plan, room, toWorld, ceilingY, style)
	end
	folder.Parent = parent
end

return table.freeze(MurderMansionDecor)
