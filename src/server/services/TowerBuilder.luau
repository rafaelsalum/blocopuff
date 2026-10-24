--!strict

-- Monta a Torre do Relógio da Corrida (Fase 5D.2, refeita na Fase 5F): numa
-- ilha de pedra ao norte do Casarão, coluna de pedra com janelas acesas,
-- rampa larga em espiral com mureta e ameias na borda de fora, barreira
-- invisível até a volta de cima (ninguém pula para fora), contrafortes,
-- patamares de checkpoint com arco e estandarte, e o terraço do topo cercado,
-- com o relógio de 4 faces e o campanário (TowerSpire). A geometria vem de
-- RaceRules; aqui só se criam as peças.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local RaceRules = require(script.Parent.Parent.data.RaceRules)
local TowerIsland = require(script.Parent.TowerIsland)
local TowerKit = require(script.Parent.TowerKit)
local TowerSpire = require(script.Parent.TowerSpire)

export type TowerLayout = {
	folder: Folder,
	spiral: RaceRules.Spiral,
	center: Vector3,
	-- Pontos do meio da rampa, da base ao topo (caminho dos bots e barris).
	path: { Vector3 },
	-- Posição de cada ponto em voltas (mesma ordem de `path`).
	pathTurns: { number },
	checkpointHeights: { number },
	checkpointCFrames: { CFrame },
	topY: number,
	-- Ponto da rampa (meio) na volta `t`, e para onde ela sobe ali.
	pointAt: (t: number) -> Vector3,
	tangentAt: (t: number) -> Vector3,
	-- Sino do campanário (toca quando alguém chega ao topo).
	bell: BasePart?,
}

local FOLDER_NAME = "RaceTower"
local GENERATED_BY = "TowerBuilder"
-- Sobra nas pontas de cada peça da rampa, para a borda de fora não abrir
-- fresta na curva.
local SEGMENT_OVERLAP = 3
local LANDING_LENGTH = 12
local SPAWN_LANES = 4
local SPAWN_SPACING = 4.5
local MERLONS_PER_SEGMENT = 2
-- Parede de pedra embaixo da primeira volta, deixando aberta a largada.
local SKIRT_FROM_TURN = 0.1
local SKIRT_TO_TURN = 0.85
local BUTTRESS_COUNT = 8
local BUTTRESS_SIZE = 4
local WINDOWS_PER_TURN = 4
local WINDOW_SIZE = Vector2.new(4, 8)
local ARCH_HEIGHT = 14
-- Abertura na mureta do terraço por onde a rampa chega (radianos).
local TOP_OPENING_FROM = math.rad(-40)
local TOP_OPENING_TO = math.rad(8)
local TOP_WALL_SEGMENTS = 24
-- Fração do caminho do centro do topo até o fim da rampa (ponto final dos
-- bots, fora do relógio do meio).
local FINISH_POINT_FRACTION = 0.6

local COLORS = TowerKit.COLORS
local part = TowerKit.part
local cylinder = TowerKit.cylinder

local TowerBuilder = {}

local cached: TowerLayout? = nil

local function spiralOf(): RaceRules.Spiral
	local tower = RaceConfig.Tower
	return {
		radius = tower.Radius,
		turns = tower.Turns,
		climbPerTurn = tower.ClimbPerTurn,
		baseY = tower.Center.Y,
	}
end

local function outwardAt(center: Vector3, position: Vector3): Vector3
	local away = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	return if away.Magnitude > 1e-3 then away.Unit else Vector3.xAxis
end

local function barrier(parent: Instance, from: Vector3, to: Vector3, height: number)
	local length = (to - from).Magnitude
	if height <= 0 or length < 1e-3 then
		return
	end
	local base = CFrame.lookAt((from + to) / 2, to)
	local wall = part(parent, "Barrier", Vector3.new(1, height, length + 1), base * CFrame.new(0, height / 2, 0), COLORS.stone, Enum.Material.SmoothPlastic)
	wall.Transparency = 1
	wall.CanTouch = false
end

