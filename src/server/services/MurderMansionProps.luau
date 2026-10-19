--!strict

-- Móveis e esconderijos da Ala do Assassinato (Fase 5E.2), por cômodo da
-- planta (MurderMansionPlan). Posições em relação ao centro do cômodo (rx de
-- oeste para leste, rz de norte para sul; cômodo de 32 x 36). Os móveis
-- ficam junto das paredes e nos cantos, longe das portas (meio das paredes),
-- do miolo livre (onde se nasce) e da escada, para não travar o caminho.
-- Esconderijos: armários abertos com cortina, cercas vivas da Estufa e
-- cortinas, sempre deixando o jogador parcialmente visível.

local MurderMansionPlan = require(script.Parent.Parent.data.MurderMansionPlan)
local MysteryAssets = require(script.Parent.MysteryAssets)

type Room = MurderMansionPlan.Room
type Facing = "N" | "S" | "E" | "W"

local COLORS = {
	wood = Color3.fromRGB(122, 82, 52),
	darkWood = Color3.fromRGB(74, 48, 32),
	lightWood = Color3.fromRGB(176, 132, 88),
	red = Color3.fromRGB(150, 44, 56),
	velvet = Color3.fromRGB(96, 40, 110),
	cream = Color3.fromRGB(236, 224, 200),
	stone = Color3.fromRGB(150, 146, 140),
	black = Color3.fromRGB(32, 28, 32),
	green = Color3.fromRGB(70, 140, 70),
	leaf = Color3.fromRGB(60, 160, 80),
	brick = Color3.fromRGB(150, 74, 56),
	gold = Color3.fromRGB(230, 180, 70),
	felt = Color3.fromRGB(40, 120, 70),
	blue = Color3.fromRGB(70, 110, 170),
	pantry = Color3.fromRGB(150, 110, 70),
}

local FACING: { [Facing]: Vector3 } = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}

local MurderMansionProps = {}

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

type Builder = {
	box: (name: string, rx: number, rz: number, size: Vector3, color: Color3, material: Enum.Material?, lift: number?) -> Part,
	soft: (name: string, rx: number, rz: number, size: Vector3, color: Color3, transparency: number, lift: number?) -> Part,
	rug: (rx: number, rz: number, sx: number, sz: number, color: Color3) -> (),
	closet: (rx: number, rz: number, facing: Facing) -> (),
	plant: (rx: number, rz: number) -> (),
	portrait: (rx: number, rz: number, facing: Facing, color: Color3) -> (),
	model: (name: string, rx: number, rz: number, facing: Facing, scale: number, fallbackSize: Vector3, color: Color3) -> (),
	decor: (name: string, rx: number, rz: number, facing: Facing, scale: number, lift: number) -> (),
}

