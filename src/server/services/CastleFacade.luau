--!strict

-- Fachadas de castelo nas paredes de fora do Casarão e do prédio da Arena:
-- um revestimento de pedra rente à parede (sem tampar janela, porta ou vão),
-- janelas góticas de enfeite com arco pontudo e contrafortes nos trechos de
-- parede cheia. Cada fachada é medida com raios de fora para dentro numa
-- grade (FacadeGrid). Tudo aqui é enfeite, exceto o pé dos contrafortes.

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
local GLASS = Color3.fromRGB(196, 128, 58)
local LEAD = Color3.fromRGB(40, 38, 40)

local WINDOW_COLS = 2
local WINDOW_ROWS = 4
local WINDOW_SPACING = 8
local WINDOW_OFFSET = 3
local WINDOW_TOP_MARGIN = 3
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
}

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

-- Mede a fachada: profundidade da parede em cada célula (0 = vão).
function CastleFacade.measure(face: Face, params: RaycastParams): Measured
	local cols = math.max(1, math.floor(face.length / CELL))
	local rows = math.max(1, math.floor((face.top - face.bottom) / CELL))
	local grid = FacadeGrid.new(cols, rows, function(col: number, row: number): number
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
		if first <= row or rowTop > face.plinthTop + CELL then
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
		TowerKit.decor(TowerKit.part(parent, "CastlePlinth", Vector3.new(size.X, size.Y + PLINTH_SINK, PLINTH_OUT), sunk, PLINTH, Enum.Material.Cobblestone))
	end
end

local function skin(parent: Instance, measured: Measured)
	for _, rect in ipairs(FacadeGrid.rects(measured.grid)) do
		local frame, size = panelFrame(measured.face, rect.col0, rect.col1, rect.row0, rect.row1, rect.key, SKIN_THICKNESS / 2)
		TowerKit.decor(TowerKit.part(parent, "CastleStone", Vector3.new(size.X, size.Y, SKIN_THICKNESS), frame, STONE, Enum.Material.Cobblestone))
	end
end

-- Janela gótica: moldura clara, vidro aceso, mainel e arco pontudo (um
-- quadrado girado 45 graus em cima).
local function window(parent: Instance, frame: CFrame, size: Vector2)
	local lift = SKIN_THICKNESS
	local surround = TowerKit.part(parent, "CastleWindowFrame", Vector3.new(size.X + 1, size.Y + 1, 0.3), frame * CFrame.new(0, 0, -lift - 0.15), STONE_TRIM, Enum.Material.Limestone)
	TowerKit.decor(surround)
	local glass = TowerKit.part(parent, "CastleWindowGlass", Vector3.new(size.X - 0.6, size.Y - 0.6, 0.2), frame * CFrame.new(0, 0, -lift - 0.35), GLASS, Enum.Material.Neon)
	TowerKit.decor(glass)
	local arch = size.X / math.sqrt(2)
	local top = frame * CFrame.new(0, size.Y / 2, 0)
	TowerKit.decor(TowerKit.part(parent, "CastleWindowArch", Vector3.new(arch + 0.7, arch + 0.7, 0.3), top * CFrame.new(0, 0, -lift - 0.15) * CFrame.Angles(0, 0, math.rad(45)), STONE_TRIM, Enum.Material.Limestone))
	TowerKit.decor(TowerKit.part(parent, "CastleWindowArchGlass", Vector3.new(arch - 0.4, arch - 0.4, 0.2), top * CFrame.new(0, 0, -lift - 0.35) * CFrame.Angles(0, 0, math.rad(45)), GLASS, Enum.Material.Neon))
	TowerKit.decor(TowerKit.part(parent, "CastleWindowMullion", Vector3.new(0.25, size.Y + size.X / 2, 0.25), frame * CFrame.new(0, size.X / 4, -lift - 0.45), LEAD, Enum.Material.Metal))
	TowerKit.decor(TowerKit.part(parent, "CastleWindowSill", Vector3.new(size.X + 1.6, 0.4, 0.8), frame * CFrame.new(0, -size.Y / 2 - 0.6, -lift - 0.4), STONE_TRIM, Enum.Material.Limestone))
end

local function windows(parent: Instance, measured: Measured): { number }
	local grid = measured.grid
	local row1 = grid.rows - WINDOW_TOP_MARGIN
	local row0 = row1 - WINDOW_ROWS + 1
	if row0 < 2 then
		return {}
	end
	-- A ponta do arco também precisa de parede cheia em cima.
	local spots = FacadeGrid.spots(grid, WINDOW_COLS, row0, math.min(grid.rows, row1 + 2), WINDOW_SPACING, WINDOW_OFFSET)
	for _, col in ipairs(spots) do
		local key = grid.keys[row0][col]
		-- O CFrame olha para fora: -Z local aponta para fora da parede.
		local frame, size = panelFrame(measured.face, col, col + WINDOW_COLS - 1, row0, row1, key, 0)
		window(parent, frame, size)
	end
	return spots
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
		local clear = true
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

-- Mede e decora uma fachada.
function CastleFacade.build(parent: Instance, face: Face, params: RaycastParams): Measured
	local measured = CastleFacade.measure(face, params)
	skin(parent, measured)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	plinth(parent, measured, overlap)
	local windowCols = windows(parent, measured)
	buttresses(parent, measured, windowCols)
	return measured
end

return table.freeze(CastleFacade)
