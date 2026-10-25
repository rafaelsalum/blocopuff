--!strict

-- Lado de fora do Casarão com cara de castelo (inspirado em Hogwarts): o
-- prédio da Arena, o Casarão, a ala leste, os anexos dela (Salas do Barão e
-- Sala de Troféus) e o Saguão da Torre ganham pedra, janelas góticas,
-- contrafortes e ameias (CastleFacade), telhados de ardósia de duas águas,
-- torres redondas com telhado pontudo e uma torre de menagem com pináculo no
-- meio do telhado (CastleTowers). Só por fora: as torres ficam afastadas o
-- bastante para não entrar em nenhuma sala. Chamar depois do BuildingService
-- e do MansionService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OutdoorConfig = require(ReplicatedStorage.Shared.config.OutdoorConfig)
local CastleEntrance = require(script.Parent.CastleEntrance)
local CastleFacade = require(script.Parent.CastleFacade)
local CastleTowers = require(script.Parent.CastleTowers)
local CastleWindows = require(script.Parent.CastleWindows)

local MODEL_NAME = "CastleExterior"
local TOWER_SINK = 4
-- As fachadas descem um pouco abaixo do chão (o terreno ondula).
local FACADE_SINK = 4
-- Alcance normal da medição das fachadas e o do prédio da Arena, cuja
-- parede principal fica atrás dos corredores secretos.
local REACH = 4
local BUILDING_REACH = 24
-- Espessura das paredes de fora (a torre do canto não pode passar dela).
local WALL = 2
local TOWER_CLEARANCE = 0.5
-- Folga para a ponta da ameia não encostar na parede de cima.
local WALL_GAP = 0.05
-- Janelas: peitoril acima do piso de cada andar e altura do vão.
local WINDOW_SILL = 4
local WINDOW_HEIGHT = 7
local ATTIC_WINDOW_SILL = 3
local ATTIC_WINDOW_HEIGHT = 6
-- No prédio da Arena, as janelas ficam acima dos corredores secretos.
local BUILDING_WINDOW_DROP = 12
-- Folga em volta da porta principal sem revestimento, e em volta do portal
-- sem janela nem contraforte.
local DOOR_CLEAR = 0.3
local PORTAL_RESERVE = 9

type Face = CastleFacade.Face
type Area = CastleFacade.Area
type WindowBand = CastleFacade.WindowBand
type Volume = { minX: number, maxX: number, minZ: number, maxZ: number, top: number }
-- Retângulo no chão ocupado pelo castelo por fora (torres e escadaria).
export type Block = { minX: number, maxX: number, minZ: number, maxZ: number }

local CastleExterior = {}

local blocks: { Block } = {}
-- Janelas escolhidas na montagem, esperando o resto do mundo ficar pronto.
local pending: { model: Model, spots: { CastleFacade.WindowSpot }, targets: { Instance } }? = nil

local function bounds(instance: Instance?): Volume?
	if instance == nil then
		return nil
	end
	local parts: { Instance } = if instance:IsA("BasePart") then { instance } else instance:GetDescendants()
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, item in ipairs(parts) do
		if item:IsA("BasePart") then
			low = low:Min(item.Position - item.Size / 2)
			high = high:Max(item.Position + item.Size / 2)
		end
	end
	if low.X == math.huge then
		return nil
	end
	return { minX = low.X, maxX = high.X, minZ = low.Z, maxZ = high.Z, top = high.Y }
end

local function find(parent: Instance?, name: string): Instance?
	return if parent ~= nil then parent:FindFirstChild(name) else nil
end

-- Fachada de um lado do volume: "N" (z mínimo), "S", "W" (x mínimo) ou "E",
-- de `from` a `to` studs ao longo dela (padrão: inteira).
type Extras = { windows: { WindowBand }?, clear: { Area }?, reserve: { Area }? }

local function face(volume: Volume, side: string, bottom: number, reach: number, plinthTop: number, from: number?, to: number?, extras: Extras?): Face
	local origin: Vector3, along: Vector3, normal: Vector3, length: number
	if side == "N" then
		origin, along, normal, length = Vector3.new(volume.minX, 0, volume.minZ), Vector3.xAxis, -Vector3.zAxis, volume.maxX - volume.minX
	elseif side == "S" then
		origin, along, normal, length = Vector3.new(volume.minX, 0, volume.maxZ), Vector3.xAxis, Vector3.zAxis, volume.maxX - volume.minX
	elseif side == "W" then
		origin, along, normal, length = Vector3.new(volume.minX, 0, volume.minZ), Vector3.zAxis, -Vector3.xAxis, volume.maxZ - volume.minZ
	else
		origin, along, normal, length = Vector3.new(volume.maxX, 0, volume.minZ), Vector3.zAxis, Vector3.xAxis, volume.maxZ - volume.minZ
	end
	local start = from or 0
	return {
		name = side,
		origin = origin + along * start,
		along = along,
		normal = normal,
		length = (to or length) - start,
		bottom = bottom,
		top = volume.top - WALL_GAP,
		reach = reach,
		plinthTop = plinthTop,
		windows = if extras ~= nil and extras.windows ~= nil then extras.windows else {},
		clear = if extras ~= nil and extras.clear ~= nil then extras.clear else {},
		reserve = if extras ~= nil and extras.reserve ~= nil then extras.reserve else {},
	}
