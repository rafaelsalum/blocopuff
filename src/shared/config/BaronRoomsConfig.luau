--!strict

-- Salas Secretas do Barão (Fase 5C.3, parte 3):
--   * Study: o Gabinete do Vovô Puff, atrás da estante giratória da
--     Biblioteca. Abre para quem achou as 10 páginas do Diário.
--   * Treasure: a sala do tesouro, no fim do túnel do Porão. Abre para quem
--     resolveu o Cofrinho do Porão.
-- Cada sala dá um prêmio uma vez por jogador (troféu ou baú). Amigos podem
-- entrar junto enquanto quem tem acesso estiver perto, mas não ganham o
-- prêmio. Ids ficam salvos nos perfis: nunca renomeie.

export type RoomId = "Study" | "Treasure"

export type RoomInfo = {
	name: string,
	icon: string,
	title: string,
	-- Texto do prompt do prêmio.
	action: string,
	object: string,
	-- Aviso de quando a passagem abre para o jogador.
	hint: string,
}

local BaronRoomsConfig = {}

BaronRoomsConfig.Ids = table.freeze({ "Study", "Treasure" } :: { RoomId })

BaronRoomsConfig.Info = table.freeze({
	Study = table.freeze({
		name = "Gabinete do Vovô Puff",
		icon = "📚",
		title = "Herdeiro do Vovô Puff",
		action = "Pegar o troféu",
		object = "Troféu do Vovô Puff",
		hint = "A estante do leste da Biblioteca se abriu",
	}),
	Treasure = table.freeze({
		name = "Sala do Tesouro",
		icon = "💰",
		title = "Caçador de Tesouros",
		action = "Abrir o baú",
		object = "Baú do Tesouro",
		hint = "O túnel do Porão está aberto",
	}),
} :: { [RoomId]: RoomInfo })

BaronRoomsConfig.Tickets = 15

-- Passagem: abre para um amigo quando alguém com acesso está a até
-- `OwnerRadius` studs da entrada (no mesmo andar, até `OwnerHeight` de
-- diferença), e fecha `CloseDelay` segundos depois de ele sair.
BaronRoomsConfig.OwnerRadius = 14
BaronRoomsConfig.OwnerHeight = 6
BaronRoomsConfig.CloseDelay = 3
BaronRoomsConfig.CheckInterval = 0.25
BaronRoomsConfig.ShelfTurnSeconds = 1.2

-- Prêmio: prompt e conferência do servidor (distância e folga da sala).
BaronRoomsConfig.PromptDistance = 8
BaronRoomsConfig.ServerDistance = 12
BaronRoomsConfig.RoomMargin = 1
BaronRoomsConfig.ClaimCooldown = 1

-- Atributos.
BaronRoomsConfig.PromptAttribute = "BaronRoomId"
-- No Player: "Study"/"Treasure" verdadeiros para quem tem acesso (o
-- servidor publica; os amigos usam para saber se o dono está perto).
BaronRoomsConfig.AccessAttributePrefix = "BaronRoom_"
-- Peças que somem (e deixam passar) para quem tem a passagem aberta: o
-- lacre do vão e as tábuas do túnel. Valor: id da sala.
BaronRoomsConfig.PassageAttribute = "BaronPassage"
-- A estante giratória da Biblioteca (valor: id da sala).
BaronRoomsConfig.ShelfAttribute = "BaronShelf"
-- Quanto a estante gira para abrir (graus).
BaronRoomsConfig.ShelfOpenDegrees = 85

-- Títulos das salas já abertas (lista de ids do perfil), na ordem dos ids.
function BaronRoomsConfig.titlesFor(rooms: { string }): { string }
	local titles = {}
	for _, id in ipairs(BaronRoomsConfig.Ids) do
		if table.find(rooms, id) ~= nil then
			table.insert(titles, BaronRoomsConfig.Info[id :: RoomId].title)
		end
	end
	return titles
end

return table.freeze(BaronRoomsConfig)
