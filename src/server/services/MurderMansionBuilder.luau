--!strict

-- Monta a Ala do Assassinato (Fase 5E.2) a partir da planta de
-- MurderMansionPlan: dois andares de cômodos com portas entre todos os
-- vizinhos, duas escadas de degraus em lados opostos (com o vão aberto no
-- andar de cima e um guarda-corpo), a passagem secreta atrás das estantes,
-- um lustre por cômodo e os móveis de cada um (MurderMansionProps). Fica
-- longe do lobby, da Arena e da Torre, é montada uma vez e tudo é ancorado.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local MurderMansionPlan = require(script.Parent.Parent.data.MurderMansionPlan)
local MurderMansionProps = require(script.Parent.MurderMansionProps)
local MurderMansionCover = require(script.Parent.MurderMansionCover)
local MurderMansionDecor = require(script.Parent.MurderMansionDecor)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionDoors = require(script.Parent.MansionDoors)

type Plan = MurderMansionPlan.Plan
type Room = MurderMansionPlan.Room

export type WingLayout = {
	folder: Folder,
	-- Centro do chão do térreo.
	center: Vector3,
	floorY: number,
	plan: Plan,
	-- Centro do chão de cada cômodo (os dois andares).
	roomCenters: { Vector3 },
	-- Um ponto do chão sorteado no miolo livre de um cômodo sorteado.
	randomPoint: (random: Random) -> Vector3,
	-- Um ponto do chão sorteado no miolo livre de um cômodo da planta.
	randomPointIn: (roomId: string, random: Random) -> Vector3?,
	-- Pontos do chão atrás das coberturas e junto das portas, para as
	-- moedas que pedem um pouco de risco (MysteryCoins).
	coinSpots: { Vector3 },
	-- Altura do chão do andar em que `position` está.
	floorAt: (position: Vector3) -> number,
	-- Posição no mundo de um ponto da planta.
	toWorld: (x: number, z: number, level: number) -> Vector3,
}

local FOLDER_NAME = "MysteryWing"
local GENERATED_BY = "MurderMansionBuilder"
local WALL_THICKNESS = 1
local GROUND_THICKNESS = 2
local SLAB_THICKNESS = 1
local RAILING_HEIGHT = 3.5
-- Abertura da passagem secreta e altura do corredor escondido.
local PASSAGE_GAP_HEIGHT = 8
local PASSAGE_HEIGHT = 9
-- Lâmpadas pequenas e fracas da passagem secreta (o resto da luz é do
-- acabamento do Casarão, MurderMansionDecor).
local PASSAGE_LAMP_SIZE = 0.9
local PASSAGE_LAMP_BRIGHTNESS = 0.8
local PASSAGE_LAMP_RANGE = 16
-- Moedas junto das portas: tantos studs para dentro de cada cômodo.
local DOOR_COIN_INSET = 4

local COLORS = {
	floorGround = MansionConfig.FloorColor,
	floorUpper = MansionConfig.FloorColor,
	wallGround = Color3.fromRGB(184, 144, 128),
	wallUpper = Color3.fromRGB(116, 104, 140),
	exterior = Color3.fromRGB(150, 118, 112),
	roof = Color3.fromRGB(52, 42, 48),
	stair = Color3.fromRGB(96, 62, 40),
	railing = Color3.fromRGB(70, 46, 30),
	passage = Color3.fromRGB(60, 50, 46),
	passageLight = Color3.fromRGB(255, 170, 110),
}

local MurderMansionBuilder = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Anchored = true
	newPart.Size = size
	newPart.CFrame = cframe
	newPart.Color = color
	newPart.Material = material
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	newPart.CastShadow = false
	newPart.Parent = parent
	return newPart
end

