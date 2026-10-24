--!strict

-- Testes dos Momentos Puff e das conquistas das armadilhas (Fase 5.8)
-- (rodar com: lune run tests/TrapMomentRules.spec.luau).

local TrapMomentRules = require("../src/server/data/TrapMomentRules")

local passed = 0
local failures = 0
local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

-- Cada armadilha que derruba alguém tem o seu Momento Puff.
check("window moment", TrapMomentRules.momentFor("Window") == "TrapWindow")
check("rug moment", TrapMomentRules.momentFor("Rug") == "TrapRug")
check("chandelier moment", TrapMomentRules.momentFor("Chandelier") == "TrapChandelier")
check("fireplace moment", TrapMomentRules.momentFor("Fireplace") == "TrapFireplace")
check("unknown trap has no moment", TrapMomentRules.momentFor("Barrel") == nil)

-- Vidraceiro: 5 janelas quebradas de longe na mesma partida.
check("four windows are not enough", TrapMomentRules.secretForWindows(4) == nil)
check("fifth window gives glazier", TrapMomentRules.secretForWindows(5) == "vidraceiro")
check("more windows still glazier", TrapMomentRules.secretForWindows(7) == "vidraceiro")

-- Derrubadas: tapete dá Puxa-Tapete na hora; lustre só com 2 vítimas do
-- mesmo lustre.
check("rug knockout gives rug puller", TrapMomentRules.secretForKnockout("Rug", 1) == "puxa_tapete")
check("one chandelier victim is not enough", TrapMomentRules.secretForKnockout("Chandelier", 1) == nil)
check("two victims of the same chandelier", TrapMomentRules.secretForKnockout("Chandelier", 2) == "lustre_na_cabeca")
check("window knockout has no secret", TrapMomentRules.secretForKnockout("Window", 3) == nil)
check("fireplace knockout has no secret", TrapMomentRules.secretForKnockout("Fireplace", 1) == nil)

-- Nas estatísticas (desafios diários) só contam derrubadas de humanos, como
-- nas derrubadas comuns.
check("human victim counts", TrapMomentRules.countsForStats(false))
check("bot victim does not count", not TrapMomentRules.countsForStats(true))

print(`TrapMomentRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error("TrapMomentRules tests failed")
end
