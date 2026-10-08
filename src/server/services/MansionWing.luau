--!strict

-- Ala leste do Casarão (Fase 5C.1, parte 2): a estrutura (paredes, pisos,
-- tetos, escadas, guarda-corpos, portas e placas) da Biblioteca, do Hall da
-- Escadaria e da Sala de Música, mais o Sótão em cima e o Porão embaixo. Os
-- móveis ficam com o MansionWingDecor. Geometria: MansionWingLayout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionWingConfig = require(ReplicatedStorage.Shared.config.MansionWingConfig)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local BaronRoomsLayout = require(ReplicatedStorage.Shared.modules.BaronRoomsLayout)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local BaronRoomsBuilder = require(script.Parent.BaronRoomsBuilder)
local BuildingDecor = require(script.Parent.BuildingDecor)
local MansionDoors = require(script.Parent.MansionDoors)
local MansionPlaque = require(script.Parent.MansionPlaque)
local MansionWingDecor = require(script.Parent.MansionWingDecor)
local WallBuilder = require(script.Parent.WallBuilder)

type BuildingConfig = GameConfig.BuildingConfig
type Box = WallBuilder.Box
type DoorGap = BuildingDecor.DoorGap
type Wing = MansionWingLayout.Wing
type Stair = MansionWingLayout.Stair
type Doorway = MansionWingLayout.Doorway

local CONFIG = MansionWingConfig
local MODEL_NAME = "MansionWing"
local DECOR_SEED = 5021
local RAIL_THICKNESS = 0.4
local SLAB = 1
local CHANDELIER_DROP = 5
local RAMP_THICKNESS = 0.2

local MansionWing = {}

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return { min = Vector3.new(minX, minY, minZ), max = Vector3.new(maxX, maxY, maxZ) }
end

local function solid(parent: Instance, name: string, b: Box, color: Color3, material: Enum.Material)
	WallBuilder.createBox(parent, name, b, color, material)
end

-- Laje (piso ou teto) com um buraco retangular: até quatro faixas em volta.
local function slabWithHole(parent: Instance, name: string, slab: Box, hole: Box, color: Color3, material: Enum.Material)
	local y0, y1 = slab.min.Y, slab.max.Y
	solid(parent, `{name}North`, box(slab.min.X, y0, slab.min.Z, slab.max.X, y1, hole.min.Z), color, material)
	solid(parent, `{name}South`, box(slab.min.X, y0, hole.max.Z, slab.max.X, y1, slab.max.Z), color, material)
	solid(parent, `{name}West`, box(slab.min.X, y0, hole.min.Z, hole.min.X, y1, hole.max.Z), color, material)
	solid(parent, `{name}East`, box(hole.max.X, y0, hole.min.Z, slab.max.X, y1, hole.max.Z), color, material)
end

-- Vão de porta numa parede (atravessa a espessura toda).
local function doorHole(doorway: Doorway, thickness: number): Box
	local inward = doorway.normal
	local point = doorway.center - doorway.normal * (thickness / 2)
	return WallBuilder.hole(point, inward, doorway.along, thickness, doorway.size)
end

local function stairHole(stair: Stair): Box
	return box(math.min(stair.lowX, stair.highX), 0, stair.minZ, math.max(stair.lowX, stair.highX), 0, stair.maxZ)
end

-- Degraus maciços (do chão de baixo até o topo de cada degrau) e, em cada
-- lado aberto, uma mureta que acompanha a escada.
local function createStairs(parent: Instance, stair: Stair, baseY: number, openSides: { number }, style: BuildingConfig)
	local run = stair.highX - stair.lowX
	local depth = run / stair.steps
	for index = 1, stair.steps do
		local x0 = stair.lowX + depth * (index - 1)
		local x1 = x0 + depth
		local top = MansionWingLayout.stepTop(stair, index)
		local minX, maxX = math.min(x0, x1), math.max(x0, x1)
		solid(parent, `{stair.name}Step{index}`, box(minX, baseY, stair.minZ, maxX, top, stair.maxZ), style.WainscotColor, Enum.Material.WoodPlanks)
		for _, side in ipairs(openSides) do
			local z = if side < 0 then stair.minZ else stair.maxZ - RAIL_THICKNESS
			solid(parent, `{stair.name}Rail{index}`, box(minX, top, z, maxX, top + CONFIG.RailHeight, z + RAIL_THICKNESS), style.FrameColor, Enum.Material.Wood)
		end
	end
end

