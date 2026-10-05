--!strict

-- Cenário simples dos Mistérios do Barão (Fase 5C.3, parte 2), só de peças:
-- reserva para quando os modelos (assets/MysteryModels) não carregam. O
-- normal é o MysteryProps. Montado com as respostas sorteadas do servidor:
--   * Salão Principal: vitrais coloridos acima do arco norte, quatro
--     candelabros (cada um com a taça de uma cor) e o quadro de cavalete
--     com a hora certa do relógio;
--   * Sótão: o relógio da torre (parado nas 12h) e a partitura da Vovó;
--   * Biblioteca, Sala de Música e Sótão: um quadro com um dígito do código;
--   * Porão: o cofrinho;
--   * Piano: o nome de cada nota acima das teclas brancas.
-- Os nomes começam com "Mystery" (não confundem as âncoras das relíquias).
-- Tudo de enfeite: quem confere as respostas é o MysteryService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClockFace = require(ReplicatedStorage.Shared.modules.ClockFace)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MysteryConfig = require(ReplicatedStorage.Shared.config.MysteryConfig)
local BuildingDecor = require(script.Parent.BuildingDecor)
local MysteryRules = require(script.Parent.Parent.data.MysteryRules)

type Answers = MysteryRules.Answers

export type Built = {
	-- Onde cada mistério é resolvido (conferência de distância).
	anchors: { [string]: Vector3 },
	-- Áreas para não colocar gente em cima dos móveis novos.
	reserved: { { center: Vector3, size: Vector3 } },
}

local WOOD = Color3.fromRGB(96, 64, 40)
local DARK_WOOD = Color3.fromRGB(60, 40, 28)
local BRASS = Color3.fromRGB(196, 160, 80)
local CANVAS = Color3.fromRGB(236, 226, 200)
local LEAD = Color3.fromRGB(30, 26, 30)
local IRON = Color3.fromRGB(58, 60, 66)
local CANDLE_WAX = Color3.fromRGB(250, 246, 232)
local FLAME = Color3.fromRGB(255, 170, 60)
local PIXELS = 60

local MysteryPropsBasic = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	return BuildingDecor.createPart(parent, name, size, cframe, color, { material = material, shape = shape })
end

