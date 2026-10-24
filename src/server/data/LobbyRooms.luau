--!strict

-- Em qual cômodo do lobby (Casarão, ala leste, Sótão, Porão, salas
-- secretas) está uma posição, sem Roblox: para a telemetria RoomEntered e
-- SecretRoomOpened (Fase 5C). Os testes rodam no Lune
-- (tests/LobbyRooms.spec.luau).

export type Zone = {
	name: string,
	minX: number,
	maxX: number,
	minY: number,
	maxY: number,
	minZ: number,
	maxZ: number,
	-- Sala secreta do Barão (a primeira visita também conta como "aberta").
	secret: boolean?,
}

local LobbyRooms = {}

-- Primeira zona da lista que contém o ponto (a ordem é a prioridade: salas
-- secretas e andares antes dos cômodos do térreo). nil fora de todas.
function LobbyRooms.zoneAt(zones: { Zone }, x: number, y: number, z: number): Zone?
	for _, zone in ipairs(zones) do
		if x >= zone.minX and x <= zone.maxX and y >= zone.minY and y <= zone.maxY and z >= zone.minZ and z <= zone.maxZ then
			return zone
		end
	end
	return nil
end

-- Primeira vez nesta zona na sessão? Marca em `visited` e devolve true.
function LobbyRooms.firstVisit(visited: { [string]: boolean }, zone: string): boolean
	if visited[zone] then
		return false
	end
	visited[zone] = true
	return true
end

return table.freeze(LobbyRooms)
