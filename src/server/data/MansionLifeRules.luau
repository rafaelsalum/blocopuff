--!strict

-- Regras puras da Vida no Casarão (Fase 5C.4): limites diários do
-- Fantasminha e do presente do Barão, sorteios de cômodo e de intervalo.

local MansionLifeRules = {}

-- Quantos já pegou hoje (o contador zera quando o dia muda).
function MansionLifeRules.usedToday(day: number, count: number, today: number): number
	return if day == today then math.max(count, 0) else 0
end

-- Conta mais um no dia `today`. Devolve o novo contador, ou nil se o
-- limite do dia já foi alcançado.
function MansionLifeRules.claimDaily(day: number, count: number, today: number, limit: number): number?
	local used = MansionLifeRules.usedToday(day, count, today)
	if used >= limit then
		return nil
	end
	return used + 1
end

-- O carinho vira presente? `roll` em [0, 1).
function MansionLifeRules.giftRoll(roll: number, chance: number): boolean
	return roll < chance
end

-- Intervalo sorteado entre `min` e `max` (`roll` em [0, 1)).
function MansionLifeRules.interval(roll: number, min: number, max: number): number
	local low = math.min(min, max)
	local high = math.max(min, max)
	return low + math.clamp(roll, 0, 1) * (high - low)
end

-- Cômodo sorteado (`roll` em [0, 1)), sem repetir o último quando há outro.
function MansionLifeRules.pickRoom(rooms: { string }, last: string?, roll: number): string?
	local options: { string } = {}
	for _, room in ipairs(rooms) do
		if room ~= last then
			table.insert(options, room)
		end
	end
	if #options == 0 then
		options = rooms
	end
	if #options == 0 then
		return nil
	end
	local index = math.clamp(math.floor(math.clamp(roll, 0, 1) * #options) + 1, 1, #options)
	return options[index]
end

return table.freeze(MansionLifeRules)
