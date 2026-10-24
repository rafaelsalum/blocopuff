--!strict

-- Horários da Tempestade do Caos Final (Fase 5, entrega 5.7), em segundos
-- desde o começo do Caos. As janelas estouram uma por vez e os lustres caem
-- em sequência; quando o Caos é curto, os intervalos encolhem para caber
-- todos antes do fim (menos `QuietTail`, para o efeito terminar a tempo).
-- Lógica pura, testada em tests/StormSchedule.spec.luau.

export type Timing = {
	StartDelay: number,
	WindowInterval: number,
	ChandelierStart: number,
	ChandelierInterval: number,
	QuietTail: number,
}

export type Plan = {
	windows: { number },
	chandeliers: { number },
}

local StormSchedule = {}

-- `count` horários a partir de `first`, até `interval` de distância, todos
-- até `last`.
local function spread(count: number, first: number, interval: number, last: number): { number }
	local times: { number } = {}
	if count <= 0 or first > last then
		return times
	end
	local step = if count > 1 then math.min(interval, (last - first) / (count - 1)) else 0
	for index = 1, count do
		table.insert(times, first + (index - 1) * step)
	end
	return times
end

function StormSchedule.plan(windowCount: number, chandelierCount: number, duration: number, timing: Timing): Plan
	local last = duration - timing.QuietTail
	return {
		windows = spread(windowCount, timing.StartDelay, timing.WindowInterval, last),
		chandeliers = spread(chandelierCount, timing.ChandelierStart, timing.ChandelierInterval, last),
	}
end

return table.freeze(StormSchedule)
