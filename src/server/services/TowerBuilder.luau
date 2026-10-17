--!strict

-- Monta a Torre do Relógio da Corrida (Fase 5D.2): base com mureta, coluna
-- central, rampa em espiral, patamares de checkpoint com bandeira e o topo
-- (a chegada). Tudo ancorado e com poucas peças (celular). A geometria vem
-- de RaceRules; aqui só se criam as peças.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local RaceRules = require(script.Parent.Parent.data.RaceRules)

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
}

local FOLDER_NAME = "RaceTower"
local GENERATED_BY = "TowerBuilder"
-- Sobra nas pontas de cada peça da rampa, para a borda de fora não abrir
-- fresta na curva.
local SEGMENT_OVERLAP = 3
local LANDING_LENGTH = 12
local WALL_SEGMENTS = 24
local SPAWN_LANES = 4
local SPAWN_SPACING = 4.5

local COLORS = {
	ramp = Color3.fromRGB(150, 104, 66),
	landing = Color3.fromRGB(196, 160, 92),
	column = Color3.fromRGB(128, 72, 58),
	base = Color3.fromRGB(96, 98, 104),
	wall = Color3.fromRGB(120, 112, 100),
	top = Color3.fromRGB(226, 196, 120),
	flagPole = Color3.fromRGB(70, 60, 50),
	flag = Color3.fromRGB(236, 186, 60),
}

local TowerBuilder = {}

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

-- Cilindro de pé (o eixo do cilindro do Roblox é o X).
local function cylinder(parent: Instance, name: string, radius: number, height: number, centerPosition: Vector3, color: Color3, material: Enum.Material): Part
	local newPart = part(parent, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(centerPosition) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	newPart.Shape = Enum.PartType.Cylinder
	return newPart
end

local function spiralOf(): RaceRules.Spiral
	local tower = RaceConfig.Tower
	return {
		radius = tower.Radius,
		turns = tower.Turns,
		climbPerTurn = tower.ClimbPerTurn,
		baseY = tower.Center.Y,
	}
end

local function buildBase(folder: Folder, center: Vector3)
	local tower = RaceConfig.Tower
	cylinder(folder, "BaseFloor", tower.BaseRadius, 2, center - Vector3.new(0, 1, 0), COLORS.base, Enum.Material.Slate)
	-- Mureta em volta: segura quem cai da primeira volta.
	local step = 2 * math.pi / WALL_SEGMENTS
	local length = 2 * tower.BaseRadius * math.sin(step / 2) + 1
	for index = 1, WALL_SEGMENTS do
		local angle = (index - 0.5) * step
		local position = center + Vector3.new(math.cos(angle) * tower.BaseRadius, tower.BaseWallHeight / 2, math.sin(angle) * tower.BaseRadius)
		local cframe = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
		part(folder, "BaseWall", Vector3.new(length, tower.BaseWallHeight, 1.5), cframe, COLORS.wall, Enum.Material.Cobblestone)
	end
end

local function buildRamp(folder: Folder, layout: TowerLayout)
	local tower = RaceConfig.Tower
	for index = 1, #layout.path - 1 do
		local from = layout.path[index]
		local to = layout.path[index + 1]
		local middle = (from + to) / 2
		local length = (to - from).Magnitude + SEGMENT_OVERLAP
		-- A face de cima passa pelo meio da rampa.
		local cframe = CFrame.lookAt(middle, to) * CFrame.new(0, -tower.RampThickness / 2, 0)
		part(folder, "Ramp", Vector3.new(tower.RampWidth, tower.RampThickness, length), cframe, COLORS.ramp, Enum.Material.WoodPlanks)
	end
end

local function buildCheckpoint(folder: Folder, layout: TowerLayout, turn: number, index: number): CFrame
	local tower = RaceConfig.Tower
	local position = layout.pointAt(turn)
	local tangent = layout.tangentAt(turn)
	local flat = Vector3.new(tangent.X, 0, tangent.Z).Unit
	local landing = CFrame.lookAt(position, position + flat)
	part(folder, "Checkpoint" .. index, Vector3.new(tower.RampWidth + 2, tower.RampThickness, LANDING_LENGTH), landing * CFrame.new(0, -tower.RampThickness / 2 + 0.05, 0), COLORS.landing, Enum.Material.Wood)
	-- Bandeira do Barão na borda de fora do patamar.
	local outward = Vector3.new(position.X - layout.center.X, 0, position.Z - layout.center.Z).Unit
	local poleBase = position + outward * (tower.RampWidth / 2 - 0.5)
	part(folder, "FlagPole", Vector3.new(0.4, 8, 0.4), CFrame.new(poleBase + Vector3.new(0, 4, 0)), COLORS.flagPole, Enum.Material.Wood)
	part(folder, "Flag", Vector3.new(0.2, 2, 3), CFrame.lookAt(poleBase + Vector3.new(0, 7, 0), poleBase + Vector3.new(0, 7, 0) + outward) * CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.rad(90), 0), COLORS.flag, Enum.Material.Fabric)
	return landing + Vector3.new(0, 4, 0)
end

-- Remove uma torre montada antes (ex.: servidor reiniciando a rodada).
function TowerBuilder.destroy()
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
	-- Último passo do caminho: do fim da rampa para o meio do topo (a chegada).
	local rampEnd = path[#path]
	table.insert(path, Vector3.new(center.X, topY, center.Z):Lerp(rampEnd, 0.3))
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
	}

	buildBase(folder, center)
	local columnRadius = tower.Radius - tower.RampWidth / 2
	local columnHeight = topY - center.Y
	cylinder(folder, "Column", columnRadius, columnHeight, center + Vector3.new(0, columnHeight / 2, 0), COLORS.column, Enum.Material.Brick)
	buildRamp(folder, layout)
	for index = 1, #checkpointHeights do
		table.insert(layout.checkpointCFrames, buildCheckpoint(folder, layout, index, index))
	end
	-- Topo: a chegada, em cima da coluna e no nível do fim da rampa (sem
	-- cobrir a rampa, para ninguém bater a cabeça nele na última curva).
	cylinder(folder, "Top", tower.TopRadius, 2, Vector3.new(center.X, topY - 1, center.Z), COLORS.top, Enum.Material.Marble)
	part(folder, "Bell", Vector3.new(4, 4, 4), CFrame.new(center + Vector3.new(0, columnHeight + 12, 0)), COLORS.flag, Enum.Material.Metal).Shape = Enum.PartType.Ball
	part(folder, "BellPost", Vector3.new(0.8, 10, 0.8), CFrame.new(center + Vector3.new(0, columnHeight + 5, 0)), COLORS.flagPole, Enum.Material.Wood)

	local world = Workspace:FindFirstChild("BlocoPuffWorld")
	folder.Parent = if world ~= nil then world else Workspace
	return layout
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