local function buildRamp(folder: Folder, layout: TowerLayout)
	local tower = RaceConfig.Tower
	local parapetRadius = RaceRules.parapetRadius(tower.Radius, tower.RampWidth, tower.ParapetThickness)
	local barrierHeight = RaceRules.barrierHeight(tower.ClimbPerTurn, tower.RampThickness, tower.ParapetHeight, tower.BarrierHeadroom)
	local lift = Vector3.new(0, tower.ParapetHeight, 0)
	local sink = Vector3.new(0, tower.RampThickness, 0)
	local function edge(position: Vector3): Vector3
		local outward = outwardAt(layout.center, position)
		return Vector3.new(layout.center.X, position.Y, layout.center.Z) + outward * parapetRadius
	end
	-- O último ponto do caminho vai para o topo; a rampa termina antes dele.
	for index = 1, #layout.path - 2 do
		local from = layout.path[index]
		local to = layout.path[index + 1]
		local middle = (from + to) / 2
		local length = (to - from).Magnitude + SEGMENT_OVERLAP
		-- A face de cima passa pelo meio da rampa.
		local cframe = CFrame.lookAt(middle, to) * CFrame.new(0, -tower.RampThickness / 2, 0)
		part(folder, "Ramp", Vector3.new(tower.RampWidth, tower.RampThickness, length), cframe, COLORS.ramp, Enum.Material.Slate)

		local outerFrom, outerTo = edge(from), edge(to)
		TowerKit.wall(folder, outerFrom - sink, outerTo - sink, tower.ParapetHeight + tower.RampThickness, tower.ParapetThickness, COLORS.stone, MERLONS_PER_SEGMENT)
		barrier(folder, outerFrom + lift, outerTo + lift, barrierHeight)

		local turn = (layout.pathTurns[index] + layout.pathTurns[index + 1]) / 2
		if turn >= SKIRT_FROM_TURN and turn <= SKIRT_TO_TURN then
			local floorY = layout.center.Y
			local height = middle.Y - tower.RampThickness - floorY
			local floorFrom = Vector3.new(outerFrom.X, floorY, outerFrom.Z)
			local floorTo = Vector3.new(outerTo.X, floorY, outerTo.Z)
			local base = CFrame.lookAt((floorFrom + floorTo) / 2, floorTo)
			part(folder, "Skirt", Vector3.new(tower.ParapetThickness, height, (floorTo - floorFrom).Magnitude + tower.ParapetThickness), base * CFrame.new(0, height / 2, 0), COLORS.stoneDark, Enum.Material.Cobblestone)
		end
	end
end

-- Contrafortes de fora, do chão da ilha até acima do terraço, com pináculo.
local function buildButtresses(folder: Folder, center: Vector3, topY: number)
	local tower = RaceConfig.Tower
	local radius = RaceRules.parapetRadius(tower.Radius, tower.RampWidth, tower.ParapetThickness) + tower.ParapetThickness / 2 + BUTTRESS_SIZE / 2 + 0.5
	local height = topY - center.Y + 6
	for index = 1, BUTTRESS_COUNT do
		local angle = (index - 0.5) * 2 * math.pi / BUTTRESS_COUNT
		local base = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local pier = part(folder, "Buttress", Vector3.new(BUTTRESS_SIZE, height, BUTTRESS_SIZE), CFrame.lookAt(base + Vector3.new(0, height / 2, 0), center + Vector3.new(0, height / 2, 0)), COLORS.stoneDark, Enum.Material.Cobblestone)
		TowerKit.decor(pier)
		TowerKit.decor(TowerKit.cone(folder, "Pinnacle", BUTTRESS_SIZE * 0.7, 9, base + Vector3.new(0, height, 0), COLORS.roof, Enum.Material.Slate))
	end
end

-- Janelas góticas acesas na coluna, entre uma volta da rampa e a de cima.
local function buildWindows(folder: Folder, layout: TowerLayout, columnRadius: number)
	local tower = RaceConfig.Tower
	for turn = 0, tower.Turns - 1 do
		for slot = 1, WINDOWS_PER_TURN do
			local fraction = (slot - 0.5) / WINDOWS_PER_TURN
			local angle = fraction * 2 * math.pi
			local y = layout.center.Y + (turn + fraction) * tower.ClimbPerTurn + tower.ClimbPerTurn / 2
			if y + WINDOW_SIZE.Y / 2 + WINDOW_SIZE.X / 2 < layout.topY - 2 then
				local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local position = Vector3.new(layout.center.X, y, layout.center.Z) + outward * (columnRadius + 0.1)
				local pane = part(folder, "Window", Vector3.new(WINDOW_SIZE.X, WINDOW_SIZE.Y, 0.4), CFrame.lookAt(position, position + outward), COLORS.window, Enum.Material.Neon)
				TowerKit.decor(pane)
				local archCenter = position + Vector3.new(0, WINDOW_SIZE.Y / 2, 0)
				local arch = part(folder, "WindowArch", Vector3.new(0.4, WINDOW_SIZE.X, WINDOW_SIZE.X), CFrame.fromMatrix(archCenter, outward, Vector3.yAxis), COLORS.window, Enum.Material.Neon)
				arch.Shape = Enum.PartType.Cylinder
				TowerKit.decor(arch)
			end
		end
	end
end