local function surfaceGui(target: BasePart, name: string, face: Enum.NormalId?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS
	gui.LightInfluence = 0.4
	gui.Parent = target
	return gui
end

local function text(parent: Instance, name: string, value: string, position: UDim2, size: UDim2, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
	return label
end

-- Prompt que abre o quebra-cabeça no cliente.
local function prompt(target: BasePart, id: string, action: string, objectText: string)
	local proximity = Instance.new("ProximityPrompt")
	proximity.Name = "MysteryPrompt"
	proximity.ActionText = action
	proximity.ObjectText = objectText
	proximity.HoldDuration = 0
	proximity.MaxActivationDistance = MysteryConfig.PromptDistance
	proximity.RequiresLineOfSight = false
	proximity:SetAttribute(MysteryConfig.PromptAttribute, id)
	proximity.Parent = target
end

-- Cavalete com uma tela virada para `facing`; devolve a tela (a frente da
-- peça é a face pintada).
local function easel(parent: Instance, name: string, base: Vector3, facing: Vector3): Part
	local model = Instance.new("Model")
	model.Name = name
	local frame = CFrame.lookAt(base, base + Vector3.new(facing.X, 0, facing.Z))
	-- Pernas atrás da tela, inclinadas como ela (não cobrem a pintura).
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Leg", Vector3.new(0.2, 4.6, 0.2), frame * CFrame.new(side * 1.3, 2.3, 0.1) * CFrame.Angles(math.rad(8), 0, math.rad(side * 6)), WOOD, Enum.Material.Wood)
	end
	part(model, "BackLeg", Vector3.new(0.2, 4.6, 0.2), frame * CFrame.new(0, 2.2, 1) * CFrame.Angles(math.rad(22), 0, 0), WOOD, Enum.Material.Wood)
	part(model, "Ledge", Vector3.new(3.4, 0.15, 0.5), frame * CFrame.new(0, 2.15, -0.3), WOOD, Enum.Material.Wood)
	local tilt = frame * CFrame.new(0, 3.65, -0.18) * CFrame.Angles(math.rad(8), 0, 0)
	part(model, "Frame", Vector3.new(3.6, 3, 0.12), tilt * CFrame.new(0, 0, 0.04), DARK_WOOD, Enum.Material.Wood)
	local canvas = part(model, "Canvas", Vector3.new(3.3, 2.7, 0.08), tilt, CANVAS, Enum.Material.Fabric)
	model.Parent = parent
	return canvas
end

-- Quadro com a hora certa (pista do relógio).
local function paintClock(gui: SurfaceGui, answers: Answers)
	local sky = Instance.new("Frame")
	sky.Size = UDim2.fromScale(1, 1)
	sky.BackgroundColor3 = Color3.fromRGB(70, 90, 140)
	sky.Parent = gui
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.8, 0.8)
	holder.BackgroundTransparency = 1
	holder.Parent = sky
	local face = ClockFace.draw(holder, 2)
	ClockFace.set(face, answers.hour, answers.minute)
end

local function clockPainting(parent: Instance, base: Vector3, facing: Vector3, answers: Answers)
	local canvas = easel(parent, "MysteryClockPainting", base, facing)
	paintClock(surfaceGui(canvas, "Painting"), answers)
end

-- Quadro com um dígito do código do cofrinho e a posição dele.
local function paintDigit(gui: SurfaceGui, position: number, digit: number)
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(120, 40, 50)
	background.Parent = gui
	text(background, "Position", `{position}º`, UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.3, 0.26), Color3.fromRGB(255, 220, 140))
	text(background, "Digit", tostring(digit), UDim2.fromScale(0.25, 0.12), UDim2.fromScale(0.5, 0.82), Color3.fromRGB(255, 240, 210))
end

local function digitPainting(parent: Instance, name: string, base: Vector3, facing: Vector3, position: number, digit: number)
	local canvas = easel(parent, name, base, facing)
	paintDigit(surfaceGui(canvas, "Painting"), position, digit)
end

-- Vitrais acima do arco norte do Salão (cores na ordem da resposta).
local function stainedGlass(parent: Instance, answers: Answers)
	local mansion = MansionLayout.get()
	local hall = mansion.rooms.GrandHall
	local half = MansionConfig.PartitionThickness / 2
	local centerX = (hall.minX + hall.maxX) / 2
	local z = hall.minZ + half + 0.08
	-- Acima da placa da porta norte, abaixo das vigas do teto.
	local y = mansion.floorY + MansionConfig.ArchHeight + 6.7
	local width, height, gap = 3.2, 4.4, 1
	local count = #answers.windows
	local total = count * width + (count - 1) * gap
	local model = Instance.new("Model")
	model.Name = "MysteryStainedGlass"
	part(model, "Frame", Vector3.new(total + 1.2, height + 1.2, 0.1), CFrame.new(centerX, y, z - 0.02), DARK_WOOD, Enum.Material.Wood)
	for index, colorIndex in ipairs(answers.windows) do
		local color = MysteryConfig.CandleColors[colorIndex].color
		local x = centerX - total / 2 + width / 2 + (index - 1) * (width + gap)
		local glass = part(model, `Window{index}`, Vector3.new(width, height, 0.12), CFrame.new(x, y, z), color:Lerp(Color3.new(0, 0, 0), 0.4), Enum.Material.Neon)
		glass.Transparency = 0.15
		part(model, "LeadV", Vector3.new(0.12, height, 0.16), CFrame.new(x, y, z + 0.02), LEAD)
		part(model, "LeadH", Vector3.new(width, 0.12, 0.16), CFrame.new(x, y + height * 0.15, z + 0.02), LEAD)
	end
	model.Parent = parent
end