-- Parede de `length` ao longo de `axis` ("X": corre em x; "Z": corre em z),
-- centrada em `middle` (no chão), com um vão de `gap` x `gapHeight` no
-- ponto `gapAt` (distância a partir do meio) quando houver.
local function wall(parent: Instance, middle: Vector3, length: number, axis: "X" | "Z", height: number, color: Color3, gap: number?, gapHeight: number?, gapAt: number?)
	local direction = if axis == "X" then Vector3.xAxis else Vector3.zAxis
	local function segment(center: Vector3, segmentLength: number, segmentHeight: number)
		if segmentLength <= 0.01 or segmentHeight <= 0.01 then
			return
		end
		local size = if axis == "X" then Vector3.new(segmentLength, segmentHeight, WALL_THICKNESS) else Vector3.new(WALL_THICKNESS, segmentHeight, segmentLength)
		part(parent, "Wall", size, CFrame.new(center), color, Enum.Material.Plaster)
	end
	if gap == nil or gapHeight == nil then
		segment(middle + Vector3.new(0, height / 2, 0), length, height)
		return
	end
	local at = gapAt or 0
	local startEdge = -length / 2
	local endEdge = length / 2
	local gapStart = at - gap / 2
	local gapEnd = at + gap / 2
	segment(middle + direction * ((startEdge + gapStart) / 2) + Vector3.new(0, height / 2, 0), gapStart - startEdge, height)
	segment(middle + direction * ((gapEnd + endEdge) / 2) + Vector3.new(0, height / 2, 0), endEdge - gapEnd, height)
	segment(middle + direction * at + Vector3.new(0, gapHeight + (height - gapHeight) / 2, 0), gap, height - gapHeight)
end

