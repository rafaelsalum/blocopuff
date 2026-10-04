--!strict

-- Relíquias e Álbum do Casarão (Fase 5C.2): 40 objetos pequenos, 5 em cada
-- um de 8 cômodos. Pegar cada uma dá tickets; completar um cômodo dá mais
-- tickets e um título; completar o álbum dá o Puff Explorador. A Relíquia
-- do Dia muda de esconderijo a cada dia e tem coleção própria.
--
-- Os esconderijos são frações (u, v) do cômodo: u de oeste (0) a leste (1)
-- e v de norte (0) a sul (1), com uma folga das paredes. O servidor
-- (RelicService) acomoda cada relíquia em cima do que houver ali (piso ou
-- móvel baixo).
--
-- Ids ficam salvos nos perfis: nunca renomeie nem reaproveite um id.
-- Sem dependências (os testes do Lune carregam este arquivo direto).

export type RelicShape = "Key" | "Coin" | "Puff" | "Portrait" | "Chess"

export type RelicDefinition = {
	id: string,
	name: string,
	-- Pista curta no Álbum (onde procurar, sem entregar o lugar).
	hint: string,
	shape: RelicShape,
	-- Cor principal, em RGB (0 a 255).
	color: { number },
	room: string,
	u: number,
	v: number,
}

export type RelicRoom = {
	id: string,
	name: string,
	emoji: string,
	-- Título ganho ao completar o cômodo.
	title: string,
	relics: { RelicDefinition },
}

export type DailySpot = {
	room: string,
	u: number,
	v: number,
}

export type Rewards = {
	RelicTickets: number,
	RoomTickets: number,
	DailyTickets: number,
	-- Relíquias do Dia para completar a coleção (prêmio e título).
	DailyGoal: number,
	DailyGoalTickets: number,
}

local CORNER = 0.15

-- Pista a partir do esconderijo: canto, junto a uma parede ou longe delas.
local function hintFor(u: number, v: number): string
	local edgeU = u <= CORNER or u >= 1 - CORNER
	local edgeV = v <= CORNER or v >= 1 - CORNER
	if edgeU and edgeV then
		return "Num cantinho do cômodo"
	elseif edgeU or edgeV then
		return "Junto a uma parede"
	end
	return "Longe das paredes"
end

local BRASS = { 214, 170, 70 }
local GOLD = { 255, 205, 80 }
local SILVER = { 200, 205, 215 }
local COPPER = { 196, 112, 60 }
local WOOD = { 140, 96, 60 }
local IVORY = { 240, 232, 210 }
local EBONY = { 50, 44, 48 }
local PINK = { 255, 170, 214 }
local MINT = { 150, 240, 200 }
local SKY = { 140, 200, 255 }
local LILAC = { 196, 160, 255 }
local GHOST = { 225, 235, 255 }
local MOSS = { 120, 150, 96 }

local function relic(id: string, name: string, shape: RelicShape, color: { number }, u: number, v: number): RelicDefinition
	return { id = id, name = name, hint = hintFor(u, v), shape = shape, color = color, room = "", u = u, v = v }
end

