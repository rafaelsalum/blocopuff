--!strict

-- Regras do Mistério no Casarão (Fase 5D.3), sem Roblox: sorteio dos papéis,
-- fim da partida, quem pode pegar o Puffador do chão, proteção e recarga do
-- susto e do lençol, e moedas em tickets. Os testes rodam no Lune
-- (tests/MysteryModeRules.spec.luau).

export type Role = "Ghost" | "Detective" | "Resident"

export type RoleHistory = {
	ghost: number,
	detective: number,
}

export type Roles = {
	ghost: number,
	detective: number,
}

export type OutcomeInput = {
	ghostAwake: boolean,
	-- Moradores (inclusive Detetive e Herói) ainda acordados.
	awakeResidents: number,
	timeUp: boolean,
}

export type Winner = "Ghost" | "Residents"

local MysteryModeRules = {}

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

-- Um Fantasma e um Detetive entre os candidatos (só humanos). O Fantasma da
-- partida anterior não repete quando há outra opção. nil com menos de dois.
function MysteryModeRules.assignRoles(candidates: { number }, history: { [number]: RoleHistory }, lastGhost: number?, random: () -> number): Roles?
	if #candidates < 2 then
		return nil
	end
	local ghostPool: { number } = {}
	for _, id in ipairs(candidates) do
		if id ~= lastGhost then
			table.insert(ghostPool, id)
		end
	end
	if #ghostPool == 0 then
		ghostPool = table.clone(candidates)
	end
	local ghost = weightedPick(ghostPool, function(id)
		local entry = history[id]
		return if entry ~= nil then entry.ghost else 0
	end, random)
	local detectivePool: { number } = {}
	for _, id in ipairs(candidates) do
		if id ~= ghost then
			table.insert(detectivePool, id)
		end
	end
	local detective = weightedPick(detectivePool, function(id)
		local entry = history[id]
		return if entry ~= nil then entry.detective else 0
	end, random)
	return { ghost = ghost, detective = detective }
end

-- Quem venceu, ou nil se a partida segue.
function MysteryModeRules.outcome(input: OutcomeInput): Winner?
	if not input.ghostAwake then
		return "Residents"
	end
	if input.awakeResidents == 0 then
		return "Ghost"
	end
	if input.timeUp then
		return "Residents"
	end
	return nil
end

-- O Puffador caído é de qualquer Morador humano acordado (vira o Herói),
-- menos de quem já o derrubou por errar o tiro nesta partida.
function MysteryModeRules.canPickUp(role: Role, isBot: boolean, awake: boolean, disarmed: boolean): boolean
	return role ~= "Ghost" and not isBot and awake and not disarmed
end

-- Susto e lençol só depois da proteção da largada e fora da recarga.
function MysteryModeRules.actionReady(elapsed: number, grace: number, lastUsed: number?, cooldown: number, now: number): boolean
	if elapsed < grace then
		return false
	end
	return lastUsed == nil or now - lastUsed >= cooldown
end

function MysteryModeRules.coinTickets(coins: number, coinsPerTicket: number, maxTickets: number): number
	if coinsPerTicket <= 0 then
		return 0
	end
	return math.clamp(math.floor(coins / coinsPerTicket), 0, maxTickets)
end

return table.freeze(MysteryModeRules)