end

-- Ameias nas beiras do telhado, menos nos lados de `skip` (que encostam
-- num volume mais alto).
local function battlements(parent: Instance, volume: Volume, skip: { string })
	local y = volume.top
	local edges = {
		{ side = "N", from = Vector3.new(volume.minX, y, volume.minZ), to = Vector3.new(volume.maxX, y, volume.minZ), inward = Vector3.zAxis },
		{ side = "S", from = Vector3.new(volume.minX, y, volume.maxZ), to = Vector3.new(volume.maxX, y, volume.maxZ), inward = -Vector3.zAxis },
		{ side = "W", from = Vector3.new(volume.minX, y, volume.minZ), to = Vector3.new(volume.minX, y, volume.maxZ), inward = Vector3.xAxis },
		{ side = "E", from = Vector3.new(volume.maxX, y, volume.minZ), to = Vector3.new(volume.maxX, y, volume.maxZ), inward = -Vector3.xAxis },
	}
	for _, edge in ipairs(edges) do
		if table.find(skip, edge.side) == nil then
			CastleTowers.parapet(parent, edge.from, edge.to, edge.inward)
		end
	end
end

-- Torre num canto de fora do volume (`dx`, `dz` = -1 ou 1: para que lado o
-- canto fica), afastada na diagonal até não entrar na sala do canto.
local function cornerTower(parent: Instance, name: string, volume: Volume, dx: number, dz: number, radius: number, top: number, roofHeight: number, ground: number)
	local cornerX = if dx < 0 then volume.minX else volume.maxX
	local cornerZ = if dz < 0 then volume.minZ else volume.maxZ
	local offset = math.max(0, radius / math.sqrt(2) - WALL + TOWER_CLEARANCE)
	local center = Vector3.new(cornerX + dx * offset, 0, cornerZ + dz * offset)
	CastleTowers.round(parent, name, { center = center, radius = radius, bottom = ground - TOWER_SINK, top = top, roofHeight = roofHeight })
	table.insert(blocks, { minX = center.X - radius, maxX = center.X + radius, minZ = center.Z - radius, maxZ = center.Z + radius })
end

