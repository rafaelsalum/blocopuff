--!strict

-- Móveis e esconderijos da Ala do Assassinato (Fase 5E.2), por cômodo da
-- planta (MurderMansionPlan). Posições em relação ao centro do cômodo (rx de
-- oeste para leste, rz de norte para sul; cômodo de 32 x 36). Os móveis
-- ficam junto das paredes e nos cantos, longe das portas (meio das paredes),
-- do miolo livre (onde se nasce) e da escada, para não travar o caminho.
-- Esconderijos: guarda-roupas abertos com cortina, cercas vivas da Estufa e
-- cortinas, sempre deixando o jogador parcialmente visível.
--
-- Fase 5I: os móveis são modelos de verdade no estilo do castelo
-- (MurderAssets: estantes com livros, camas de dossel, lareira de pedra,
-- sofá chesterfield, armaduras, caldeirão...) e peças feitas por código
-- (MurderMansionPieces: guarda-roupa, harpa e xadrez de bruxo). Cada modelo
-- ganha uma caixa invisível que bloqueia passagem, tiros e facas; sem o
-- arquivo de modelos, volta a caixa simples.

local MurderMansionPlan = require(script.Parent.Parent.data.MurderMansionPlan)
local MysteryAssets = require(script.Parent.MysteryAssets)
local MurderAssets = require(script.Parent.MurderAssets)
local MurderMansionPieces = require(script.Parent.MurderMansionPieces)
local MurderMansionCover = require(script.Parent.MurderMansionCover)

type Room = MurderMansionPlan.Room
type Facing = "N" | "S" | "E" | "W"
-- Peças do modelo a repintar (nome da peça → cor), como as cobertas.
type Tints = { [string]: Color3 }

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
	blue = Color3.fromRGB(70, 110, 170),
	pantry = Color3.fromRGB(150, 110, 70),
	emerald = Color3.fromRGB(34, 92, 62),
	sapphire = Color3.fromRGB(36, 58, 116),
}

-- Altura da tampa da mesa comprida (MurderAssets "LongTable", tamanho 1).
local LONG_TABLE_TOP = 3
-- Harpa: caixa que bloqueia passagem (a harpa em si só enfeita).
local HARP_BLOCK = Vector3.new(1.4, 6, 3.4)
-- Vaso das plantas (MurderAssets "Vase" tem 2 x 1.5 x 2).
local PLANT_VASE_SCALE = 1.3

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
	asset: (name: string, rx: number, rz: number, facing: Facing, scale: number, fallbackSize: Vector3, color: Color3, tints: Tints?) -> (),
	harp: (rx: number, rz: number, facing: Facing) -> (),
	chessTable: (rx: number, rz: number, facing: Facing) -> (),
	screen: (rx: number, rz: number, facing: Facing) -> (),
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
	-- Guarda-roupa aberto (esconderijo, MurderMansionPieces): fundo,
	-- laterais e tampo sólidos, portas abertas e cortina na frente virada
	-- para `facing`.
	builder.closet = function(rx, rz, facing)
		local base = origin + Vector3.new(rx, 0, rz)
		MurderMansionPieces.wardrobe(parent, CFrame.lookAt(base, base + FACING[facing]))
	end
	-- Vaso de cerâmica (MurderAssets "Vase") com uma moita redonda; sem o
	-- modelo, um vaso de tijolo.
	builder.plant = function(rx, rz)
		local vase = MurderAssets.clone("Vase")
		if vase ~= nil then
			MysteryAssets.place(vase, origin + Vector3.new(rx, 0, rz), FACING.S, PLANT_VASE_SCALE, parent)
			MysteryAssets.blocker(vase, "Block", Vector3.new(2, 2, 2), CFrame.new(origin + Vector3.new(rx, 1, rz)))
		else
			builder.box("PlantPot", rx, rz, Vector3.new(2, 2, 2), COLORS.brick, Enum.Material.Brick)
		end
		local leaves = builder.box("PlantLeaves", rx, rz, Vector3.new(3, 3, 3), COLORS.leaf, Enum.Material.Grass, 1.8)
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
	-- Modelo da Creator Store (MurderAssets) com a frente para `facing`, no
	-- tamanho `scale`, com uma caixa invisível que bloqueia; `tints` repinta
	-- peças pelo nome. Sem o modelo, uma caixa simples de `fallbackSize`.
	builder.asset = function(name, rx, rz, facing, scale, fallbackSize, color, tints)
		local model = MurderAssets.clone(name)
		if model == nil then
			builder.box(name, rx, rz, fallbackSize, color)
			return
		end
		for partName, tint in pairs(tints or {}) do
			MurderAssets.tint(model, partName, tint)
		end
		MysteryAssets.place(model, origin + Vector3.new(rx, 0, rz), FACING[facing], scale, parent)
		local cframe, size = model:GetBoundingBox()
		MysteryAssets.blocker(model, "Block", size, cframe)
	end
	builder.harp = function(rx, rz, facing)
		local base = origin + Vector3.new(rx, 0, rz)
		MurderMansionPieces.harp(parent, CFrame.lookAt(base, base + FACING[facing]))
		MysteryAssets.blocker(parent, "HarpBlock", HARP_BLOCK, CFrame.lookAt(base, base + FACING[facing]) * CFrame.new(0, HARP_BLOCK.Y / 2, 0))
	end
	-- Mesa comprida com o tabuleiro do xadrez de bruxo em cima.
	builder.chessTable = function(rx, rz, facing)
		builder.asset("LongTable", rx, rz, facing, 1, Vector3.new(9, LONG_TABLE_TOP, 4), COLORS.wood)
		local top = origin + Vector3.new(rx, LONG_TABLE_TOP, rz)
		MurderMansionPieces.chessBoard(parent, CFrame.lookAt(top, top + FACING[facing]))
	end
	-- Biombo de três folhas (o mesmo das coberturas).
	builder.screen = function(rx, rz, facing)
		MurderMansionCover.foldingScreen(parent, origin + Vector3.new(rx, 0, rz), FACING[facing])
	end
	return builder
