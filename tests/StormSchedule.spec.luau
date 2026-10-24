--!strict

-- Testes dos horários da Tempestade do Caos Final (Fase 5, entrega 5.7)
-- (rodar com: lune run tests/StormSchedule.spec.luau).

local StormSchedule = require("../src/server/data/StormSchedule")

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

local TIMING: StormSchedule.Timing = {
	StartDelay = 2,
	WindowInterval = 2.5,
	ChandelierStart = 4,
	ChandelierInterval = 5,
	QuietTail = 3,
}

local roomy = StormSchedule.plan(4, 2, 30, TIMING)
check("roomy chaos keeps the window interval", #roomy.windows == 4 and roomy.windows[1] == 2 and roomy.windows[4] == 9.5)
check("roomy chaos keeps the chandelier interval", #roomy.chandeliers == 2 and roomy.chandeliers[1] == 4 and roomy.chandeliers[2] == 9)

local tight = StormSchedule.plan(9, 2, 20, TIMING)
check("tight chaos fits every window", #tight.windows == 9)
check("tight windows end before the quiet tail", tight.windows[9] <= 17)
check("tight windows keep their order", tight.windows[2] > tight.windows[1])
check("tight windows are squeezed", tight.windows[2] - tight.windows[1] < 2.5)

local tiny = StormSchedule.plan(3, 2, 4, TIMING)
check("no time for the storm", #tiny.windows == 0 and #tiny.chandeliers == 0)

local cramped = StormSchedule.plan(0, 3, 12, TIMING)
check("chandeliers squeezed to fit", #cramped.chandeliers == 3 and cramped.chandeliers[3] <= 9)
check("no windows when none are ready", #cramped.windows == 0)

local single = StormSchedule.plan(1, 1, 10, TIMING)
check("a single window starts after the delay", single.windows[1] == 2)
check("a single chandelier starts at its time", single.chandeliers[1] == 4)

print(`StormSchedule: {passed} passed, {failures} failed`)
if failures > 0 then
	error("StormSchedule tests failed")
end
