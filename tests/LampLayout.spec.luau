--!strict

-- Testes dos postes de lampião do lado de fora (rodar com: lune run tests/LampLayout.spec.luau).

local LampLayout = require("../src/server/data/LampLayout")

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

-- Retângulo de 100 x 40 com postes a 10 da parede e no máximo 30 entre si:
-- 120 x 60 em volta, 4 postes em cada lado comprido e 2 em cada curto.
local spots = LampLayout.around(0, 0, 100, 40, 10, 30)
check("one post per corner and per gap", #spots == 12)

local outside, farOrClose, corners = 0, 0, 0
for _, spot in ipairs(spots) do
	if spot.x >= 0 and spot.x <= 100 and spot.z >= 0 and spot.z <= 40 then
		outside += 1
	end
	local dx = math.max(0 - spot.x, 0, spot.x - 100)
	local dz = math.max(0 - spot.z, 0, spot.z - 40)
	if math.abs(math.max(dx, dz) - 10) > 1e-6 then
		farOrClose += 1
	end
	if (spot.x == -10 or spot.x == 110) and (spot.z == -10 or spot.z == 50) then
		corners += 1
	end
end
check("no post inside the building", outside == 0)
check("every post sits at the offset", farOrClose == 0)
check("each corner gets exactly one post", corners == 4)

local gaps = 0
for index, spot in ipairs(spots) do
	local nextSpot = spots[index % #spots + 1]
	if math.sqrt((nextSpot.x - spot.x) ^ 2 + (nextSpot.z - spot.z) ^ 2) > 30 + 1e-6 then
		gaps += 1
	end
end
check("posts never further apart than the spacing", gaps == 0)

-- Acesos à noite, apagados de dia.
check("lit after dusk", LampLayout.isLit(19, 17.6, 6.4))
check("lit at midnight", LampLayout.isLit(0, 17.6, 6.4))
check("lit before dawn", LampLayout.isLit(6, 17.6, 6.4))
check("off in the morning", not LampLayout.isLit(6.4, 17.6, 6.4))
check("off at noon", not LampLayout.isLit(12, 17.6, 6.4))
check("on exactly at dusk", LampLayout.isLit(17.6, 17.6, 6.4))
check("daytime window works too", LampLayout.isLit(10, 8, 16) and not LampLayout.isLit(20, 8, 16))

print(`LampLayout: {passed} passed, {failures} failed`)
if failures > 0 then
	error("LampLayout tests failed")
end
