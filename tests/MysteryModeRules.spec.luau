--!strict

-- Testes das regras do Mistério no Casarão (Fase 5D.3)
-- (rodar com: lune run tests/MysteryModeRules.spec.luau).

local MysteryModeRules = require("../src/server/data/MysteryModeRules")

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

-- Papéis: sempre 1 Fantasma e 1 Detetive, diferentes, entre os candidatos.
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

local valid = 0
for seed = 1, 200 do
	local roles = MysteryModeRules.assignRoles({ 10, 20, 30, 40 }, {}, nil, rngFor(seed))
	if roles ~= nil and roles.ghost ~= roles.detective and roles.ghost ~= nil and roles.detective ~= nil then
		valid += 1
	end
end
check("always one ghost and one detective", valid == 200)
check("needs two candidates", MysteryModeRules.assignRoles({ 10 }, {}, nil, sequence({ 0.5 })) == nil)
-- Dois humanos já bastam (os bots são Moradores): um Fantasma, um Detetive,
-- e o Fantasma alterna entre eles.
local pair = MysteryModeRules.assignRoles({ 10, 20 }, {}, nil, sequence({ 0.1, 0.5 }))
check("two humans get both roles", pair ~= nil and pair.ghost ~= pair.detective)
local nextPair = MysteryModeRules.assignRoles({ 10, 20 }, {}, if pair ~= nil then pair.ghost else nil, sequence({ 0.1, 0.5 }))
check("ghost alternates between two humans", pair ~= nil and nextPair ~= nil and nextPair.ghost ~= pair.ghost)

-- O Fantasma da rodada passada não repete (com outra opção).
local repeats = 0
for seed = 1, 200 do
	local roles = MysteryModeRules.assignRoles({ 10, 20, 30 }, {}, 10, rngFor(seed))
	if roles ~= nil and roles.ghost == 10 then
		repeats += 1
	end
end
check("last ghost is not ghost again", repeats == 0)

-- Quem nunca foi Fantasma tem mais chance.
local newcomer = 0
for seed = 1, 400 do
	local roles = MysteryModeRules.assignRoles({ 10, 20 }, { [10] = { ghost = 5, detective = 5 } }, nil, rngFor(seed))
	if roles ~= nil and roles.ghost == 20 then
		newcomer += 1
	end
end
check("newcomer is ghost more often", newcomer > 260)

-- Fim da partida.
check("captured ghost: residents win", MysteryModeRules.outcome({ ghostAwake = false, awakeResidents = 3, timeUp = false }) == "Residents")
check("everyone scared: ghost wins", MysteryModeRules.outcome({ ghostAwake = true, awakeResidents = 0, timeUp = false }) == "Ghost")
check("time up with residents: residents win", MysteryModeRules.outcome({ ghostAwake = true, awakeResidents = 1, timeUp = true }) == "Residents")
check("still playing", MysteryModeRules.outcome({ ghostAwake = true, awakeResidents = 2, timeUp = false }) == nil)

-- Quem pode pegar o Puffador do chão.
check("resident human picks up", MysteryModeRules.canPickUp("Resident", false, true, false))
check("ghost never picks up", not MysteryModeRules.canPickUp("Ghost", false, true, false))
check("bots never pick up", not MysteryModeRules.canPickUp("Resident", true, true, false))
check("scared players never pick up", not MysteryModeRules.canPickUp("Resident", false, false, false))
check("who missed never picks it up again", not MysteryModeRules.canPickUp("Detective", false, true, true))

-- Susto e lençol: proteção da largada e recarga.
check("no scare during the start grace", not MysteryModeRules.actionReady(5, 10, nil, 4, 100))
check("first scare after grace", MysteryModeRules.actionReady(11, 10, nil, 4, 100))
check("cooldown blocks", not MysteryModeRules.actionReady(30, 10, 98, 4, 100))
check("cooldown over", MysteryModeRules.actionReady(30, 10, 95, 4, 100))

-- Moedas viram tickets, com teto.
check("five coins pay one ticket", MysteryModeRules.coinTickets(5, 5, 2) == 1)
check("coins round down", MysteryModeRules.coinTickets(9, 5, 2) == 1)
check("tickets are capped", MysteryModeRules.coinTickets(40, 5, 2) == 2)
check("no coins no tickets", MysteryModeRules.coinTickets(0, 5, 2) == 0)

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("MysteryModeRules tests failed")
end