-- Rampa invisível sobre as quinas dos degraus, do primeiro ao penúltimo:
-- quem anda sobe e desce liso (no celular, sem tropeçar em cada degrau).
local function createRamp(parent: Instance, stair: Stair)
	local run = stair.highX - stair.lowX
	local depth = run / stair.steps
	local rise = (stair.highY - stair.lowY) / stair.steps
	local from = Vector3.new(stair.lowX, stair.lowY + rise, 0)
	local to = Vector3.new(stair.lowX + depth * (stair.steps - 1), stair.highY, 0)
	local direction = to - from
	local length = direction.Magnitude
	local z = (stair.minZ + stair.maxZ) / 2
	local width = stair.maxZ - stair.minZ
	local forward = direction.Unit
	local up = Vector3.zAxis:Cross(forward)
	if up.Y < 0 then
		up = -up
	end
	local center = Vector3.new((from.X + to.X) / 2, (from.Y + to.Y) / 2, z) - up * (RAMP_THICKNESS / 2)
	local ramp = BuildingDecor.createPart(parent, `{stair.name}Ramp`, Vector3.new(length, RAMP_THICKNESS, width), CFrame.fromMatrix(center, forward, up), Color3.new(1, 1, 1), {
		collide = true,
		transparency = 1,
	})
	-- Consultável: o Humanoid detecta o piso por raycast.
	ramp.CanQuery = true
	ramp.CastShadow = false
end

-- Guarda-corpo em volta de um buraco no piso, menos no lado `openX` (a
-- entrada da escada).
local function railAround(parent: Instance, name: string, hole: Box, floorY: number, openX: number, sides: { string }, style: BuildingConfig)
	local top = floorY + CONFIG.RailHeight
	local r = RAIL_THICKNESS
	for _, side in ipairs(sides) do
		if side == "North" then
			solid(parent, `{name}North`, box(hole.min.X, floorY, hole.min.Z - r, hole.max.X, top, hole.min.Z), style.FrameColor, Enum.Material.Wood)
		elseif side == "South" then
			solid(parent, `{name}South`, box(hole.min.X, floorY, hole.max.Z, hole.max.X, top, hole.max.Z + r), style.FrameColor, Enum.Material.Wood)
		end
	end
	local endX = if math.abs(openX - hole.min.X) < 0.01 then hole.max.X else hole.min.X
	solid(parent, `{name}End`, box(endX - r / 2, floorY, hole.min.Z, endX + r / 2, top, hole.max.Z), style.FrameColor, Enum.Material.Wood)
end

-- Vão de uma Sala Secreta do Barão na parede leste (BaronRoomsLayout).
local function passageHole(id: string): Box
	local room = BaronRoomsLayout.room(id)
	assert(room ~= nil, `Unknown baron room {id}`)
	local hole = room.passage.hole
	return box(hole.minX, hole.minY, hole.minZ, hole.maxX, hole.maxY, hole.maxZ)
end

-- Paredes externas da ala (norte, sul e leste) entre `y0` e `y1`; a oeste
-- fica a parede do Casarão. `eastHole`: vão de uma Sala Secreta na leste
-- (fechado pelo lacre do BaronRoomsBuilder).
local function outerWalls(parent: Instance, name: string, wing: Wing, y0: number, y1: number, color: Color3, material: Enum.Material, withWest: boolean, eastHole: Box?)
	local t = wing.wallThickness
	-- No andar principal a parede do Casarão já cobre o canto oeste.
	local x0 = if withWest then wing.minX - t else wing.minX
	solid(parent, `{name}North`, box(x0, y0, wing.minZ - t, wing.maxX + t, y1, wing.minZ), color, material)
	solid(parent, `{name}South`, box(x0, y0, wing.maxZ, wing.maxX + t, y1, wing.maxZ + t), color, material)
	local east = box(wing.maxX, y0, wing.minZ, wing.maxX + t, y1, wing.maxZ)
	if eastHole ~= nil then
		WallBuilder.createWallWithHoles(parent, `{name}East`, east, { eastHole }, color, material)
	else
		solid(parent, `{name}East`, east, color, material)
	end
	if withWest then
		solid(parent, `{name}West`, box(wing.minX - t, y0, wing.minZ, wing.minX, y1, wing.maxZ), color, material)
	end
end

