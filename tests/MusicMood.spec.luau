--!strict

-- Testes da trilha sonora por clima (rodar com: lune run tests/MusicMood.spec.luau).

local MusicMood = require("../src/shared/modules/MusicMood")

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

local function input(overrides: { [string]: any }): MusicMood.Input
	local base: { [string]: any } = {
		roundState = "WaitingForPlayers",
		roundMode = "Arena",
		finalChaos = false,
		competing = false,
		mysteryFinal = false,
		place = "Indoors",
		clock = 12,
		nightFrom = 17.6,
		nightUntil = 6.4,
	}
	for key, value in pairs(overrides) do
		base[key] = value
	end
	return (base :: any) :: MusicMood.Input
end

-- Dia e noite atravessando a meia-noite.
check("noon is day", not MusicMood.isNight(12, 17.6, 6.4))
check("evening is night", MusicMood.isNight(20, 17.6, 6.4))
check("dawn is night", MusicMood.isNight(3, 17.6, 6.4))
check("morning is day", not MusicMood.isNight(6.4, 17.6, 6.4))

-- Fora da partida: depende de onde está e da hora.
check("lobby by day", MusicMood.pick(input({})) == "LobbyDay")
check("lobby at night", MusicMood.pick(input({ clock = 22 })) == "LobbyNight")
check("outdoors by day", MusicMood.pick(input({ place = "Outdoors" })) == "OutdoorDay")
check("outdoors at night", MusicMood.pick(input({ place = "Outdoors", clock = 1 })) == "OutdoorNight")
check("inside the tower", MusicMood.pick(input({ place = "Tower", clock = 1 })) == "Tower")

-- Quem só assiste do lobby não troca de música com a partida.
check("lobby ignores a match it is not in", MusicMood.pick(input({ roundState = "Active", finalChaos = true })) == "LobbyDay")

-- Na partida: cada modo com a sua.
check("arena match", MusicMood.pick(input({ roundState = "Active", competing = true })) == "Arena")
check("countdown already plays the mode", MusicMood.pick(input({ roundState = "Countdown", competing = true, roundMode = "Race" })) == "Race")
check("final chaos", MusicMood.pick(input({ roundState = "Active", competing = true, finalChaos = true })) == "Chaos")
check("race match", MusicMood.pick(input({ roundState = "Active", competing = true, roundMode = "Race" })) == "Race")
check("mystery match", MusicMood.pick(input({ roundState = "Active", competing = true, roundMode = "Mystery" })) == "Mystery")
check("mystery final stretch is silent", MusicMood.pick(input({ roundState = "Active", competing = true, roundMode = "Mystery", mysteryFinal = true })) == "Silent")
check("mystery final stretch silences a ghost too", MusicMood.pick(input({ roundState = "Active", roundMode = "Mystery", mysteryFinal = true })) == "Silent")
check("unknown mode falls back to arena", MusicMood.pick(input({ roundState = "Active", competing = true, roundMode = nil })) == "Arena")
check("waiting while competing is the lobby", MusicMood.pick(input({ competing = true })) == "LobbyDay")

-- Ambiente só do lado de fora.
check("birds by day outdoors", MusicMood.ambienceFor("OutdoorDay") == "Birds")
check("crickets at night outdoors", MusicMood.ambienceFor("OutdoorNight") == "Crickets")
check("no ambience indoors", MusicMood.ambienceFor("LobbyNight") == "None")
check("no ambience in a match", MusicMood.ambienceFor("Arena") == "None")

-- Rodízio de faixas: nunca repete a anterior e cobre a lista toda.
check("single track always first", MusicMood.nextIndex(1, 1, 0.9) == 1)
check("first pick in range", MusicMood.nextIndex(3, nil, 0.999) == 3 and MusicMood.nextIndex(3, nil, 0) == 1)
local repeated, seen = 0, {}
for step = 0, 99 do
	local roll = step / 100
	for previous = 1, 4 do
		local index = MusicMood.nextIndex(4, previous, roll)
		if index == previous or index < 1 or index > 4 then
			repeated += 1
		end
		seen[index] = true
	end
end
check("next track never repeats and stays in range", repeated == 0)
check("every track gets its turn", seen[1] == true and seen[2] == true and seen[3] == true and seen[4] == true)

-- Vinhetas do fim.
check("winner hears the win sting", MusicMood.stingFor(true, 42, 42) == "Win")
check("others hear the end sting", MusicMood.stingFor(true, 7, 42) == "End")
check("no winner still ends", MusicMood.stingFor(true, nil, 42) == "End")
check("lobby hears no sting", MusicMood.stingFor(false, 42, 42) == nil)

print(`MusicMood: {passed} passed, {failures} failed`)
if failures > 0 then
	error("MusicMood tests failed")
end
