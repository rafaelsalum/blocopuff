--!strict

-- Coberturas da Ala do Assassinato: móveis sólidos e altos para se
-- esconder atrás e desviar de tiros e facas (bloqueiam passagem, raycast e
-- projéteis). Estantes com livros de verdade (MurderAssets, Fase 5I), baús e
-- móveis cobertos por lençol do Casarão (MansionWingDecor), mais biombos,
-- caixotes e floreiras.
--
-- Cada cobertura ocupa uma das quatro vagas do cômodo (32 x 36), uma por
-- quadrante, fora das rotas dos bots (MurderMansionPlan): longe do miolo
-- livre (|rx| <= 7, |rz| <= 9), das linhas do centro até as portas (rx = 0 e
-- rz = 0), das escadas e das aproximações delas. A planta de cada cômodo
-- abaixo já desvia dos móveis de MurderMansionProps.

local MurderMansionPlan = require(script.Parent.Parent.data.MurderMansionPlan)
local MansionWingDecor = require(script.Parent.MansionWingDecor)
local BuildingDecor = require(script.Parent.BuildingDecor)
local MurderAssets = require(script.Parent.MurderAssets)
local MysteryAssets = require(script.Parent.MysteryAssets)

type Room = MurderMansionPlan.Room
type Kind = "shelf" | "screen" | "covered" | "crates" | "planter"
type Slot = "NW" | "NE" | "SW" | "SE"
type Entry = { slot: Slot, kind: Kind }

local SEED = 5157
-- Centro das vagas em relação ao centro do cômodo.
local SLOT_X = 11
local SLOT_Z = 5.5
-- Largura (em x) e altura das coberturas: escondem um personagem de pé.
local WIDTH = 5
local HEIGHT = 6.5
local SHELF_HEIGHT = 7.5
-- Estante com livros de verdade (MurderAssets "Bookshelf", 9.6 x 13.4 x
-- 3.9): neste tamanho fica com 5.3 de largura e 7.4 de altura.
local SHELF_SCALE = 0.55
-- Moeda atrás de cada cobertura (do lado da parede): pegar exige sair do
-- miolo do cômodo.
local COIN_BEHIND = 3

local COLORS = {
	frame = Color3.fromRGB(74, 48, 32),
	screen = Color3.fromRGB(226, 208, 176),
	crate = Color3.fromRGB(150, 108, 66),
	band = Color3.fromRGB(60, 60, 64),
	pot = Color3.fromRGB(150, 74, 56),
	hedge = Color3.fromRGB(56, 128, 64),
}

local SLOTS: { [Slot]: Vector2 } = {
	NW = Vector2.new(-SLOT_X, -SLOT_Z),
	NE = Vector2.new(SLOT_X, -SLOT_Z),
	SW = Vector2.new(-SLOT_X, SLOT_Z),
	SE = Vector2.new(SLOT_X, SLOT_Z),
}

-- Vagas e tipo de cobertura por cômodo (pelo id da planta). Sem as vagas do
-- lado da escada (Salão de Baile, Sala de Estar, Sala de Música e Estufa)
-- nem as que batem em móveis (Cozinha, Corredor dos Retratos e Estufa).
local LAYOUT: { [string]: { Entry } } = {
	library = { { slot = "NW", kind = "shelf" }, { slot = "SE", kind = "shelf" }, { slot = "SW", kind = "covered" } },
	dining = { { slot = "NW", kind = "screen" }, { slot = "NE", kind = "screen" }, { slot = "SE", kind = "covered" } },
	kitchen = { { slot = "NW", kind = "crates" }, { slot = "NE", kind = "crates" } },
	ballroom = { { slot = "NE", kind = "screen" }, { slot = "SE", kind = "covered" } },
	hall = { { slot = "NW", kind = "planter" }, { slot = "NE", kind = "planter" }, { slot = "SW", kind = "screen" } },
	lounge = { { slot = "NW", kind = "covered" }, { slot = "SW", kind = "screen" } },
	baronBedroom = { { slot = "NE", kind = "screen" }, { slot = "SW", kind = "shelf" }, { slot = "SE", kind = "covered" } },
	portraits = { { slot = "NE", kind = "screen" }, { slot = "SE", kind = "screen" } },
	guestBedroom = { { slot = "NW", kind = "covered" }, { slot = "SW", kind = "screen" }, { slot = "NE", kind = "shelf" } },
	music = { { slot = "NE", kind = "shelf" }, { slot = "SE", kind = "screen" } },
	games = { { slot = "NW", kind = "covered" }, { slot = "SW", kind = "shelf" }, { slot = "SE", kind = "screen" } },
	greenhouse = { { slot = "NW", kind = "planter" } },
}

local MurderMansionCover = {}

