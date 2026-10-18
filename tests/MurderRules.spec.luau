--!strict

-- Testes das regras do Assassinato no Casarão (Fase 5E)
-- (rodar com: lune run tests/MurderRules.spec.luau).

local MurderRules = require("../src/server/data/MurderRules")

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

local function sequence(values: { number }): () -> number
	local index = 0
	return function(): number
		index += 1
		return values[((index - 1) % #values) + 1]
	end
end

-- Gerador simples e determinístico (o Lune não tem o Random do Roblox).
local function rngFor(seed: number): () -> number
	local state = seed * 7919 + 13
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

-- Papéis: sempre 1 Assassino e 1 Xerife, diferentes, entre os humanos.
local valid = 0
for seed = 1, 200 do
	local roles = MurderRules.assignRoles({ 10, 20, 30, 40 }, {}, nil, rngFor(seed))
	if roles ~= nil and roles.murderer ~= roles.sheriff then
		valid += 1
	end
end
check("always one murderer and one sheriff", valid == 200)
check("needs two humans", MurderRules.assignRoles({ 10 }, {}, nil, sequence({ 0.5 })) == nil)

local pair = MurderRules.assignRoles({ 10, 20 }, {}, nil, sequence({ 0.1, 0.5 }))
check("two humans get both roles", pair ~= nil and pair.murderer ~= pair.sheriff)
local nextPair = MurderRules.assignRoles({ 10, 20 }, {}, if pair ~= nil then pair.murderer else nil, sequence({ 0.1, 0.5 }))
check("murderer alternates between two humans", pair ~= nil and nextPair ~= nil and nextPair.murderer ~= pair.murderer)

local repeats = 0
for seed = 1, 200 do
	local roles = MurderRules.assignRoles({ 10, 20, 30 }, {}, 10, rngFor(seed))
	if roles ~= nil and roles.murderer == 10 then
		repeats += 1
	end
end
check("last murderer is not murderer again", repeats == 0)

local newcomer = 0
for seed = 1, 400 do
	local roles = MurderRules.assignRoles({ 10, 20 }, { [10] = { murderer = 5, sheriff = 5 } }, nil, rngFor(seed))
	if roles ~= nil and roles.murderer == 20 then
		newcomer += 1
	end
end
check("newcomer is murderer more often", newcomer > 260)

-- Fim da partida.
check("murderer down: innocents win", MurderRules.outcome({ murdererAlive = false, othersAlive = 3, timeUp = false }) == "Innocents")
check("everyone down: murderer wins", MurderRules.outcome({ murdererAlive = true, othersAlive = 0, timeUp = false }) == "Murderer")
check("time up with innocents: innocents win", MurderRules.outcome({ murdererAlive = true, othersAlive = 1, timeUp = true }) == "Innocents")
check("still playing", MurderRules.outcome({ murdererAlive = true, othersAlive = 2, timeUp = false }) == nil)

-- Tiro do Xerife.
check("shooting the murderer", MurderRules.shotResult("Murderer") == "MurdererDown")
check("shooting an innocent is a misfire", MurderRules.shotResult("Innocent") == "Misfire")

-- Arma caída: só Inocentes humanos vivos.
check("innocent human picks up", MurderRules.canPickUp("Innocent", false, true))
check("murderer never picks up", not MurderRules.canPickUp("Murderer", false, true))
check("bots never pick up", not MurderRules.canPickUp("Innocent", true, true))
check("eliminated never pick up", not MurderRules.canPickUp("Innocent", false, false))

-- Proteção da largada e recargas.
check("nothing during the start grace", not MurderRules.actionReady(5, 10, nil, 4, 100))
check("first action after grace", MurderRules.actionReady(11, 10, nil, 4, 100))
check("cooldown blocks", not MurderRules.actionReady(30, 10, 98, 4, 100))
check("cooldown over", MurderRules.actionReady(30, 10, 95, 4, 100))

-- Golpe da faca: alcance e ângulo à frente, no plano (offset do alvo e
-- direção do olhar em x, z; a altura é conferida à parte).
check("stab in front within range", MurderRules.inStabReach(0, -4, 0, -1, 5, 70))
check("stab out of range", not MurderRules.inStabReach(0, -6, 0, -1, 5, 70))
check("stab behind fails", not MurderRules.inStabReach(0, 3, 0, -1, 5, 70))
check("stab to the side within the cone", MurderRules.inStabReach(1.5, -3, 0, -1, 5, 70))
check("stab too far to the side fails", not MurderRules.inStabReach(4, -1, 0, -1, 5, 70))
check("stab right on top counts", MurderRules.inStabReach(0, 0, 0, -1, 5, 70))
check("no look direction: only right on top", not MurderRules.inStabReach(0, -3, 0, 0, 5, 70))

-- Moedas.
check("bag has a cap", MurderRules.collect(10, 10) == nil)
check("bag fills one by one", MurderRules.collect(3, 10) == 4)
check("five coins pay one ticket", MurderRules.coinTickets(5, 5, 2) == 1)
check("coins round down", MurderRules.coinTickets(9, 5, 2) == 1)
check("tickets are capped", MurderRules.coinTickets(40, 5, 2) == 2)
check("no coins no tickets", MurderRules.coinTickets(0, 5, 2) == 0)

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("MurderRules tests failed")
end
