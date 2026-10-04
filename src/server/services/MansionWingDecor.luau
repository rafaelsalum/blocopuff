--!strict

-- Móveis da ala leste do Casarão (Fase 5C.1): Biblioteca, Sala de Música
-- (com o piano tocável, tag MansionWingConfig.Piano.Tag), Sótão e Porão. Os
-- caminhos das portas e das escadas ficam livres. A estrutura é do
-- MansionWing; a geometria, do MansionWingLayout.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionWingConfig = require(ReplicatedStorage.Shared.config.MansionWingConfig)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)

type BuildingConfig = GameConfig.BuildingConfig
type Wing = MansionWingLayout.Wing
type PartOptions = BuildingDecor.PartOptions

local CONFIG = MansionWingConfig
local SEED = 7331
local DARK_WOOD = Color3.fromRGB(70, 44, 28)
local BOOK_COLORS = {
	Color3.fromRGB(140, 40, 40),
	Color3.fromRGB(40, 70, 130),
	Color3.fromRGB(46, 110, 64),
	Color3.fromRGB(170, 130, 60),
	Color3.fromRGB(96, 50, 110),
	Color3.fromRGB(150, 90, 50),
}
local SHEET_COLOR = Color3.fromRGB(236, 232, 220)
local WEB_COLOR = Color3.fromRGB(235, 235, 235)
local BRASS = Color3.fromRGB(214, 170, 80)
-- Notas do piano: Dó a Dó (teclas brancas) e os sustenidos (pretas).
local WHITE_KEYS = { 0, 2, 4, 5, 7, 9, 11, 12 }
local BLACK_KEYS = { { after = 1, semitone = 1 }, { after = 2, semitone = 3 }, { after = 4, semitone = 6 }, { after = 5, semitone = 8 }, { after = 6, semitone = 10 } }

local MansionWingDecor = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, options: PartOptions?): Part
	return BuildingDecor.createPart(parent, name, size, cframe, color, options)
end

local function solidPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return part(parent, name, size, cframe, color, { material = material or Enum.Material.Wood, collide = true })
end

local function pointLight(parent: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
end

-- Estante encostada numa parede: `base` no piso, junto da parede; `facing`
-- aponta para dentro da sala.
local function bookshelf(parent: Instance, name: string, base: Vector3, facing: Vector3, width: number, height: number, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = name
	local depth = 2
	local right = facing:Cross(Vector3.yAxis)
	local center = base + facing * (depth / 2)
	local frame = CFrame.fromMatrix(center + Vector3.new(0, height / 2, 0), right, Vector3.yAxis)
	solidPart(model, "Back", Vector3.new(width, height, 0.4), frame * CFrame.new(0, 0, depth / 2 - 0.2), DARK_WOOD)
	for _, side in ipairs({ -1, 1 }) do
		solidPart(model, "Side", Vector3.new(0.4, height, depth), frame * CFrame.new(side * (width / 2 - 0.2), 0, 0), DARK_WOOD)
	end
	local rows = math.floor(height / 2.6)
	local rowHeight = height / rows
	for row = 0, rows - 1 do
		local y = -height / 2 + row * rowHeight
		part(model, "Shelf", Vector3.new(width - 0.8, 0.3, depth), frame * CFrame.new(0, y + 0.15, 0), DARK_WOOD, { material = Enum.Material.Wood })
		-- Duas fileiras de livros de cores e alturas diferentes por prateleira.
		local half = (width - 0.8) / 2
		for segment = 0, 1 do
			local bookHeight = rowHeight * rng:NextNumber(0.6, 0.85)
			local color = BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)] :: Color3
			local x = -half / 2 + segment * half
			part(model, "Books", Vector3.new(half - 0.2, bookHeight, depth * 0.7), frame * CFrame.new(x, y + 0.3 + bookHeight / 2, -0.1), color, { material = Enum.Material.Fabric })
		end
	end
	model.Parent = parent
	return model
end