local ROOMS: { RelicRoom } = {
	{
		id = "GrandHall",
		name = "Salão Principal",
		emoji = "🏠",
		title = "Anfitrião",
		relics = {
			relic("salao_puff", "Puff Dourado", "Puff", GOLD, 0.05, 0.08),
			relic("salao_moeda", "Moeda do Barão", "Coin", GOLD, 0.95, 0.92),
			relic("salao_retrato", "Retrato da Vovó Puff", "Portrait", PINK, 0.92, 0.06),
			relic("salao_chave", "Chave do Salão", "Key", BRASS, 0.3, 0.5),
			relic("salao_rei", "Rei de Xadrez", "Chess", IVORY, 0.06, 0.94),
		},
	},
	{
		id = "Collection",
		name = "Salão da Coleção",
		emoji = "✨",
		title = "Colecionador",
		relics = {
			relic("colecao_puff", "Puff de Cristal", "Puff", SKY, 0.04, 0.1),
			relic("colecao_moeda", "Moeda Rara", "Coin", SILVER, 0.35, 0.92),
			relic("colecao_retrato", "Retrato do Fundador", "Portrait", LILAC, 0.62, 0.06),
			relic("colecao_chave", "Chave da Vitrine", "Key", SILVER, 0.8, 0.5),
			relic("colecao_torre", "Torre de Xadrez", "Chess", EBONY, 0.97, 0.9),
		},
	},
	{
		id = "Garden",
		name = "Jardim do Barão",
		emoji = "🐶",
		title = "Amigo do Barão",
		relics = {
			relic("jardim_puff", "Puff de Jardim", "Puff", MINT, 0.08, 0.06),
			relic("jardim_moeda", "Moeda Enterrada", "Coin", COPPER, 0.5, 0.3),
			relic("jardim_retrato", "Retrato do Barão Filhote", "Portrait", WOOD, 0.94, 0.95),
			relic("jardim_chave", "Chave do Portão", "Key", COPPER, 0.07, 0.93),
			relic("jardim_cavalo", "Cavalo de Xadrez", "Chess", IVORY, 0.6, 0.75),
		},
	},
	{
		id = "Meeting",
		name = "Ponto de Encontro",
		emoji = "👥",
		title = "Detetive",
		relics = {
			relic("encontro_puff", "Puff Detetive", "Puff", WOOD, 0.05, 0.92),
			relic("encontro_moeda", "Moeda da Sorte", "Coin", GOLD, 0.94, 0.9),
			relic("encontro_retrato", "Retrato da Turma", "Portrait", SKY, 0.45, 0.94),
			relic("encontro_chave", "Chave do Cofre Velho", "Key", BRASS, 0.7, 0.45),
			relic("encontro_bispo", "Bispo de Xadrez", "Chess", EBONY, 0.06, 0.08),
		},
	},
	{
		id = "Library",
		name = "Biblioteca",
		emoji = "📚",
		title = "Bibliotecário",
		relics = {
			relic("biblioteca_puff", "Puff Leitor", "Puff", LILAC, 0.94, 0.07),
			relic("biblioteca_moeda", "Moeda Esquecida", "Coin", SILVER, 0.06, 0.06),
			relic("biblioteca_retrato", "Retrato do Escritor", "Portrait", MOSS, 0.5, 0.5),
			relic("biblioteca_chave", "Chave de Latão", "Key", BRASS, 0.95, 0.92),
			relic("biblioteca_rainha", "Rainha de Xadrez", "Chess", IVORY, 0.3, 0.9),
		},
	},
	{
		id = "Music",
		name = "Sala de Música",
		emoji = "🎹",
		title = "Maestro",
		relics = {
			relic("musica_puff", "Puff Cantor", "Puff", PINK, 0.95, 0.94),
			relic("musica_moeda", "Moeda do Gramofone", "Coin", GOLD, 0.06, 0.92),
			relic("musica_retrato", "Retrato da Pianista", "Portrait", LILAC, 0.94, 0.1),
			relic("musica_chave", "Chave de Afinar", "Key", SILVER, 0.55, 0.55),
			relic("musica_peao", "Peão Musical", "Chess", EBONY, 0.35, 0.08),
		},
	},
	{
		id = "Attic",
		name = "Sótão",
		emoji = "🕯️",
		title = "Rato de Sótão",
		relics = {
			relic("sotao_puff", "Puff Empoeirado", "Puff", IVORY, 0.06, 0.04),
			relic("sotao_moeda", "Moeda Antiga", "Coin", COPPER, 0.94, 0.16),
			relic("sotao_retrato", "Retrato Rachado", "Portrait", WOOD, 0.5, 0.56),
			relic("sotao_chave", "Chave Enferrujada", "Key", COPPER, 0.08, 0.78),
			relic("sotao_rei", "Rei de Madeira", "Chess", WOOD, 0.92, 0.96),
		},
	},
	{
		id = "Cellar",
		name = "Porão",
		emoji = "🍷",
		title = "Guardião do Porão",
		relics = {
			relic("porao_puff", "Puff Fantasma", "Puff", GHOST, 0.94, 0.04),
			relic("porao_moeda", "Moeda Perdida", "Coin", SILVER, 0.06, 0.24),
			relic("porao_retrato", "Retrato Mofado", "Portrait", MOSS, 0.5, 0.45),
			relic("porao_chave", "Chave do Barril", "Key", BRASS, 0.92, 0.86),
			relic("porao_torre", "Torre de Pedra", "Chess", SILVER, 0.08, 0.96),
		},
	},
}

-- Esconderijos da Relíquia do Dia (um por dia, sorteado). Incluem lugares
-- sem relíquia fixa (Escadaria e Treino).
local DAILY_SPOTS: { DailySpot } = {
	{ room = "GrandHall", u = 0.7, v = 0.2 },
	{ room = "Collection", u = 0.2, v = 0.5 },
	{ room = "Garden", u = 0.3, v = 0.95 },
	{ room = "Meeting", u = 0.25, v = 0.5 },
	{ room = "Training", u = 0.9, v = 0.9 },
	{ room = "Library", u = 0.7, v = 0.25 },
	{ room = "StairHall", u = 0.06, v = 0.5 },
	{ room = "Music", u = 0.2, v = 0.5 },
	{ room = "Attic", u = 0.4, v = 0.9 },
	{ room = "Cellar", u = 0.5, v = 0.92 },
	{ room = "GrandHall", u = 0.75, v = 0.85 },
	{ room = "Garden", u = 0.9, v = 0.5 },
}