-- Andar principal: piso (com o buraco da escada do Porão), teto (com o da
-- escada do Sótão), paredes externas e as duas divisórias com porta.
local function createMainLevel(parent: Instance, wing: Wing, style: BuildingConfig)
	local t = wing.wallThickness
	local floorY = wing.floorY
	local downHole = stairHole(wing.downStairs)
	local upHole = stairHole(wing.upStairs)
	slabWithHole(parent, "WingFloor", box(wing.minX, floorY - SLAB, wing.minZ - t, wing.maxX + t, floorY, wing.maxZ + t), downHole, MansionConfig.FloorColor, Enum.Material.WoodPlanks)
	slabWithHole(parent, "WingCeiling", box(wing.minX, wing.ceilingY, wing.minZ - t, wing.maxX + t, wing.atticFloorY, wing.maxZ + t), upHole, CONFIG.AtticColor, Enum.Material.WoodPlanks)
	outerWalls(parent, "WingWall", wing, floorY, wing.ceilingY, CONFIG.WallpaperColors.StairHall :: Color3, Enum.Material.Plaster, false, passageHole("Study"))

	local half = MansionConfig.PartitionThickness / 2
	for _, doorway in ipairs(wing.doorways) do
		if doorway.normal == Vector3.zAxis then
			local z = doorway.center.Z
			local wall = box(wing.minX, floorY, z - half, wing.maxX, wing.ceilingY, z + half)
			WallBuilder.createWallWithHoles(parent, `{doorway.name}Wall`, wall, { doorHole(doorway, MansionConfig.PartitionThickness) }, CONFIG.WallpaperColors.StairHall :: Color3, Enum.Material.Plaster)
		end
	end
	railAround(parent, "CellarRail", downHole, floorY, downHole.min.X, { "North" }, style)
end

local function createAttic(parent: Instance, wing: Wing, style: BuildingConfig)
	local t = wing.wallThickness
	outerWalls(parent, "AtticWall", wing, wing.atticFloorY, wing.atticCeilingY, CONFIG.AtticColor, Enum.Material.WoodPlanks, true)
	solid(parent, "AtticRoof", box(wing.minX - t, wing.atticCeilingY, wing.minZ - t, wing.maxX + t, wing.atticCeilingY + SLAB, wing.maxZ + t), CONFIG.AtticColor, Enum.Material.WoodPlanks)
	railAround(parent, "AtticRail", stairHole(wing.upStairs), wing.atticFloorY, wing.upStairs.highX, { "North", "South" }, style)
end

local function createCellar(parent: Instance, wing: Wing)
	local t = wing.wallThickness
	local floorTop = wing.cellarFloorY
	solid(parent, "CellarFloor", box(wing.minX - t, floorTop - SLAB, wing.minZ - t, wing.maxX + t, floorTop, wing.maxZ + t), CONFIG.CellarFloorColor, Enum.Material.Cobblestone)
	outerWalls(parent, "CellarWall", wing, floorTop, wing.floorY - SLAB, CONFIG.CellarColor, Enum.Material.Brick, true, passageHole("Treasure"))
end

-- Papel de parede, lambri e quadros das faces do andar principal.
local function decorateWalls(parent: Instance, wing: Wing, style: BuildingConfig)
	local rng = Random.new(DECOR_SEED)
	local colors = CONFIG.WallpaperColors
	local half = MansionConfig.PartitionThickness / 2
	local function gapsFor(origin: Vector3, along: Vector3, length: number, faceZ: number?, faceX: number?): { DoorGap }
		local gaps: { DoorGap } = {}
		for _, doorway in ipairs(wing.doorways) do
			local onFace = (faceZ ~= nil and doorway.normal == Vector3.zAxis and math.abs(doorway.center.Z - faceZ) < 2)
				or (faceX ~= nil and doorway.normal == Vector3.xAxis and math.abs(doorway.center.X - faceX) < 3)
			local offset = (doorway.center - origin):Dot(along)
			if onFace and math.abs(offset) + doorway.size.X / 2 <= length / 2 then
				table.insert(gaps, { offset = offset, frame = true, width = doorway.size.X, height = doorway.size.Y })
			end
		end
		return gaps
	end
	-- Vão do Gabinete (atrás da estante): sem papel de parede nem moldura.
	local studyHole = passageHole("Study")
	local function face(name: string, a: Vector3, b: Vector3, inward: Vector3, color: Color3, faceZ: number?, faceX: number?, noArt: boolean?)
		local origin = Vector3.new((a.X + b.X) / 2, 0, (a.Z + b.Z) / 2)
		local along = inward:Cross(Vector3.yAxis)
		local length = Vector2.new(b.X - a.X, b.Z - a.Z).Magnitude
		local gaps = gapsFor(origin, along, length, faceZ, faceX)
		if name == "LibraryEast" then
			local center = (studyHole.min + studyHole.max) / 2
			table.insert(gaps, {
				offset = (center - origin):Dot(along),
				frame = false,
				width = studyHole.max.Z - studyHole.min.Z,
				height = studyHole.max.Y - studyHole.min.Y,
			})
		end
		BuildingDecor.decorateStory(parent, {
			name = name,
			origin = origin,
			inward = inward,
			length = length,
			bottomY = wing.floorY,
			topY = wing.ceilingY,
		}, wing.floorY, wing.ceilingY, style, {
			wallpaperColor = color,
			lamps = false,
			art = noArt ~= true,
			windows = false,
			door = false,
			gaps = gaps,
			lampRange = 0,
			lampBrightness = 0,
		}, rng)
	end
	local x0, x1 = wing.minX, wing.maxX
	local nz, sz = wing.northPartitionZ, wing.southPartitionZ
	local toEast, toWest = Vector3.xAxis, -Vector3.xAxis
	local toSouth, toNorth = Vector3.zAxis, -Vector3.zAxis
	local function at(x: number, z: number): Vector3
		return Vector3.new(x, 0, z)
	end
	-- Biblioteca
	face("LibraryNorth", at(x0, wing.minZ), at(x1, wing.minZ), toSouth, colors.Library)
	face("LibraryWest", at(x0, wing.minZ), at(x0, nz - half), toEast, colors.Library, nil, x0 - wing.wallThickness / 2)
	face("LibraryEast", at(x1, wing.minZ), at(x1, nz - half), toWest, colors.Library)
	face("LibrarySouth", at(x0, nz - half), at(x1, nz - half), toNorth, colors.Library, nz)
	-- Hall da Escadaria: só a parede oeste (as outras ficam atrás das escadas).
	face("StairHallWest", at(x0, nz + half), at(x0, sz - half), toEast, colors.StairHall, nil, x0 - wing.wallThickness / 2)
	-- Sala de Música
	face("MusicNorth", at(x0, sz + half), at(x1, sz + half), toSouth, colors.Music, sz)
	face("MusicWest", at(x0, sz + half), at(x0, wing.maxZ), toEast, colors.Music)
	face("MusicEast", at(x1, sz + half), at(x1, wing.maxZ), toWest, colors.Music)
	-- Sem quadros: ali ficam as partituras (MansionWingDecor).
	face("MusicSouth", at(x0, wing.maxZ), at(x1, wing.maxZ), toNorth, colors.Music, nil, nil, true)