-- Escada de rodinhas encostada na estante.
local function rollingLadder(parent: Instance, base: Vector3, facing: Vector3, height: number)
	local right = facing:Cross(Vector3.yAxis)
	local lean = CFrame.fromMatrix(base + facing * 1.6 + Vector3.new(0, height / 2, 0), right, Vector3.yAxis) * CFrame.Angles(math.rad(-10), 0, 0)
	for _, side in ipairs({ -1, 1 }) do
		part(parent, "LadderRail", Vector3.new(0.3, height, 0.3), lean * CFrame.new(side * 0.9, 0, 0), BRASS, { material = Enum.Material.Metal })
	end
	local rungs = math.floor(height / 1.4)
	for index = 1, rungs do
		part(parent, "LadderRung", Vector3.new(1.8, 0.2, 0.25), lean * CFrame.new(0, -height / 2 + index * 1.4, 0), BRASS, { material = Enum.Material.Metal })
	end
end

local function floorLamp(parent: Instance, base: Vector3)
	part(parent, "LampPole", Vector3.new(0.3, 5, 0.3), CFrame.new(base + Vector3.new(0, 2.5, 0)), BRASS, { material = Enum.Material.Metal })
	local shade = part(parent, "LampShade", Vector3.new(1.6, 1.2, 1.6), CFrame.new(base + Vector3.new(0, 5.4, 0)), Color3.fromRGB(240, 210, 160), { material = Enum.Material.Fabric })
	pointLight(shade, Color3.fromRGB(255, 214, 160), 14, 0.9)
end

local function rug(parent: Instance, name: string, center: Vector3, width: number, depth: number, color: Color3, style: BuildingConfig)
	part(parent, `{name}Border`, Vector3.new(width + 1, 0.08, depth + 1), CFrame.new(center + Vector3.new(0, 0.04, 0)), style.RugColor, { material = Enum.Material.Fabric })
	part(parent, name, Vector3.new(width, 0.1, depth), CFrame.new(center + Vector3.new(0, 0.07, 0)), color, { material = Enum.Material.Fabric })
end

local function buildLibrary(parent: Instance, wing: Wing, style: BuildingConfig, rng: Random)
	local room = wing.rooms.Library
	local floorY = wing.floorY
	local folder = Instance.new("Model")
	folder.Name = "Library"
	local shelfHeight = MansionConfig.CeilingHeight - 6
	-- Estantes na parede norte e na leste.
	for index = 0, 3 do
		local x = room.minX + 9 + index * 9
		bookshelf(folder, `NorthShelf{index + 1}`, Vector3.new(x, floorY, room.minZ), Vector3.zAxis, 8, shelfHeight, rng)
	end
	for index = 0, 2 do
		local z = room.minZ + 9 + index * 9
		local shelf = bookshelf(folder, `EastShelf{index + 1}`, Vector3.new(room.maxX, floorY, z), -Vector3.xAxis, 8, shelfHeight, rng)
		if index == 1 then
			-- O livro "errado" (vermelho, saindo da estante): abre a passagem
			-- secreta na 5C.3.
			local wrong = part(shelf, "WrongBook", Vector3.new(0.9, 1.8, 1.4), CFrame.new(room.maxX - 2.3, floorY + 6.2, z + 1.5), Color3.fromRGB(200, 30, 30), { material = Enum.Material.Fabric })
			wrong:SetAttribute("WrongBook", true)
		end
	end
	rollingLadder(folder, Vector3.new(room.minX + 18, floorY, room.minZ + 2), Vector3.zAxis, shelfHeight - 2)
	-- Canto de leitura no meio da sala.
	local center = Vector3.new((room.minX + room.maxX) / 2 + 2, floorY, (room.minZ + room.maxZ) / 2 + 3)
	rug(folder, "LibraryRug", center, 16, 12, Color3.fromRGB(110, 40, 46), style)
	for index, side in ipairs({ -1, 1 }) do
		BuildingDecor.createSofa(folder, `ReadingChair{index}`, center + Vector3.new(side * 4.5, 0, 0), Vector3.new(-side, 0, 0), 3.4, style)
	end
	BuildingDecor.createSideTable(folder, "ReadingTable", center, style)
	floorLamp(folder, center + Vector3.new(0, 0, -4.5))
	folder.Parent = parent
