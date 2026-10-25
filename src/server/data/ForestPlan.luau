--!strict

-- Regras puras da floresta do lado de fora: onde nasce cada árvore. A grade
-- cobre o terreno todo e cada célula sorteia no máximo uma árvore, mais
-- fechada perto do Casarão e rala nas encostas das montanhas, com clareiras
-- (ruído) e sem árvore no gramado das construções, na água, em encosta
-- íngreme, em cima dos caminhos ou acima da linha das árvores. O sorteio tem semente fixa: todo
-- servidor monta a mesma floresta. Sem dependências (os testes do Lune
-- carregam este arquivo direto).

export type Settings = {
	Seed: number,
	CellSize: number,
	NearChance: number,
	FarChance: number,
	FarRadius: number,
	ClearingMargin: number,
	-- Folga sem árvore dos dois lados dos caminhos de pedra.
	PathMargin: number,
	MinScale: number,
	MaxScale: number,
	MaxSlope: number,
	TreeLine: number,
	DeadChance: number,
	ShadowRadius: number,
	-- Centro e meia largura do terreno.
	CenterX: number,
	CenterZ: number,
	HalfExtent: number,
	GroundY: number,
	-- Centro do Casarão (as sombras vão até ShadowRadius dele).
	HomeX: number,
	HomeZ: number,
}

-- O chão num ponto: altura, inclinação, distância até a construção e até o
-- caminho mais perto, se é água e se está dentro do terreno.
export type Sample = {
	height: number,
	slope: number,
	clearance: number,
	path: number,
	wet: boolean,
	inside: boolean,
}

export type TreeKind = "Pine" | "Dead"

export type Tree = {
	x: number,
	z: number,
	y: number,
	kind: TreeKind,
	-- Qual dos modelos do tipo (1 a `variants`).
	variant: number,
	scale: number,
	-- Giro em volta do tronco (radianos).
	yaw: number,
	shadow: boolean,
}

-- Escala do ruído das clareiras e quanto ele pesa.
local GROVE_SCALE = 300
local GROVE_WEIGHT = 1.6
local GROVE_MIN = 0.15
local GROVE_MAX = 1.6
-- Árvores secas: só dois modelos (TowerAssets).
local DEAD_VARIANTS = 2

local ForestPlan = {}

-- Gerador de Park-Miller: números em [0, 1) a partir da semente.
local function generator(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
end

-- Árvores do terreno descrito por `sample`, com `variants` modelos de
-- pinheiro.
function ForestPlan.plan(settings: Settings, sample: (x: number, z: number) -> Sample, variants: number): { Tree }
	local random = generator(settings.Seed)
	local trees: { Tree } = {}
	local cell = settings.CellSize
	local cells = math.floor(2 * settings.HalfExtent / cell)
	local startX = settings.CenterX - settings.HalfExtent
	local startZ = settings.CenterZ - settings.HalfExtent
	for column = 0, cells - 1 do
		for row = 0, cells - 1 do
			-- Sempre os mesmos sorteios por célula, para uma árvore a menos
			-- num canto não mudar a floresta inteira.
			local jitterX, jitterZ, roll = random(), random(), random()
			local kindRoll, variantRoll, scaleRoll, yawRoll = random(), random(), random(), random()
			local x = startX + (column + jitterX) * cell
			local z = startZ + (row + jitterZ) * cell
			local fromCenter = math.sqrt((x - settings.CenterX) ^ 2 + (z - settings.CenterZ) ^ 2)
			local chance = if fromCenter < settings.FarRadius then settings.NearChance else settings.FarChance
			local grove = math.clamp(1 + math.noise(x / GROVE_SCALE, z / GROVE_SCALE, 9.1) * GROVE_WEIGHT, GROVE_MIN, GROVE_MAX)
			if roll < chance * grove then
				local ground = sample(x, z)
				local fits = ground.inside
					and not ground.wet
					and ground.clearance >= settings.ClearingMargin
					and ground.path >= settings.PathMargin
					and ground.slope <= settings.MaxSlope
					and ground.height - settings.GroundY <= settings.TreeLine
				if fits then
					local dead = kindRoll < settings.DeadChance
					local count = if dead then DEAD_VARIANTS else variants
					table.insert(trees, {
						x = x,
						z = z,
						y = ground.height,
						kind = if dead then "Dead" else "Pine",
						variant = math.min(count, 1 + math.floor(variantRoll * count)),
						scale = settings.MinScale + scaleRoll * (settings.MaxScale - settings.MinScale),
						yaw = yawRoll * 2 * math.pi,
						shadow = math.sqrt((x - settings.HomeX) ^ 2 + (z - settings.HomeZ) ^ 2) <= settings.ShadowRadius,
					})
				end
			end
		end
	end
	return trees
end

return table.freeze(ForestPlan)
