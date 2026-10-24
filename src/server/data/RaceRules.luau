--!strict

-- Regras da Corrida da Torre do Relógio (Fase 5D.2), sem Roblox: a espiral
-- da rampa, checkpoints, volta ao checkpoint, classificação, fim da corrida,
-- ritmo dos obstáculos e acerto do barril. Os testes rodam no Lune
-- (tests/RaceRules.spec.luau).
--
-- A rampa sobe em espiral em volta de uma coluna central. A posição na
-- espiral é medida em voltas (`t`): 0 é o começo, `turns` é o topo.

export type Spiral = {
	-- Distância do centro da torre até o meio da rampa.
	radius: number,
	turns: number,
	-- Quanto a rampa sobe por volta.
	climbPerTurn: number,
	-- Altura do chão da base (começo da rampa).
	baseY: number,
}

export type RankEntry = {
	id: number,
	-- Ordem de chegada no topo (nil = não chegou).
	finishOrder: number?,
	-- Maior altura alcançada na corrida.
	bestHeight: number,
	-- Quando (segundos de corrida) alcançou essa altura: na mesma altura,
	-- fica na frente quem chegou nela primeiro (nil = empata).
	reachedAt: number?,
}

local RaceRules = {}

-- Ponto do meio da rampa na volta `t`: x e z em relação ao centro da torre,
-- y absoluto. Fora do intervalo, fica no começo ou no topo.
function RaceRules.spiralPoint(spiral: Spiral, t: number): (number, number, number)
	local turns = math.clamp(t, 0, spiral.turns)
	local angle = turns * 2 * math.pi
	return spiral.radius * math.cos(angle), spiral.baseY + turns * spiral.climbPerTurn, spiral.radius * math.sin(angle)
end

function RaceRules.topY(spiral: Spiral): number
	return spiral.baseY + spiral.turns * spiral.climbPerTurn
end

-- Posições (em voltas) dos pontos do caminho, do começo ao topo.
function RaceRules.pathTurns(spiral: Spiral, segmentsPerTurn: number): { number }
	local total = math.max(1, math.floor(spiral.turns * segmentsPerTurn))
	local points: { number } = {}
	for index = 0, total do
		table.insert(points, spiral.turns * index / total)
	end
	return points
end

-- Alturas dos checkpoints: o patamar no fim de cada volta, menos a última
-- (lá é a chegada).
function RaceRules.checkpointHeights(spiral: Spiral, count: number): { number }
	local heights: { number } = {}
	for turn = 1, math.min(count, spiral.turns - 1) do
		table.insert(heights, spiral.baseY + turn * spiral.climbPerTurn)
	end
	return heights
end

-- Maior checkpoint alcançado a esta altura (0 = nenhum).
function RaceRules.checkpointFor(height: number, heights: { number }, tolerance: number): number
	local reached = 0
	for index, checkpointY in ipairs(heights) do
		if height >= checkpointY - tolerance then
			reached = index
		end
	end
	return reached
end

-- Subida possível entre duas checagens (`dt` s): andar, pular e empurrões
-- cabem em `maxSpeed`; um teletransporte para cima, não. Descer sempre pode.
function RaceRules.plausibleRise(previousHeight: number, height: number, dt: number, maxSpeed: number): boolean
	return height - previousHeight <= maxSpeed * dt
end

-- Checkpoints contam em ordem: no máximo o próximo, nunca para trás.
function RaceRules.nextCheckpoint(current: number, reached: number): number
	return math.max(current, math.min(reached, current + 1))
end

-- Caiu bem abaixo do último checkpoint (ou da base, sem checkpoint)? Uma
-- queda curta (um degrau, um empurrão) segue a corrida de onde caiu.
function RaceRules.shouldReturn(height: number, checkpointY: number?, tolerance: number, floorY: number?): boolean
	local reference = checkpointY or floorY
	if reference == nil then
		return false
	end
	return height < reference - tolerance
end