local REWARDS: Rewards = table.freeze({
	RelicTickets = 1,
	RoomTickets = 5,
	DailyTickets = 2,
	DailyGoal = 30,
	DailyGoalTickets = 20,
})

local MAX_ID_LENGTH = 32

local byId: { [string]: RelicDefinition } = {}
local roomsById: { [string]: RelicRoom } = {}
local allIds: { string } = {}
for roomIndex, room in ipairs(ROOMS) do
	assert(roomsById[room.id] == nil, `Duplicated relic room {room.id}`)
	local frozen: { RelicDefinition } = {}
	for _, entry in ipairs(room.relics) do
		assert(byId[entry.id] == nil, `Duplicated relic id {entry.id}`)
		assert(#entry.id <= MAX_ID_LENGTH, `Relic id too long: {entry.id}`)
		assert(entry.u >= 0 and entry.u <= 1 and entry.v >= 0 and entry.v <= 1, `Relic spot out of range: {entry.id}`)
		local definition = table.freeze({
			id = entry.id,
			name = entry.name,
			hint = entry.hint,
			shape = entry.shape,
			color = table.freeze(table.clone(entry.color)),
			room = room.id,
			u = entry.u,
			v = entry.v,
		})
		byId[entry.id] = definition
		table.insert(frozen, definition)
		table.insert(allIds, entry.id)
	end
	local frozenRoom = table.freeze({
		id = room.id,
		name = room.name,
		emoji = room.emoji,
		title = room.title,
		relics = table.freeze(frozen),
	})
	ROOMS[roomIndex] = frozenRoom
	roomsById[room.id] = frozenRoom
end
for index, spot in ipairs(DAILY_SPOTS) do
	DAILY_SPOTS[index] = table.freeze(spot)
end

local RelicCatalog = {}

RelicCatalog.MaxIdLength = MAX_ID_LENGTH
RelicCatalog.Rewards = REWARDS
RelicCatalog.Tag = "Relic"
RelicCatalog.DailyTag = "DailyRelic"
RelicCatalog.IdAttribute = "RelicId"
RelicCatalog.DayAttribute = "RelicDay"
RelicCatalog.DailyName = "Relíquia do Dia"
-- Puff exclusivo de quem completa o álbum (ver PuffCatalog).
RelicCatalog.AlbumPuffId = "explorador"
RelicCatalog.AlbumTitle = "Explorador do Casarão"
RelicCatalog.DailyTitle = "Caçador de Relíquias"

function RelicCatalog.rooms(): { RelicRoom }
	return ROOMS
end

function RelicCatalog.room(id: unknown): RelicRoom?
	if typeof(id) ~= "string" then
		return nil
	end
	return roomsById[id]
end

function RelicCatalog.get(id: unknown): RelicDefinition?
	if typeof(id) ~= "string" then
		return nil
	end
	return byId[id]
end

-- Todos os ids, na ordem do álbum.
function RelicCatalog.allIds(): { string }
	return allIds
end

-- Ids das relíquias de um cômodo.
function RelicCatalog.roomIds(roomId: string): { string }
	local ids: { string } = {}
	local room = roomsById[roomId]
	if room ~= nil then
		for _, definition in ipairs(room.relics) do
			table.insert(ids, definition.id)
		end
	end
	return ids
end

function RelicCatalog.dailySpots(): { DailySpot }
	return DAILY_SPOTS
end

-- Quantas relíquias de um cômodo estão em `owned`.
function RelicCatalog.roomCount(owned: { [string]: any }, roomId: string): number
	local count = 0
	local room = roomsById[roomId]
	if room ~= nil then
		for _, definition in ipairs(room.relics) do
			if owned[definition.id] ~= nil then
				count += 1
			end
		end
	end
	return count
end

-- Títulos ganhos, do mais importante para o menos: álbum completo, coleção
-- da Relíquia do Dia e os cômodos completos (na ordem do álbum).
function RelicCatalog.titlesFor(owned: { [string]: any }, dailyCount: number): { string }
	local titles: { string } = {}
	local total = 0
	for _, id in ipairs(allIds) do
		if owned[id] ~= nil then
			total += 1
		end
	end
	if total == #allIds then
		table.insert(titles, RelicCatalog.AlbumTitle)
	end
	if dailyCount >= REWARDS.DailyGoal then
		table.insert(titles, RelicCatalog.DailyTitle)
	end
	for _, room in ipairs(ROOMS) do
		if RelicCatalog.roomCount(owned, room.id) == #room.relics then
			table.insert(titles, room.title)
		end
	end
	return titles
end

return table.freeze(RelicCatalog)