local function builderFor(parent: Instance, origin: Vector3): Builder
	local builder = {} :: Builder
	builder.box = function(name, rx, rz, size, color, material, lift)
		local position = origin + Vector3.new(rx, size.Y / 2 + (lift or 0), rz)
		return part(parent, name, size, CFrame.new(position), color, material or Enum.Material.Wood)
	end
	-- Pano ou folhagem que dá para atravessar (esconde em parte).
	builder.soft = function(name, rx, rz, size, color, transparency, lift)
		local soft = builder.box(name, rx, rz, size, color, Enum.Material.Fabric, lift)
		soft.CanCollide = false
		soft.CanQuery = false
		soft.Transparency = transparency
		return soft
	end
	builder.rug = function(rx, rz, sx, sz, color)
		local rug = builder.box("Rug", rx, rz, Vector3.new(sx, 0.1, sz), color, Enum.Material.Fabric)
		rug.CanCollide = false
		rug.CanQuery = false
	end
	-- Armário aberto (esconderijo): fundo, laterais e teto, com uma cortina
	-- na frente virada para `facing`.
	builder.closet = function(rx, rz, facing)
		local front = FACING[facing]
		local base = origin + Vector3.new(rx, 0, rz)
		local frame = CFrame.lookAt(base, base + front)
		local width, depth, height = 6, 4.5, 9
		local function piece(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
			return part(parent, name, size, frame * CFrame.new(offset), color, material)
		end
		piece("ClosetBack", Vector3.new(width, height, 0.5), Vector3.new(0, height / 2, depth / 2), COLORS.darkWood, Enum.Material.Wood)
		piece("ClosetSide", Vector3.new(0.5, height, depth), Vector3.new(-width / 2, height / 2, 0), COLORS.darkWood, Enum.Material.Wood)
		piece("ClosetSide", Vector3.new(0.5, height, depth), Vector3.new(width / 2, height / 2, 0), COLORS.darkWood, Enum.Material.Wood)
		piece("ClosetTop", Vector3.new(width, 0.5, depth), Vector3.new(0, height, 0), COLORS.darkWood, Enum.Material.Wood)
		local curtain = piece("ClosetCurtain", Vector3.new(width - 1, height - 1, 0.2), Vector3.new(0, (height - 1) / 2, -depth / 2 + 0.2), COLORS.velvet, Enum.Material.Fabric)
		curtain.CanCollide = false
		curtain.CanQuery = false
		curtain.Transparency = 0.35
	end
	builder.plant = function(rx, rz)
		builder.box("PlantPot", rx, rz, Vector3.new(2, 2, 2), COLORS.brick, Enum.Material.Brick)
		local leaves = builder.box("PlantLeaves", rx, rz, Vector3.new(3, 3, 3), COLORS.leaf, Enum.Material.Grass, 2)
		leaves.Shape = Enum.PartType.Ball
	end
	-- Quadro pendurado na parede (só enfeite).
	builder.portrait = function(rx, rz, facing, color)
		local front = FACING[facing]
		local base = origin + Vector3.new(rx, 6, rz)
		local frame = part(parent, "PortraitFrame", Vector3.new(5, 6, 0.3), CFrame.lookAt(base, base + front), COLORS.gold, Enum.Material.SmoothPlastic)
		frame.CanCollide = false
		local canvas = part(parent, "Portrait", Vector3.new(4, 5, 0.2), CFrame.lookAt(base + front * 0.1, base + front * 2), color, Enum.Material.SmoothPlastic)
		canvas.CanCollide = false
	end
	-- Modelo pronto do Casarão (MysteryAssets) com uma caixa invisível que
	-- bloqueia passagem, tiros e facas; sem o modelo, uma caixa simples.
	builder.model = function(name, rx, rz, facing, scale, fallbackSize, color)
		local model = MysteryAssets.clone(name)
		if model == nil then
			builder.box(name, rx, rz, fallbackSize, color, Enum.Material.SmoothPlastic)
			return
		end
		MysteryAssets.place(model, origin + Vector3.new(rx, 0, rz), FACING[facing], scale, parent)
		local cframe, size = model:GetBoundingBox()
		MysteryAssets.blocker(model, "Block", size, cframe)
	end
	-- Enfeite pronto sem colisão (candelabros sobre a mesa).
	builder.decor = function(name, rx, rz, facing, scale, lift)
		local model = MysteryAssets.clone(name)
		if model ~= nil then
			MysteryAssets.place(model, origin + Vector3.new(rx, lift, rz), FACING[facing], scale, parent)
		end
	end
	return builder
end

-- Móveis de cada cômodo (pelo id da planta).
local FURNISH: { [string]: (b: Builder) -> () } = {
	library = function(b)
		b.box("Bookshelf", -15, -11, Vector3.new(1.5, 10, 8), COLORS.darkWood)
		b.box("Bookshelf", -15, 11, Vector3.new(1.5, 10, 8), COLORS.darkWood)
		b.box("Bookshelf", 15, -11, Vector3.new(1.5, 10, 8), COLORS.darkWood)
		b.box("ReadingTable", 10, 12, Vector3.new(6, 3, 4), COLORS.wood)
		b.box("Armchair", -10, 13, Vector3.new(3, 3, 3), COLORS.red, Enum.Material.Fabric)
		b.closet(11, -14, "S")
		b.rug(0, 0, 12, 14, COLORS.red)
	end,
	dining = function(b)
		b.box("DiningTable", 0, -14, Vector3.new(16, 3, 5), COLORS.wood)
		b.decor("Candelabra", -4.5, -14, "S", 0.6, 3)
		b.decor("Candelabra", 4.5, -14, "S", 0.6, 3)
		for _, x in ipairs({ -6, -2, 2, 6 }) do
			b.box("Chair", x, -10.3, Vector3.new(2, 4, 2), COLORS.darkWood)
		end
		b.box("Cupboard", -14.5, 13, Vector3.new(2, 8, 6), COLORS.darkWood)
		b.box("Cupboard", 14.5, 13, Vector3.new(2, 8, 6), COLORS.darkWood)
		b.plant(-13, -15)
		b.plant(13, -15)
	end,
	kitchen = function(b)
		b.box("Stove", 12, -14.5, Vector3.new(6, 5, 3), COLORS.stone, Enum.Material.Slate)
		b.box("Counter", 14, 10, Vector3.new(3, 4, 10), COLORS.lightWood)
		b.box("KitchenTable", -11, 7, Vector3.new(6, 3, 4), COLORS.wood)
		b.box("Barrel", -13.5, -14, Vector3.new(3, 4, 3), COLORS.wood, Enum.Material.WoodPlanks)
		b.box("Barrel", -9.5, -14.5, Vector3.new(3, 4, 3), COLORS.wood, Enum.Material.WoodPlanks)
		b.closet(-12, 15.5, "N")
	end,
	ballroom = function(b)
		b.box("Pillar", 8, -10, Vector3.new(2, 14, 2), COLORS.stone, Enum.Material.Marble)
		b.box("Pillar", 8, 10, Vector3.new(2, 14, 2), COLORS.stone, Enum.Material.Marble)
		b.box("Pillar", -6, -10, Vector3.new(2, 14, 2), COLORS.stone, Enum.Material.Marble)
		b.model("GrandPiano", 10.5, -14, "W", 0.4, Vector3.new(7, 4, 4), COLORS.black)
		b.soft("Curtain", 10, 17.3, Vector3.new(8, 12, 0.4), COLORS.red, 0.3)
		b.box("FoldingScreen", -10, -14, Vector3.new(6, 7, 0.5), COLORS.cream, Enum.Material.Fabric)
		b.rug(1, 0, 16, 18, COLORS.velvet)
	end,
	hall = function(b)
		b.model("GrandfatherClock", -13.5, 15.6, "N", 1.2, Vector3.new(3, 10, 2), COLORS.darkWood)
		b.box("Bench", -11, -15, Vector3.new(6, 2, 2), COLORS.wood)
		b.box("Bench", 11, -15, Vector3.new(6, 2, 2), COLORS.wood)
		b.closet(12, 15, "N")
		b.plant(-14, -9)
		b.plant(14, -9)
		b.rug(0, 4, 8, 22, COLORS.red)
	end,
	lounge = function(b)
		b.box("Fireplace", -15, -11, Vector3.new(2, 6, 6), COLORS.brick, Enum.Material.Brick)
		b.box("Sofa", -7, -15, Vector3.new(8, 3, 3), COLORS.blue, Enum.Material.Fabric)
		b.box("CoffeeTable", 6, -13, Vector3.new(4, 2, 3), COLORS.wood)
		b.box("Armchair", -12, 12, Vector3.new(3, 3, 3), COLORS.blue, Enum.Material.Fabric)
		b.closet(-6, 15.5, "N")
		b.rug(-2, -4, 12, 10, COLORS.cream)
	end,
	baronBedroom = function(b)
		b.box("Bed", -11, -12, Vector3.new(8, 3, 10), COLORS.red, Enum.Material.Fabric)
		b.box("Pillow", -11, -15.5, Vector3.new(6, 1, 2), COLORS.cream, Enum.Material.Fabric, 3)
		b.closet(12, -15, "S")
		b.box("Desk", -12, 14, Vector3.new(6, 3, 3), COLORS.darkWood)
		b.box("Chest", 10, 14.5, Vector3.new(4, 3, 3), COLORS.wood)
		b.portrait(-15.3, 8, "E", COLORS.velvet)
	end,
	portraits = function(b)
		b.portrait(-10, -17.3, "S", COLORS.blue)
		b.portrait(0, -17.3, "S", COLORS.red)
		b.portrait(10, -17.3, "S", COLORS.green)
		b.box("Bench", 0, -14, Vector3.new(6, 2, 2), COLORS.wood)
		b.box("Pedestal", -12, 12, Vector3.new(2, 4, 2), COLORS.stone, Enum.Material.Marble)
		b.box("Pedestal", 12, 12, Vector3.new(2, 4, 2), COLORS.stone, Enum.Material.Marble)
		b.box("FoldingScreen", -9, 9, Vector3.new(6, 7, 0.5), COLORS.cream, Enum.Material.Fabric)
		b.closet(-13.5, -9, "E")
	end,
	guestBedroom = function(b)
		b.box("Bed", 11, -12, Vector3.new(7, 3, 9), COLORS.blue, Enum.Material.Fabric)
		b.box("Bed", 11, 12, Vector3.new(7, 3, 9), COLORS.green, Enum.Material.Fabric)
		b.closet(-12, -15, "S")
		b.box("Dresser", -14, 12, Vector3.new(3, 4, 6), COLORS.lightWood)
		b.plant(-8, 15)
	end,
	music = function(b)
		b.model("GrandPiano", 10.5, -14, "W", 0.4, Vector3.new(7, 4, 4), COLORS.black)
		b.box("Harp", 13, 12, Vector3.new(2, 6, 2), COLORS.gold, Enum.Material.SmoothPlastic)
		b.box("Chair", 6, 12, Vector3.new(2, 4, 2), COLORS.darkWood)
		b.box("Chair", 9, 9, Vector3.new(2, 4, 2), COLORS.darkWood)
		b.soft("Curtain", 8, 17.3, Vector3.new(8, 12, 0.4), COLORS.velvet, 0.3)
		b.closet(-6.5, 15, "N")
	end,
	games = function(b)
		b.box("PoolTable", 0, 12, Vector3.new(10, 3, 6), COLORS.felt, Enum.Material.Fabric)
		b.box("CardTable", -11, -12, Vector3.new(5, 3, 5), COLORS.wood)
		b.box("ArcadeCabinet", 13, -14, Vector3.new(3, 7, 3), COLORS.blue, Enum.Material.SmoothPlastic)
		b.box("ArcadeCabinet", 13, -9, Vector3.new(3, 7, 3), COLORS.red, Enum.Material.SmoothPlastic)
		b.closet(-12, 15, "N")
	end,
	greenhouse = function(b)
		b.box("PlantBed", -10, -13, Vector3.new(8, 2, 4), COLORS.green, Enum.Material.Grass)
		b.box("PlantBed", -10, 13, Vector3.new(8, 2, 4), COLORS.green, Enum.Material.Grass)
		-- Cercas vivas: dá para entrar e se esconder entre as folhas.
		b.soft("Hedge", 5, 13, Vector3.new(6, 7, 3), COLORS.leaf, 0.15)
		b.soft("Hedge", -14, 8, Vector3.new(3, 7, 6), COLORS.leaf, 0.15)
		b.plant(-14, -8)
		b.plant(-14, -15)
	end,
}

function MurderMansionProps.furnish(parent: Instance, room: Room, roomCenter: Vector3)
	local furnish = FURNISH[room.id]
	if furnish ~= nil then
		furnish(builderFor(parent, roomCenter))
	end
end

-- Molduras de estante (Biblioteca) e de despensa (Cozinha) em volta das
-- aberturas da passagem secreta, do lado de dentro dos cômodos. O corredor
-- fica livre: é rota de fuga.
function MurderMansionProps.passageFrames(parent: Instance, passage: MurderMansionPlan.Passage, toWorld: (number, number, number) -> Vector3)
	for index, x in ipairs({ passage.fromX, passage.toX }) do
		local color = if index == 1 then COLORS.darkWood else COLORS.pantry
		local side = passage.gapWidth / 2 + 1.5
		for _, offset in ipairs({ -side, side }) do
			local base = toWorld(x + offset, passage.wallZ + 1, 0)
			part(parent, "SecretShelf", Vector3.new(3, 10, 1.5), CFrame.new(base + Vector3.new(0, 5, 0)), color, Enum.Material.Wood)
		end
		local top = toWorld(x, passage.wallZ + 1, 0)
		part(parent, "SecretShelfTop", Vector3.new(passage.gapWidth, 2, 1.5), CFrame.new(top + Vector3.new(0, 9, 0)), color, Enum.Material.Wood)
	end
end

return table.freeze(MurderMansionProps)
