-- Testes das recompensas em partidas com bots RoboPuff (Fase 5B).
-- Rodar: lune run tests/BotRewardRules.spec

local BotRewardRules = require("../src/server/data/BotRewardRules")

local failures = 0
local passed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

local config = {
	MinHumansForStats = 2,
	BotMatchMinMultiplier = 0.8,
	BotKnockoutXpFactor = 0.5,
}

local function round(overrides: { [string]: any }): BotRewardRules.RoundInput
	local input: { [string]: any } = {
		won = false,
		podium = false,
		humans = 1,
		bots = 3,
		knockouts = 0,
		botKnockouts = 0,
		beginner = false,
	}
	for key, value in pairs(overrides) do
		input[key] = value
	end
	return input :: any
end

-- Partida sem bots: nada muda.
local plain = BotRewardRules.evaluate(round({ bots = 0, humans = 4, won = true, podium = true, knockouts = 3 }), config)
check("no bots: win counts", plain.stats.wins == 1)
check("no bots: top3 counts", plain.stats.top3 == 1)
check("no bots: knockouts count", plain.stats.knockouts == 3)
check("no bots: no bot win", plain.stats.botWins == 0)
check("no bots: win ticket", plain.ticketWins == 1 and not plain.cappedTickets)
check("no bots: normal xp", plain.xp.minMultiplier == nil and plain.xp.multiplierCount == nil and plain.xp.botKnockouts == 0)

-- Sozinho com bots: vitória vira botWins, ticket com limite diário.
local solo = BotRewardRules.evaluate(round({ won = true, podium = true, knockouts = 3, botKnockouts = 3 }), config)
check("solo: win does not count as a real win", solo.stats.wins == 0)
check("solo: bot win is recorded", solo.stats.botWins == 1)
check("solo: podium does not count", solo.stats.top3 == 0)
check("solo: bot knockouts never count", solo.stats.knockouts == 0)
check("solo: win ticket inside the daily cap", solo.ticketWins == 1 and solo.cappedTickets)
check("solo: no top3 ticket", solo.ticketTop3 == 0)
check("solo: xp multiplier uses humans", solo.xp.multiplierCount == 1)
check("solo: xp multiplier floor", solo.xp.minMultiplier == 0.8)
check("solo: bot knockouts give half xp", solo.xp.knockouts == 0 and solo.xp.botKnockouts == 3 and solo.xp.botKnockoutFactor == 0.5)

-- Dois humanos e bots: vencer valeu de verdade (havia outro humano).
local duo = BotRewardRules.evaluate(round({ humans = 2, bots = 2, won = true, podium = true, knockouts = 3, botKnockouts = 2 }), config)
check("duo: win counts", duo.stats.wins == 1 and duo.stats.botWins == 0)
check("duo: top3 counts", duo.stats.top3 == 1)
check("duo: only human knockouts count", duo.stats.knockouts == 1)
check("duo: full win ticket", duo.ticketWins == 1 and not duo.cappedTickets)
check("duo: top3 ticket", duo.ticketTop3 == 1)
check("duo: xp splits knockouts", duo.xp.knockouts == 1 and duo.xp.botKnockouts == 2)

-- Novato: recompensa cheia (XP e tickets), estatísticas continuam filtradas.
local rookie = BotRewardRules.evaluate(round({ won = true, podium = true, knockouts = 2, botKnockouts = 2, beginner = true }), config)
check("rookie: stats still filtered", rookie.stats.wins == 0 and rookie.stats.botWins == 1 and rookie.stats.knockouts == 0)
check("rookie: full win ticket", rookie.ticketWins == 1 and not rookie.cappedTickets)
check("rookie: top3 ticket", rookie.ticketTop3 == 1)
check("rookie: full xp multiplier", rookie.xp.multiplierCount == 4 and rookie.xp.minMultiplier == nil)
check("rookie: full knockout xp", rookie.xp.knockouts == 2 and rookie.xp.botKnockouts == 0)

-- Perdeu com bots: nada de vitória.
local lost = BotRewardRules.evaluate(round({ knockouts = 1, botKnockouts = 1 }), config)
check("lost: no wins", lost.stats.wins == 0 and lost.stats.botWins == 0 and lost.ticketWins == 0)
check("lost solo: round tickets still capped", lost.cappedTickets)
local lostDuo = BotRewardRules.evaluate(round({ humans = 2, bots = 2 }), config)
check("lost duo: tickets not capped", not lostDuo.cappedTickets)

-- Dados incoerentes não geram valor negativo.
local odd = BotRewardRules.evaluate(round({ knockouts = 1, botKnockouts = 4 }), config)
check("odd: human knockouts never negative", odd.stats.knockouts == 0 and odd.xp.knockouts == 0)
check("odd: bot knockouts capped by total", odd.xp.botKnockouts == 1)

print(`BotRewardRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} BotRewardRules checks failed`)
end
