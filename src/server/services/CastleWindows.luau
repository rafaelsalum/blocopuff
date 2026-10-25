--!strict

-- Janelas góticas de verdade nas paredes de fora do castelo (Fase 5H.2):
-- cada janela escolhida pelo CastleFacade é recortada (CSG) na parede, no
-- papel de parede, no lambri e no revestimento de pedra, com vidro claro no
-- vão, moldura de pedra por fora e de madeira por dentro. Dá para olhar
-- para fora de dentro do Casarão e para dentro de fora.
--
-- Só abre onde é seguro: a parede tem espessura normal e, por dentro, na
-- frente da janela, só tem acabamento de parede (nada de quadro, placa,
-- estante, porta ou móvel). Roda em segundo plano (GeometryService).

local CollectionService = game:GetService("CollectionService")
local GeometryService = game:GetService("GeometryService")
local Players = game:GetService("Players")

local TowerKit = require(script.Parent.TowerKit)

-- Peças que podem ser recortadas: paredes e acabamentos.
local CUTTABLE = { "Wall", "Wallpaper", "Wainscot", "Baseboard", "ChairRail", "Crown", "FloorBand", "Lintel", "Span", "Above", "Below", "CastleStone" }
-- Mesmo com uma palavra acima, estas ficam inteiras.
local KEEP = { "Door", "Painting", "Plaque", "Sconce", "Window", "Shelf", "Glass", "Mullion", "Board", "Frame" }
-- Distância de onde o raio de dentro sai e espessura máxima da parede.
local PROBE = 9
local MAX_THICKNESS = 5
-- Folga do recorte para fora (passa o revestimento) e para dentro (passa o
-- rodapé, o lambri e a moldura que saltam do papel de parede).
local CUT_OUT = 0.9
local CUT_IN = 1
local OUTDOORS_NAME = "Outdoors"
-- Espaço livre exigido na frente da janela, por dentro.
local ROOM_CLEARANCE = 2

local GLASS = Color3.fromRGB(196, 214, 236)
local GLASS_TRANSPARENCY = 0.6
local STONE_TRIM = Color3.fromRGB(176, 172, 162)
local WOOD = Color3.fromRGB(92, 60, 38)
local LEAD = Color3.fromRGB(40, 38, 40)

export type Spot = { frame: CFrame, size: Vector2 }

type Opening = { spot: Spot, thickness: number }

local CastleWindows = {}

local function hasWord(name: string, words: { string }): boolean
	for _, word in ipairs(words) do
		if string.find(name, word, 1, true) ~= nil then
			return true
		end
	end
	return false
end

-- Peça com tag ou atributo é de algum serviço (passagem secreta, trava,
-- armadilha) e pode estar guardada por ele: essa não é trocada.
local function cuttable(part: BasePart): boolean
	return hasWord(part.Name, CUTTABLE)
		and not hasWord(part.Name, KEEP)
		and #CollectionService:GetTags(part) == 0
		and next(part:GetAttributes()) == nil
end

-- Vão retangular e o losango que faz a ponta do arco, com `depth` de
-- profundidade a partir de `outside` (para fora) da face de fora.
local function holeShapes(spot: Spot, outside: number, depth: number): { BasePart }
	local size = spot.size
	local middle = depth / 2 - outside
	local rect = Instance.new("Part")
	rect.Size = Vector3.new(size.X, size.Y, depth)
	rect.CFrame = spot.frame * CFrame.new(0, 0, middle)
	local side = size.X / math.sqrt(2)
	local arch = Instance.new("Part")
	arch.Size = Vector3.new(side, side, depth)
	arch.CFrame = spot.frame * CFrame.new(0, size.Y / 2, middle) * CFrame.Angles(0, 0, math.rad(45))
	return { rect, arch }
end

