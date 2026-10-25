--!strict

-- Peças feitas por código da Ala do Assassinato (Fase 5I), no lugar das
-- caixas lisas: o guarda-roupa esconderijo (portas abertas, cortina de
-- veludo, coroa, pés e puxadores dourados), a harpa da Sala de Música e o
-- tabuleiro do xadrez de bruxo da Sala de Jogos. Recebem o frame da base
-- (frente para -Z do frame) e montam tudo ancorado.

local MurderMansionPieces = {}

local COLORS = {
	darkWood = Color3.fromRGB(64, 40, 28),
	trim = Color3.fromRGB(92, 60, 38),
	gold = Color3.fromRGB(214, 168, 72),
	velvet = Color3.fromRGB(96, 40, 110),
	string = Color3.fromRGB(246, 232, 196),
	marbleLight = Color3.fromRGB(232, 226, 214),
	marbleDark = Color3.fromRGB(44, 40, 46),
	ivory = Color3.fromRGB(238, 230, 210),
	ebony = Color3.fromRGB(30, 26, 30),
}

-- Guarda-roupa: largura, fundo e altura do corpo.
local WARDROBE_WIDTH = 6
local WARDROBE_DEPTH = 4.5
local WARDROBE_HEIGHT = 9
local WARDROBE_FOOT = 0.5
-- Quanto as portas ficam abertas (graus, a partir de fechadas).
local DOOR_OPEN_DEGREES = 115
local DOOR_THICKNESS = 0.3

-- Harpa: altura, comprimento da base e cordas.
local HARP_HEIGHT = 6
local HARP_DEPTH = 3
local HARP_STRINGS = 9