local function buildCheckpoint(folder: Folder, layout: TowerLayout, turn: number, index: number): CFrame
	local tower = RaceConfig.Tower
	local position = layout.pointAt(turn)
	local tangent = layout.tangentAt(turn)
	local flat = Vector3.new(tangent.X, 0, tangent.Z).Unit
	local landing = CFrame.lookAt(position, position + flat)
	part(folder, "Checkpoint" .. index, Vector3.new(tower.RampWidth, tower.RampThickness, LANDING_LENGTH), landing * CFrame.new(0, -tower.RampThickness / 2 + 0.05, 0), COLORS.landing, Enum.Material.Cobblestone)
	-- Arco de pedra sobre o patamar, com o estandarte no meio.
	local outward = outwardAt(layout.center, position)
	local halfSpan = tower.RampWidth / 2 - 1.5
	for _, side in ipairs({ -1, 1 }) do
		local foot = position + outward * side * halfSpan
		part(folder, "ArchPillar", Vector3.new(2, ARCH_HEIGHT, 2), CFrame.new(foot + Vector3.new(0, ARCH_HEIGHT / 2, 0)), COLORS.stoneLight, Enum.Material.Cobblestone)
	end
	local lintelCenter = position + Vector3.new(0, ARCH_HEIGHT + 1, 0)
	part(folder, "ArchLintel", Vector3.new(halfSpan * 2 + 2, 2, 2.5), CFrame.lookAt(lintelCenter, lintelCenter + flat), COLORS.stoneLight, Enum.Material.Cobblestone)
	local banner = part(folder, "Banner", Vector3.new(5, 7, 0.2), CFrame.lookAt(lintelCenter - Vector3.new(0, 4.5, 0), lintelCenter - Vector3.new(0, 4.5, 0) - flat), COLORS.banner, Enum.Material.Fabric)
	TowerKit.decor(banner)
	local stripe = part(folder, "BannerStripe", Vector3.new(5.1, 0.8, 0.3), banner.CFrame * CFrame.new(0, -2.5, 0), COLORS.gold, Enum.Material.Fabric)
	TowerKit.decor(stripe)
	return landing + Vector3.new(0, 4, 0)
end

-- Patamar de chegada no fim da rampa, parede no fim dele e o terraço do
-- topo cercado (com abertura só por onde a rampa chega).
local function buildTop(folder: Folder, layout: TowerLayout, columnRadius: number)
	local tower = RaceConfig.Tower
	local center = layout.center
	local topY = layout.topY
	cylinder(folder, "Top", columnRadius + 0.5, 2, Vector3.new(center.X, topY - 1, center.Z), COLORS.stoneLight, Enum.Material.Slate)

	local arrival = layout.pointAt(tower.Turns)
	local tangent = layout.tangentAt(tower.Turns)
	local flat = Vector3.new(tangent.X, 0, tangent.Z).Unit
	part(folder, "Arrival", Vector3.new(tower.RampWidth, tower.RampThickness, LANDING_LENGTH), CFrame.lookAt(arrival, arrival + flat) * CFrame.new(0, -tower.RampThickness / 2 + 0.05, 0), COLORS.landing, Enum.Material.Cobblestone)
	local outward = outwardAt(center, arrival)
	local endCenter = arrival + flat * (LANDING_LENGTH / 2 + 1)
	local inner = endCenter - outward * (tower.RampWidth / 2 + 1)
	local outer = endCenter + outward * (tower.RampWidth / 2 + tower.ParapetThickness)
	local sink = Vector3.new(0, tower.RampThickness, 0)
	local lift = Vector3.new(0, tower.ParapetHeight, 0)
	TowerKit.wall(folder, inner - sink, outer - sink, tower.ParapetHeight + tower.RampThickness, tower.ParapetThickness, COLORS.stone, 3)
	barrier(folder, inner + lift, outer + lift, tower.TopBarrierHeight)
	-- Mureta na borda de fora do patamar, do fim da rampa até a parede.
	local parapetRadius = RaceRules.parapetRadius(tower.Radius, tower.RampWidth, tower.ParapetThickness)
	local edgeStart = Vector3.new(center.X, topY, center.Z) + outward * parapetRadius
	local edgeEnd = Vector3.new(outer.X, topY, outer.Z)
	TowerKit.wall(folder, edgeStart - sink, edgeEnd - sink, tower.ParapetHeight + tower.RampThickness, tower.ParapetThickness, COLORS.stone, 1)
	barrier(folder, edgeStart + lift, edgeEnd + lift, tower.TopBarrierHeight)

	local wallRadius = columnRadius - tower.ParapetThickness / 2
	local step = 2 * math.pi / TOP_WALL_SEGMENTS
	for index = 1, TOP_WALL_SEGMENTS do
		local fromAngle = (index - 1) * step
		local toAngle = index * step
		local middleAngle = (fromAngle + toAngle) / 2
		if not RaceRules.inArc(middleAngle, TOP_OPENING_FROM, TOP_OPENING_TO) then
			local from = Vector3.new(center.X + math.cos(fromAngle) * wallRadius, topY, center.Z + math.sin(fromAngle) * wallRadius)
			local to = Vector3.new(center.X + math.cos(toAngle) * wallRadius, topY, center.Z + math.sin(toAngle) * wallRadius)
			TowerKit.wall(folder, from, to, tower.ParapetHeight, tower.ParapetThickness, COLORS.stone, 1)
			barrier(folder, from + Vector3.new(0, tower.ParapetHeight, 0), to + Vector3.new(0, tower.ParapetHeight, 0), tower.TopBarrierHeight)
		end
	end
