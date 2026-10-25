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
-- Colado no Assassino (até `closeRange`), vale quase meia-volta: quem
-- passa raspando do lado também é pego; atrás, não.
check("close target to the side counts", MurderRules.inStabReach(3, -0.5, 0, -1, 7, 100, 3.5))
check("close target slightly behind the shoulder counts", MurderRules.inStabReach(3, 0.8, 0, -1, 7, 100, 3.5))
check("close target right behind fails", not MurderRules.inStabReach(0, 3, 0, -1, 7, 100, 3.5))
check("side target beyond close range needs the cone", not MurderRules.inStabReach(5, -0.5, 0, -1, 7, 100, 3.5))
check("no close range keeps the cone", not MurderRules.inStabReach(3, -0.5, 0, -1, 7, 100))

-- Rebobinar pela latência: quanto (s) olhar para trás nas posições dos
-- alvos (o Assassino vê os outros um pouco atrasados).
check("rewind adds the ping to the base", math.abs(MurderRules.stabRewind(0.1, 0.1, 0.4) - 0.2) < 1e-6)
check("rewind without ping is the base", math.abs(MurderRules.stabRewind(0, 0.1, 0.4) - 0.1) < 1e-6)
check("rewind is capped", math.abs(MurderRules.stabRewind(2, 0.1, 0.4) - 0.4) < 1e-6)
check("rewind ignores a broken ping", math.abs(MurderRules.stabRewind(0 / 0, 0.1, 0.4) - 0.1) < 1e-6)
check("rewind ignores a negative ping", math.abs(MurderRules.stabRewind(-1, 0.1, 0.4) - 0.1) < 1e-6)

-- Posição do golpe mandada pelo cliente: vale perto da do servidor.
check("client origin close to the server one is trusted", MurderRules.originTrusted(2, 0.5, -2.5, 4))
check("client origin far from the server one is not trusted", not MurderRules.originTrusted(5, 0, 0, 4))
check("broken client origin is not trusted", not MurderRules.originTrusted(0 / 0, 0, 0, 4))

-- Golpe pela mira: entre dois ao alcance, vale o que está mais perto da
-- linha da mira (cosseno maior).
check("aim straight ahead scores 1", math.abs(MurderRules.aimCosine(0, -4, 0, -1) - 1) < 1e-6)
check("aim to the side scores less", MurderRules.aimCosine(2, -3, 0, -1) < MurderRules.aimCosine(0.5, -3, 0, -1))
check("aim with no offset scores 1", MurderRules.aimCosine(0, 0, 0, -1) == 1)

-- Faca arremessada em 3D: o trecho percorrido no quadro (de p, na direção
-- d, até `reach`) acerta o corpo (raio 2.5 na horizontal, de 3 abaixo a 2
-- acima da raiz)?
local function hits(px, py, pz, dx, dy, dz, reach, tx, ty, tz)
	return MurderRules.knifeHitsBody(px, py, pz, dx, dy, dz, reach, tx, ty, tz, 2.5, 3, 2)
end
local up = math.sqrt(0.5)
check("throw straight hits a body ahead", hits(0, 0, 0, 0, 0, -1, 10, 0, 0, -6))
check("throw straight misses a body behind", not hits(0, 0, 0, 0, 0, -1, 10, 0, 0, 6))
check("throw straight misses a body beyond the step", not hits(0, 0, 0, 0, 0, -1, 4, 0, 0, -8))
check("throw upward passes over a body ahead", not hits(0, 0, 0, 0, up, -up, 20, 0, 0, -12))
check("throw upward hits someone on the stairs above", hits(0, 0, 0, 0, up, -up, 20, 0, 8, -8))
check("throw downward hits someone below", hits(0, 10, 0, 0, -up, -up, 20, 0, 3, -7))
check("throw to the side misses", not hits(0, 0, 0, 0, 0, -1, 10, 4, 0, -6))

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