-- Espessura da parede (da face de fora até o acabamento de dentro), ou nil
-- se a janela não pode abrir aqui.
local function measure(spot: Spot, targets: RaycastParams, overlap: OverlapParams): number?
	local inward = -spot.frame.LookVector
	local start = spot.frame.Position + inward * PROBE
	local hit = workspace:Raycast(start, -inward * PROBE, targets)
	if hit == nil then
		return nil
	end
	local thickness = PROBE - hit.Distance
	if thickness <= 0 or thickness > MAX_THICKNESS then
		return nil
	end
	-- O que o recorte vai atravessar tem que ser parede ou acabamento.
	for _, shape in ipairs(holeShapes(spot, CUT_OUT, thickness + CUT_OUT + CUT_IN)) do
		for _, part in ipairs(workspace:GetPartBoundsInBox(shape.CFrame, shape.Size, overlap)) do
			if not cuttable(part) then
				return nil
			end
		end
	end
	-- Na frente da janela, por dentro, só pode ter acabamento de parede.
	local room = spot.frame * CFrame.new(0, 0, thickness + CUT_IN + ROOM_CLEARANCE / 2)
	for _, part in ipairs(workspace:GetPartBoundsInBox(room, Vector3.new(spot.size.X + 1, spot.size.Y + spot.size.X / 2, ROOM_CLEARANCE), overlap)) do
		if not cuttable(part) then
			return nil
		end
	end
	return thickness
end

-- Troca a peça pelo resultado do recorte, com o mesmo nome, pai, colisão,
-- atributos e tags.
local function cut(part: BasePart, holes: { BasePart }): BasePart?
	local ok, result = pcall(function()
		return GeometryService:SubtractAsync(part, holes, {
			CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
			SplitApart = false,
		})
	end)
	if not ok or result == nil or result[1] == nil then
		warn(`[BlocoPuff] Castle window cut failed on {part:GetFullName()}: {result}`)
		return nil
	end
	local union = result[1]
	union.Name = part.Name
	union.Anchored = true
	union.CanCollide = part.CanCollide
	union.CanQuery = part.CanQuery
	union.CanTouch = part.CanTouch
	union.CastShadow = part.CastShadow
	union.Transparency = part.Transparency
	for name, value in pairs(part:GetAttributes()) do
		union:SetAttribute(name, value)
	end
	for _, tag in ipairs(CollectionService:GetTags(part)) do
		CollectionService:AddTag(union, tag)
	end
	union.Parent = part.Parent
	part:Destroy()
	return union
end

-- Acabamentos (papel de parede, lambri, quadros, móveis) costumam ter
-- CanQuery desligado e sumiriam das consultas: durante o recorte, as peças
-- de `targets` ficam consultáveis. Devolve as que foram ligadas.
local function exposeTargets(targets: { Instance }): { [BasePart]: true }
	local exposed: { [BasePart]: true } = {}
	for _, target in ipairs(targets) do
		for _, item in ipairs(target:GetDescendants()) do
			if item:IsA("BasePart") and not item.CanQuery then
				item.CanQuery = true
				exposed[item] = true
			end
		end
	end
	return exposed
end

