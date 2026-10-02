-- Testes do funil da primeira sessão e do tipo da primeira partida.
-- Rodar: lune run tests/OnboardingRules.spec

local OnboardingRules = require("../src/server/data/OnboardingRules")

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

local Step = OnboardingRules.Step
local FirstMatch = OnboardingRules.FirstMatch

-- Passos uma vez só.
local mask, isNew = OnboardingRules.mark(0, Step.Joined)
check("first step is new", isNew and OnboardingRules.has(mask, Step.Joined))
mask, isNew = OnboardingRules.mark(mask, Step.Joined)
check("same step never repeats", not isNew and mask == 1)
mask, isNew = OnboardingRules.mark(mask, Step.FirstBlockDown)
check("steps can arrive out of order", isNew and OnboardingRules.has(mask, Step.FirstBlockDown) and not OnboardingRules.has(mask, Step.FirstShot))
local before = mask
mask, isNew = OnboardingRules.mark(mask, 0)
check("invalid step ignored", not isNew and mask == before)
mask, isNew = OnboardingRules.mark(mask, #OnboardingRules.Steps + 1)
check("step past the end ignored", not isNew and mask == before)

local all = 0
for step = 1, #OnboardingRules.Steps do
	all = OnboardingRules.mark(all, step)
end
check("all steps equal AllSteps", all == OnboardingRules.AllSteps)
check("step names match ids", OnboardingRules.Steps[Step.ReturnedAnotherDay] == "ReturnedAnotherDay" and OnboardingRules.Steps[Step.Joined] == "Joined")

-- Perfis antigos ficam fora do funil.
check("new player starts empty", OnboardingRules.initial(0, 0) == 0)
check("veteran gets every step", OnboardingRules.initial(0, 12) == OnboardingRules.AllSteps)
check("player mid funnel keeps progress", OnboardingRules.initial(5, 3) == 5)
check("garbage mask is clamped", OnboardingRules.initial(1e12, 0) == OnboardingRules.AllSteps)

-- Passos comprovados pelo perfil.
local now = 1_000_000
local steps = OnboardingRules.stepsFromProfile(0, now, now)
check("fresh profile proves nothing", #steps == 0)
steps = OnboardingRules.stepsFromProfile(1, now - 100, now)
check("one match proves finished", #steps == 1 and steps[1] == Step.MatchFinished)
steps = OnboardingRules.stepsFromProfile(2, now - 86400, now)
check("two matches and a day later", #steps == 3 and steps[2] == Step.SecondMatch and steps[3] == Step.ReturnedAnotherDay)

-- Tipo da primeira partida.
check("first match with bots", OnboardingRules.firstMatchKind(FirstMatch.None, 0, 1, true) == FirstMatch.Bots)
check("first match humans only", OnboardingRules.firstMatchKind(FirstMatch.None, 0, 1, false) == FirstMatch.Humans)
check("later matches keep the first", OnboardingRules.firstMatchKind(FirstMatch.Humans, 1, 1, true) == FirstMatch.Humans)
check("veteran without record stays none", OnboardingRules.firstMatchKind(FirstMatch.None, 5, 1, true) == FirstMatch.None)
check("round without a match changes nothing", OnboardingRules.firstMatchKind(FirstMatch.None, 0, 0, true) == FirstMatch.None)
check("labels", OnboardingRules.firstMatchLabel(FirstMatch.Bots) == "FirstBots"
	and OnboardingRules.firstMatchLabel(FirstMatch.Humans) == "FirstHumans"
	and OnboardingRules.firstMatchLabel(FirstMatch.None) == "FirstNone")

print(`OnboardingRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} OnboardingRules checks failed`)
end