-- Posição de cada corredor: quem chegou, pela ordem de chegada; depois quem
-- não chegou, pela maior altura (mesma altura, mesma posição).
function RaceRules.rank(entries: { RankEntry }): { [number]: number }
	local positions: { [number]: number } = {}
	local finishers = 0
	local climbers: { RankEntry } = {}
	for _, entry in ipairs(entries) do
		if entry.finishOrder ~= nil then
			finishers += 1
		else
			table.insert(climbers, entry)
		end
	end
	for _, entry in ipairs(entries) do
		if entry.finishOrder ~= nil then
			positions[entry.id] = entry.finishOrder
		end
	end
	local function reached(entry: RankEntry): number
		return entry.reachedAt or math.huge
	end
	table.sort(climbers, function(a, b)
		if a.bestHeight ~= b.bestHeight then
			return a.bestHeight > b.bestHeight
		end
		return reached(a) < reached(b)
	end)
	for index, entry in ipairs(climbers) do
		local previous = climbers[index - 1]
		if previous ~= nil and previous.bestHeight == entry.bestHeight and reached(previous) == reached(entry) then
			positions[entry.id] = positions[previous.id]
		else
			positions[entry.id] = finishers + index
		end
	end
	return positions
end

-- A corrida acaba quando o pódio enche (ou todos chegam, em corrida pequena).
function RaceRules.isOver(finished: number, racers: number, podium: number): boolean
	return racers > 0 and finished >= math.min(podium, racers)
end

-- Intervalo entre obstáculos: de `slow` no começo a `fast` no fim.
function RaceRules.hazardInterval(progress: number, slow: number, fast: number): number
	local alpha = math.clamp(progress, 0, 1)
	return slow + (fast - slow) * alpha
end

-- O barril acerta quem está perto, sem ter pulado por cima e sem estar numa
-- volta de baixo da rampa.
function RaceRules.barrelHits(horizontalDistance: number, heightAbove: number, hitRadius: number, barrelRadius: number, clearHeight: number): boolean
	return horizontalDistance <= hitRadius and heightAbove < clearHeight and heightAbove > -barrelRadius * 2
end

-- Raio do meio da mureta: encostada na borda de fora da rampa.
function RaceRules.parapetRadius(radius: number, rampWidth: number, thickness: number): number
	return radius + rampWidth / 2 + thickness / 2
end

-- Altura da barreira invisível em cima da mureta: fecha a borda até perto da
-- volta de cima da rampa, sem encostar nela (Fase 5F).
function RaceRules.barrierHeight(climbPerTurn: number, rampThickness: number, parapetHeight: number, headroom: number): number
	return math.max(0, climbPerTurn - rampThickness - parapetHeight - headroom)
end

-- `angle` está no arco que vai de `from` a `to` (radianos, sentido
-- anti-horário, dando a volta no 0 se preciso)?
function RaceRules.inArc(angle: number, from: number, to: number): boolean
	local full = 2 * math.pi
	local span = (to - from) % full
	return (angle - from) % full <= span
end

-- Obstáculo em faixa (bando de livros): acerta quem está dentro da faixa
-- (`along` no comprimento, `across` na largura, em relação ao meio dela) e
-- não pulou por cima. `heightAbove` é a altura da raiz acima da rampa.
function RaceRules.bandHits(along: number, across: number, heightAbove: number, halfLength: number, halfWidth: number, clearHeight: number): boolean
	return math.abs(along) <= halfLength and math.abs(across) <= halfWidth and heightAbove > -2 and heightAbove < clearHeight
end

-- Diferença de `to` para `from` em radianos, entre -pi e pi.
local function angleDelta(from: number, to: number): number
	return math.atan2(math.sin(to - from), math.cos(to - from))
end

-- O ponteiro gigante girou de `previous` para `current` neste passo: acerta
-- quem está entre os dois ângulos, no comprimento do ponteiro, no chão (não
-- pulando por cima).
function RaceRules.handSweeps(previous: number, current: number, angle: number, radius: number, innerRadius: number, outerRadius: number, heightAbove: number, clearHeight: number): boolean
	if radius < innerRadius or radius > outerRadius or heightAbove <= -2 or heightAbove >= clearHeight then
		return false
	end
	local swept = angleDelta(previous, current)
	local offset = angleDelta(previous, angle)
	-- Folga de meio stud de cada lado (a largura do ponteiro).
	local slack = 0.75 / math.max(radius, 1)
	if swept >= 0 then
		return offset >= -slack and offset <= swept + slack
	end
	return offset <= slack and offset >= swept - slack
end

-- Empurrão de quem é atingido: rampa abaixo (contra a tangente de subida,
-- só na horizontal) e um pouco para cima. Nunca para fora da torre.
function RaceRules.downhillPush(tangentX: number, tangentZ: number, downhill: number, vertical: number): (number, number, number)
	local length = math.sqrt(tangentX * tangentX + tangentZ * tangentZ)
	if length < 1e-6 then
		return 0, vertical, 0
	end
	return -tangentX / length * downhill, vertical, -tangentZ / length * downhill
end

return table.freeze(RaceRules)
