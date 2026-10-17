--!strict

-- Ambiente do Casarão (Fase 5C.4, parte 2), lado do servidor: pendura os
-- retratos da família Puff e marca os lustres do Casarão e da ala leste
-- (tag MansionChandelier no "…Body" de cada um). Quem anima tudo é o
-- cliente (MansionAmbienceController): olhos, balanço dos lustres e o
-- relógio da torre. Nada roda continuamente aqui.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MansionAmbienceConfig = require(ReplicatedStorage.Shared.config.MansionAmbienceConfig)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local MansionPortraitArt = require(script.Parent.MansionPortraitArt)
local RelicSpots = require(script.Parent.RelicSpots)

type Portrait = MansionAmbienceConfig.Portrait

local TUNING = MansionAmbienceConfig.Portrait
local FOLDER_NAME = "MansionAmbience"
local FRAME_BORDER = 0.35
local FRAME_DEPTH = 0.3
local CANVAS_DEPTH = 0.1
-- Distância do raio que procura a face da parede (de dentro do cômodo).
local WALL_PROBE = 3
local WALL_REACH = 6
local PLAQUE_SIZE = Vector3.new(2.4, 0.5, 0.12)
local PLAQUE_GAP = 0.35
local FRAME_COLOR = Color3.fromRGB(176, 132, 52)
local PLAQUE_COLOR = Color3.fromRGB(214, 172, 80)
local CHANDELIER_SUFFIX = "Body"

local MansionAmbienceService = {}

local started = false

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = color
	instance.Material = material
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CastShadow = false
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Parent = parent
	return instance
end

-- Centro da parede `wall` do retângulo, a `offset` studs do começo dela, e
-- a normal apontando para dentro do cômodo.
local function wallPoint(rect: MansionLayout.Rect, wall: string, offset: number, y: number): (Vector3, Vector3)
	if wall == "N" then
		return Vector3.new(rect.minX + offset, y, rect.minZ), Vector3.zAxis
	elseif wall == "S" then
		return Vector3.new(rect.minX + offset, y, rect.maxZ), -Vector3.zAxis
	elseif wall == "W" then
		return Vector3.new(rect.minX, y, rect.minZ + offset), Vector3.xAxis
	end
	return Vector3.new(rect.maxX, y, rect.minZ + offset), -Vector3.xAxis
end

local function plaque(parent: Instance, frame: CFrame, height: number, text: string)
	local board = part(parent, "Plaque", PLAQUE_SIZE, frame * CFrame.new(0, -(height / 2) - PLAQUE_GAP, -(FRAME_DEPTH / 2)), PLAQUE_COLOR, Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.MaxDistance = 40
	gui.LightInfluence = 0.3
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Color3.fromRGB(60, 40, 20)
	label.TextScaled = true
	label.Parent = gui
end

local function hang(parent: Instance, definition: Portrait, params: RaycastParams): Model?
	local level = RelicSpots.level(definition.room)
	if level == nil then
		warn(`[BlocoPuff] Portrait {definition.id}: unknown room {definition.room}`)
		return nil
	end
	local canvasSize = TUNING.CanvasSize
	local height = canvasSize.Y + FRAME_BORDER * 2
	local y = level.floorY + TUNING.Bottom + height / 2
	local point, normal = wallPoint(level.rect, definition.wall, definition.offset, y)
	local hit = Workspace:Raycast(point + normal * WALL_PROBE, -normal * WALL_REACH, params)
	if hit == nil then
		warn(`[BlocoPuff] Portrait {definition.id}: no wall found`)
		return nil
	end
	local center = hit.Position + normal * (FRAME_DEPTH / 2 + 0.02)
	-- A frente (−Z) olha para dentro do cômodo.
	local frame = CFrame.lookAt(center, center + normal)
	local model = Instance.new("Model")
	model.Name = `Portrait_{definition.id}`
	part(model, "Frame", Vector3.new(canvasSize.X + FRAME_BORDER * 2, height, FRAME_DEPTH), frame, FRAME_COLOR, Enum.Material.Wood)
	local canvas = part(model, "Canvas", Vector3.new(canvasSize.X, canvasSize.Y, CANVAS_DEPTH), frame * CFrame.new(0, 0, -(FRAME_DEPTH / 2) - CANVAS_DEPTH / 2 + 0.02), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	MansionPortraitArt.paint(canvas, definition)
	plaque(model, frame, height, Lang.t(definition.name))
	model.PrimaryPart = canvas
	model:SetAttribute(TUNING.IdAttribute, definition.id)
	model.Parent = parent
	CollectionService:AddTag(canvas, TUNING.Tag)
	return model
end

-- Dentro do Casarão ou da ala leste (qualquer andar).
local function inMansion(position: Vector3): boolean
	if MansionLayout.contains(position) then
		return true
	end
	local wing = MansionWingLayout.get()
	return position.X >= wing.minX and position.X <= wing.maxX and position.Z >= wing.minZ and position.Z <= wing.maxZ
end

local function tagChandeliers(root: Instance): number
	local count = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and string.find(descendant.Name, "Chandelier", 1, true) ~= nil and string.sub(descendant.Name, -#CHANDELIER_SUFFIX) == CHANDELIER_SUFFIX and inMansion(descendant.Position) then
			CollectionService:AddTag(descendant, MansionAmbienceConfig.Chandelier.Tag)
			count += 1
		end
	end
	return count
end

function MansionAmbienceService.start(worldRoot: Instance)
	if started then
		return
	end
	started = true
	local mansionRoot = worldRoot:FindFirstChild("Mansion") or worldRoot
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { worldRoot }
	for _, definition in ipairs(MansionAmbienceConfig.Portraits) do
		local ok, failure = pcall(hang, folder, definition, params)
		if not ok then
			warn(`[BlocoPuff] Portrait {definition.id} failed: {failure}`)
		end
	end
	folder.Parent = mansionRoot
	-- A ala leste fica dentro do modelo do Casarão: lustres de prédios de
	-- partida ficam de fora.
	tagChandeliers(mansionRoot)
end

return table.freeze(MansionAmbienceService)
