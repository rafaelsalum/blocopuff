--!strict

-- Mapa do Casarão (Fase 5C.4): os cômodos que o mapa mostra, na ordem dos
-- andares. Cada um aparece quando o jogador entra nele (salvo no perfil) e
-- conta para o "% explorado"; chegar a 100% dá a conquista Explorador. As
-- Salas Secretas do Barão (`secret`) só aparecem depois de visitadas e não
-- contam (dependem dos mistérios). Os ids são os nomes dos cômodos nos
-- layouts (MansionLayout, MansionWingLayout, TrophyRoomLayout,
-- TowerHallLayout, BaronRoomsLayout) e ficam salvos nos perfis: nunca renomeie.
-- Sem dependências (os testes do Lune carregam este arquivo direto).

export type MapFloor = "Main" | "Attic" | "Cellar"

export type MapRoom = {
	id: string,
	name: string,
	icon: string,
	floor: MapFloor,
	secret: boolean,
}

local function room(id: string, name: string, icon: string, floor: MapFloor, secret: boolean?): MapRoom
	return table.freeze({ id = id, name = name, icon = icon, floor = floor, secret = secret == true })
end

local MansionMapConfig = {}

MansionMapConfig.Rooms = table.freeze({
	room("GrandHall", "Salão Principal", "🏠", "Main"),
	room("Collection", "Salão da Coleção", "✨", "Main"),
	room("Garden", "Jardim do Barão", "🐶", "Main"),
	room("Meeting", "Ponto de Encontro", "👥", "Main"),
	room("Training", "Treino", "🎯", "Main"),
	room("Library", "Biblioteca", "📚", "Main"),
	-- 🪜 não existe na fonte do Roblox (vira um quadrado).
	room("StairHall", "Escadaria", "👣", "Main"),
	room("Music", "Sala de Música", "🎹", "Main"),
	room("Trophy", "Sala dos Troféus", "🏆", "Main"),
	room("TowerHall", "Saguão da Torre", "🕰️", "Main"),
	room("Study", "Gabinete do Vovô Puff", "📖", "Main", true),
	room("Attic", "Sótão", "🕯️", "Attic"),
	room("Cellar", "Porão", "🍷", "Cellar"),
	room("Treasure", "Sala do Tesouro", "💰", "Cellar", true),
} :: { MapRoom })

MansionMapConfig.Floors = table.freeze({
	table.freeze({ id = "Main" :: MapFloor, name = "Térreo" }),
	table.freeze({ id = "Attic" :: MapFloor, name = "Sótão" }),
	table.freeze({ id = "Cellar" :: MapFloor, name = "Porão" }),
})

-- Conquista secreta de quem conhece todos os cômodos que contam.
MansionMapConfig.ExplorerSecretId = "explorador"
MansionMapConfig.MaxIdLength = 16

return table.freeze(MansionMapConfig)