-- Candelabros encostados na parede norte, a oeste do arco (posições da
-- esquerda para a direita de quem olha para o norte). Devolve o centro.
local function candelabra(parent: Instance, answers: Answers): Vector3
	local mansion = MansionLayout.get()
	local hall = mansion.rooms.GrandHall
	local half = MansionConfig.PartitionThickness / 2
	local floorY = mansion.floorY
	local z = hall.minZ + half + 1.6
	local firstX = hall.minX + 7.6
	local spacing = 4
	for index, colorIndex in ipairs(answers.candles) do
		local base = Vector3.new(firstX + (index - 1) * spacing, floorY, z)
		local model = Instance.new("Model")
		model.Name = `MysteryCandle{index}`
		model:SetAttribute("CandleIndex", index)
		model:SetAttribute("CandleColor", colorIndex)
		local upright = CFrame.Angles(0, 0, math.pi / 2)
		part(model, "Base", Vector3.new(0.4, 2.2, 2.2), CFrame.new(base + Vector3.new(0, 0.2, 0)) * upright, BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
		part(model, "Pole", Vector3.new(5.6, 0.4, 0.4), CFrame.new(base + Vector3.new(0, 3.1, 0)) * upright, BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
		local cup = part(model, "Cup", Vector3.new(1.4, 1.4, 1.4), CFrame.new(base + Vector3.new(0, 6.2, 0)), MysteryConfig.CandleColors[colorIndex].color, Enum.Material.Glass, Enum.PartType.Ball)
		cup.Transparency = 0.1
		part(model, "Candle", Vector3.new(1.5, 0.55, 0.55), CFrame.new(base + Vector3.new(0, 7.4, 0)) * upright, CANDLE_WAX, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local flame = part(model, "Flame", Vector3.new(0.4, 0.6, 0.4), CFrame.new(base + Vector3.new(0, 8.4, 0)), FLAME, Enum.Material.Neon, Enum.PartType.Ball)
		-- Acesa só no cliente de quem resolveu (ou durante a tentativa).
		flame.Transparency = 1
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = FLAME
		light.Range = 8
		light.Brightness = 1.4
		light.Enabled = false
		light.Parent = flame
		model.Parent = parent
	end
	local center = Vector3.new(firstX + spacing * (#answers.candles - 1) / 2, floorY, z)
	local anchor = part(parent, "MysteryCandlesPrompt", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 3.5, 0)), WOOD)
	anchor.Transparency = 1
	prompt(anchor, "Candles", "Acender as velas", "Velas do Salão")
	return center
end

-- Relógio da torre: o mostrador fica na parede leste do Sótão, parado nas
-- 12h (cada cliente gira os seus ponteiros ao resolver).
local function towerClock(parent: Instance): Vector3
	local wing = MansionWingLayout.get()
	local center = Vector3.new(wing.maxX - 0.45, wing.atticFloorY + 6.5, 20)
	local model = Instance.new("Model")
	model.Name = "MysteryTowerClock"
	local frame = CFrame.lookAt(center, center - Vector3.xAxis)
	part(model, "Ring", Vector3.new(0.3, 8.2, 8.2), CFrame.new(center + Vector3.new(0.1, 0, 0)), DARK_WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	local faceBoard = part(model, "Face", Vector3.new(7.2, 7.2, 0.05), frame * CFrame.new(0, 0, -0.1), CANVAS)
	faceBoard.Transparency = 1
	local gui = surfaceGui(faceBoard, "Clock")
	gui.PixelsPerStud = 50
	ClockFace.draw(gui :: any, 1)
	-- Engrenagens de enfeite em volta.
	for index, offset in ipairs({ Vector3.new(0, -5.6, 3.4), Vector3.new(0, 4.8, -4.2), Vector3.new(0, -4.4, -4.6) }) do
		part(model, `Gear{index}`, Vector3.new(0.25, 1.8, 1.8), CFrame.new(center + offset + Vector3.new(0.1, 0, 0)), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	local anchor = part(model, "Hitbox", Vector3.new(1, 1, 1), CFrame.new(center - Vector3.new(1.5, 3, 0)), WOOD)
	anchor.Transparency = 1
	prompt(anchor, "Clock", "Acertar o relógio", "Relógio da Torre")
	model.Parent = parent
	return center
end

-- Partitura da Vovó: título, pauta e o nome das notas.
local function paintSheet(gui: SurfaceGui, answers: Answers)
	local paper = Instance.new("Frame")
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = CANVAS
	paper.Parent = gui
	text(paper, "Title", "♪ Música da Vovó ♪", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.24), Color3.fromRGB(80, 50, 30))
	for index = 0, 4 do
		local line = Instance.new("Frame")
		line.Position = UDim2.fromScale(0.04, 0.42 + index * 0.1)
		line.Size = UDim2.new(0.92, 0, 0, 2)
		line.BackgroundColor3 = Color3.fromRGB(120, 100, 80)
		line.BorderSizePixel = 0
		line.Parent = paper
	end
	local count = #answers.melody
	for index, semitone in ipairs(answers.melody) do
		local name = MysteryConfig.NoteNames[semitone] or "?"
		text(paper, `Note{index}`, name, UDim2.fromScale(0.04 + (index - 1) * (0.92 / count), 0.44), UDim2.fromScale(0.92 / count, 0.36), Color3.fromRGB(40, 30, 60))
	end
end

-- Partitura da Vovó num suporte, no Sótão.
local function sheetStand(parent: Instance, answers: Answers)
	local wing = MansionWingLayout.get()
	local base = Vector3.new(wing.maxX - 8, wing.atticFloorY, 8)
	local model = Instance.new("Model")
	model.Name = "MysterySheetStand"
	local frame = CFrame.lookAt(base, base - Vector3.xAxis)
	part(model, "Pole", Vector3.new(0.15, 3.4, 0.15), frame * CFrame.new(0, 1.7, 0), IRON, Enum.Material.Metal)
	part(model, "Foot", Vector3.new(1.4, 0.12, 1.4), frame * CFrame.new(0, 0.06, 0), IRON, Enum.Material.Metal)
	local board = part(model, "Sheet", Vector3.new(3.4, 2.2, 0.06), frame * CFrame.new(0, 3.9, 0) * CFrame.Angles(math.rad(18), 0, 0), CANVAS, Enum.Material.Fabric)
	paintSheet(surfaceGui(board, "Sheet"), answers)
	model.Parent = parent
end

-- Nome de cada tecla branca, da mais grave (esquerda) para a mais aguda.
local function paintNotes(gui: SurfaceGui)
	local keys = #MysteryConfig.WhiteKeys
	for index, semitone in ipairs(MysteryConfig.WhiteKeys) do
		text(gui :: any, `Note{index}`, MysteryConfig.NoteNames[semitone], UDim2.fromScale((index - 1) / keys, 0), UDim2.fromScale(1 / keys, 1), Color3.fromRGB(255, 236, 190))
	end
end

-- Nome das notas acima das teclas brancas do piano.
local function pianoLabels(root: Instance)
	local piano = root:FindFirstChild("Piano", true)
	local body = if piano ~= nil then piano:FindFirstChild("Body") else nil
	if body == nil or not body:IsA("BasePart") then
		warn("[BlocoPuff] Mystery: piano not found for note labels")
		return
	end
	local keys = #MysteryConfig.WhiteKeys
	local length = keys * 1.05
	local front = body.Position - Vector3.new(body.Size.X / 2 + 0.03, 0, 0)
	local position = Vector3.new(front.X, body.Position.Y + 1.15, body.Position.Z)
	local strip = part(piano :: Instance, "MysteryNoteStrip", Vector3.new(length, 0.7, 0.05), CFrame.lookAt(position, position - Vector3.xAxis), Color3.fromRGB(40, 30, 28))
	paintNotes(surfaceGui(strip, "Notes"))
end

-- Cofrinho no Porão, encostado na parede leste.
local function safe(parent: Instance): Vector3
	local wing = MansionWingLayout.get()
	local base = Vector3.new(wing.maxX - 1.6, wing.cellarFloorY, -6)
	local model = Instance.new("Model")
	model.Name = "MysterySafe"
	local box = part(model, "Box", Vector3.new(2.4, 3, 3), CFrame.new(base + Vector3.new(0, 1.5, 0)), IRON, Enum.Material.DiamondPlate)
	box.CanCollide = true
	local door = part(model, "Door", Vector3.new(0.12, 2.5, 2.5), CFrame.new(base + Vector3.new(-1.26, 1.5, 0)), Color3.fromRGB(80, 84, 92), Enum.Material.Metal)
	door:SetAttribute("ClosedCFrame", door.CFrame)
	-- Dobradiça no lado -Z da porta (o cliente gira por ela ao abrir).
	door:SetAttribute("HingeCFrame", door.CFrame * CFrame.new(0, 0, -door.Size.Z / 2))
	door:SetAttribute("OpenAngle", -100)
	part(model, "Dial", Vector3.new(0.12, 0.9, 0.9), CFrame.new(base + Vector3.new(-1.36, 1.8, 0)), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(model, "Handle", Vector3.new(0.12, 0.2, 0.8), CFrame.new(base + Vector3.new(-1.36, 0.9, 0)), BRASS, Enum.Material.Metal)
	local coins = part(model, "Coins", Vector3.new(0.8, 1.6, 1.6), CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 205, 80), Enum.Material.Metal, Enum.PartType.Cylinder)
	coins.Transparency = 1
	-- Luz fraca em cima: o Porão é escuro.
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 200, 130)
	glow.Range = 9
	glow.Brightness = 0.8
	glow.Parent = box
	prompt(box, "Safe", "Abrir o cofrinho", "Cofrinho do Porão")
	model.Parent = parent
	return base
end

-- Pinturas e ajudantes, usados também pelo cenário com modelos.
MysteryPropsBasic.surfaceGui = surfaceGui
MysteryPropsBasic.prompt = prompt
MysteryPropsBasic.paintClock = paintClock
MysteryPropsBasic.paintDigit = paintDigit
MysteryPropsBasic.paintSheet = paintSheet
MysteryPropsBasic.paintNotes = paintNotes
MysteryPropsBasic.pianoLabels = pianoLabels

function MysteryPropsBasic.build(parent: Instance, mansionRoot: Instance, answers: Answers): Built
	local mansion = MansionLayout.get()
	local wing = MansionWingLayout.get()
	local hall = mansion.rooms.GrandHall
	local reserved: { { center: Vector3, size: Vector3 } } = {}

	stainedGlass(parent, answers)
	local candles = candelabra(parent, answers)
	table.insert(reserved, { center = candles, size = Vector3.new(16, 0, 6) })

	-- Quadro do relógio entre as portas da galeria (oeste) do Salão.
	local clockClue = Vector3.new(hall.minX + 6, mansion.floorY, -11.25)
	clockPainting(parent, clockClue, Vector3.new(1, 0, 0.3), answers)
	table.insert(reserved, { center = clockClue, size = Vector3.new(5, 0, 5) })

	local library = wing.rooms.Library
	local music = wing.rooms.Music
	digitPainting(parent, "MysteryDigit1", Vector3.new(library.maxX - 6, wing.floorY, library.maxZ - 4), Vector3.new(-1, 0, -0.4), 1, answers.code[1])
	digitPainting(parent, "MysteryDigit2", Vector3.new(music.maxX - 5, wing.floorY, music.minZ + 4), Vector3.new(-1, 0, 0.4), 2, answers.code[2])
	digitPainting(parent, "MysteryDigit3", Vector3.new(wing.minX + 6, wing.atticFloorY, 44), Vector3.new(1, 0, -0.3), 3, answers.code[3])

	local clock = towerClock(parent)
	sheetStand(parent, answers)
	pianoLabels(mansionRoot)
	local safeAt = safe(parent)

	local piano = mansionRoot:FindFirstChild("Piano", true)
	local pianoAt = if piano ~= nil and piano:IsA("Model") then piano:GetPivot().Position else Vector3.new(music.maxX, wing.floorY, (music.minZ + music.maxZ) / 2)
	return {
		anchors = { Clock = clock, Candles = candles, Safe = safeAt, Piano = pianoAt },
		reserved = reserved,
	}
end

return table.freeze(MysteryPropsBasic)
