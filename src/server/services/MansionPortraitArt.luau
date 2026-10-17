--!strict

-- Desenho dos retratos da família Puff (Fase 5C.4, parte 2): formas
-- arredondadas numa SurfaceGui, no estilo dos Puffs. Os olhos ("EyeL" e
-- "EyeR") têm a pupila ("Pupil") e a pálpebra ("Lid") que o cliente mexe
-- (MansionAmbienceController): olham para quem passa e piscam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionAmbienceConfig = require(ReplicatedStorage.Shared.config.MansionAmbienceConfig)

type Portrait = MansionAmbienceConfig.Portrait

local PIXELS_PER_STUD = 60
local INK = Color3.fromRGB(30, 24, 40)
local WHITE = Color3.fromRGB(250, 248, 240)
local BLUSH = Color3.fromRGB(255, 140, 170)
local GOLD = Color3.fromRGB(240, 196, 92)
-- Centro dos olhos na tela (fração) e tamanho de cada olho (fração da
-- largura da tela).
local EYE_Y = 0.5
local EYE_GAP = 0.13
local EYE_SIZE = 0.17

local MansionPortraitArt = {}

local function shape(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3, round: number?, z: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z or 2
	if round ~= nil then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

local function at(x: number, y: number): UDim2
	return UDim2.fromScale(x, y)
end

-- Tamanho em fração da largura (os círculos ficam redondos na tela alta).
local function wide(w: number, h: number, aspect: number): UDim2
	return UDim2.fromScale(w, h * aspect)
end

local function eye(parent: Instance, name: string, x: number, aspect: number, lidColor: Color3, puppy: boolean)
	local white = shape(parent, name, at(x, EYE_Y), wide(EYE_SIZE, EYE_SIZE, aspect), if puppy then INK else WHITE, 0.5, 5)
	white.ClipsDescendants = true
	local pupil = shape(white, "Pupil", at(0.5, 0.5), UDim2.fromScale(0.52, 0.52), if puppy then Color3.fromRGB(70, 50, 40) else INK, 0.5, 6)
	shape(pupil, "Shine", at(0.68, 0.3), UDim2.fromScale(0.34, 0.34), WHITE, 0.5, 7)
	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.AnchorPoint = Vector2.new(0.5, 0)
	lid.Position = UDim2.fromScale(0.5, 0)
	lid.Size = UDim2.fromScale(1.1, 0)
	lid.BackgroundColor3 = lidColor
	lid.BorderSizePixel = 0
	lid.ZIndex = 8
	lid.Parent = white
end

-- Enfeites de cada antepassado.
local function accessories(art: Frame, style: string, body: Color3, aspect: number)
	if style == "Grandpa" then
		shape(art, "Mustache", at(0.42, 0.64), wide(0.2, 0.07, aspect), Color3.fromRGB(235, 235, 240), 0.5, 6)
		shape(art, "Mustache2", at(0.58, 0.64), wide(0.2, 0.07, aspect), Color3.fromRGB(235, 235, 240), 0.5, 6)
		shape(art, "HatBrim", at(0.5, 0.25), wide(0.62, 0.05, aspect), INK, 0.3, 6)
		shape(art, "HatTop", at(0.5, 0.17), wide(0.38, 0.2, aspect), INK, 0.12, 5)
		shape(art, "HatBand", at(0.5, 0.215), wide(0.38, 0.035, aspect), Color3.fromRGB(170, 40, 60), nil, 6)
		local monocle = shape(art, "Monocle", at(0.5 + EYE_GAP, EYE_Y), wide(EYE_SIZE + 0.06, EYE_SIZE + 0.06, aspect), GOLD, 0.5, 4)
		monocle.BackgroundTransparency = 0.1
	elseif style == "Grandma" then
		shape(art, "Bun", at(0.5, 0.2), wide(0.24, 0.24, aspect), Color3.fromRGB(230, 226, 236), 0.5, 3)
		for index = 1, 5 do
			shape(art, `Pearl{index}`, at(0.3 + index * 0.067, 0.92 - math.abs(index - 3) * 0.012), wide(0.06, 0.06, aspect), WHITE, 0.5, 6)
		end
		for _, side in ipairs({ -1, 1 }) do
			local lens = shape(art, `Glasses{side}`, at(0.5 + side * EYE_GAP, EYE_Y), wide(EYE_SIZE + 0.07, EYE_SIZE + 0.07, aspect), Color3.fromRGB(200, 120, 160), 0.5, 4)
			lens.BackgroundTransparency = 0.2
		end
	elseif style == "Explorer" then
		shape(art, "HatBrim", at(0.5, 0.29), wide(0.86, 0.06, aspect), Color3.fromRGB(150, 116, 70), 0.5, 6)
		shape(art, "HatDome", at(0.5, 0.23), wide(0.5, 0.2, aspect), Color3.fromRGB(196, 160, 100), 0.5, 5)
		shape(art, "Mustache", at(0.5, 0.645), wide(0.34, 0.07, aspect), Color3.fromRGB(110, 70, 40), 0.5, 6)
		shape(art, "Scarf", at(0.5, 0.82), wide(0.5, 0.08, aspect), Color3.fromRGB(200, 60, 50), 0.4, 6)
	elseif style == "Singer" then
		shape(art, "BowL", at(0.38, 0.27), wide(0.17, 0.13, aspect), Color3.fromRGB(255, 90, 160), 0.5, 6)
		shape(art, "BowR", at(0.62, 0.27), wide(0.17, 0.13, aspect), Color3.fromRGB(255, 90, 160), 0.5, 6)
		shape(art, "BowKnot", at(0.5, 0.27), wide(0.08, 0.08, aspect), Color3.fromRGB(230, 60, 130), 0.5, 7)
		shape(art, "Mouth", at(0.5, 0.67), wide(0.1, 0.1, aspect), Color3.fromRGB(120, 30, 60), 0.5, 6)
		local note = Instance.new("TextLabel")
		note.Name = "Note"
		note.AnchorPoint = Vector2.new(0.5, 0.5)
		note.Position = at(0.82, 0.36)
		note.Size = wide(0.2, 0.2, aspect)
		note.BackgroundTransparency = 1
		note.Font = Enum.Font.FredokaOne
		note.Text = "♪"
		note.TextColor3 = GOLD
		note.TextScaled = true
		note.ZIndex = 6
		note.Parent = art
	elseif style == "Puppy" then
		for _, side in ipairs({ -1, 1 }) do
			local ear = shape(art, `Ear{side}`, at(0.5 + side * 0.34, 0.5), wide(0.16, 0.36, aspect), Color3.fromRGB(110, 64, 32), 0.5, 3)
			ear.Rotation = side * 12
		end
		shape(art, "Snout", at(0.5, 0.65), wide(0.3, 0.2, aspect), Color3.fromRGB(230, 196, 150), 0.5, 5)
		shape(art, "Nose", at(0.5, 0.61), wide(0.1, 0.07, aspect), INK, 0.5, 6)
		shape(art, "Tongue", at(0.5, 0.72), wide(0.08, 0.08, aspect), Color3.fromRGB(240, 110, 130), 0.5, 6)
		shape(art, "Collar", at(0.5, 0.83), wide(0.5, 0.05, aspect), Color3.fromRGB(0, 140, 70), 0.4, 6)
		shape(art, "Tag", at(0.5, 0.86), wide(0.07, 0.07, aspect), GOLD, 0.5, 7)
	elseif style == "Ghost" then
		for index = 1, 4 do
			shape(art, `Hem{index}`, at(0.17 + index * 0.13, 0.86), wide(0.15, 0.15, aspect), body, 0.5, 3)
		end
		shape(art, "Mouth", at(0.5, 0.67), wide(0.08, 0.1, aspect), INK, 0.5, 6)
	end
end

-- Pinta o retrato na face da frente de `canvas`.
function MansionPortraitArt.paint(canvas: BasePart, definition: Portrait)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Portrait"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0.25
	gui.MaxDistance = 80
	gui.Parent = canvas
	local size = canvas.Size
	local aspect = size.X / size.Y
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.Size = UDim2.fromScale(1, 1)
	-- Branco: o UIGradient multiplica a cor de fundo (com a cor do fundo
	-- aqui, ela sairia ao quadrado, quase preta).
	art.BackgroundColor3 = Color3.new(1, 1, 1)
	art.BorderSizePixel = 0
	art.ClipsDescendants = true
	art.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(definition.background:Lerp(Color3.new(1, 1, 1), 0.2), definition.background:Lerp(Color3.new(0, 0, 0), 0.12))
	gradient.Parent = art
	local puppy = definition.style == "Puppy"
	local body = shape(art, "Body", at(0.5, 0.58), wide(0.78, 0.78, aspect), definition.body, 0.5, 2)
	if definition.style == "Ghost" then
		body.BackgroundTransparency = 0.12
	end
	shape(art, "Shoulders", at(0.5, 1.02), wide(0.95, 0.5, aspect), definition.body:Lerp(Color3.new(0, 0, 0), 0.15), 0.5, 1)
	for _, side in ipairs({ -1, 1 }) do
		shape(art, if side < 0 then "CheekL" else "CheekR", at(0.5 + side * 0.25, 0.63), wide(0.1, 0.06, aspect), BLUSH, 0.5, 4)
	end
	eye(art, "EyeL", 0.5 - EYE_GAP, aspect, definition.body, puppy)
	eye(art, "EyeR", 0.5 + EYE_GAP, aspect, definition.body, puppy)
	accessories(art, definition.style, definition.body, aspect)
end

return table.freeze(MansionPortraitArt)
