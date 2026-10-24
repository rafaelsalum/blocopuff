--!strict

-- Testes dos cômodos do lobby para a telemetria (Fase 5C)
-- (rodar com: lune run tests/LobbyRooms.spec.luau).

local LobbyRooms = require("../src/server/data/LobbyRooms")

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

local ZONES: { LobbyRooms.Zone } = {
	{ name = "Study", minX = 10, maxX = 20, minY = 0, maxY = 10, minZ = 0, maxZ = 10, secret = true },
	{ name = "Attic", minX = 0, maxX = 40, minY = 20, maxY = 30, minZ = 0, maxZ = 40 },
	{ name = "Library", minX = 0, maxX = 40, minY = 0, maxY = 19, minZ = 0, maxZ = 40 },
}

local study = LobbyRooms.zoneAt(ZONES, 15, 5, 5)
check("secret room has priority over the room around it", study ~= nil and study.name == "Study" and study.secret == true)
local library = LobbyRooms.zoneAt(ZONES, 30, 5, 30)
check("ground floor room", library ~= nil and library.name == "Library")
local attic = LobbyRooms.zoneAt(ZONES, 30, 25, 30)
check("upper floor by height", attic ~= nil and attic.name == "Attic")
check("outside every zone", LobbyRooms.zoneAt(ZONES, 50, 5, 5) == nil)
check("between floors is outside", LobbyRooms.zoneAt(ZONES, 30, 19.5, 30) == nil)

local visited: { [string]: boolean } = {}
check("first visit counts", LobbyRooms.firstVisit(visited, "Library"))
check("second visit does not", not LobbyRooms.firstVisit(visited, "Library"))
check("another room counts", LobbyRooms.firstVisit(visited, "Attic"))

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("LobbyRooms tests failed")
end