end

-- Placas dos dois lados de cada porta interna da ala e do lado da ala nas
-- portas da parede leste do Casarão (o lado do Casarão é do MansionService).
local function createPlaques(parent: Instance, wing: Wing, style: BuildingConfig)
	for _, doorway in ipairs(wing.doorways) do
		local internal = doorway.normal == Vector3.zAxis
		local depth = if internal then MansionConfig.PartitionThickness / 2 else wing.wallThickness / 2
		local y = wing.floorY + doorway.size.Y + MansionPlaque.Lift
		for _, sideInfo in ipairs({ { 1, doorway.labelPositive }, { -1, doorway.labelNegative } }) do
			local side = sideInfo[1] :: number
			local label = sideInfo[2] :: string?
			if label ~= nil and (internal or side > 0) then
				local inward = doorway.normal * side
				local along = inward:Cross(Vector3.yAxis)
				local position = Vector3.new(doorway.center.X, y, doorway.center.Z) + inward * (depth + 0.55)
				MansionPlaque.create(parent, `{doorway.name}Plaque`, CFrame.fromMatrix(position, along, Vector3.yAxis), Lang.t(label), style)
			end
		end
	end
end

local function createLights(parent: Instance, wing: Wing, style: BuildingConfig)
	for _, roomName in ipairs({ "Library", "StairHall", "Music" }) do
		local room = wing.rooms[roomName]
		assert(room ~= nil, `Unknown wing room {roomName}`)
		local anchor = Vector3.new((room.minX + room.maxX) / 2, wing.ceilingY, (room.minZ + room.maxZ) / 2)
		BuildingDecor.createChandelier(parent, `{roomName}Chandelier`, anchor, CHANDELIER_DROP, 2.2, style, MansionConfig.ChandelierRange, MansionConfig.ChandelierBrightness, false)
	end
end

function MansionWing.build(parent: Instance, style: BuildingConfig): Model
	local wing = MansionWingLayout.get()
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	createMainLevel(model, wing, style)
	createStairs(model, wing.upStairs, wing.floorY, { 1 }, style)
	createStairs(model, wing.downStairs, wing.cellarFloorY, { -1 }, style)
	createRamp(model, wing.upStairs)
	createRamp(model, wing.downStairs)
	createAttic(model, wing, style)
	createCellar(model, wing)
	decorateWalls(model, wing, style)
	createPlaques(model, wing, style)
	createLights(model, wing, style)
	MansionDoors.build(model, wing.doorways)
	MansionWingDecor.build(model, wing, style)
	-- Depois da decoração: marca a estante e o túnel como passagens.
	BaronRoomsBuilder.build(model, style)
	model.Parent = parent
	return model
end

return table.freeze(MansionWing)
