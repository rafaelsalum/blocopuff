--!strict

-- Regras puras das Salas Secretas do Barão (Fase 5C.3, parte 3): acesso,
-- "está dentro da sala", prêmio uma vez por jogador e quando a passagem
-- aparece aberta no cliente. Sem Roblox (testes no Lune:
-- tests/BaronRoomsRules.spec.luau); devolvem tabelas NOVAS.

export type Box = {
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

export type Outcome = {
	tickets: number,
	-- Quantas salas o jogador já abriu, contando esta.
	count: number,
}

local BaronRoomsRules = {}

-- Gabinete: todas as páginas do Diário. Tesouro: o cofrinho resolvido.
function BaronRoomsRules.hasAccess(id: string, diaryOwned: number, diaryTotal: number, safeSolved: boolean): boolean
	if id == "Study" then
		return diaryTotal > 0 and diaryOwned >= diaryTotal
	elseif id == "Treasure" then
		return safeSolved
	end
	return false
end

function BaronRoomsRules.inside(x: number, y: number, z: number, box: Box, margin: number): boolean
	return x >= box.minX - margin
		and x <= box.maxX + margin
		and y >= box.minY - margin
		and y <= box.maxY + margin
		and z >= box.minZ - margin
		and z <= box.maxZ + margin
end

-- Registra o prêmio da sala `id` (uma vez). Devolve nil se já pegou ou se
-- a sala não existe.
function BaronRoomsRules.claim(
	rooms: { [string]: number },
	id: string,
	ids: { string },
	tickets: number,
	now: number
): ({ [string]: number }?, Outcome?)
	if rooms[id] ~= nil or table.find(ids, id) == nil then
		return nil, nil
	end
	local updated = table.clone(rooms)
	updated[id] = now
	local count = 0
	for _, other in ipairs(ids) do
		if updated[other] ~= nil then
			count += 1
		end
	end
	return updated, { tickets = tickets, count = count }
end

-- A passagem aparece aberta para este jogador? Sempre para quem tem acesso
-- e para quem já está dentro (ninguém fica preso). Para um amigo, enquanto
-- alguém com acesso estiver a até `radius` (`ownerDistance`, nil se
-- ninguém) e por `closeDelay` segundos depois. Devolve também o último
-- instante em que havia dono perto.
function BaronRoomsRules.shouldOpen(
	hasAccess: boolean,
	inside: boolean,
	ownerDistance: number?,
	radius: number,
	lastNearAt: number?,
	now: number,
	closeDelay: number
): (boolean, number?)
	if hasAccess or inside then
		return true, lastNearAt
	end
	if ownerDistance ~= nil and ownerDistance <= radius then
		return true, now
	end
	if lastNearAt ~= nil and now - lastNearAt < closeDelay then
		return true, lastNearAt
	end
	return false, lastNearAt
end

return table.freeze(BaronRoomsRules)