-- Tabuleiro: lado, casas e altura da tampa da mesa que o recebe.
local BOARD_SIZE = 3.6
local BOARD_SQUARES = 8

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- Enfeite sem colisão e fora do raycast (não segura faca nem tiro).
local function trim(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(parent, name, size, cframe, color, material)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Guarda-roupa esconderijo: fundo, laterais e tampo sólidos (escondem e
-- seguram facas), sobre pés, com coroa moldurada, as duas portas abertas
-- para os lados e uma cortina de veludo meio transparente na frente (dá
-- para entrar; quem olha vê um vulto).
function MurderMansionPieces.wardrobe(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Wardrobe"
	local width, depth, height = WARDROBE_WIDTH, WARDROBE_DEPTH, WARDROBE_HEIGHT
	local body = base * CFrame.new(0, WARDROBE_FOOT, 0)
	local function at(x: number, y: number, z: number): CFrame
		return body * CFrame.new(x, y, z)
	end
	piece(model, "WardrobeBack", Vector3.new(width, height, 0.5), at(0, height / 2, depth / 2 - 0.25), COLORS.darkWood, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "WardrobeSide", Vector3.new(0.5, height, depth), at(side * (width / 2 - 0.25), height / 2, 0), COLORS.darkWood, Enum.Material.Wood)
		-- Pés torneados nos quatro cantos.
		for _, front in ipairs({ -1, 1 }) do
			trim(model, "WardrobeFoot", Vector3.new(0.6, WARDROBE_FOOT, 0.6), base * CFrame.new(side * (width / 2 - 0.4), WARDROBE_FOOT / 2, front * (depth / 2 - 0.4)), COLORS.trim, Enum.Material.Wood)
		end
		-- Porta aberta: gira na dobradiça da frente de cada lado.
		local hinge = at(side * width / 2, height / 2, -depth / 2)
		local leaf = hinge * CFrame.Angles(0, side * -math.rad(DOOR_OPEN_DEGREES), 0) * CFrame.new(-side * width / 4, 0, -DOOR_THICKNESS / 2)
		trim(model, "WardrobeDoor", Vector3.new(width / 2, height - 0.6, DOOR_THICKNESS), leaf, COLORS.darkWood, Enum.Material.Wood)
		-- Almofada da porta e puxador dourado.
		trim(model, "WardrobeDoorPanel", Vector3.new(width / 2 - 0.8, height - 2.4, 0.1), leaf * CFrame.new(0, 0, -DOOR_THICKNESS / 2 - 0.05), COLORS.trim, Enum.Material.Wood)
		local knob = trim(model, "WardrobeKnob", Vector3.one * 0.3, leaf * CFrame.new(-side * (width / 4 - 0.4), 0, -DOOR_THICKNESS / 2 - 0.15), COLORS.gold, Enum.Material.Metal)
		knob.Shape = Enum.PartType.Ball
	end
	piece(model, "WardrobeTop", Vector3.new(width, 0.5, depth), at(0, height - 0.25, 0), COLORS.darkWood, Enum.Material.Wood)
	-- Coroa: duas molduras escalonadas e um frontão no meio.
	trim(model, "WardrobeCrown", Vector3.new(width + 0.6, 0.4, depth + 0.4), at(0, height + 0.2, 0), COLORS.trim, Enum.Material.Wood)
	trim(model, "WardrobeCrown", Vector3.new(width + 1, 0.3, depth + 0.7), at(0, height + 0.55, 0), COLORS.darkWood, Enum.Material.Wood)
	trim(model, "WardrobePediment", Vector3.new(width / 2, 0.8, 0.3), at(0, height + 1.1, -depth / 2 - 0.2), COLORS.trim, Enum.Material.Wood)
	trim(model, "WardrobePlinth", Vector3.new(width + 0.4, 0.4, depth + 0.3), at(0, 0.2, 0), COLORS.trim, Enum.Material.Wood)
	local curtain = trim(model, "WardrobeCurtain", Vector3.new(width - 1, height - 1, 0.2), at(0, (height - 1) / 2 + 0.4, -depth / 2 + 0.3), COLORS.velvet, Enum.Material.Fabric)
	curtain.Transparency = 0.35
	-- Varão dourado da cortina.
	trim(model, "WardrobeRod", Vector3.new(width - 0.8, 0.15, 0.15), at(0, height - 0.6, -depth / 2 + 0.3), COLORS.gold, Enum.Material.Metal)
	model.Parent = parent
	return model
end

-- Harpa de pé: coluna, pescoço curvo (em dois trechos), caixa de ressonância
-- inclinada e as cordas entre o pescoço e a caixa. Sólida só na base.
function MurderMansionPieces.harp(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Harp"
	local height, depth = HARP_HEIGHT, HARP_DEPTH
	-- Coluna na frente (-Z), caixa atrás subindo até perto do alto.
	piece(model, "HarpBase", Vector3.new(1.4, 0.5, depth + 0.4), base * CFrame.new(0, 0.25, 0), COLORS.trim, Enum.Material.Wood)
	trim(model, "HarpPillar", Vector3.new(0.35, height, 0.35), base * CFrame.new(0, height / 2 + 0.5, -depth / 2), COLORS.gold, Enum.Material.Metal)
	-- Caixa: sobe de perto do pé da coluna até o alto, atrás.
	local boxBottom = Vector3.new(0, 0.6, -depth / 2 + 0.6)
	local boxTop = Vector3.new(0, height - 0.6, depth / 2)
	local boxMiddle = (boxBottom + boxTop) / 2
	local boxLength = (boxTop - boxBottom).Magnitude
	local boxFrame = base * CFrame.lookAt(boxMiddle, boxTop) * CFrame.Angles(math.rad(90), 0, 0)
	trim(model, "HarpSoundbox", Vector3.new(0.9, boxLength, 0.6), boxFrame, COLORS.trim, Enum.Material.Wood)
	-- Pescoço: do alto da coluna ao alto da caixa, com uma curva.
	local neckA = Vector3.new(0, height + 0.5, -depth / 2)
	local neckMid = Vector3.new(0, height + 0.9, 0)
	for _, pair in ipairs({ { neckA, neckMid }, { neckMid, boxTop } }) do
		local from, to = pair[1], pair[2]
		local middle = (from + to) / 2
		trim(model, "HarpNeck", Vector3.new(0.3, 0.45, (to - from).Magnitude + 0.2), base * CFrame.lookAt(middle, to), COLORS.gold, Enum.Material.Metal)
	end
	-- Altura do pescoço em cada z (os dois trechos retos).
	local function neckY(z: number): number
		local from, to = if z < neckMid.Z then neckA else neckMid, if z < neckMid.Z then neckMid else boxTop
		return from.Y + (to.Y - from.Y) * ((z - from.Z) / (to.Z - from.Z))
	end
	-- Cordas: verticais, do pescoço até a caixa (mais longas perto da coluna).
	for index = 1, HARP_STRINGS do
		local t = (index - 0.5) / HARP_STRINGS
		local z = boxBottom.Z + 0.2 + t * (boxTop.Z - boxBottom.Z - 0.6)
		local bottomY = boxBottom.Y + (boxTop.Y - boxBottom.Y) * ((z - boxBottom.Z) / (boxTop.Z - boxBottom.Z)) + 0.3
		local topY = neckY(z) - 0.2
		local length = topY - bottomY
		if length > 0.3 then
			trim(model, "HarpString", Vector3.new(0.04, length, 0.04), base * CFrame.new(0, bottomY + length / 2, z), COLORS.string, Enum.Material.SmoothPlastic)
		end
	end
	model.Parent = parent
	return model
end

-- Tabuleiro de xadrez de bruxo sobre a tampa (`top`: centro da face de
-- cima da mesa), com casas de mármore claro e escuro e algumas peças no meio
-- da partida (peão, torre e rei de cada lado).
function MurderMansionPieces.chessBoard(parent: Instance, top: CFrame)
	local model = Instance.new("Model")
	model.Name = "WizardChess"
	local square = BOARD_SIZE / BOARD_SQUARES
	trim(model, "ChessFrame", Vector3.new(BOARD_SIZE + 0.4, 0.15, BOARD_SIZE + 0.4), top * CFrame.new(0, 0.075, 0), COLORS.trim, Enum.Material.Wood)
	for row = 0, BOARD_SQUARES - 1 do
		for column = 0, BOARD_SQUARES - 1 do
			local light = (row + column) % 2 == 0
			local x = -BOARD_SIZE / 2 + square * (column + 0.5)
			local z = -BOARD_SIZE / 2 + square * (row + 0.5)
			trim(model, "ChessSquare", Vector3.new(square, 0.05, square), top * CFrame.new(x, 0.175, z), if light then COLORS.marbleLight else COLORS.marbleDark, Enum.Material.Marble)
		end
	end
	local function chessPiece(column: number, row: number, height: number, white: boolean, crown: boolean)
		local x = -BOARD_SIZE / 2 + square * (column + 0.5)
		local z = -BOARD_SIZE / 2 + square * (row + 0.5)
		local color = if white then COLORS.ivory else COLORS.ebony
		local body = trim(model, "ChessPiece", Vector3.new(height, square * 0.55, square * 0.55), top * CFrame.new(x, 0.2 + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Marble)
		body.Shape = Enum.PartType.Cylinder
		local head = trim(model, "ChessHead", Vector3.one * square * 0.5, top * CFrame.new(x, 0.2 + height + square * 0.2, z), if crown then COLORS.gold else color, Enum.Material.Marble)
		head.Shape = Enum.PartType.Ball
	end
	chessPiece(1, 1, 0.35, true, false)
	chessPiece(4, 2, 0.35, true, false)
	chessPiece(0, 0, 0.45, true, false)
	chessPiece(3, 0, 0.6, true, true)
	chessPiece(5, 5, 0.35, false, false)
	chessPiece(2, 6, 0.35, false, false)
	chessPiece(7, 7, 0.45, false, false)
	chessPiece(4, 7, 0.6, false, true)
	model.Parent = parent
	return model
end

return table.freeze(MurderMansionPieces)
