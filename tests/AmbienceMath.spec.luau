--!strict

-- Testes das contas do ambiente do Casarão: relógio da torre, balanço dos
-- lustres e olhar dos retratos (rodar com: lune run tests/AmbienceMath.spec.luau).

local AmbienceMath = require("../src/shared/modules/AmbienceMath")

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

-- Relógio: todo mundo no mesmo período pelo horário do servidor.
check("slot start", AmbienceMath.clockSlot(600, 300) == 2)
check("slot just before the next", AmbienceMath.clockSlot(899.9, 300) == 2)
check("slot next", AmbienceMath.clockSlot(900, 300) == 3)
check("never strikes on the first check", not AmbienceMath.shouldStrike(nil, 5))
check("no strike in the same slot", not AmbienceMath.shouldStrike(5, 5))
check("strikes on a new slot", AmbienceMath.shouldStrike(5, 6))
check("no strike going back in time", not AmbienceMath.shouldStrike(6, 5))

-- Força do balanço.
check("full strength at the door", AmbienceMath.swingStrength(0, 40) == 1)
check("half radius keeps most strength", near(AmbienceMath.swingStrength(20, 40), 0.75))
check("zero at the radius", AmbienceMath.swingStrength(40, 40) == 0)
check("zero beyond the radius", AmbienceMath.swingStrength(55, 40) == 0)
check("zero radius never swings", AmbienceMath.swingStrength(0, 0) == 0)
check("strength decreases", AmbienceMath.swingStrength(10, 40) > AmbienceMath.swingStrength(30, 40))

-- Ângulo do balanço: começa em zero, oscila e vai parando.
check("angle starts at zero", AmbienceMath.swingAngle(10, 0, 2, 2.4) == 0)
check("first quarter swings forward", AmbienceMath.swingAngle(10, 0.6, 2, 2.4) > 0)
check("third quarter swings back", AmbienceMath.swingAngle(10, 1.8, 2, 2.4) < 0)
check("dies down", math.abs(AmbienceMath.swingAngle(10, 0.6 + 2.4 * 3, 2, 2.4)) < math.abs(AmbienceMath.swingAngle(10, 0.6, 2, 2.4)) * 0.05)
check("never above the amplitude", math.abs(AmbienceMath.swingAngle(10, 0.6, 2, 2.4)) <= 10)
check("negative time is still", AmbienceMath.swingAngle(10, -1, 2, 2.4) == 0)
check("bad damping is still", AmbienceMath.swingAngle(10, 1, 0, 2.4) == 0)

-- Olhar do retrato (a frente da tela é −z; direita de quem olha é −x).
local x, y = AmbienceMath.lookOffset(0, 0, -5, 36, 2.5)
check("straight ahead looks forward", x == 0 and y == 0)
x, y = AmbienceMath.lookOffset(4, 0, -5, 36, 2.5)
check("target at part +X looks to the viewer's left", x < 0 and y == 0)
x, y = AmbienceMath.lookOffset(-4, 0, -5, 36, 2.5)
check("target at part -X looks to the viewer's right", x > 0)
x, y = AmbienceMath.lookOffset(0, -3, -5, 36, 2.5)
check("target below looks down", y > 0 and x == 0)
x, y = AmbienceMath.lookOffset(0, 0, 5, 36, 2.5)
check("target behind the canvas is ignored", x == 0 and y == 0)
x, y = AmbienceMath.lookOffset(30, 0, -30, 36, 2.5)
check("target too far is ignored", x == 0 and y == 0)
x, y = AmbienceMath.lookOffset(-20, -20, -1, 36, 2.5)
check("look is clamped to the eye", near(math.sqrt(x * x + y * y), 1))

print(`AmbienceMath: {passed} passed, {failures} failed`)
if failures > 0 then
	error("AmbienceMath tests failed")
end
