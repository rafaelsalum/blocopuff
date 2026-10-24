--!strict

-- Testes do céu na hora de Brasília (rodar com: lune run tests/DayCycle.spec.luau).

local DayCycle = require("../src/server/data/DayCycle")

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
	return math.abs(a - b) < 1e-3
end

-- Hora de Brasília (UTC-3) a partir do relógio do servidor (UTC).
check("epoch zero is 21h in Brasilia", near(DayCycle.clockAt(0, -3), 21))
check("23:11 UTC is 20:11 in Brasilia", near(DayCycle.clockAt(1792883460, -3), 20 + 11 / 60))
check("3h UTC wraps to midnight", near(DayCycle.clockAt(3 * 3600, -3), 0))
check("clock stays inside the day", DayCycle.clockAt(1792883460 + 5 * 3600, -3) < 24)

-- Dia, tarde e noite.
check("7h is morning", DayCycle.phaseOf(7) == "Morning")
check("6h starts the morning", DayCycle.phaseOf(6) == "Morning")
check("12h starts the afternoon", DayCycle.phaseOf(12) == "Afternoon")
check("17h is afternoon", DayCycle.phaseOf(17.9) == "Afternoon")
check("18h starts the night", DayCycle.phaseOf(18) == "Night")
check("3h is night", DayCycle.phaseOf(3) == "Night")

local function key(hour: number, brightness: number): DayCycle.LightKey
	return {
		hour = hour,
		brightness = brightness,
		outdoorAmbient = { brightness * 100, 0, 0 },
		atmosphereColor = { 0, 0, 0 },
		atmosphereDecay = { 0, 0, 0 },
		atmosphereDensity = 0.3,
		atmosphereHaze = 0,
		atmosphereGlare = 0,
	}
end

local keys = { key(6, 1), key(18, 0) }
check("exact key keeps its light", near(DayCycle.lightAt(6, keys).brightness, 1))
check("halfway between keys mixes the light", near(DayCycle.lightAt(12, keys).brightness, 0.5))
check("colors mix with the light", near(DayCycle.lightAt(12, keys).outdoorAmbient[1], 50))
check("midnight sits between yesterday's last key and the first", near(DayCycle.lightAt(0, keys).brightness, 0.5))
check("before the first key heads from yesterday's last to it", DayCycle.lightAt(3, keys).brightness > 0.5 and DayCycle.lightAt(3, keys).brightness < 1)
check("change is eased near a key", DayCycle.lightAt(7, keys).brightness > 1 - 1 / 12)

local single = { key(10, 0.7) }
check("a single key lights the whole day", near(DayCycle.lightAt(22, single).brightness, 0.7))

print(`DayCycle: {passed} passed, {failures} failed`)
if failures > 0 then
	error("DayCycle tests failed")
end
