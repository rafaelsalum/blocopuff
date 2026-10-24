--!strict

-- Regras puras do Mapa do Casarão (Fase 5C.4): quantos cômodos o jogador
-- já conhece e se conhece todos. Só contam os cômodos que não são secretos.
-- Sem Roblox (testes no Lune: tests/MansionMapRules.spec.luau).

export type Room = {
	id: string,
	secret: boolean,
}

local MansionMapRules = {}

function MansionMapRules.progress(rooms: { Room }, visited: { [string]: any }): (number, number)
	local count, total = 0, 0
	for _, room in ipairs(rooms) do
		if not room.secret then
			total += 1
			if visited[room.id] ~= nil then
				count += 1
			end
		end
	end
	return count, total
end

-- Porcentagem inteira (arredondada para baixo: 100% só com todos).
function MansionMapRules.percent(rooms: { Room }, visited: { [string]: any }): number
	local count, total = MansionMapRules.progress(rooms, visited)
	return if total > 0 then math.floor(count * 100 / total) else 0
end

function MansionMapRules.complete(rooms: { Room }, visited: { [string]: any }): boolean
	local count, total = MansionMapRules.progress(rooms, visited)
	return total > 0 and count >= total
end

-- O cômodo existe no mapa?
function MansionMapRules.isRoom(rooms: { Room }, id: unknown): boolean
	if typeof(id) ~= "string" then
		return false
	end
	for _, room in ipairs(rooms) do
		if room.id == id then
			return true
		end
	end
	return false
end

return table.freeze(MansionMapRules)
