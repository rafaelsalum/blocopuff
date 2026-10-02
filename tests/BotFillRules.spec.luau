-- Testes das regras de preenchimento com bots RoboPuff (Fase 5B).
-- Rodar: lune run tests/BotFillRules.spec

local BotFillRules = require("../src/server/data/BotFillRules")

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

local fill = {
	Enabled = true,
	TargetCombatants = 4,
	MaxBots = 3,
	WaitSeconds = 12,
}

-- Quantos bots completam a partida.
check("no humans, no bots", BotFillRules.desiredBots(0, fill) == 0)
check("1 human gets 3 bots", BotFillRules.desiredBots(1, fill) == 3)
check("2 humans get 2 bots", BotFillRules.desiredBots(2, fill) == 2)
check("3 humans get 1 bot", BotFillRules.desiredBots(3, fill) == 1)
check("4 humans get no bots", BotFillRules.desiredBots(4, fill) == 0)
check("12 humans get no bots", BotFillRules.desiredBots(12, fill) == 0)
check("disabled never fills", BotFillRules.desiredBots(1, { Enabled = false, TargetCombatants = 4, MaxBots = 3, WaitSeconds = 12 }) == 0)
check("max bots caps the fill", BotFillRules.desiredBots(1, { Enabled = true, TargetCombatants = 6, MaxBots = 3, WaitSeconds = 12 }) == 3)
check("negative humans is safe", BotFillRules.desiredBots(-2, fill) == 0)

-- Quando os bots podem chegar.
check("waits before the first fill", not BotFillRules.canFill(1, 5, false, fill))
check("fills after the wait", BotFillRules.canFill(1, 12, false, fill))
check("warm fill does not wait", BotFillRules.canFill(1, 0, true, fill))
check("no fill without humans even if warm", not BotFillRules.canFill(0, 100, true, fill))
check("no fill with a full match", not BotFillRules.canFill(4, 100, true, fill))
check("disabled never can fill", not BotFillRules.canFill(1, 100, true, { Enabled = false, TargetCombatants = 4, MaxBots = 3, WaitSeconds = 12 }))

-- Ajuste do grupo de bots já no mirante: quantos entram (+) ou saem (-).
check("adds missing bots", BotFillRules.adjustment(1, 0, true, fill) == 3)
check("keeps a matching pool", BotFillRules.adjustment(1, 3, true, fill) == 0)
check("a new human replaces a bot", BotFillRules.adjustment(2, 3, true, fill) == -1)
check("full match sends all bots away", BotFillRules.adjustment(4, 3, true, fill) == -3)
check("no humans sends all bots away", BotFillRules.adjustment(0, 2, true, fill) == -2)
check("not allowed yet keeps bots away", BotFillRules.adjustment(1, 0, false, fill) == 0)
check("not allowed still trims extras", BotFillRules.adjustment(4, 1, false, fill) == -1)

print(`BotFillRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} BotFillRules checks failed`)
end