end

-- Remove uma torre montada antes (ex.: servidor reiniciando a rodada).
function TowerBuilder.destroy()
	cached = nil
	for _, child in ipairs(Workspace:GetDescendants()) do
		if child:IsA("Folder") and child.Name == FOLDER_NAME and child:GetAttribute("GeneratedBy") == GENERATED_BY then
			child:Destroy()
		end
	end
end

function TowerBuilder.build(): TowerLayout
	TowerBuilder.destroy()
	local tower = RaceConfig.Tower
	local spiral = spiralOf()
	local center = tower.Center

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("GeneratedBy", GENERATED_BY)

	local function pointAt(t: number): Vector3
		local x, y, z = RaceRules.spiralPoint(spiral, t)
		return Vector3.new(center.X + x, y, center.Z + z)
	end
	local function tangentAt(t: number): Vector3
		local delta = 0.01
		local before = pointAt(math.max(0, t - delta))
		local after = pointAt(math.min(spiral.turns, t + delta))
		return (after - before).Unit
	end

	local pathTurns = RaceRules.pathTurns(spiral, tower.SegmentsPerTurn)
	local path: { Vector3 } = {}
	for _, t in ipairs(pathTurns) do
		table.insert(path, pointAt(t))
	end
	local topY = RaceRules.topY(spiral)
	-- Último passo do caminho: do fim da rampa para o terraço (a chegada).
	local rampEnd = path[#path]
	table.insert(path, Vector3.new(center.X, topY, center.Z):Lerp(rampEnd, FINISH_POINT_FRACTION))
	table.insert(pathTurns, spiral.turns)
	local checkpointHeights = RaceRules.checkpointHeights(spiral, RaceConfig.CheckpointCount)

	local layout: TowerLayout = {
		folder = folder,
		spiral = spiral,
		center = center,
		path = path,
		pathTurns = pathTurns,
		checkpointHeights = checkpointHeights,
		checkpointCFrames = {},
		topY = topY,
		pointAt = pointAt,
		tangentAt = tangentAt,
		bell = nil,
	}

	TowerIsland.build(folder, center)
	local columnRadius = tower.Radius - tower.RampWidth / 2
	local columnHeight = topY - center.Y
	cylinder(folder, "Column", columnRadius, columnHeight, center + Vector3.new(0, columnHeight / 2, 0), COLORS.stone, Enum.Material.Cobblestone)
	buildWindows(folder, layout, columnRadius)
	buildRamp(folder, layout)
	buildButtresses(folder, center, topY)
	for index = 1, #checkpointHeights do
		table.insert(layout.checkpointCFrames, buildCheckpoint(folder, layout, index, index))
	end
	buildTop(folder, layout, columnRadius)
	layout.bell = TowerSpire.build(folder, Vector3.new(center.X, topY, center.Z))

	local world = Workspace:FindFirstChild("BlocoPuffWorld")
	folder.Parent = if world ~= nil then world else Workspace
	cached = layout
	return layout
end

-- A torre já montada (monta na primeira vez). Fica de pé o tempo todo, à
-- vista do Casarão.
function TowerBuilder.get(): TowerLayout
	local current = cached
	if current ~= nil and current.folder.Parent ~= nil then
		return current
	end
	return TowerBuilder.build()
end

-- Toca o sino do campanário (alguém chegou ao topo).
function TowerBuilder.ringBell(layout: TowerLayout)
	TowerSpire.ring(layout.bell)
end

-- Lugares de largada atrás do começo da rampa, olhando para ela.
function TowerBuilder.startCFrames(layout: TowerLayout, count: number): { CFrame }
	local start = layout.pointAt(0)
	local forward = layout.tangentAt(0)
	local flatForward = Vector3.new(forward.X, 0, forward.Z).Unit
	local right = flatForward:Cross(Vector3.yAxis)
	local cframes: { CFrame } = {}
	for index = 1, count do
		local row = math.floor((index - 1) / SPAWN_LANES)
		local lane = (index - 1) % SPAWN_LANES - (SPAWN_LANES - 1) / 2
		local position = start - flatForward * (6 + row * SPAWN_SPACING) + right * lane * SPAWN_SPACING + Vector3.new(0, 3, 0)
		table.insert(cframes, CFrame.lookAt(position, position + flatForward))
	end
	return cframes
end

return table.freeze(TowerBuilder)
