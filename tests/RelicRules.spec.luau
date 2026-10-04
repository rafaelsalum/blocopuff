-- Testes das regras das Relíquias e do catálogo do Álbum do Casarão.
-- Rodar: lune run tests/RelicRules.spec

local RelicRules = require("../src/server/data/RelicRules")
local RelicCatalog = require("../src/shared/config/RelicCatalog")

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

local rewards = RelicCatalog.Rewards
local allIds = RelicCatalog.allIds()

-- Catálogo: 8 cômodos com 5 relíquias cada.
check("eight rooms", #RelicCatalog.rooms() == 8)
check("forty relics", #allIds == 40)
for _, room in ipairs(RelicCatalog.rooms()) do
	check(`{room.id} has five relics`, #room.relics == 5)
	for _, definition in ipairs(room.relics) do
		check(`{definition.id} points to its room`, definition.room == room.id)
	end
end
check("daily spots exist", #RelicCatalog.dailySpots() >= 7)

-- Pegar uma relíquia.
local libraryIds = RelicCatalog.roomIds("Library")
local relics, outcome = RelicRules.collect({}, libraryIds[1], libraryIds, allIds, rewards, 100)
check("first relic is collected", relics ~= nil and outcome ~= nil and relics[libraryIds[1]] == 100)
check("first relic pays one ticket", outcome ~= nil and outcome.tickets == rewards.RelicTickets and outcome.roomCount == 1 and outcome.total == 1)
check("first relic does not complete the room", outcome ~= nil and not outcome.roomCompleted and not outcome.albumCompleted)

local again = RelicRules.collect(relics :: any, libraryIds[1], libraryIds, allIds, rewards, 200)
check("same relic twice is refused", again == nil)
check("unknown relic is refused", RelicRules.collect({}, "nao_existe", libraryIds, allIds, rewards, 1) == nil)
check("relic from another room is refused", RelicRules.collect({}, RelicCatalog.roomIds("Music")[1], libraryIds, allIds, rewards, 1) == nil)

local original = {}
RelicRules.collect(original, libraryIds[2], libraryIds, allIds, rewards, 5)
check("collect does not mutate the input", next(original) == nil)

-- Completar o cômodo.
local state: { [string]: number } = {}
local last = nil
for _, id in ipairs(libraryIds) do
	local updated, result = RelicRules.collect(state, id, libraryIds, allIds, rewards, 10)
	state = updated :: any
	last = result
end
check("fifth relic completes the room", last ~= nil and last.roomCompleted and last.roomCount == 5)
check("room bonus is paid", last ~= nil and last.tickets == rewards.RelicTickets + rewards.RoomTickets)
check("room title is earned", table.find(RelicCatalog.titlesFor(state, 0), "Bibliotecário") ~= nil)

-- Completar o álbum.
local everything: { [string]: number } = {}
for _, id in ipairs(allIds) do
	everything[id] = 1
end
local lastId = allIds[#allIds]
everything[lastId] = nil
local lastRoom = (RelicCatalog.get(lastId) :: any).room
local _, finalOutcome = RelicRules.collect(everything, lastId, RelicCatalog.roomIds(lastRoom), allIds, rewards, 50)
check("last relic completes the album", finalOutcome ~= nil and finalOutcome.albumCompleted and finalOutcome.total == 40)
everything[lastId] = 50
local titles = RelicCatalog.titlesFor(everything, 0)
check("album title comes first", titles[1] == RelicCatalog.AlbumTitle and #titles == 9)

-- Relíquia do Dia.
local daily = RelicRules.collectDaily(0, 0, 500, rewards)
check("daily relic on a fresh profile", daily ~= nil and daily.count == 1 and daily.tickets == rewards.DailyTickets)
check("daily relic only once a day", RelicRules.collectDaily(500, 1, 500, rewards) == nil)
check("daily relic next day", RelicRules.collectDaily(500, 1, 501, rewards) ~= nil)
local goal = RelicRules.collectDaily(10, rewards.DailyGoal - 1, 11, rewards)
check("daily goal pays the bonus", goal ~= nil and goal.goalReached and goal.tickets == rewards.DailyTickets + rewards.DailyGoalTickets)
local after = RelicRules.collectDaily(11, rewards.DailyGoal, 12, rewards)
check("daily goal bonus only once", after ~= nil and not after.goalReached and after.tickets == rewards.DailyTickets)
check("daily title at the goal", table.find(RelicCatalog.titlesFor({}, rewards.DailyGoal), RelicCatalog.DailyTitle) ~= nil)

-- Esconderijo do dia: no intervalo, fixo e nunca igual ao do dia anterior.
local spots = #RelicCatalog.dailySpots()
local repeated = 0
local outOfRange = 0
local seen: { [number]: boolean } = {}
for day = 19000, 19400 do
	local index = RelicRules.dailySpotIndex(day, spots)
	if index < 1 or index > spots then
		outOfRange += 1
	end
	if index == RelicRules.dailySpotIndex(day - 1, spots) then
		repeated += 1
	end
	seen[index] = true
end
local distinct = 0
for _ in pairs(seen) do
	distinct += 1
end
check("daily spot in range", outOfRange == 0)
check("daily spot never repeats the day before", repeated == 0)
check("daily spot uses every hiding place", distinct == spots)
check("daily spot is deterministic", RelicRules.dailySpotIndex(20000, spots) == RelicRules.dailySpotIndex(20000, spots))

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("RelicRules tests failed")
end