local function solid(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return BuildingDecor.createPart(parent, name, size, cframe, color, { material = material, collide = true })
end

-- Biombo de três folhas em zigue-zague, com moldura de madeira.
local function screen(parent: Instance, base: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "CoverScreen"
	local right = facing:Cross(Vector3.yAxis)
	local panelWidth = WIDTH / 3
	for index = -1, 1 do
		local tilt = math.rad(18 * (if index == 0 then 1 else -1))
		local center = base + right * (index * panelWidth * 0.95) + Vector3.new(0, HEIGHT / 2, 0)
		local frame = CFrame.fromMatrix(center, right, Vector3.yAxis) * CFrame.Angles(0, tilt, 0)
		solid(model, "ScreenPanel", Vector3.new(panelWidth, HEIGHT - 0.6, 0.3), frame, COLORS.screen, Enum.Material.Fabric)
		solid(model, "ScreenFrame", Vector3.new(panelWidth + 0.2, 0.3, 0.4), frame * CFrame.new(0, HEIGHT / 2 - 0.15, 0), COLORS.frame, Enum.Material.Wood)
		solid(model, "ScreenFrame", Vector3.new(panelWidth + 0.2, 0.3, 0.4), frame * CFrame.new(0, -HEIGHT / 2 + 0.15, 0), COLORS.frame, Enum.Material.Wood)
	end
	model.Parent = parent
end

-- Biombo solto num cômodo (MurderMansionProps), fora das vagas de cobertura.
function MurderMansionCover.foldingScreen(parent: Instance, base: Vector3, facing: Vector3)
	screen(parent, base, facing)
end

-- Pilha de caixotes com um baú do Casarão por cima.
local function crates(parent: Instance, base: Vector3, facing: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "CoverCrates"
	local right = facing:Cross(Vector3.yAxis)
	local size = 2.4
	for _, side in ipairs({ -1, 1 }) do
		for level = 0, 1 do
			local center = base + right * (side * (size / 2 + 0.05)) + Vector3.new(0, size / 2 + level * size, 0)
			local frame = CFrame.fromMatrix(center, right, Vector3.yAxis) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0)
			solid(model, "Crate", Vector3.one * size, frame, COLORS.crate, Enum.Material.WoodPlanks)
			BuildingDecor.createPart(model, "CrateBand", Vector3.new(size + 0.1, 0.3, size + 0.1), frame, COLORS.band, { material = Enum.Material.Metal })
		end
	end
	MansionWingDecor.chest(model, base + Vector3.new(0, size * 2, 0), math.atan2(facing.X, facing.Z))
	model.Parent = parent
end

-- Floreira de tijolos com uma cerca viva sólida.
local function planter(parent: Instance, base: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "CoverPlanter"
	local right = facing:Cross(Vector3.yAxis)
	local frame = CFrame.fromMatrix(base, right, Vector3.yAxis)
	solid(model, "PlanterPot", Vector3.new(WIDTH, 2.5, 2), frame * CFrame.new(0, 1.25, 0), COLORS.pot, Enum.Material.Brick)
	solid(model, "PlanterHedge", Vector3.new(WIDTH - 0.4, HEIGHT - 2.5, 1.8), frame * CFrame.new(0, 2.5 + (HEIGHT - 2.5) / 2, 0), COLORS.hedge, Enum.Material.LeafyGrass)
	model.Parent = parent
end

local function build(parent: Instance, kind: Kind, base: Vector3, facing: Vector3, rng: Random)
	if kind == "shelf" then
		local shelf = MurderAssets.clone("Bookshelf")
		if shelf ~= nil then
			shelf.Name = "CoverBookshelf"
			MysteryAssets.place(shelf, base, facing, SHELF_SCALE, parent)
			local cframe, size = shelf:GetBoundingBox()
			MysteryAssets.blocker(shelf, "Block", size, cframe)
		else
			-- A estante simples tem 2 de fundo a partir da base: centraliza na vaga.
			MansionWingDecor.bookshelf(parent, "CoverBookshelf", base - facing, facing, WIDTH, SHELF_HEIGHT, rng)
		end
	elseif kind == "screen" then
		screen(parent, base, facing)
	elseif kind == "covered" then
		MansionWingDecor.coveredFurniture(parent, base, Vector3.new(WIDTH, HEIGHT, 2))
	elseif kind == "crates" then
		crates(parent, base, facing, rng)
	else
		planter(parent, base, facing)
	end
end

-- Monta as coberturas do cômodo e devolve os pontos do chão atrás delas.
function MurderMansionCover.place(parent: Instance, room: Room, roomCenter: Vector3): { Vector3 }
	local spots: { Vector3 } = {}
	local entries = LAYOUT[room.id]
	if entries == nil then
		return spots
	end
	-- Semente por cômodo: os mesmos livros e caixotes em todo servidor.
	local rng = Random.new(SEED + #room.id * 31 + room.minX + room.minZ)
	local folder = Instance.new("Model")
	folder.Name = `Cover_{room.id}`
	for _, entry in ipairs(entries) do
		local slot = SLOTS[entry.slot]
		local base = roomCenter + Vector3.new(slot.X, 0, slot.Y)
		-- Frente virada para o meio do cômodo.
		local facing = Vector3.new(0, 0, -math.sign(slot.Y))
		build(folder, entry.kind, base, facing, rng)
		table.insert(spots, base - facing * COIN_BEHIND)
	end
	folder.Parent = parent
	return spots
end

return table.freeze(MurderMansionCover)