function CastleExterior.build(world: Instance): Model?
	local existing = world:FindFirstChild(MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	table.clear(blocks)
	local mansionModel = world:FindFirstChild("Mansion")
	local buildingModel = world:FindFirstChild("Building")
	local wingModel = find(mansionModel, "MansionWing")
	-- O prédio inteiro (com os corredores secretos de fora) e só o corpo
	-- principal, pelo teto (onde vão as ameias, as torres e o telhado).
	local buildingOuter = bounds(buildingModel)
	local building = bounds(find(buildingModel, "Ceiling"))
	local mansion = bounds(find(mansionModel, "MansionCeiling"))
	local mansionFloor = find(mansionModel, "MansionFloor")
	if buildingModel == nil or mansionModel == nil or buildingOuter == nil or building == nil or mansion == nil or mansionFloor == nil or not mansionFloor:IsA("BasePart") then
		warn("[BlocoPuff] Castle exterior skipped: building or mansion missing")
		return nil
	end
	local wing = bounds(find(wingModel, "AtticRoof"))
	-- Anexos a leste da ala, pelo teto de cada sala: o escritório e a sala
	-- do tesouro do Barão (com um túnel entre eles) e a Sala de Troféus.
	local baronModel = find(wingModel, "BaronRooms")
	local study = bounds(find(baronModel, "StudyCeiling"))
	local treasure = bounds(find(baronModel, "TreasureCeiling"))
	local tunnel = bounds(find(baronModel, "TunnelCeiling"))
	local trophy = bounds(find(find(wingModel, "TrophyRoom"), "TrophyCeiling"))
	local hall = bounds(find(mansionModel, "TowerHall"))
	local ground = OutdoorConfig.Terrain.GroundY
	local floorTop = mansionFloor.Position.Y + mansionFloor.Size.Y / 2

	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { buildingModel, mansionModel }

	-- Entrada principal: escadaria e portal na frente da porta da parede sul.
	local entrance = CastleEntrance.build(model, ground)
	local stairs = entrance.plan
	table.insert(blocks, { minX = stairs.minX - 2, maxX = stairs.maxX + 2, minZ = entrance.wallZ, maxZ = stairs.foot.z })

	-- Fachadas de fora; os trechos onde encosta outro volume ficam de fora.
	-- Cada fachada devolve onde abrir janelas; abrem todas no fim.
	local spots: { CastleFacade.WindowSpot } = {}
	local function dress(volume: Volume, side: string, from: number?, to: number?, reach: number?, bottom: number?, plinthTop: number?, extras: Extras?)
		for _, spot in ipairs(CastleFacade.build(model, face(volume, side, bottom or ground - FACADE_SINK, reach or REACH, plinthTop or floorTop, from, to, extras), params)) do
			table.insert(spots, spot)
		end
	end
	local mainFloor = { { bottom = floorTop + WINDOW_SILL, height = WINDOW_HEIGHT } }
	local buildingRow = { { bottom = building.top - BUILDING_WINDOW_DROP, height = WINDOW_HEIGHT } }
	local outer = { minX = buildingOuter.minX, maxX = building.maxX, minZ = buildingOuter.minZ, maxZ = buildingOuter.maxZ, top = building.top }
	dress(outer, "W", nil, nil, BUILDING_REACH, nil, nil, { windows = buildingRow })
	dress(outer, "N", nil, mansion.minX - outer.minX, BUILDING_REACH, nil, nil, { windows = buildingRow })
	dress(outer, "S", nil, mansion.minX - outer.minX, BUILDING_REACH, nil, nil, { windows = buildingRow })
	-- Fachada sul do Casarão, com a porta principal (sem revestimento no
	-- vão) e o portal (sem janela nem contraforte em volta).
	local door = entrance.door
	local doorAlong = door.center.X - mansion.minX
	local doorTop = floorTop + door.size.Y
	dress(mansion, "S", nil, nil, nil, nil, nil, {
		windows = mainFloor,
		clear = { { from = doorAlong - door.size.X / 2 - DOOR_CLEAR, to = doorAlong + door.size.X / 2 + DOOR_CLEAR, bottom = floorTop - DOOR_CLEAR, top = doorTop + DOOR_CLEAR } },
		reserve = { { from = doorAlong - door.size.X / 2 - PORTAL_RESERVE, to = doorAlong + door.size.X / 2 + PORTAL_RESERVE, bottom = -math.huge, top = math.huge } },
	})
	-- As pontas da parede oeste do Casarão que sobram ao lado do prédio.
	dress(mansion, "W", 0, building.minZ - mansion.minZ)
	dress(mansion, "W", building.maxZ - mansion.minZ, mansion.maxZ - mansion.minZ)
	if hall ~= nil then
		-- A fachada norte do Casarão em dois pedaços, um de cada lado do Saguão.
		dress(mansion, "N", 0, hall.minX - mansion.minX, nil, nil, nil, { windows = mainFloor })
		dress(mansion, "N", hall.maxX - mansion.minX, mansion.maxX - mansion.minX, nil, nil, nil, { windows = mainFloor })
		local hallOutside = { minX = hall.minX, maxX = hall.maxX, minZ = hall.minZ, maxZ = mansion.minZ, top = hall.top }
		dress(hallOutside, "N")
		dress(hallOutside, "W")
		dress(hallOutside, "E")
		battlements(model, hallOutside, { "S" })
		cornerTower(model, "TowerGateWest", hallOutside, -1, -1, 3.5, hall.top + 6, 11, ground)
		cornerTower(model, "TowerGateEast", hallOutside, 1, -1, 3.5, hall.top + 6, 11, ground)
	else
		dress(mansion, "N", nil, nil, nil, nil, nil, { windows = mainFloor })
	end

	-- A ala leste tem dois andares: o térreo e o sótão.
	local wingRows = { mainFloor[1], { bottom = mansion.top + ATTIC_WINDOW_SILL, height = ATTIC_WINDOW_HEIGHT } }
	if wing ~= nil then
		dress(wing, "N", nil, nil, nil, nil, nil, { windows = wingRows })
		dress(wing, "S", nil, nil, nil, nil, nil, { windows = wingRows })
		-- Fachada leste da ala: inteira onde não encosta anexo; onde encosta,
		-- só o pedaço acima do telhado do anexo.
		local cuts: { Volume } = {}
		for _, annex in ipairs({ study, trophy }) do
			if annex ~= nil then
				table.insert(cuts, annex)
			end
		end
		table.sort(cuts, function(a: Volume, b: Volume): boolean
			return a.minZ < b.minZ
		end)
		local cursor = wing.minZ
		for _, annex in ipairs(cuts) do
			dress(wing, "E", cursor - wing.minZ, annex.minZ - wing.minZ, nil, nil, nil, { windows = wingRows })
			dress(wing, "E", annex.minZ - wing.minZ, annex.maxZ - wing.minZ, nil, annex.top, nil, { windows = { wingRows[2] } })
			cursor = annex.maxZ
		end
		dress(wing, "E", cursor - wing.minZ, wing.maxZ - wing.minZ, nil, nil, nil, { windows = wingRows })
		battlements(model, wing, {})
		cornerTower(model, "TowerNorthEast", wing, 1, -1, 9, wing.top + 18, 30, ground)
		cornerTower(model, "TowerSouthEast", wing, 1, 1, 9, wing.top + 18, 30, ground)
		CastleTowers.gable(model, wing.minX, wing.maxX, wing.minZ, wing.maxZ, wing.top)
	end

	-- Anexos: fachadas, ameias e telhado; o lado oeste encosta na ala.
	for _, annex in ipairs({ study, trophy, treasure }) do
		if annex ~= nil then
			dress(annex, "N")
			dress(annex, "S")
			-- Embaixo da fachada leste do escritório passa o túnel do Barão:
			-- ali fica sem embasamento.
			dress(annex, "E", nil, nil, nil, nil, if annex == study then -math.huge else nil)
			battlements(model, annex, if annex == treasure then {} else { "W" })
			CastleTowers.gable(model, annex.minX, annex.maxX, annex.minZ, annex.maxZ, annex.top)
		end
	end
	if study ~= nil then
		-- Só a torrinha do canto norte: a do sul entraria no túnel e no tesouro.
		cornerTower(model, "TowerStudy", study, 1, -1, 4.5, study.top + 10, 14, ground)
	end
	if trophy ~= nil then
		cornerTower(model, "TowerTrophyNorth", trophy, 1, -1, 3, trophy.top + 8, 12, ground)
		cornerTower(model, "TowerTrophySouth", trophy, 1, 1, 3, trophy.top + 8, 12, ground)
	end
	if treasure ~= nil then
		-- A parede oeste do tesouro fica à mostra dos dois lados do túnel.
		if tunnel ~= nil and study ~= nil then
			dress(treasure, "W", 0, tunnel.minZ - treasure.minZ)
			dress(treasure, "W", tunnel.maxZ - treasure.minZ, treasure.maxZ - treasure.minZ)
			-- O pedaço do túnel entre o escritório e o tesouro.
			local gap = { minX = study.maxX, maxX = treasure.minX, minZ = tunnel.minZ, maxZ = tunnel.maxZ, top = tunnel.top }
			dress(gap, "N")
			dress(gap, "S")
		end
		cornerTower(model, "TowerTreasureNorth", treasure, 1, -1, 4, treasure.top + 12, 12, ground)
		cornerTower(model, "TowerTreasureSouth", treasure, 1, 1, 4, treasure.top + 12, 12, ground)
	end

	battlements(model, building, { "E" })
	battlements(model, mansion, { "E" })
	cornerTower(model, "TowerNorthWest", building, -1, -1, 7, building.top + 16, 24, ground)
	cornerTower(model, "TowerSouthWest", building, -1, 1, 7, building.top + 16, 24, ground)
	cornerTower(model, "TowerNorthJoin", mansion, -1, -1, 6.5, mansion.top + 12, 20, ground)
	cornerTower(model, "TowerSouthJoin", mansion, -1, 1, 6.5, mansion.top + 12, 20, ground)

	local middle = Vector3.new((mansion.minX + mansion.maxX) / 2, 0, (mansion.minZ + mansion.maxZ) / 2)
	CastleTowers.keep(model, middle, 11, mansion.top, mansion.top + 30, 36)
	-- Telhados de ardósia de duas águas por cima dos tetos planos.
	CastleTowers.gable(model, building.minX, building.maxX, building.minZ, building.maxZ, building.top)
	CastleTowers.gable(model, mansion.minX, mansion.maxX, mansion.minZ, mansion.maxZ, mansion.top)

	model.Parent = world
	pending = { model = model, spots = spots, targets = { buildingModel :: Instance, mansionModel } }
	return model
end

-- Abre as janelas de verdade (recorte nas paredes), em segundo plano.
-- Chamar no fim da subida do servidor: só abre onde, por dentro, nada foi
-- pendurado na parede (estações, armadilhas, retratos, relíquias).
function CastleExterior.openWindows(world: Instance)
	local job = pending
	pending = nil
	if job == nil then
		return
	end
	task.spawn(function()
		local ok, opened = pcall(CastleWindows.open, job.model, job.spots, job.targets, world)
		if ok then
			print(`[BlocoPuff] Castle windows opened: {opened} of {#job.spots}`)
		else
			warn(`[BlocoPuff] Castle windows unavailable: {opened}`)
		end
	end)
end

-- Retângulos no chão ocupados pelas torres e pela escadaria, para quem
-- planta coisas lá fora (os lampiões) desviar deles.
function CastleExterior.blocks(): { Block }
	return table.clone(blocks)
end

return table.freeze(CastleExterior)
