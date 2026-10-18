--!strict

-- Regras do Assassinato no Casarão (Fase 5E), sem Roblox: sorteio dos papéis,
-- fim da partida, tiro do Xerife, quem pode pegar a arma caída, proteção da
-- largada e recargas, alcance do golpe da faca e moedas. Os testes rodam no
-- Lune (tests/MurderRules.spec.luau).

export type Role = "Murderer" | "Sheriff" | "Innocent"

export type RoleHistory = {
	murderer: number,
	sheriff: number,
}

export type Roles = {
	murderer: number,
	sheriff: number,
}

export type OutcomeInput = {
	murdererAlive: boolean,
	-- Todos os outros ainda vivos (Inocentes, Xerife e Herói).
	othersAlive: number,
	timeUp: boolean,
}

export type Winner = "Murderer" | "Innocents"

export type ShotResult = "MurdererDown" | "Misfire"

local MurderRules = {}

-- Sorteio com peso: quem foi o papel menos vezes tem mais chance.
local function weightedPick(candidates: { number }, countOf: (number) -> number, random: () -> number): number
	local total = 0
	local weights: { number } = {}
	for index, id in ipairs(candidates) do
		weights[index] = 1 / (1 + countOf(id))
		total += weights[index]
	end
	local roll = random() * total
	for index, id in ipairs(candidates) do
		roll -= weights[index]
		if roll <= 0 then
			return id
		end
	end
	return candidates[#candidates]
end

-- Um Assassino e um Xerife entre os humanos (bots nunca recebem esses
-- papéis). O Assassino da partida anterior não repete quando há outra opção.
-- nil com menos de dois.
function MurderRules.assignRoles(candidates: { number }, history: { [number]: RoleHistory }, lastMurderer: number?, random: () -> number): Roles?
	if #candidates < 2 then
		return nil
	end
	local murdererPool: { number } = {}
	for _, id in ipairs(candidates) do
		if id ~= lastMurderer then
			table.insert(murdererPool, id)
		end
	end
	if #murdererPool == 0 then
		murdererPool = table.clone(candidates)
	end
	local murderer = weightedPick(murdererPool, function(id)
		local entry = history[id]
		return if entry ~= nil then entry.murderer else 0
	end, random)
	local sheriffPool: { number } = {}
	for _, id in ipairs(candidates) do
		if id ~= murderer then
			table.insert(sheriffPool, id)
		end
	end
	local sheriff = weightedPick(sheriffPool, function(id)
		local entry = history[id]
		return if entry ~= nil then entry.sheriff else 0
	end, random)
	return { murderer = murderer, sheriff = sheriff }
end

-- Quem venceu, ou nil se a partida segue.
function MurderRules.outcome(input: OutcomeInput): Winner?
	if not input.murdererAlive then
		return "Innocents"
	end
	if input.othersAlive == 0 then
		return "Murderer"
	end
	if input.timeUp then
		return "Innocents"
	end
	return nil
end

-- Tiro do Xerife (ou do Herói) que acertou alguém: no Assassino, os
-- Inocentes vencem; em qualquer outro, o alvo e quem atirou saem e a arma cai.
function MurderRules.shotResult(victimRole: Role): ShotResult
	return if victimRole == "Murderer" then "MurdererDown" else "Misfire"
end

-- A arma caída é de qualquer Inocente humano vivo (vira o Herói).
function MurderRules.canPickUp(role: Role, isBot: boolean, alive: boolean): boolean
	return role == "Innocent" and not isBot and alive
end

-- Faca e arma só depois da proteção da largada e fora da recarga.
function MurderRules.actionReady(elapsed: number, grace: number, lastUsed: number?, cooldown: number, now: number): boolean
	if elapsed < grace then
		return false
	end
	return lastUsed == nil or now - lastUsed >= cooldown
end

-- O alvo está ao alcance da faca: dentro de `range` e até `coneDegrees`/2
-- para cada lado da direção do olhar, no plano (x, z). Colado conta mesmo
-- sem direção.
function MurderRules.inStabReach(offsetX: number, offsetZ: number, lookX: number, lookZ: number, range: number, coneDegrees: number): boolean
	local distance = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
	if distance > range then
		return false
	end
	if distance < 1 then
		return true
	end
	local lookLength = math.sqrt(lookX * lookX + lookZ * lookZ)
	if lookLength < 1e-3 then
		return false
	end
	local cosine = (offsetX * lookX + offsetZ * lookZ) / (distance * lookLength)
	return cosine >= math.cos(math.rad(coneDegrees / 2))
end

-- Moeda nova no saco, ou nil se o saco já está cheio.
function MurderRules.collect(current: number, bagSize: number): number?
	if current >= bagSize then
		return nil
	end
	return current + 1
end

function MurderRules.coinTickets(coins: number, coinsPerTicket: number, maxTickets: number): number
	if coinsPerTicket <= 0 then
		return 0
	end
	return math.clamp(math.floor(coins / coinsPerTicket), 0, maxTickets)
end

return table.freeze(MurderRules)
