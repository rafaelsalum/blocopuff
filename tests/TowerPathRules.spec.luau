--!strict

-- Testes do caminho do Saguão da Torre até a ilha e do portão da largada
-- (rodar com: lune run tests/TowerPathRules.spec.luau).

local TowerPathRules = require("../src/shared/modules/TowerPathRules")

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

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) < (tolerance or 1e-6)
end

-- Portão: na borda da ilha, virado para quem chega.
do
	local angle, x, z = TowerPathRules.gate(0, 0, 10, 0, 50)
	check("gate straight south angle", near(angle, math.pi / 2))
	check("gate straight south x", near(x, 0))
	check("gate straight south z", near(z, 10))
end
do
	local angle, x, z = TowerPathRules.gate(180, -230, 85, 147, -95)
	check("gate on the rim", near(math.sqrt((x - 180) ^ 2 + (z + 230) ^ 2), 85, 1e-4))
	check("gate faces the hall", angle > math.pi / 2 and angle < math.pi * 0.65)
	check("gate between hall and tower x", x > 147 and x < 180)
end
do
	-- Quem chega exatamente do centro não quebra (vai para +X).
	local angle, x, z = TowerPathRules.gate(5, 5, 3, 5, 5)
	check("gate degenerate angle", near(angle, 0))
	check("gate degenerate point", near(x, 8) and near(z, 5))
end

-- Inclinação da ponte em graus.
check("slope flat", near(TowerPathRules.slopeDegrees(0, 0, 0, 10, 0, 0), 0))
check("slope 45", near(TowerPathRules.slopeDegrees(0, 10, 0, 10, 0, 0), 45))
check("slope ignores direction", near(TowerPathRules.slopeDegrees(10, 0, 0, 0, 10, 0), 45))
check("slope vertical", near(TowerPathRules.slopeDegrees(0, 0, 0, 0, 5, 0), 90))

-- Portão da largada: só passa quem corre na Corrida e não saiu.
check("racer passes", TowerPathRules.startGateOpen(true, false, "Race"))
check("lobby blocked", not TowerPathRules.startGateOpen(false, false, "Race"))
check("eliminated blocked", not TowerPathRules.startGateOpen(true, true, "Race"))
check("other mode blocked", not TowerPathRules.startGateOpen(true, false, "Arena"))
check("no mode blocked", not TowerPathRules.startGateOpen(true, false, nil))

print(`TowerPathRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error("TowerPathRules tests failed")
end
