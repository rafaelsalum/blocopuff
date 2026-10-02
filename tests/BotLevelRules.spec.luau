-- Testes da escolha de nível dos bots RoboPuff (Fase 5B).
-- Rodar: lune run tests/BotLevelRules.spec

local BotLevelRules = require("../src/server/data/BotLevelRules")

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

local rules = { BeginnerMatches = 3, ExperiencedLevel = 5 }

local function count(levels: { string }, wanted: string): number
	local total = 0
	for _, level in ipairs(levels) do
		if level == wanted then
			total += 1
		end
	end
	return total
end

-- Novato na partida: todos os bots no modo fácil.
local beginner = BotLevelRules.choose(3, { { matches = 1, level = 1 } }, rules)
check("beginner gets 3 levels", #beginner == 3)
check("beginner gets only easy bots", count(beginner, "Easy") == 3)

local mixedRoom = BotLevelRules.choose(2, { { matches = 40, level = 12 }, { matches = 0, level = 1 } }, rules)
check("any beginner in the room keeps bots easy", count(mixedRoom, "Easy") == 2)

-- Jogador com algumas partidas e nível baixo: Fácil e Normal misturados.
local casual = BotLevelRules.choose(3, { { matches = 10, level = 3 } }, rules)
check("casual gets 3 levels", #casual == 3)
check("casual never gets hard bots", count(casual, "Hard") == 0)
check("casual gets at least one easy", count(casual, "Easy") >= 1)
check("casual gets at least one normal", count(casual, "Normal") >= 1)

-- Jogador experiente: Normal e Esperto misturados.
local veteran = BotLevelRules.choose(3, { { matches = 80, level = 20 } }, rules)
check("veteran never gets easy bots", count(veteran, "Easy") == 0)
check("veteran gets at least one hard", count(veteran, "Hard") >= 1)
check("veteran gets at least one normal", count(veteran, "Normal") >= 1)

-- O mais experiente da sala decide.
local room = BotLevelRules.choose(2, { { matches = 10, level = 2 }, { matches = 90, level = 30 } }, rules)
check("strongest human sets the tier", count(room, "Easy") == 0)

check("zero bots gives empty list", #BotLevelRules.choose(0, { { matches = 10, level = 3 } }, rules) == 0)
check("no humans falls back to easy", count(BotLevelRules.choose(1, {}, rules), "Easy") == 1)

-- Exatamente no limite de nível ainda é casual.
check("level at threshold is casual", count(BotLevelRules.choose(2, { { matches = 10, level = 5 } }, rules), "Hard") == 0)
check("matches at threshold is no longer beginner", count(BotLevelRules.choose(2, { { matches = 3, level = 1 } }, rules), "Normal") == 1)

print(`BotLevelRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} BotLevelRules checks failed`)
end
