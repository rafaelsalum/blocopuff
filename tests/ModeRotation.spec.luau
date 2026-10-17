--!strict

-- Testes da rotação de modos (Fase 5D.1) (rodar com: lune run tests/ModeRotation.spec.luau).

local ModeRotation = require("../src/server/data/ModeRotation")

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

local SEQUENCE = { "Arena", "Race", "Arena", "Mystery" }
local ALL = { Arena = true, Race = true, Mystery = true }

local function input(available: { [string]: boolean }, hasBeginner: boolean?): ModeRotation.Input
	return {
		sequence = SEQUENCE,
		baseMode = "Arena",
		available = available,
		hasBeginner = hasBeginner == true,
	}
end

-- Sequência completa, voltando ao começo.
local cursor = ModeRotation.initialCursor()
local played: { string } = {}
for _ = 1, 6 do
	local mode, nextCursor = ModeRotation.pick(cursor, input(ALL))
	table.insert(played, mode)
	cursor = nextCursor
end
check("follows the sequence and wraps", table.concat(played, ",") == "Arena,Race,Arena,Mystery,Arena,Race")

-- pick não altera o cursor recebido.
local start = ModeRotation.initialCursor()
local _, advanced = ModeRotation.pick(start, input(ALL))
check("pick keeps the original cursor", start.index == 1 and start.last == nil and advanced.index == 2)

-- Modo indisponível é pulado (Mistério sem gente suficiente).
local noMystery = { Arena = true, Race = true, Mystery = false }
local atMystery: ModeRotation.Cursor = { index = 4, last = "Arena" }
local skipped, afterSkip = ModeRotation.pick(atMystery, input(noMystery))
check("unavailable mode is skipped", skipped == "Arena")
check("skip moves past the unavailable mode", afterSkip.index == 2)

-- Só a Arena registrada: sempre Arena (5D.1, sem mudança visível).
local onlyArena = { Arena = true }
local arenaCursor = ModeRotation.initialCursor()
local allArena = true
for _ = 1, 8 do
	local mode, nextCursor = ModeRotation.pick(arenaCursor, input(onlyArena))
	allArena = allArena and mode == "Arena"
	arenaCursor = nextCursor
end
check("only arena available always plays arena", allArena)

-- Um modo novo nunca se repete duas vezes seguidas.
local raceOnly: { string } = { "Race", "Race", "Arena" }
local repeatCursor: ModeRotation.Cursor = { index = 2, last = "Race" }
local repeated = ModeRotation.pick(repeatCursor, {
	sequence = raceOnly,
	baseMode = "Arena",
	available = ALL,
	hasBeginner = false,
})
check("new mode never repeats back to back", repeated == "Arena")

-- A Arena pode se repetir (é a casa).
local arenaTwice: ModeRotation.Cursor = { index = 1, last = "Arena" }
check("base mode may repeat", ModeRotation.pick(arenaTwice, input(ALL)) == "Arena")

-- Novato na fila: Arena, e a rotação não anda (o modo novo vem depois).
local atRace: ModeRotation.Cursor = { index = 2, last = "Arena" }
local beginnerMode, beginnerCursor = ModeRotation.pick(atRace, input(ALL, true))
check("beginner forces the base mode", beginnerMode == "Arena")
check("beginner keeps the rotation position", beginnerCursor.index == 2)
local nextMode = ModeRotation.pick(beginnerCursor, input(ALL, false))
check("rotation resumes after the beginner", nextMode == "Race")

-- Nada disponível nem a base: cai na base mesmo assim.
local nothing = ModeRotation.pick(ModeRotation.initialCursor(), input({}))
check("falls back to the base mode", nothing == "Arena")

-- Sequência vazia ou cursor inválido não quebram.
local empty = ModeRotation.pick(ModeRotation.initialCursor(), {
	sequence = {},
	baseMode = "Arena",
	available = ALL,
	hasBeginner = false,
})
check("empty sequence falls back to base", empty == "Arena")
local broken: ModeRotation.Cursor = { index = 99, last = nil }
local fromBroken = ModeRotation.pick(broken, input(ALL))
check("out of range cursor is normalized", fromBroken == "Arena" or fromBroken == "Race" or fromBroken == "Mystery")

-- Votos das portas: o mais votado entre os que podem rodar.
local function voted(votes: { [string]: number }, available: { [string]: boolean }?, hasBeginner: boolean?): ModeRotation.Input
	return {
		sequence = SEQUENCE,
		baseMode = "Arena",
		available = available or ALL,
		hasBeginner = hasBeginner == true,
		votes = votes,
	}
end
check("most voted mode wins", ModeRotation.pick(ModeRotation.initialCursor(), voted({ Mystery = 3, Race = 1 })) == "Mystery")
check("votes beat the beginner rule", ModeRotation.pick(ModeRotation.initialCursor(), voted({ Race = 1 }, nil, true)) == "Race")
local again: ModeRotation.Cursor = { index = 3, last = "Race" }
check("voted mode may repeat", ModeRotation.pick(again, voted({ Race = 2 })) == "Race")
check("unavailable vote falls to the next", ModeRotation.pick(ModeRotation.initialCursor(), voted({ Mystery = 4, Race = 2 }, noMystery)) == "Race")
check("only unavailable votes: rotation", ModeRotation.pick({ index = 2, last = "Arena" }, voted({ Mystery = 4 }, noMystery)) == "Race")
local tieCursor: ModeRotation.Cursor = { index = 4, last = "Arena" }
check("tie follows the rotation order", ModeRotation.pick(tieCursor, voted({ Race = 2, Mystery = 2 })) == "Mystery")
local _, afterVote = ModeRotation.pick({ index = 2, last = "Arena" }, voted({ Mystery = 1 }))
check("a vote keeps the rotation position", afterVote.index == 2 and afterVote.last == "Mystery")
check("no votes: plain rotation", ModeRotation.pick({ index = 2, last = "Arena" }, voted({})) == "Race")

-- Porta de entrada e contagem dos votos.
local DOORS = { -22.5, 0, 22.5 }
check("nearest door by z", ModeRotation.nearestDoor(DOORS, -20) == 1 and ModeRotation.nearestDoor(DOORS, 3) == 2 and ModeRotation.nearestDoor(DOORS, 30) == 3)
check("no doors, no vote", ModeRotation.nearestDoor({}, 0) == nil)
local counted = ModeRotation.tally({ "Race", "", "Mystery", "Race" })
check("tally counts votes and skips blanks", counted.Race == 2 and counted.Mystery == 1 and counted[""] == nil)

-- Novato: só as primeiras partidas.
check("beginner below the limit", ModeRotation.isBeginner(2, 3))
check("not a beginner at the limit", not ModeRotation.isBeginner(3, 3))

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("ModeRotation tests failed")
end