end

-- Piano de armário encostado na parede leste, teclado virado para oeste.
local function buildPiano(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "Piano"
	local piano = CONFIG.Piano
	local keyWidth = 1.05
	local keyboardLength = #WHITE_KEYS * keyWidth
	local width = keyboardLength + 2
	solidPart(model, "Body", Vector3.new(2.6, 6, width), CFrame.new(base + Vector3.new(-1.3, 3, 0)), Color3.fromRGB(28, 22, 22))
	solidPart(model, "Ledge", Vector3.new(2.2, 1, width), CFrame.new(base + Vector3.new(-3.6, 2.6, 0)), Color3.fromRGB(28, 22, 22))
	part(model, "Trim", Vector3.new(2.7, 0.3, width + 0.2), CFrame.new(base + Vector3.new(-1.3, 6.1, 0)), BRASS, { material = Enum.Material.Metal })
	local startZ = -keyboardLength / 2 + keyWidth / 2
	local function key(name: string, size: Vector3, position: Vector3, color: Color3, semitone: number)
		local keyPart = part(model, name, size, CFrame.new(position), color, { material = Enum.Material.SmoothPlastic })
		keyPart.CanQuery = true
		keyPart.CanTouch = false
		keyPart:SetAttribute(piano.SemitoneAttribute, semitone)
		CollectionService:AddTag(keyPart, piano.Tag)
	end
	for index, semitone in ipairs(WHITE_KEYS) do
		local z = startZ + (index - 1) * keyWidth
		key(`WhiteKey{index}`, Vector3.new(1.8, 0.35, keyWidth - 0.08), base + Vector3.new(-3.8, 3.25, z), Color3.fromRGB(245, 242, 232), semitone)
	end
	for index, black in ipairs(BLACK_KEYS) do
		local z = startZ + (black.after - 0.5) * keyWidth
		key(`BlackKey{index}`, Vector3.new(1.1, 0.4, 0.6), base + Vector3.new(-3.4, 3.6, z), Color3.fromRGB(20, 20, 24), black.semitone)
	end
	solidPart(model, "Bench", Vector3.new(1.8, 2, 4), CFrame.new(base + Vector3.new(-6.6, 1, 0)), Color3.fromRGB(28, 22, 22))
	model.Parent = parent
end

local function gramophone(parent: Instance, base: Vector3)
	BuildingDecor.createSideTable(parent, "GramophoneTable", base, GameConfig.Building)
	local top = base + Vector3.new(0, 3.2, 0)
	part(parent, "GramophoneBox", Vector3.new(1.6, 0.8, 1.6), CFrame.new(top + Vector3.new(0, 0.4, 0)), DARK_WOOD, { material = Enum.Material.Wood })
	part(parent, "GramophoneNeck", Vector3.new(0.25, 1.4, 0.25), CFrame.new(top + Vector3.new(0, 1.4, 0)), BRASS, { material = Enum.Material.Metal })
	part(parent, "GramophoneHorn", Vector3.new(0.4, 1.8, 1.8), CFrame.new(top + Vector3.new(0.5, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(35)), BRASS, {
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
	})
end

-- Partituras emolduradas na parede (texto: notas).
local function sheetMusic(parent: Instance, position: Vector3, facing: Vector3, text: string)
	local right = facing:Cross(Vector3.yAxis)
	local sheet = part(parent, "SheetMusic", Vector3.new(3, 4, 0.15), CFrame.fromMatrix(position, right, Vector3.yAxis), SHEET_COLOR, { material = Enum.Material.SmoothPlastic })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.MaxDistance = 50
	gui.Parent = sheet
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(30, 30, 40)
	label.TextScaled = true
	label.Parent = gui
end

local function buildMusicRoom(parent: Instance, wing: Wing, style: BuildingConfig)
	local room = wing.rooms.Music
	local floorY = wing.floorY
	local folder = Instance.new("Model")
	folder.Name = "MusicRoom"
	local centerZ = (room.minZ + room.maxZ) / 2
	buildPiano(folder, Vector3.new(room.maxX, floorY, centerZ))
	rug(folder, "MusicRug", Vector3.new(room.maxX - 12, floorY, centerZ), 12, 14, Color3.fromRGB(60, 40, 90), style)
	-- Plateia de frente para o piano.
	for index, dz in ipairs({ -5, 5 }) do
		BuildingDecor.createSofa(folder, `MusicSofa{index}`, Vector3.new(room.maxX - 20, floorY, centerZ + dz), Vector3.xAxis, 6, style)
	end
	gramophone(folder, Vector3.new(room.minX + 4, floorY, room.maxZ - 4))
	local southInner = room.maxZ - 0.7
	for index, text in ipairs({ "♪ ♫ ♪", "♩ ♬ ♩", "♫ ♪ ♬" }) do
		sheetMusic(folder, Vector3.new(room.minX + 12 + index * 6, floorY + 8, southInner), -Vector3.zAxis, text)
	end
	BuildingDecor.createPlant(folder, "MusicPlant", Vector3.new(room.maxX - 3, floorY, room.maxZ - 3), style)
	folder.Parent = parent
end

-- Baú com tampa e ferragens.
local function chest(parent: Instance, base: Vector3, yaw: number)
	local frame = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	solidPart(parent, "Chest", Vector3.new(3.6, 2, 2.2), frame * CFrame.new(0, 1, 0), Color3.fromRGB(110, 70, 40), Enum.Material.WoodPlanks)
	part(parent, "ChestLid", Vector3.new(3.7, 0.5, 2.3), frame * CFrame.new(0, 2.25, 0), Color3.fromRGB(96, 60, 34), { material = Enum.Material.WoodPlanks })
	part(parent, "ChestBand", Vector3.new(0.3, 2.6, 2.4), frame * CFrame.new(0, 1.3, 0), BRASS, { material = Enum.Material.Metal })
end

-- Móvel coberto por lençol (formas arredondadas, brancas).
local function coveredFurniture(parent: Instance, base: Vector3, size: Vector3)
	solidPart(parent, "SheetCovered", size, CFrame.new(base + Vector3.new(0, size.Y / 2, 0)), Color3.fromRGB(226, 222, 212), Enum.Material.Fabric)
	part(parent, "SheetDrape", Vector3.new(size.X + 0.4, 0.4, size.Z + 0.4), CFrame.new(base + Vector3.new(0, 0.2, 0)), Color3.fromRGB(214, 210, 200), { material = Enum.Material.Fabric })
end

-- Teia num canto do teto.
local function cobweb(parent: Instance, corner: Vector3, yaw: number)
	local web = part(parent, "Cobweb", Vector3.new(0.05, 3, 3), CFrame.new(corner) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(45), 0, 0), WEB_COLOR, {
		material = Enum.Material.ForceField,
		transparency = 0.55,
	})
	web.CastShadow = false
end

local function buildAttic(parent: Instance, wing: Wing)
	local folder = Instance.new("Model")
	folder.Name = "Attic"
	local y = wing.atticFloorY
	local top = wing.atticCeilingY
	-- Vigas do telhado.
	for index = 0, 8 do
		local z = wing.minZ + 8 + index * ((wing.maxZ - wing.minZ - 16) / 8)
		part(folder, "AtticBeam", Vector3.new(wing.maxX - wing.minX, 1, 1), CFrame.new((wing.minX + wing.maxX) / 2, top - 0.5, z), Color3.fromRGB(80, 56, 36), { material = Enum.Material.Wood })
	end
	-- Fora da faixa da escada (lado norte do Hall) e da saída dela (oeste).
	local mid = (wing.minX + wing.maxX) / 2
	chest(folder, Vector3.new(wing.maxX - 4, y, wing.minZ + 4), 0)
	chest(folder, Vector3.new(wing.maxX - 4, y, wing.maxZ - 5), math.rad(15))
	chest(folder, Vector3.new(mid, y, wing.maxZ - 4), math.rad(-10))
	coveredFurniture(folder, Vector3.new(mid - 6, y, wing.minZ + 10), Vector3.new(6, 3.4, 3))
	coveredFurniture(folder, Vector3.new(mid + 8, y, wing.minZ + 14), Vector3.new(3, 5, 3))
	coveredFurniture(folder, Vector3.new(wing.minX + 6, y, wing.maxZ - 12), Vector3.new(4, 6, 2))
	coveredFurniture(folder, Vector3.new(mid + 6, y, wing.southPartitionZ + 8), Vector3.new(7, 3, 3))
	for _, corner in ipairs({
		{ Vector3.new(wing.minX + 1.5, top - 1.5, wing.minZ + 1.5), math.rad(45) },
		{ Vector3.new(wing.maxX - 1.5, top - 1.5, wing.minZ + 1.5), math.rad(-45) },
		{ Vector3.new(wing.minX + 1.5, top - 1.5, wing.maxZ - 1.5), math.rad(135) },
		{ Vector3.new(wing.maxX - 1.5, top - 1.5, wing.maxZ - 1.5), math.rad(-135) },
	}) do
		cobweb(folder, corner[1] :: Vector3, corner[2] :: number)
	end
	folder.Parent = parent
end

-- Barril deitado.
local function barrel(parent: Instance, center: Vector3, yaw: number)
	local frame = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	solidPart(parent, "Barrel", Vector3.new(4, 3, 3), frame, Color3.fromRGB(120, 76, 42), Enum.Material.WoodPlanks).Shape = Enum.PartType.Cylinder
	for _, dx in ipairs({ -1.3, 1.3 }) do
		part(parent, "BarrelHoop", Vector3.new(0.3, 3.15, 3.15), frame * CFrame.new(dx, 0, 0), Color3.fromRGB(60, 60, 64), {
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
	end
end

local function wallLantern(parent: Instance, position: Vector3)
	local lantern = part(parent, "CellarLantern", Vector3.new(0.8, 1.2, 0.8), CFrame.new(position), Color3.fromRGB(255, 190, 110), { material = Enum.Material.Neon })
	pointLight(lantern, Color3.fromRGB(255, 180, 110), 18, 0.8)
end

-- Gotas caindo do teto numa poça, com som de goteira.
local function drip(parent: Instance, position: Vector3, floorY: number, withSound: boolean)
	local source = part(parent, "Drip", Vector3.new(0.4, 0.2, 0.4), CFrame.new(position), Color3.fromRGB(80, 80, 90), { transparency = 1 })
	local attachment = Instance.new("Attachment")
	attachment.Parent = source
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drops.Color = ColorSequence.new(Color3.fromRGB(170, 200, 230))
	drops.Size = NumberSequence.new(0.18)
	drops.Lifetime = NumberRange.new(0.9, 1)
	drops.Rate = 1.5
	drops.Speed = NumberRange.new(0)
	drops.Acceleration = Vector3.new(0, -(position.Y - floorY) * 2.2, 0)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Parent = attachment
	part(parent, "Puddle", Vector3.new(0.08, 3, 3), CFrame.new(position.X, floorY + 0.04, position.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 90, 110), {
		material = Enum.Material.Glass,
		transparency = 0.35,
		shape = Enum.PartType.Cylinder,
	})
	if withSound then
		local sound = Instance.new("Sound")
		sound.Name = "DripLoop"
		sound.SoundId = CONFIG.CellarDripSoundId
		sound.Looped = true
		sound.Volume = 0.5
		sound.RollOffMaxDistance = 45
		sound.Playing = true
		sound.Parent = source
	end
end

local function buildCellar(parent: Instance, wing: Wing)
	local folder = Instance.new("Model")
	folder.Name = "Cellar"
	local y = wing.cellarFloorY
	local ceiling = wing.floorY - 1
	-- Fileiras de barris nas paredes norte e oeste.
	for index = 0, 4 do
		barrel(folder, Vector3.new(wing.minX + 6 + index * 7, y + 1.5, wing.minZ + 2.5), 0)
	end
	for index = 0, 3 do
		barrel(folder, Vector3.new(wing.minX + 2.5, y + 1.5, wing.minZ + 12 + index * 6), math.rad(90))
	end
	-- Prateleira de vinhos na parede sul.
	local rack = Vector3.new((wing.minX + wing.maxX) / 2, y, wing.maxZ - 1.5)
	solidPart(folder, "WineRack", Vector3.new(14, 7, 2), CFrame.new(rack + Vector3.new(0, 3.5, 0)), Color3.fromRGB(80, 50, 30))
	for row = 0, 2 do
		part(folder, "Bottles", Vector3.new(13, 1, 0.6), CFrame.new(rack + Vector3.new(0, 1.5 + row * 2, -1.1)), Color3.fromRGB(40, 70, 50), { material = Enum.Material.Glass })
	end
	-- Entrada do túnel fechada com tábuas (parede leste, abre na 5C.3).
	local tunnel = Vector3.new(wing.maxX - 0.4, y, wing.minZ + 22)
	local tunnelModel = Instance.new("Model")
	tunnelModel.Name = "CellarTunnel"
	tunnelModel:SetAttribute("CellarTunnel", true)
	solidPart(tunnelModel, "TunnelFrameTop", Vector3.new(0.8, 1, 8), CFrame.new(tunnel + Vector3.new(0, 9, 0)), DARK_WOOD)
	for _, dz in ipairs({ -3.6, 3.6 }) do
		solidPart(tunnelModel, "TunnelFramePost", Vector3.new(0.8, 9, 0.8), CFrame.new(tunnel + Vector3.new(0, 4.5, dz)), DARK_WOOD)
	end
	part(tunnelModel, "TunnelDark", Vector3.new(0.2, 8.5, 6.4), CFrame.new(tunnel + Vector3.new(0.3, 4.25, 0)), Color3.fromRGB(10, 8, 8), { material = Enum.Material.SmoothPlastic })
	for index = 0, 3 do
		local plank = solidPart(tunnelModel, "TunnelPlank", Vector3.new(0.4, 1, 7.6), CFrame.new(tunnel + Vector3.new(-0.3, 1.6 + index * 2, 0)) * CFrame.Angles(math.rad(if index % 2 == 0 then 8 else -8), 0, 0), Color3.fromRGB(130, 90, 56), Enum.Material.WoodPlanks)
		plank.CanCollide = true
	end
	tunnelModel.Parent = folder
	for _, position in ipairs({
		Vector3.new(wing.minX + 0.6, y + 7, (wing.minZ + wing.maxZ) / 2),
		Vector3.new(wing.maxX - 0.6, y + 7, wing.minZ + 12),
		Vector3.new((wing.minX + wing.maxX) / 2, y + 7, wing.maxZ - 0.6),
	}) do
		wallLantern(folder, position)
	end
	drip(folder, Vector3.new(wing.minX + 16, ceiling - 0.2, wing.minZ + 30), y, true)
	drip(folder, Vector3.new(wing.maxX - 12, ceiling - 0.2, wing.maxZ - 20), y, false)
	folder.Parent = parent
end

function MansionWingDecor.build(parent: Instance, wing: Wing, style: BuildingConfig)
	local rng = Random.new(SEED)
	buildLibrary(parent, wing, style, rng)
	buildMusicRoom(parent, wing, style)
	buildAttic(parent, wing)
	buildCellar(parent, wing)
end

return table.freeze(MansionWingDecor)
