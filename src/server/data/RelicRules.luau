--!strict

-- Regras puras das Relíquias (Fase 5C.2): pegar uma relíquia do álbum,
-- pegar a Relíquia do Dia e sortear o esconderijo do dia. Sem estado e sem
-- Roblox (testes no Lune: tests/RelicRules.spec.luau); devolvem tabelas
-- NOVAS.

export type Rewards = {
	RelicTickets: number,
	RoomTickets: number,
	DailyTickets: number,
	DailyGoal: number,
	DailyGoalTickets: number,
}

export type Outcome = {
	tickets: number,
	-- Relíquias do cômodo e do álbum já com a nova.
	roomCount: number,
	total: number,
	roomCompleted: boolean,
	albumCompleted: boolean,
}

export type DailyOutcome = {
	count: number,
	tickets: number,
	goalReached: boolean,
}

local RelicRules = {}

local function countOwned(owned: { [string]: number }, ids: { string }): number
	local count = 0
	for _, id in ipairs(ids) do
		if owned[id] ~= nil then
			count += 1
		end
	end
	return count
end

-- Pega `relicId` (do cômodo `roomIds`, entre todas `allIds`). Devolve o
-- novo mapa de relíquias e o resultado, ou nil se já tinha ou o id não
-- existe.
function RelicRules.collect(
	relics: { [string]: number },
	relicId: string,
	roomIds: { string },
	allIds: { string },
	rewards: Rewards,
	now: number
): ({ [string]: number }?, Outcome?)
	if relics[relicId] ~= nil or table.find(roomIds, relicId) == nil or table.find(allIds, relicId) == nil then
		return nil, nil
	end
	local updated = table.clone(relics)
	updated[relicId] = now
	local roomCount = countOwned(updated, roomIds)
	local total = countOwned(updated, allIds)
	local roomCompleted = roomCount == #roomIds
	local albumCompleted = total == #allIds
	local tickets = rewards.RelicTickets + (if roomCompleted then rewards.RoomTickets else 0)
	return updated, {
		tickets = tickets,
		roomCount = roomCount,
		total = total,
		roomCompleted = roomCompleted,
		albumCompleted = albumCompleted,
	}
end

-- Relíquia do Dia: uma vez por dia do jogo. `lastDay` é o último dia em
-- que pegou e `count` quantas já pegou no total.
function RelicRules.collectDaily(lastDay: number, count: number, today: number, rewards: Rewards): DailyOutcome?
	if today <= 0 or lastDay >= today then
		return nil
	end
	local newCount = count + 1
	local goalReached = newCount == rewards.DailyGoal
	return {
		count = newCount,
		tickets = rewards.DailyTickets + (if goalReached then rewards.DailyGoalTickets else 0),
		goalReached = goalReached,
	}
end

-- Embaralha 1..n de forma fixa pela semente (gerador congruente simples:
-- o mesmo resultado em qualquer servidor).
local function shuffled(seed: number, n: number): { number }
	local list: { number } = {}
	for index = 1, n do
		list[index] = index
	end
	local state = (seed * 7919 + 104729) % 2147483647
	for index = n, 2, -1 do
		state = (state * 48271) % 2147483647
		local other = (state % index) + 1
		list[index], list[other] = list[other], list[index]
	end
	return list
end

-- Ordem dos esconderijos num bloco de `n` dias: todos aparecem uma vez, e
-- o primeiro do bloco nunca repete o último do bloco anterior.
local function blockOrder(block: number, n: number): { number }
	local order = shuffled(block, n)
	local previous = shuffled(block - 1, n)
	if order[1] == previous[n] then
		order[1], order[2] = order[2], order[1]
	end
	return order
end

-- Esconderijo da Relíquia do Dia (índice em 1..`spotCount`): o mesmo em
-- qualquer servidor no mesmo dia e nunca igual ao do dia anterior.
function RelicRules.dailySpotIndex(day: number, spotCount: number): number
	if spotCount <= 1 then
		return 1
	end
	local block = math.floor(day / spotCount)
	return blockOrder(block, spotCount)[(day % spotCount) + 1]
end

return table.freeze(RelicRules)
