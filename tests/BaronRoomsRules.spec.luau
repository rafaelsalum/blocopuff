--!strict

-- Testes das Salas Secretas do Barão (rodar com: lune run tests/BaronRoomsRules.spec.luau).

local BaronRoomsConfig = require("../src/shared/config/BaronRoomsConfig")
local BaronRoomsRules = require("../src/shared/modules/BaronRoomsRules")

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

local IDS = BaronRoomsConfig.Ids

-- Acesso: Gabinete com o Diário completo; tesouro com o cofrinho resolvido.
check("study needs every diary page", not BaronRoomsRules.hasAccess("Study", 9, 10, true))
check("study opens with the full diary", BaronRoomsRules.hasAccess("Study", 10, 10, false))
check("study never opens with an empty diary", not BaronRoomsRules.hasAccess("Study", 0, 0, true))
check("treasure needs the safe", not BaronRoomsRules.hasAccess("Treasure", 10, 10, false))
check("treasure opens with the safe", BaronRoomsRules.hasAccess("Treasure", 0, 10, true))
check("unknown room has no access", not BaronRoomsRules.hasAccess("Nope", 10, 10, true))

-- Dentro da sala (caixa com folga).
local box = { minX = 0, minY = 0, minZ = 0, maxX = 10, maxY = 5, maxZ = 10 }
check("inside the box", BaronRoomsRules.inside(5, 2, 5, box, 0))
check("outside the box", not BaronRoomsRules.inside(12, 2, 5, box, 0))
check("margin lets the edge count", BaronRoomsRules.inside(10.5, 2, 5, box, 1))
check("below the floor is outside", not BaronRoomsRules.inside(5, -3, 5, box, 1))

-- Prêmio: uma vez por jogador.
local first, outcome = BaronRoomsRules.claim({}, "Study", IDS, 15, 100)
check("first claim pays", first ~= nil and outcome ~= nil and outcome.tickets == 15 and outcome.count == 1)
check("claim records the time", first ~= nil and first.Study == 100)
local again, repeated = BaronRoomsRules.claim(first :: any, "Study", IDS, 15, 200)
check("second claim is refused", again == nil and repeated == nil)
local unknown = BaronRoomsRules.claim({}, "Nope", IDS, 15, 100)
check("unknown room is refused", unknown == nil)
local original = { Study = 50 }
local both, last = BaronRoomsRules.claim(original, "Treasure", IDS, 15, 100)
check("count includes earlier rooms", both ~= nil and last ~= nil and last.count == 2)
check("claim keeps the original", original.Treasure == nil)

-- Passagem aberta no cliente.
local open, nearAt = BaronRoomsRules.shouldOpen(true, false, nil, 14, nil, 10, 3)
check("owner always sees it open", open and nearAt == nil)
open = BaronRoomsRules.shouldOpen(false, true, nil, 14, nil, 10, 3)
check("anyone inside can always leave", open)
open, nearAt = BaronRoomsRules.shouldOpen(false, false, 8, 14, nil, 10, 3)
check("friend near an owner sees it open", open and nearAt == 10)
open = BaronRoomsRules.shouldOpen(false, false, 20, 14, nil, 10, 3)
check("owner too far keeps it closed", not open)
open, nearAt = BaronRoomsRules.shouldOpen(false, false, nil, 14, 10, 12, 3)
check("stays open a moment after the owner leaves", open and nearAt == 10)
open = BaronRoomsRules.shouldOpen(false, false, nil, 14, 10, 13.5, 3)
check("closes after the delay", not open)

-- Títulos.
local titles = BaronRoomsConfig.titlesFor({ "Treasure" })
check("treasure title", #titles == 1 and titles[1] == BaronRoomsConfig.Info.Treasure.title)
check("no rooms, no titles", #BaronRoomsConfig.titlesFor({}) == 0)
check("unknown ids ignored", #BaronRoomsConfig.titlesFor({ "Nope" }) == 0)

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("BaronRoomsRules tests failed")
end
