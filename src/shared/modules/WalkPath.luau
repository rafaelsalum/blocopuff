--!strict

-- Onde está quem anda num caminho de trechos retos, a partir do tempo
-- passado desde a saída (puro, sem Vector3: servidor e cliente chegam ao
-- mesmo lugar só com o horário do servidor). Cada trecho tem o comprimento
-- e uma parada no fim dele (cheirar o chão, olhar em volta).

export type Leg = {
	length: number,
	wait: number,
}

export type Spot = {
	-- Trecho atual (1..#legs) e quanto dele já foi andado (0..1).
	leg: number,
	fraction: number,
	-- Parado no fim do trecho.
	waiting: boolean,
	-- Passou do fim do caminho.
	done: boolean,
}

local WalkPath = {}

-- Duração total (s) andando a `speed` studs/s.
function WalkPath.duration(legs: { Leg }, speed: number): number
	local total = 0
	for _, leg in ipairs(legs) do
		total += math.max(leg.length, 0) / speed + math.max(leg.wait, 0)
	end
	return total
end

function WalkPath.locate(legs: { Leg }, speed: number, elapsed: number): Spot
	if #legs == 0 or speed <= 0 then
		return { leg = math.max(#legs, 1), fraction = 1, waiting = false, done = true }
	end
	local left = math.max(elapsed, 0)
	for index, leg in ipairs(legs) do
		local travel = math.max(leg.length, 0) / speed
		if left < travel then
			return { leg = index, fraction = left / travel, waiting = false, done = false }
		end
		left -= travel
		local wait = math.max(leg.wait, 0)
		if left < wait then
			return { leg = index, fraction = 1, waiting = true, done = false }
		end
		left -= wait
	end
	return { leg = #legs, fraction = 1, waiting = false, done = true }
end

return table.freeze(WalkPath)
