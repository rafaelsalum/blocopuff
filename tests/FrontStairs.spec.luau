--!strict

-- Testes da escadaria da porta principal (rodar com: lune run tests/FrontStairs.spec.luau).

local FrontStairs = require("../src/shared/modules/FrontStairs")

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

local SETTINGS: FrontStairs.Settings = { Landing = 8, Width = 18, Rise = 1, Run = 2 }

-- Piso a 134.5, chão a 118.6: 16 degraus de no máximo 1 stud.
local plan = FrontStairs.plan(125, 134.5, 67, 118.6, SETTINGS)
check("one piece per step above the ground", #plan.steps == 15)
check("stairs are as wide as asked", plan.maxX - plan.minX == 18 and (plan.minX + plan.maxX) / 2 == 125)
check("landing leaves the wall", plan.landingEnd == 75)
check("first step starts at the landing", plan.steps[1].minZ == 75)

local falling, rises, runs = true, true, true
local previous = 134.5
for _, step in ipairs(plan.steps) do
	if step.top >= previous then
		falling = false
	end
	if previous - step.top > SETTINGS.Rise + 1e-6 then
		rises = false
	end
	if math.abs(step.maxZ - step.minZ - SETTINGS.Run) > 1e-6 then
		runs = false
	end
	previous = step.top
end
check("each step goes down", falling)
check("no step is taller than the rise", rises)
check("each step is one run deep", runs)
check("last step is one rise above the ground", math.abs(previous - 118.6 - (134.5 - 118.6) / 16) < 1e-6)
check("steps follow one another", plan.steps[2].minZ == plan.steps[1].maxZ)
check("foot is on the ground after the last step", plan.foot.y == 118.6 and plan.foot.z == plan.steps[#plan.steps].maxZ)

-- Piso no nível do chão: sem degraus, o pé fica no fim do patamar.
local flat = FrontStairs.plan(0, 100, 0, 100, SETTINGS)
check("level floor needs no steps", #flat.steps == 0 and flat.foot.z == 8)

-- Desnível exato: sem degrau sobrando.
local exact = FrontStairs.plan(0, 104, 0, 100, SETTINGS)
check("exact drop uses whole steps", #exact.steps == 3 and exact.steps[3].top == 101)

print(`FrontStairs: {passed} passed, {failures} failed`)
if failures > 0 then
	error("FrontStairs tests failed")
end
