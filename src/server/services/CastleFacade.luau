--!strict

-- Fachadas de castelo nas paredes de fora do Casarão e do prédio da Arena:
-- um revestimento de pedra rente à parede (sem tampar janela, porta ou vão),
-- um embasamento sólido embaixo do piso e contrafortes nos trechos de
-- parede cheia. Também escolhe onde abrir as janelas góticas (quem abre de
-- verdade é o CastleWindows). Cada fachada é medida com raios de fora para
-- dentro numa grade (FacadeGrid). O revestimento é só enfeite.

local FacadeGrid = require(script.Parent.Parent.data.FacadeGrid)
local TowerKit = require(script.Parent.TowerKit)

local CELL = 2
-- Os raios saem um pouco fora da caixa e só aceitam parede até o alcance
-- da fachada (Face.reach): num vão o raio passa direto e a célula fica vazia.
local RAY_START = 1.5
-- A parede precisa estar de frente para fora (não o lado de um móvel).
local FACING_MIN = 0.9
local SKIN_THICKNESS = 0.4
local DEPTH_STEP = 0.5
local SKIP_NAMES = { "Door", "Window", "Glass", "Mullion", "Knob", "Transom" }

local STONE = Color3.fromRGB(150, 148, 142)
local STONE_TRIM = Color3.fromRGB(176, 172, 162)
local PLINTH = Color3.fromRGB(104, 100, 96)
local PLINTH_OUT = 1.2
local PLINTH_SINK = 3
-- Quanto o embasamento pode passar do piso (não sobe numa porta).
local PLINTH_OVERLAP = 0.5

local WINDOW_COLS = 2
local WINDOW_SPACING = 8
local WINDOW_OFFSET = 3
-- Parede cheia em volta da janela (moldura e ponta do arco), em células.
local WINDOW_MARGIN_ROWS = 1
local WINDOW_ARCH_ROWS = 2
local BUTTRESS_SPACING = 8
local BUTTRESS_OFFSET = 7
local BUTTRESS_DEPTH = 2.4
local BUTTRESS_FRACTION = 0.6

export type Face = {
	name: string,
	-- Ponto inicial da fachada no chão, direção ao longo dela e normal para fora.
	origin: Vector3,
	along: Vector3,
	normal: Vector3,
	length: number,
	bottom: number,
	top: number,
	-- Até onde (a partir da linha da fachada) a parede pode estar.
	reach: number,
	-- Abaixo desta altura, o vão embaixo da parede vira embasamento de pedra.
	plinthTop: number,
	-- Faixas de janelas: altura do peitoril e altura do vão (sem o arco).
	windows: { WindowBand },
	-- Trechos sem revestimento nenhum (a porta principal).
	clear: { Area },
	-- Trechos sem janela nem contraforte (o portal da porta principal).
	reserve: { Area },
}

-- Retângulo na fachada: de `from` a `to` studs ao longo dela, entre as
-- alturas `bottom` e `top`.
export type Area = { from: number, to: number, bottom: number, top: number }
export type WindowBand = { bottom: number, height: number }

-- Janela escolhida: centro do vão na face de fora da parede (-Z local
-- aponta para fora) e largura × altura do vão retangular.
export type WindowSpot = { frame: CFrame, size: Vector2 }

export type Measured = { face: Face, grid: FacadeGrid.Grid }

local CastleFacade = {}

local function skipped(part: BasePart): boolean
	if part.Transparency > 0.2 or part.Material == Enum.Material.Glass then
		return true
	end
	for _, word in ipairs(SKIP_NAMES) do
		if string.find(part.Name, word, 1, true) ~= nil then
			return true
		end
	end
	return false
end

-- Centro da célula (col, row) na linha da fachada.
local function cellPoint(face: Face, col: number, row: number): Vector3
	local along = (col - 0.5) * CELL
	local y = face.bottom + (row - 0.5) * CELL
	return Vector3.new(face.origin.X, y, face.origin.Z) + face.along * along
end

-- A célula (col, row) cai em algum dos trechos?
local function inAreas(areas: { Area }, face: Face, col: number, row: number): boolean
	local along = (col - 0.5) * CELL
	local y = face.bottom + (row - 0.5) * CELL
	for _, area in ipairs(areas) do
		if along >= area.from and along <= area.to and y >= area.bottom and y <= area.top then
			return true
		end
	end
	return false