local function lamp(parent: Instance, position: Vector3, color: Color3, brightness: number, range: number): Part
	local bulb = part(parent, "Chandelier", Vector3.new(2, 2, 2), CFrame.new(position), color, Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
	bulb.CanQuery = false
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color
	light.Shadows = false
	light.Parent = bulb
	return bulb
end

-- Laje do andar de cima de um cômodo, sem o vão da escada (se houver).
local function upperSlab(parent: Instance, room: Room, plan: Plan, toWorld: (number, number, number) -> Vector3)
	local function slab(minX: number, maxX: number, minZ: number, maxZ: number)
		if maxX - minX <= 0 or maxZ - minZ <= 0 then
			return
		end
		local top = toWorld((minX + maxX) / 2, (minZ + maxZ) / 2, 1)
		part(parent, "UpperFloor", Vector3.new(maxX - minX, SLAB_THICKNESS, maxZ - minZ), CFrame.new(top - Vector3.new(0, SLAB_THICKNESS / 2, 0)), COLORS.floorUpper, Enum.Material.WoodPlanks)
	end
	for _, stair in ipairs(plan.stairs) do
		if stair.upperRoom == room.id then
			local holeMin = stair.x - stair.width / 2
			local holeMax = stair.x + stair.width / 2
			local landingMaxZ = math.min(stair.topZ, stair.bottomZ)
			-- Resto do cômodo, fora da faixa da escada.
			slab(math.max(room.minX, holeMax), room.maxX, room.minZ, room.maxZ)
			slab(room.minX, math.min(room.maxX, holeMin), room.minZ, room.maxZ)
			-- Patamar no alto da escada.
			slab(holeMin, holeMax, room.minZ, landingMaxZ)
			-- Guarda-corpo ao longo do vão (do lado de dentro do cômodo).
			local innerX = if holeMin <= room.minX then holeMax else holeMin
			local railLength = room.maxZ - landingMaxZ
			local railCenter = toWorld(innerX, landingMaxZ + railLength / 2, 1) + Vector3.new(0, RAILING_HEIGHT / 2, 0)
			part(parent, "Railing", Vector3.new(0.6, RAILING_HEIGHT, railLength), CFrame.new(railCenter), COLORS.railing, Enum.Material.Wood)
			return
		end
	end
	slab(room.minX, room.maxX, room.minZ, room.maxZ)
end

-- Escada de degraus maciços: um degrau por stud de subida.
local function staircase(parent: Instance, stair: MurderMansionPlan.Stair, plan: Plan, toWorld: (number, number, number) -> Vector3)
	local steps = plan.floorHeight
	local run = stair.topZ - stair.bottomZ
	local depth = math.abs(run) / steps
	local direction = math.sign(run)
	for index = 1, steps do
		local nearZ = stair.bottomZ + direction * (index - 1) * depth
		local farZ = stair.bottomZ + direction * index * depth
		local base = toWorld(stair.x, (nearZ + farZ) / 2, 0)
		local stepPart = part(parent, "Step", Vector3.new(stair.width, index, depth), CFrame.new(base + Vector3.new(0, index / 2, 0)), COLORS.stair, Enum.Material.WoodPlanks)
		stepPart.Name = `Step{index}`
	end
end

-- Corredor escondido do lado de fora da parede norte, com chão, paredes,
-- teto baixo e uma luz fraca.
local function secretPassage(parent: Instance, passage: MurderMansionPlan.Passage, toWorld: (number, number, number) -> Vector3)
	local width = passage.maxX - passage.minX
	local depth = passage.maxZ - passage.minZ
	local middle = toWorld((passage.minX + passage.maxX) / 2, (passage.minZ + passage.maxZ) / 2, 0)
	part(parent, "PassageFloor", Vector3.new(width, GROUND_THICKNESS, depth), CFrame.new(middle - Vector3.new(0, GROUND_THICKNESS / 2, 0)), COLORS.passage, Enum.Material.Cobblestone)
	part(parent, "PassageRoof", Vector3.new(width, 1, depth), CFrame.new(middle + Vector3.new(0, PASSAGE_HEIGHT + 0.5, 0)), COLORS.passage, Enum.Material.Slate)
	wall(parent, toWorld((passage.minX + passage.maxX) / 2, passage.minZ, 0), width, "X", PASSAGE_HEIGHT, COLORS.passage)
	wall(parent, toWorld(passage.minX, (passage.minZ + passage.maxZ) / 2, 0), depth, "Z", PASSAGE_HEIGHT, COLORS.passage)
	wall(parent, toWorld(passage.maxX, (passage.minZ + passage.maxZ) / 2, 0), depth, "Z", PASSAGE_HEIGHT, COLORS.passage)
	for _, x in ipairs({ passage.fromX, passage.toX, (passage.fromX + passage.toX) / 2 }) do
		local bulb = lamp(parent, toWorld(x, (passage.minZ + passage.maxZ) / 2, 0) + Vector3.new(0, PASSAGE_HEIGHT - 1.5, 0), COLORS.passageLight, PASSAGE_LAMP_BRIGHTNESS, PASSAGE_LAMP_RANGE)
		bulb.Size = Vector3.one * PASSAGE_LAMP_SIZE
	end
end

-- Parede norte do térreo (z = bounds.minZ) com vãos de `gapWidth` centrados
-- em cada x de `gaps` (em ordem crescente).
local function northWallWithGaps(parent: Instance, bounds: MurderMansionPlan.Area, gaps: { number }, gapWidth: number, height: number, toWorld: (number, number, number) -> Vector3)
	local cursor = bounds.minX
	for _, gapX in ipairs(gaps) do
		local gapStart = gapX - gapWidth / 2
		local length = gapStart - cursor
		if length > 0 then
			wall(parent, toWorld(cursor + length / 2, bounds.minZ, 0), length, "X", height, COLORS.exterior)
		end
		-- Verga acima do vão.
		local lintel = toWorld(gapX, bounds.minZ, 0) + Vector3.new(0, PASSAGE_GAP_HEIGHT + (height - PASSAGE_GAP_HEIGHT) / 2, 0)
		part(parent, "Wall", Vector3.new(gapWidth, height - PASSAGE_GAP_HEIGHT, WALL_THICKNESS), CFrame.new(lintel), COLORS.exterior, Enum.Material.Plaster)
		cursor = gapX + gapWidth / 2
	end
	local rest = bounds.maxX - cursor
	if rest > 0 then
		wall(parent, toWorld(cursor + rest / 2, bounds.minZ, 0), rest, "X", height, COLORS.exterior)
	end
end

local function outerWalls(parent: Instance, plan: Plan, bounds: MurderMansionPlan.Area, level: number, toWorld: (number, number, number) -> Vector3)
	local width = bounds.maxX - bounds.minX
	local depth = bounds.maxZ - bounds.minZ
	local midX = (bounds.minX + bounds.maxX) / 2
	local midZ = (bounds.minZ + bounds.maxZ) / 2
	-- As do térreo sobem até o alto da laje de cima (sem fresta para o céu).
	local height = if level == 0 then plan.floorHeight else plan.wallHeight
	-- Parede norte do térreo: com as aberturas da passagem secreta.
	if level == 0 and #plan.passages > 0 then
		local passage = plan.passages[1]
		northWallWithGaps(parent, bounds, { passage.fromX, passage.toX }, passage.gapWidth, height, toWorld)
	else
		wall(parent, toWorld(midX, bounds.minZ, level), width, "X", height, COLORS.exterior)
	end
	wall(parent, toWorld(midX, bounds.maxZ, level), width, "X", height, COLORS.exterior)
	wall(parent, toWorld(bounds.minX, midZ, level), depth, "Z", height, COLORS.exterior)
	wall(parent, toWorld(bounds.maxX, midZ, level), depth, "Z", height, COLORS.exterior)
end

-- Portas duplas do Casarão (MansionDoors) em cada vão entre cômodos: o
-- MansionDoorController de cada cliente abre quem chega perto, com rangido,
-- e fecha batendo. As folhas não colidem nem bloqueiam tiros e facas, mas
-- fechadas escondem quem está no cômodo ao lado.
local function doors(parent: Instance, plan: Plan, toWorld: (number, number, number) -> Vector3)
	local doorways: { MansionWingLayout.Doorway } = {}
	for index, door in ipairs(plan.doors) do
		local alongZ = door.axis == "Z"
		table.insert(doorways, {
			name = `MurderDoor{index}`,
			center = toWorld(door.x, door.z, door.level),
			along = if alongZ then Vector3.zAxis else Vector3.xAxis,
			normal = if alongZ then Vector3.xAxis else Vector3.zAxis,
			size = Vector2.new(plan.doorWidth, plan.doorHeight),
		})
	end
	local model = Instance.new("Model")
	model.Name = "Doors"
	model.Parent = parent
	MansionDoors.build(model, doorways)
end

local function boundsOf(plan: Plan): MurderMansionPlan.Area
	local bounds = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, room in ipairs(plan.rooms) do
		bounds.minX = math.min(bounds.minX, room.minX)
		bounds.maxX = math.max(bounds.maxX, room.maxX)
		bounds.minZ = math.min(bounds.minZ, room.minZ)
		bounds.maxZ = math.max(bounds.maxZ, room.maxZ)
	end
	return bounds
end

function MurderMansionBuilder.destroy()
	for _, child in ipairs(Workspace:GetDescendants()) do
		if child:IsA("Folder") and child.Name == FOLDER_NAME and (child:GetAttribute("GeneratedBy") == GENERATED_BY or child:GetAttribute("GeneratedBy") == "MysteryWingBuilder") then
			child:Destroy()
		end
	end
end

function MurderMansionBuilder.build(): WingLayout
	MurderMansionBuilder.destroy()
	local config = MysteryModeConfig.Wing
	local plan = MurderMansionPlan.get()
	local center = config.Center
	local function toWorld(x: number, z: number, level: number): Vector3
		return Vector3.new(center.X + x, center.Y + level * plan.floorHeight, center.Z + z)
	end
	local bounds = boundsOf(plan)

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("GeneratedBy", GENERATED_BY)

	local width = bounds.maxX - bounds.minX
	local depth = bounds.maxZ - bounds.minZ
	local middle = toWorld((bounds.minX + bounds.maxX) / 2, (bounds.minZ + bounds.maxZ) / 2, 0)
	part(folder, "GroundFloor", Vector3.new(width, GROUND_THICKNESS, depth), CFrame.new(middle - Vector3.new(0, GROUND_THICKNESS / 2, 0)), COLORS.floorGround, Enum.Material.WoodPlanks)
	part(folder, "Roof", Vector3.new(width + 2, 1, depth + 2), CFrame.new(toWorld((bounds.minX + bounds.maxX) / 2, (bounds.minZ + bounds.maxZ) / 2, 1) + Vector3.new(0, plan.wallHeight + 0.5, 0)), COLORS.roof, Enum.Material.Slate)

	for level = 0, 1 do
		outerWalls(folder, plan, bounds, level, toWorld)
	end
	for _, door in ipairs(plan.doors) do
		local roomA, roomB
		for _, room in ipairs(plan.rooms) do
			if room.id == door.from then
				roomA = room
			elseif room.id == door.to then
				roomB = room
			end
		end
		if roomA ~= nil and roomB ~= nil then
			local color = if door.level == 0 then COLORS.wallGround else COLORS.wallUpper
			local wallHeight = if door.level == 0 then plan.floorHeight else plan.wallHeight
			if door.axis == "Z" then
				local minZ, maxZ = math.max(roomA.minZ, roomB.minZ), math.min(roomA.maxZ, roomB.maxZ)
				wall(folder, toWorld(door.x, (minZ + maxZ) / 2, door.level), maxZ - minZ, "Z", wallHeight, color, plan.doorWidth, plan.doorHeight, door.z - (minZ + maxZ) / 2)
			else
				local minX, maxX = math.max(roomA.minX, roomB.minX), math.min(roomA.maxX, roomB.maxX)
				wall(folder, toWorld((minX + maxX) / 2, door.z, door.level), maxX - minX, "X", wallHeight, color, plan.doorWidth, plan.doorHeight, door.x - (minX + maxX) / 2)
			end
		end
	end

	local roomCenters: { Vector3 } = {}
	local openRooms: { Room } = {}
	local coinSpots: { Vector3 } = {}
	for _, room in ipairs(plan.rooms) do
		local roomCenter = toWorld((room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2, room.level)
		table.insert(roomCenters, roomCenter)
		table.insert(openRooms, room)
		if room.level == 1 then
			upperSlab(folder, room, plan, toWorld)
		end
		MurderMansionProps.furnish(folder, room, roomCenter)
		for _, spot in ipairs(MurderMansionCover.place(folder, room, roomCenter)) do
			table.insert(coinSpots, spot)
		end
	end
	doors(folder, plan, toWorld)
	MurderMansionDecor.decorate(folder, plan, toWorld)
	for _, door in ipairs(plan.doors) do
		local inward = if door.axis == "Z" then Vector3.xAxis else Vector3.zAxis
		local point = toWorld(door.x, door.z, door.level)
		table.insert(coinSpots, point - inward * DOOR_COIN_INSET)
		table.insert(coinSpots, point + inward * DOOR_COIN_INSET)
	end
	for _, stair in ipairs(plan.stairs) do
		staircase(folder, stair, plan, toWorld)
	end
	for _, passage in ipairs(plan.passages) do
		secretPassage(folder, passage, toWorld)
		MurderMansionProps.passageFrames(folder, passage, toWorld)
	end

	local world = Workspace:FindFirstChild("BlocoPuffWorld")
	folder.Parent = if world ~= nil then world else Workspace

	return {
		folder = folder,
		center = center,
		floorY = center.Y,
		plan = plan,
		roomCenters = roomCenters,
		coinSpots = coinSpots,
		randomPoint = function(random: Random): Vector3
			local room = openRooms[random:NextInteger(1, #openRooms)]
			local area = MurderMansionPlan.openArea(room)
			return toWorld(random:NextNumber(area.minX, area.maxX), random:NextNumber(area.minZ, area.maxZ), room.level)
		end,
		randomPointIn = function(roomId: string, random: Random): Vector3?
			for _, room in ipairs(openRooms) do
				if room.id == roomId then
					local area = MurderMansionPlan.openArea(room)
					return toWorld(random:NextNumber(area.minX, area.maxX), random:NextNumber(area.minZ, area.maxZ), room.level)
				end
			end
			return nil
		end,
		floorAt = function(position: Vector3): number
			-- O que estiver logo abaixo (degrau, laje ou chão); sem nada, o
			-- andar pela altura.
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { folder }
			local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -(plan.floorHeight + 4), 0), params)
			if hit ~= nil then
				return hit.Position.Y
			end
			local level = if position.Y >= center.Y + plan.floorHeight - 1 then 1 else 0
			return center.Y + level * plan.floorHeight
		end,
		toWorld = toWorld,
	}
end

return table.freeze(MurderMansionBuilder)