end

-- Móveis de cada cômodo (pelo id da planta).
local FURNISH: { [string]: (b: Builder) -> () } = {
	library = function(b)
		b.asset("Bookshelf", -14, -11, "E", 0.75, Vector3.new(1.5, 10, 8), COLORS.darkWood)
		b.asset("Bookshelf", -14, 11, "E", 0.75, Vector3.new(1.5, 10, 8), COLORS.darkWood)
		b.asset("Bookshelf", 14, -11, "W", 0.75, Vector3.new(1.5, 10, 8), COLORS.darkWood)
		b.asset("RoundTable", 10, 12, "N", 0.8, Vector3.new(6, 3, 4), COLORS.wood)
		b.asset("GothicChair", -10, 13, "N", 1, Vector3.new(3, 3, 3), COLORS.red)
		b.closet(11, -14, "S")
		b.rug(0, 0, 12, 14, COLORS.red)
	end,
	dining = function(b)
		b.asset("LongTable", -4.5, -14, "S", 1, Vector3.new(8, 3, 5), COLORS.wood)
		b.asset("LongTable", 4.5, -14, "S", 1, Vector3.new(8, 3, 5), COLORS.wood)
		b.decor("Candelabra", -4.5, -14, "S", 0.6, LONG_TABLE_TOP)
		b.decor("Candelabra", 4.5, -14, "S", 0.6, LONG_TABLE_TOP)
		for _, x in ipairs({ -6, -2, 2, 6 }) do
			b.asset("DiningChair", x, -10.5, "N", 1, Vector3.new(2, 4, 2), COLORS.darkWood)
		end
		b.asset("TallBookshelf", -14.7, 13, "E", 0.8, Vector3.new(2, 8, 6), COLORS.darkWood)
		b.asset("TallBookshelf", 14.7, 13, "W", 0.8, Vector3.new(2, 8, 6), COLORS.darkWood)
		b.plant(-13, -15)
		b.plant(13, -15)
	end,
	kitchen = function(b)
		-- Lareira de pedra com o caldeirão na frente, no lugar do fogão.
		b.asset("StoneFireplace", 12, -16.2, "S", 0.85, Vector3.new(6, 5, 3), COLORS.stone)
		b.asset("Cauldron", 12, -11.8, "S", 0.6, Vector3.new(4, 3, 4), COLORS.black)
		b.asset("Counter", 14.1, 10, "W", 0.9, Vector3.new(3, 4, 10), COLORS.lightWood)
		b.asset("LongTable", -11, 7, "S", 0.8, Vector3.new(6, 3, 4), COLORS.wood)
		b.asset("BarrelRack", -13, -14.5, "S", 0.85, Vector3.new(3, 4, 3), COLORS.wood)
		b.asset("BarrelRack", -8.5, -14.5, "S", 0.85, Vector3.new(3, 4, 3), COLORS.wood)
		b.closet(-12, 15.5, "N")
	end,
	ballroom = function(b)
		b.box("Pillar", 8, -10, Vector3.new(2, 14, 2), COLORS.stone, Enum.Material.Marble)
		b.box("Pillar", 8, 10, Vector3.new(2, 14, 2), COLORS.stone, Enum.Material.Marble)
		b.box("Pillar", -6, -10, Vector3.new(2, 14, 2), COLORS.stone, Enum.Material.Marble)
		b.model("GrandPiano", 10.5, -14, "W", 0.4, Vector3.new(7, 4, 4), COLORS.black)
		b.soft("Curtain", 10, 17.3, Vector3.new(8, 12, 0.4), COLORS.red, 0.3)
		b.asset("KnightArmor", -8.5, -15.3, "S", 0.55, Vector3.new(4, 7, 4), COLORS.stone)
		b.rug(1, 0, 16, 18, COLORS.velvet)
	end,
	hall = function(b)
		b.model("GrandfatherClock", -13.5, 15.6, "N", 1.2, Vector3.new(3, 10, 2), COLORS.darkWood)
		b.asset("Bench", -11, -16, "S", 1, Vector3.new(6, 2, 2), COLORS.wood)
		b.asset("Bench", 11, -16, "S", 1, Vector3.new(6, 2, 2), COLORS.wood)
		b.closet(12, 15, "N")
		b.plant(-14, -9)
		b.plant(14, -9)
		b.rug(0, 4, 8, 22, COLORS.red)
	end,
	lounge = function(b)
		b.asset("StoneFireplace", -14.2, -11, "E", 0.8, Vector3.new(2, 6, 6), COLORS.brick)
		b.asset("ChesterfieldSofa", -6, -15, "S", 0.75, Vector3.new(8, 3, 3), COLORS.blue)
		b.asset("SideTable", -6, -10.5, "S", 0.9, Vector3.new(4, 2, 3), COLORS.wood)
		b.asset("GothicChair", -12, 12, "N", 1, Vector3.new(3, 3, 3), COLORS.blue)
		b.closet(-8.5, 15.5, "N")
		b.rug(-2, -4, 12, 10, COLORS.cream)
	end,
	baronBedroom = function(b)
		b.asset("FourPosterBed", -11, -11.5, "S", 0.7, Vector3.new(8, 3, 10), COLORS.red)
		b.closet(12, -15, "S")
		b.asset("LongTable", -11.8, 14.5, "N", 0.8, Vector3.new(6, 3, 3), COLORS.darkWood)
		b.asset("Chest", 10, 15, "N", 0.8, Vector3.new(4, 3, 3), COLORS.wood)
		b.portrait(-15.3, 8, "E", COLORS.velvet)
	end,
	portraits = function(b)
		b.portrait(-10, -17.3, "S", COLORS.blue)
		b.portrait(0, -17.3, "S", COLORS.red)
		b.portrait(10, -17.3, "S", COLORS.green)
		b.asset("Bench", 0, -14, "S", 1, Vector3.new(6, 2, 2), COLORS.wood)
		b.asset("KnightArmor", -12, 13, "N", 0.55, Vector3.new(2, 4, 2), COLORS.stone)
		b.asset("KnightArmor", 12, 13, "N", 0.55, Vector3.new(2, 4, 2), COLORS.stone)
		b.screen(-9, 9, "N")
		b.closet(-13.5, -9, "E")
	end,
	guestBedroom = function(b)
		b.asset("FourPosterBed", 10.4, -12, "W", 0.6, Vector3.new(7, 3, 9), COLORS.blue, { Blanket = COLORS.sapphire, Canopy = COLORS.sapphire })
		b.asset("FourPosterBed", 10.4, 12, "W", 0.6, Vector3.new(7, 3, 9), COLORS.green, { Blanket = COLORS.emerald, Canopy = COLORS.emerald })
		b.closet(-12, -15, "S")
		b.asset("Chest", -14, 12, "E", 0.9, Vector3.new(3, 4, 6), COLORS.lightWood)
		b.plant(-8, 15)
	end,
	music = function(b)
		b.model("GrandPiano", 10.5, -14, "W", 0.4, Vector3.new(7, 4, 4), COLORS.black)
		b.harp(13, 12, "W")
		b.asset("DiningChair", 6, 12, "E", 1, Vector3.new(2, 4, 2), COLORS.darkWood)
		b.asset("DiningChair", 9, 8.5, "S", 1, Vector3.new(2, 4, 2), COLORS.darkWood)
		b.soft("Curtain", 8, 17.3, Vector3.new(8, 12, 0.4), COLORS.velvet, 0.3)
		b.closet(-6.5, 15, "N")
	end,
	games = function(b)
		-- Xadrez de bruxo no lugar da mesa de bilhar, com uma cadeira gótica
		-- em cada ponta; armadura e estante no lugar dos fliperamas.
		b.chessTable(0, 12, "S")
		b.asset("GothicChair", -6.3, 12, "E", 1, Vector3.new(3, 3, 3), COLORS.red)
		b.asset("GothicChair", 6.3, 12, "W", 1, Vector3.new(3, 3, 3), COLORS.red)
		b.asset("RoundTable", -11, -12, "S", 0.8, Vector3.new(5, 3, 5), COLORS.wood)
		b.asset("KnightArmor", 13, -14.5, "W", 0.55, Vector3.new(3, 7, 3), COLORS.stone)
		b.asset("TallBookshelf", 14.7, -8, "W", 0.8, Vector3.new(3, 7, 3), COLORS.darkWood)
		b.closet(-12, 15, "N")
	end,
	greenhouse = function(b)
		b.box("PlantBed", -10, -13, Vector3.new(8, 2, 4), COLORS.green, Enum.Material.Grass)
		b.box("PlantBed", -10, 13, Vector3.new(8, 2, 4), COLORS.green, Enum.Material.Grass)
		-- Cercas vivas: dá para entrar e se esconder entre as folhas.
		b.soft("Hedge", 5, 13, Vector3.new(6, 7, 3), COLORS.leaf, 0.15)
		b.soft("Hedge", -14, 8, Vector3.new(3, 7, 6), COLORS.leaf, 0.15)
		b.asset("Cauldron", 6, -14.5, "S", 0.55, Vector3.new(3, 3, 3), COLORS.black)
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

-- Molduras de estante em volta das aberturas das passagens secretas, do
-- lado de dentro dos cômodos (de despensa na Cozinha). O corredor fica
-- livre: é rota de fuga.
function MurderMansionProps.passageFrames(parent: Instance, passage: MurderMansionPlan.Passage, toWorld: (number, number, number) -> Vector3)
	local inward = MurderMansionPlan.inward(passage)
	local frameZ = passage.wallZ + inward
	for _, entry in ipairs({ { passage.fromX, passage.fromRoom }, { passage.toX, passage.toRoom } }) do
		local x, roomId = entry[1], entry[2]
		local color = if roomId == "kitchen" then COLORS.pantry else COLORS.darkWood
		local side = passage.gapWidth / 2 + 1.5
		for _, offset in ipairs({ -side, side }) do
			local base = toWorld(x + offset, frameZ, passage.level)
			part(parent, "SecretShelf", Vector3.new(3, 10, 1.5), CFrame.new(base + Vector3.new(0, 5, 0)), color, Enum.Material.Wood)
		end
		local top = toWorld(x, frameZ, passage.level)
		part(parent, "SecretShelfTop", Vector3.new(passage.gapWidth, 2, 1.5), CFrame.new(top + Vector3.new(0, 9, 0)), color, Enum.Material.Wood)
	end
end

return table.freeze(MurderMansionProps)