-- Vidro no meio da parede, mainel, moldura de pedra por fora (ombreiras,
-- arco pontudo e peitoril) e de madeira por dentro.
local function dress(parent: Instance, opening: Opening)
	local spot, thickness = opening.spot, opening.thickness
	local frame, size = spot.frame, spot.size
	local half, top = size.X / 2, size.Y / 2
	local side = size.X / math.sqrt(2)
	local glassAt = frame * CFrame.new(0, 0, thickness / 2)
	local pane = TowerKit.part(parent, "CastleWindowGlass", Vector3.new(size.X, size.Y, 0.2), glassAt, GLASS, Enum.Material.Glass)
	pane.Transparency = GLASS_TRANSPARENCY
	pane.CanQuery = false
	local archPane = TowerKit.part(parent, "CastleWindowGlass", Vector3.new(side, side, 0.2), glassAt * CFrame.new(0, top, 0) * CFrame.Angles(0, 0, math.rad(45)), GLASS, Enum.Material.Glass)
	archPane.Transparency = GLASS_TRANSPARENCY
	archPane.CanQuery = false
	TowerKit.decor(TowerKit.part(parent, "CastleWindowMullion", Vector3.new(0.25, size.Y + half, 0.3), glassAt * CFrame.new(0, half / 2, 0), LEAD, Enum.Material.Metal))
	TowerKit.decor(TowerKit.part(parent, "CastleWindowMullion", Vector3.new(size.X, 0.25, 0.3), glassAt * CFrame.new(0, top * 0.35, 0), LEAD, Enum.Material.Metal))

	-- Por fora: -Z local é para fora; a pedra fica por cima do revestimento.
	local out = -0.6
	for _, x in ipairs({ -half - 0.35, half + 0.35 }) do
		TowerKit.decor(TowerKit.part(parent, "CastleWindowJamb", Vector3.new(0.7, size.Y, 0.6), frame * CFrame.new(x, 0, out), STONE_TRIM, Enum.Material.Limestone))
	end
	for _, sign in ipairs({ -1, 1 }) do
		local edge = frame * CFrame.new(sign * half / 2, top + half / 2, out) * CFrame.Angles(0, 0, sign * math.rad(45))
		TowerKit.decor(TowerKit.part(parent, "CastleWindowArch", Vector3.new(0.7, side + 0.9, 0.6), edge * CFrame.new(0.35 * sign, 0, 0), STONE_TRIM, Enum.Material.Limestone))
	end
	TowerKit.decor(TowerKit.part(parent, "CastleWindowSill", Vector3.new(size.X + 1.8, 0.5, 1), frame * CFrame.new(0, -top - 0.25, out - 0.2), STONE_TRIM, Enum.Material.Limestone))

	-- Por dentro: peitoril e ombreiras de madeira rentes ao acabamento.
	local inside = thickness + 0.15
	TowerKit.decor(TowerKit.part(parent, "CastleWindowSillInside", Vector3.new(size.X + 1.2, 0.4, 0.8), frame * CFrame.new(0, -top - 0.2, inside + 0.25), WOOD, Enum.Material.Wood))
	for _, x in ipairs({ -half - 0.25, half + 0.25 }) do
		TowerKit.decor(TowerKit.part(parent, "CastleWindowJambInside", Vector3.new(0.5, size.Y, 0.3), frame * CFrame.new(x, 0, inside), WOOD, Enum.Material.Wood))
	end
end

-- Abre as janelas em `spots`, recortando as peças de `targets` (e o
-- revestimento em `parent`). Confere contra tudo que há no mundo (menos o
-- terreno, a floresta e os personagens). Demora (CSG): chamar em segundo
-- plano.
function CastleWindows.open(parent: Instance, spots: { Spot }, targets: { Instance }, world: Instance): number
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = targets
	local ignored: { Instance } = { workspace.Terrain }
	local outdoors = world:FindFirstChild(OUTDOORS_NAME)
	if outdoors ~= nil then
		table.insert(ignored, outdoors)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character ~= nil then
			table.insert(ignored, player.Character)
		end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignored

	local exposed = exposeTargets(targets)

	-- Primeiro escolhe as janelas e junta os recortes por peça (um recorte
	-- só por peça, com todos os vãos dela).
	local openings: { Opening } = {}
	local holesByPart: { [BasePart]: { BasePart } } = {}
	for _, spot in ipairs(spots) do
		local thickness = measure(spot, rays, overlap)
		if thickness ~= nil then
			table.insert(openings, { spot = spot, thickness = thickness })
			local shapes = holeShapes(spot, CUT_OUT, thickness + CUT_OUT + CUT_IN)
			for _, shape in ipairs(shapes) do
				for _, part in ipairs(workspace:GetPartBoundsInBox(shape.CFrame, shape.Size, overlap)) do
					local list = holesByPart[part]
					if list == nil then
						list = {}
						holesByPart[part] = list
					end
					table.insert(list, shape)
				end
			end
		end
	end
	for part, holes in pairs(holesByPart) do
		if part.Parent ~= nil then
			local union = cut(part, holes)
			if union ~= nil and exposed[part] then
				exposed[part] = nil
				union.CanQuery = false
			end
		end
	end
	for part in pairs(exposed) do
		if part.Parent ~= nil then
			part.CanQuery = false
		end
	end
	for _, opening in ipairs(openings) do
		dress(parent, opening)
	end
	return #openings
end

return table.freeze(CastleWindows)
