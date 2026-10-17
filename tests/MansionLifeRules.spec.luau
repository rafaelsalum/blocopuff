--!strict

-- Testes da Vida no Casarão: limites do dia, sorteios e o caminho do
-- passeio do Barão (rodar com: lune run tests/MansionLifeRules.spec.luau).

local MansionLifeRules = require("../src/server/data/MansionLifeRules")
local WalkPath = require("../src/shared/modules/WalkPath")

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

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- Limite do dia.
check("first claim of the day", MansionLifeRules.claimDaily(0, 0, 10, 5) == 1)
check("counts up on the same day", MansionLifeRules.claimDaily(10, 3, 10, 5) == 4)
check("last claim reaches the limit", MansionLifeRules.claimDaily(10, 4, 10, 5) == 5)
check("blocked at the limit", MansionLifeRules.claimDaily(10, 5, 10, 5) == nil)
check("blocked above the limit", MansionLifeRules.claimDaily(10, 9, 10, 5) == nil)
check("new day resets the count", MansionLifeRules.claimDaily(9, 5, 10, 5) == 1)
check("zero limit never claims", MansionLifeRules.claimDaily(0, 0, 10, 0) == nil)
check("used today on another day is zero", MansionLifeRules.usedToday(9, 4, 10) == 0)
check("used today ignores negatives", MansionLifeRules.usedToday(10, -3, 10) == 0)

-- Presente e intervalo.
check("gift below the chance", MansionLifeRules.giftRoll(0.05, 0.1))
check("no gift at the chance", not MansionLifeRules.giftRoll(0.1, 0.1))
check("no gift with zero chance", not MansionLifeRules.giftRoll(0, 0))
check("interval low end", MansionLifeRules.interval(0, 180, 300) == 180)
check("interval high end", MansionLifeRules.interval(1, 180, 300) == 300)
check("interval middle", MansionLifeRules.interval(0.5, 180, 300) == 240)
check("interval swapped bounds", MansionLifeRules.interval(0, 300, 180) == 180)
check("interval clamps the roll", MansionLifeRules.interval(2, 10, 20) == 20)

-- Cômodo sorteado.
local rooms = { "A", "B", "C" }
check("never repeats the last room", (function()
	for roll = 0, 99 do
		if MansionLifeRules.pickRoom(rooms, "B", roll / 100) == "B" then
			return false
		end
	end
	return true
end)())
check("covers every other room", MansionLifeRules.pickRoom(rooms, "B", 0) == "A" and MansionLifeRules.pickRoom(rooms, "B", 0.99) == "C")
check("roll 1 stays in range", MansionLifeRules.pickRoom(rooms, nil, 1) == "C")
check("single room repeats", MansionLifeRules.pickRoom({ "A" }, "A", 0.5) == "A")
check("no rooms gives nil", MansionLifeRules.pickRoom({}, nil, 0.5) == nil)

-- Caminho: 10 studs a 5/s (2 s), parada de 1 s, mais 5 studs (1 s).
local legs: { WalkPath.Leg } = { { length = 10, wait = 1 }, { length = 5, wait = 0 } }
check("duration sums travel and waits", near(WalkPath.duration(legs, 5), 4))
local start = WalkPath.locate(legs, 5, 0)
check("starts at the first leg", start.leg == 1 and start.fraction == 0 and not start.waiting and not start.done)
local midway = WalkPath.locate(legs, 5, 1)
check("halfway through the first leg", midway.leg == 1 and near(midway.fraction, 0.5))
local waiting = WalkPath.locate(legs, 5, 2.5)
check("waits at the end of the first leg", waiting.leg == 1 and waiting.fraction == 1 and waiting.waiting)
local second = WalkPath.locate(legs, 5, 3.5)
check("halfway through the second leg", second.leg == 2 and near(second.fraction, 0.5) and not second.waiting)
local finished = WalkPath.locate(legs, 5, 4)
check("done at the end", finished.done and finished.leg == 2 and finished.fraction == 1)
check("negative time is the start", WalkPath.locate(legs, 5, -3).fraction == 0)
check("no legs is done", WalkPath.locate({}, 5, 1).done)
check("zero speed is done", WalkPath.locate(legs, 0, 1).done)
local zero = WalkPath.locate({ { length = 0, wait = 2 }, { length = 4, wait = 0 } }, 2, 1)
check("zero-length leg only waits", zero.leg == 1 and zero.waiting)

print(`MansionLifeRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error("MansionLifeRules tests failed")
end
