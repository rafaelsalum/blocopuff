--!strict

-- Testes do Mapa do Casarão (Fase 5C.4)
-- (rodar com: lune run tests/MansionMapRules.spec.luau).

local MansionMapConfig = require("../src/shared/config/MansionMapConfig")
local MansionMapRules = require("../src/shared/modules/MansionMapRules")

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

local ROOMS = MansionMapConfig.Rooms

local count, total = MansionMapRules.progress(ROOMS, {})
check("nothing visited", count == 0 and total == 12)
check("zero percent", MansionMapRules.percent(ROOMS, {}) == 0)

local some = { GrandHall = 1, Library = 2, Study = 3 }
count, total = MansionMapRules.progress(ROOMS, some)
check("secret rooms do not count", count == 2 and total == 12)
check("percent rounds down", MansionMapRules.percent(ROOMS, some) == 16)
check("not complete", not MansionMapRules.complete(ROOMS, some))

local all: { [string]: number } = {}
for _, room in ipairs(ROOMS) do
	if not room.secret then
		all[room.id] = 1
	end
end
check("all public rooms complete the map", MansionMapRules.complete(ROOMS, all))
check("hundred percent", MansionMapRules.percent(ROOMS, all) == 100)
all.Music = nil
check("one missing is not complete", not MansionMapRules.complete(ROOMS, all) and MansionMapRules.percent(ROOMS, all) == 91)

check("known room", MansionMapRules.isRoom(ROOMS, "Trophy") and MansionMapRules.isRoom(ROOMS, "TowerHall"))
check("unknown room", not MansionMapRules.isRoom(ROOMS, "Arena"))
check("non string room", not MansionMapRules.isRoom(ROOMS, 3))
check("empty map is never complete", not MansionMapRules.complete({}, {}))

local ids: { [string]: boolean } = {}
local unique, short = true, true
for _, room in ipairs(ROOMS) do
	unique = unique and not ids[room.id]
	short = short and #room.id <= MansionMapConfig.MaxIdLength
	ids[room.id] = true
end
check("room ids are unique", unique)
check("room ids fit the profile", short)

print(`MansionMapRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error("MansionMapRules tests failed")
end