end

-- Mede a fachada: profundidade da parede em cada célula (0 = vão).
function CastleFacade.measure(face: Face, params: RaycastParams): Measured
	local cols = math.max(1, math.floor(face.length / CELL))
	local rows = math.max(1, math.floor((face.top - face.bottom) / CELL))
	local grid = FacadeGrid.new(cols, rows, function(col: number, row: number): number
		if inAreas(face.clear, face, col, row) then
			return 0
		end
		local start = cellPoint(face, col, row) + face.normal * RAY_START
		local hit = workspace:Raycast(start, -face.normal * (face.reach + RAY_START), params)
		if hit == nil or not hit.Instance:IsA("BasePart") or skipped(hit.Instance) or hit.Normal:Dot(face.normal) < FACING_MIN then
			return 0
		end
		return math.floor(hit.Distance / DEPTH_STEP + 0.5) + 1
	end)
	return { face = face, grid = grid }
end

-- Distância da parede até a linha da fachada (positivo = para dentro).
local function inset(key: number): number
	return (key - 1) * DEPTH_STEP - RAY_START
end

-- CFrame de um retângulo plano na fachada, de col0..col1 e row0..row1,
-- afastado `out` studs da parede.
local function panelFrame(face: Face, col0: number, col1: number, row0: number, row1: number, key: number, out: number): (CFrame, Vector2)
	local width = (col1 - col0 + 1) * CELL
	local height = (row1 - row0 + 1) * CELL
	local along = (col0 - 1) * CELL + width / 2
	local y = face.bottom + (row0 - 1) * CELL + height / 2
	local center = Vector3.new(face.origin.X, y, face.origin.Z) + face.along * along + face.normal * (out - inset(key))
	return CFrame.lookAt(center, center + face.normal), Vector2.new(width, height)
end

-- Embasamento: onde a parede começa no alto (o piso do Casarão fica acima
-- do chão), o vão de baixo vira pedra mais escura até o chão.
local function plinth(parent: Instance, measured: Measured, overlap: OverlapParams)
	local grid = measured.grid
	local face = measured.face
	local firstSolid: { number } = {}
	for col = 1, grid.cols do
		firstSolid[col] = 0
		for row = 1, grid.rows do
			if grid.keys[row][col] ~= 0 then
				firstSolid[col] = row
				break
			end
		end
	end
	local base = FacadeGrid.new(grid.cols, grid.rows, function(col: number, row: number): number
		local first = firstSolid[col]
		local rowTop = face.bottom + row * CELL
		if first <= row or rowTop > face.plinthTop + PLINTH_OVERLAP then
			return 0
		end
		-- Embaixo do piso pode passar um túnel: o embasamento não o tampa.
		local key = grid.keys[first][col]
		local frame = panelFrame(face, col, col, row, row, key, PLINTH_OUT / 2)
		if #workspace:GetPartBoundsInBox(frame, Vector3.new(CELL - 0.2, CELL - 0.2, PLINTH_OUT), overlap) > 0 then
			return 0
		end
		return key
	end)
	for _, rect in ipairs(FacadeGrid.rects(base)) do
		local frame, size = panelFrame(face, rect.col0, rect.col1, rect.row0, rect.row1, rect.key, PLINTH_OUT / 2)
		-- Desce um pouco para dentro do chão.
		local sunk = frame * CFrame.new(0, -PLINTH_SINK / 2, 0)
		-- Sólido: fecha o vão embaixo do piso (ninguém entra por baixo do Casarão).
		local stone = TowerKit.decor(TowerKit.part(parent, "CastlePlinth", Vector3.new(size.X, size.Y + PLINTH_SINK, PLINTH_OUT), sunk, PLINTH, Enum.Material.Cobblestone))
		stone.CanCollide = true
	end
end

