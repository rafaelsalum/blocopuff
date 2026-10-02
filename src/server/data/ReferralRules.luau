--!strict

-- Regras puras do convite com recompensa, sem Roblox. Os testes rodam no
-- Lune (tests/ReferralRules.spec.luau).
--
--   * Quem convidou só fica registrado no perfil de quem nunca jogou, e
--     nunca é trocado depois.
--   * Quem convidou ganha por amigo que jogou a primeira partida, uma vez
--     por amigo, até `InviterMaxPerDay` amigos por dia e `InviterMaxTotal`
--     no total (contas descartáveis não viram fonte infinita de tickets).

export type InviterState = {
	-- Dia do jogo (DailyRules.dayIndex) do contador `dayCount`.
	day: number,
	dayCount: number,
	-- Amigos (UserId) que já renderam prêmio, desde sempre.
	friends: { number },
}

export type ReferralLimits = {
	InviterMaxPerDay: number,
	InviterMaxTotal: number,
}

local ReferralRules = {}

function ReferralRules.canRecordInviter(matches: number, currentInviter: number, inviterId: number, playerId: number): boolean
	return matches <= 0 and currentInviter <= 0 and inviterId > 0 and inviterId ~= playerId
end

-- Quais dos amigos `candidates` rendem prêmio agora (nunca o mesmo amigo
-- duas vezes) e o novo estado.
function ReferralRules.inviterGrant(state: InviterState, today: number, candidates: { number }, limits: ReferralLimits): ({ number }, InviterState)
	local dayCount = if state.day == today then state.dayCount else 0
	local friends = table.clone(state.friends)
	local granted: { number } = {}
	for _, id in ipairs(candidates) do
		if dayCount >= limits.InviterMaxPerDay or #friends >= limits.InviterMaxTotal then
			break
		end
		if id > 0 and table.find(friends, id) == nil then
			table.insert(friends, id)
			table.insert(granted, id)
			dayCount += 1
		end
	end
	return granted, { day = today, dayCount = dayCount, friends = friends }
end

-- Lista de convidados esperando quem convidou entrar no jogo, como veio do
-- DataStore: só UserIds válidos, sem repetir, no máximo `keep` (os mais novos).
function ReferralRules.readPending(stored: unknown, keep: number): { number }
	local list: { number } = {}
	if typeof(stored) == "table" then
		for _, value in ipairs(stored :: { unknown }) do
			if typeof(value) == "number" and value > 0 and math.floor(value) == value and table.find(list, value) == nil then
				table.insert(list, value)
			end
		end
	end
	while #list > keep do
		table.remove(list, 1)
	end
	return list
end

-- A mesma lista com mais um convidado (sem repetir; os mais novos ficam).
function ReferralRules.addPending(stored: unknown, inviteeId: number, keep: number): { number }
	local list = ReferralRules.readPending(stored, keep)
	if table.find(list, inviteeId) == nil then
		table.insert(list, inviteeId)
	end
	while #list > keep do
		table.remove(list, 1)
	end
	return list
end

return table.freeze(ReferralRules)