local function skin(parent: Instance, measured: Measured)
	for _, rect in ipairs(FacadeGrid.rects(measured.grid)) do
		local frame, size = panelFrame(measured.face, rect.col0, rect.col1, rect.row0, rect.row1, rect.key, SKIN_THICKNESS / 2)
		local stone = TowerKit.decor(TowerKit.part(parent, "CastleStone", Vector3.new(size.X, size.Y, SKIN_THICKNESS), frame, STONE, Enum.Material.Cobblestone))
		-- Visível para as consultas: o CastleWindows recorta as janelas nele.
		stone.CanQuery = true
	end
end

-- Onde cabem janelas em cada faixa: parede cheia em volta do vão e do
-- arco, fora dos trechos reservados.
local function windowSpots(measured: Measured): ({ WindowSpot }, { number })
	local grid = measured.grid
	local face = measured.face
	local spots: { WindowSpot } = {}
	local cols: { number } = {}
	for _, band in ipairs(face.windows) do
		local row0 = math.floor((band.bottom - face.bottom) / CELL) + 1
		local row1 = row0 + math.ceil(band.height / CELL) - 1
		for _, col in ipairs(FacadeGrid.spots(grid, WINDOW_COLS, row0 - WINDOW_MARGIN_ROWS, row1 + WINDOW_ARCH_ROWS, WINDOW_SPACING, WINDOW_OFFSET)) do
			local reserved = false
			for check = col, col + WINDOW_COLS - 1 do
				for row = row0, row1 do
					reserved = reserved or inAreas(face.reserve, face, check, row)
				end
			end
			if not reserved then
				local frame = panelFrame(face, col, col + WINDOW_COLS - 1, row0, row1, grid.keys[row0][col], 0)
				local center = frame.Position + Vector3.new(0, band.bottom + band.height / 2 - frame.Position.Y, 0)
				table.insert(spots, { frame = CFrame.lookAt(center, center + face.normal), size = Vector2.new(WINDOW_COLS * CELL - 0.6, band.height) })
				table.insert(cols, col)
			end
		end
	end
	return spots, cols
end

-- Contraforte: pé largo e um degrau mais raso em cima, com tampo inclinado.
local function buttress(parent: Instance, face: Face, col: number, rows: number, key: number)
	local frame, size = panelFrame(face, col, col, 1, rows, key, BUTTRESS_DEPTH / 2)
	local width = size.X + 0.6
	local lower = TowerKit.part(parent, "CastleButtress", Vector3.new(width, size.Y, BUTTRESS_DEPTH), frame, STONE, Enum.Material.Cobblestone)
	lower.CanQuery = false
	lower.CanTouch = false
	local capHeight = BUTTRESS_DEPTH
	local cap = Instance.new("WedgePart")
	cap.Name = "CastleButtressCap"
	cap.Anchored = true
	cap.Size = Vector3.new(width, capHeight, BUTTRESS_DEPTH)
	-- A rampa da cunha desce para -Z local, que aqui já aponta para fora.
	cap.CFrame = frame * CFrame.new(0, size.Y / 2 + capHeight / 2, 0)
	cap.Color = STONE_TRIM
	cap.Material = Enum.Material.Limestone
	cap.CastShadow = false
	TowerKit.decor(cap)
	cap.Parent = parent
end

local function buttresses(parent: Instance, measured: Measured, windowCols: { number })
	local grid = measured.grid
	local rows = math.max(2, math.floor(grid.rows * BUTTRESS_FRACTION))
	for _, col in ipairs(FacadeGrid.spots(grid, 1, 1, rows + 1, BUTTRESS_SPACING, BUTTRESS_OFFSET)) do
		local clear = not inAreas(measured.face.reserve, measured.face, col, 1)
		for _, windowCol in ipairs(windowCols) do
			if col >= windowCol - 1 and col <= windowCol + WINDOW_COLS then
				clear = false
			end
		end
		if clear then
			buttress(parent, measured.face, col, rows, grid.keys[1][col])
		end
	end
end

-- Mede e reveste uma fachada; devolve onde abrir as janelas.
function CastleFacade.build(parent: Instance, face: Face, params: RaycastParams): { WindowSpot }
	local measured = CastleFacade.measure(face, params)
	skin(parent, measured)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	plinth(parent, measured, overlap)
	local spots, windowCols = windowSpots(measured)
	buttresses(parent, measured, windowCols)
	return spots
end

return table.freeze(CastleFacade)
