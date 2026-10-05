--!strict

-- Relíquias e Álbum do Casarão (Fase 5C.2): 40 objetos pequenos, 5 em cada
-- um de 8 cômodos, escondidos atrás, debaixo ou ao lado de móveis de
-- verdade. Pegar cada uma dá tickets; completar um cômodo dá mais tickets e
-- um título; completar o álbum dá o Puff Explorador. A Relíquia do Dia muda
-- de esconderijo a cada dia e tem coleção própria. As Temporadas trazem
-- páginas novas por tempo limitado (o álbum nunca "acaba").
--
-- Cada relíquia diz o MÓVEL onde fica (`anchor`, nome das peças do móvel;
-- `nth` escolhe entre móveis repetidos, como barris e baús) e o servidor
-- (RelicSpots) acha o canto mais escondido em volta dele. `u`/`v` (fração
-- do cômodo, de oeste a leste e de norte a sul) é a reserva se o móvel não
-- existir.
--
-- Ids ficam salvos nos perfis: nunca renomeie nem reaproveite um id.
-- Sem dependências (os testes do Lune carregam este arquivo direto).

export type RelicShape =
	"Puff"
	| "Watch"
	| "GoldCoin"
	| "SilverCoin"
	| "Key"
	| "King"
	| "Rook"
	| "Bishop"
	| "Teacup"
	| "Book"
	| "Compass"
	| "Potion"
	| "Pumpkin"

export type RelicDefinition = {
	id: string,
	name: string,
	-- Pista em charada no Álbum (onde procurar, sem entregar o lugar).
	hint: string,
	shape: RelicShape,
	-- Cor principal, em RGB (0 a 255). Modelos com textura própria ignoram.
	color: { number },
	-- Página do álbum (cômodo ou temporada).
	group: string,
	-- Cômodo onde está escondida.
	room: string,
	anchor: string,
	nth: number?,
	u: number,
	v: number,
}

export type RelicGroup = {
	id: string,
	name: string,
	emoji: string,
	-- Título ganho ao completar a página.
	title: string,
	-- Tickets extras ao completar a página.
	tickets: number,
	relics: { RelicDefinition },
	-- Temporada: só aparece no mundo entre `startsAt` e `endsAt` (os.time).
	season: boolean,
	startsAt: number,
	endsAt: number,
}

export type DailySpot = {
	room: string,
	anchor: string,
	nth: number?,
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
local ORANGE = { 255, 140, 40 }
local SLIME = { 120, 230, 90 }

type Entry = {
	id: string,
	name: string,
	shape: RelicShape,
	color: { number },
	room: string,
	anchor: string,
	nth: number?,
	hint: string,
	u: number,
	v: number,
}

-- `room` vazio: o cômodo da página (relíquias do álbum).
local function relic(id: string, name: string, shape: RelicShape, color: { number }, anchor: string, nth: number?, hint: string, u: number, v: number, room: string?): Entry
	return { id = id, name = name, shape = shape, color = color, room = room or "", anchor = anchor, nth = nth, hint = hint, u = u, v = v }
end

type GroupEntry = {
	id: string,
	name: string,
	emoji: string,
	title: string,
	tickets: number?,
	relics: { Entry },
	startsAt: number?,
	endsAt: number?,
}

local ROOMS: { GroupEntry } = {
	{
		id = "GrandHall",
		name = "Salão Principal",
		emoji = "🏠",
		title = "Anfitrião",
		relics = {
			relic("salao_puff", "Puff Dourado", "Puff", GOLD, "HallSofa1", nil, "Atrás de onde todo mundo descansa", 0.05, 0.08),
			relic("salao_moeda", "Moeda do Barão", "GoldCoin", GOLD, "HallPlant2", nil, "Onde as folhas fazem sombra", 0.95, 0.92),
			relic("salao_retrato", "Relógio do Vovô Puff", "Watch", GOLD, "Statue", nil, "Aos pés de quem vigia o salão", 0.92, 0.06),
			relic("salao_chave", "Chave do Salão", "Key", BRASS, "HallSofa2", nil, "Caiu do bolso de quem cochilou", 0.3, 0.5),
			relic("salao_rei", "Rei de Xadrez", "King", EBONY, "HallPlant4", nil, "Escondido no verde de um canto", 0.06, 0.94),
		},
	},
	{
		id = "Collection",
		name = "Salão da Coleção",
		emoji = "✨",
		title = "Colecionador",
		relics = {
			relic("colecao_puff", "Puff de Cristal", "Puff", SKY, "Pedestal1", nil, "Misturado aos Puffs da vitrine", 0.04, 0.1),
			relic("colecao_moeda", "Moeda Rara", "SilverCoin", SILVER, "PuffMachine", nil, "Perto de quem engole tickets", 0.35, 0.92),
			relic("colecao_retrato", "Livro dos Puffs", "Book", LILAC, "PuffdexLectern", nil, "Ao pé de onde se lê o Puffdex", 0.62, 0.06),
			relic("colecao_chave", "Chave da Vitrine", "Key", SILVER, "Pedestal5", nil, "Atrás de um pedestal de mármore", 0.8, 0.5),
			relic("colecao_torre", "Torre de Xadrez", "Rook", EBONY, "Pedestal9", nil, "Na ponta da fila de pedestais", 0.97, 0.9),
		},
	},
	{
		id = "Garden",
		name = "Jardim do Barão",
		emoji = "🐶",
		title = "Amigo do Barão",
		relics = {
			relic("jardim_puff", "Puff de Jardim", "Puff", MINT, "GardenPlant1", nil, "Brincando de esconde-esconde num vaso", 0.08, 0.06),
			relic("jardim_moeda", "Moeda Enterrada", "GoldCoin", GOLD, "BaraoBed", nil, "Onde o Barão sonha com ossos", 0.5, 0.3),
			relic("jardim_retrato", "Bússola do Jardineiro", "Compass", BRASS, "GardenPlant3", nil, "Perdida entre as plantas", 0.94, 0.95),
			relic("jardim_chave", "Chave do Portão", "Key", COPPER, "ShopCounter", nil, "Atrás do balcão da loja", 0.07, 0.93),
			relic("jardim_cavalo", "Frasco de Adubo Mágico", "Potion", MINT, "GardenPlant4", nil, "Junto a um vaso bem regado", 0.6, 0.75),
		},
	},
	{
		id = "Meeting",
		name = "Ponto de Encontro",
		emoji = "👥",
		title = "Detetive",
		relics = {
			relic("encontro_puff", "Puff Detetive", "Puff", WOOD, "MeetingSofa1", nil, "Onde os amigos param para conversar", 0.05, 0.92),
			relic("encontro_moeda", "Moeda da Sorte", "SilverCoin", SILVER, "MeetingTable", nil, "Onde a luz da mesa não alcança", 0.94, 0.9),
			relic("encontro_retrato", "Xícara da Turma", "Teacup", SKY, "MeetingSofa2", nil, "Esquecida depois do lanche", 0.45, 0.94),
			relic("encontro_chave", "Chave do Cofre Velho", "Key", BRASS, "ChallengeBoard", nil, "Atrás do quadro dos desafios", 0.7, 0.45),
			relic("encontro_bispo", "Bispo de Xadrez", "Bishop", IVORY, "PartyPost", nil, "Ao pé da placa da Party", 0.06, 0.08),
		},
	},
	{
		id = "Library",
		name = "Biblioteca",
		emoji = "📚",
		title = "Bibliotecário",
		relics = {
			relic("biblioteca_puff", "Puff Leitor", "Puff", LILAC, "ReadingChair1", nil, "Onde alguém lê em silêncio", 0.94, 0.07),
			relic("biblioteca_moeda", "Moeda Esquecida", "GoldCoin", GOLD, "NorthShelf2", nil, "Caiu de uma estante cheia de livros", 0.06, 0.06),
			relic("biblioteca_retrato", "Livro Proibido", "Book", WOOD, "ReadingTable", nil, "Debaixo da mesinha de leitura", 0.5, 0.5),
			relic("biblioteca_chave", "Chave de Latão", "Key", BRASS, "Ladder", nil, "Perto de quem sobe até os livros mais altos", 0.95, 0.92),
			relic("biblioteca_rainha", "Bússola do Escritor", "Compass", COPPER, "EastShelf3", nil, "Atrás da última estante", 0.3, 0.9),
		},
	},
	{
		id = "Music",
		name = "Sala de Música",
		emoji = "🎹",
		title = "Maestro",
		relics = {
			relic("musica_puff", "Puff Cantor", "Puff", PINK, "MusicSofa1", nil, "Onde a plateia se senta", 0.95, 0.94),
			relic("musica_moeda", "Moeda do Gramofone", "GoldCoin", GOLD, "GramophoneTable", nil, "Debaixo de quem toca discos", 0.06, 0.92),
			relic("musica_retrato", "Relógio da Pianista", "Watch", SILVER, "Piano", nil, "Onde as notas nascem", 0.94, 0.1),
			relic("musica_chave", "Chave de Afinar", "Key", SILVER, "MusicPlant", nil, "Junto à única planta da sala", 0.55, 0.55),
			relic("musica_peao", "Torre Musical", "Rook", IVORY, "MusicSofa2", nil, "Atrás do sofá do fundo", 0.35, 0.08),
		},
	},
	{
		id = "Attic",
		name = "Sótão",
		emoji = "🕯️",
		title = "Rato de Sótão",
		relics = {
			relic("sotao_puff", "Puff Empoeirado", "Puff", IVORY, "SheetCovered", 1, "Debaixo de um lençol de fantasma", 0.06, 0.04),
			relic("sotao_moeda", "Moeda Antiga", "GoldCoin", GOLD, "Chest", 1, "Ao lado de um baú trancado", 0.94, 0.16),
			relic("sotao_retrato", "Livro de Memórias", "Book", WOOD, "Chest", 3, "Junto ao baú mais esquecido", 0.5, 0.56),
			relic("sotao_chave", "Chave Enferrujada", "Key", COPPER, "SheetCovered", 3, "Entre os móveis cobertos", 0.08, 0.78),
			relic("sotao_rei", "Rei de Madeira", "King", WOOD, "Chest", 2, "Perto de um baú no escuro", 0.92, 0.96),
		},
	},
	{
		id = "Cellar",
		name = "Porão",
		emoji = "🍷",
		title = "Guardião do Porão",
		relics = {
			relic("porao_puff", "Puff Fantasma", "Puff", GHOST, "CellarTunnel", nil, "Na boca do túnel fechado", 0.94, 0.04),
			relic("porao_moeda", "Moeda Perdida", "SilverCoin", SILVER, "Barrel", 2, "Rolou para trás de um barril", 0.06, 0.24),
			relic("porao_retrato", "Frasco Misterioso", "Potion", LILAC, "WineRack", nil, "Junto às garrafas da adega", 0.5, 0.45),
			relic("porao_chave", "Chave do Barril", "Key", BRASS, "Barrel", 6, "Entre os barris do meio", 0.92, 0.86),
			relic("porao_torre", "Torre de Pedra", "Rook", SILVER, "Barrel", 9, "Atrás do último barril", 0.08, 0.96),
		},
	},
}

-- Temporadas: páginas por tempo limitado. A página fica no álbum para
-- sempre; as relíquias só aparecem no Casarão durante a temporada.
local SEASONS: { GroupEntry } = {
	{
		id = "Season1",
		name = "Noite das Abóboras",
		emoji = "🎃",
		title = "Caça-Abóboras",
		tickets = 10,
		-- 1º/out a 8/nov de 2026, inclusive (termina às 0h UTC de 9/nov).
		startsAt = 1790812800,
		endsAt = 1794182400,
		relics = {
			relic("t1_abobora1", "Abóbora Sorridente", "Pumpkin", ORANGE, "HallPlant1", nil, "Sorrindo atrás das folhas do salão", 0.1, 0.1, "GrandHall"),
			relic("t1_abobora2", "Abóbora Risonha", "Pumpkin", ORANGE, "GardenPlant2", nil, "Rindo à toa no jardim", 0.2, 0.2, "Garden"),
			relic("t1_abobora3", "Abóbora Dorminhoca", "Pumpkin", ORANGE, "Chest", 2, "Cochilando ao lado de um baú", 0.5, 0.3, "Attic"),
			relic("t1_pocao", "Poção da Bruxa", "Potion", SLIME, "Barrel", 4, "Borbulhando entre os barris", 0.3, 0.3, "Cellar"),
			relic("t1_cripta", "Chave da Cripta", "Key", EBONY, "Barrel", 7, "Abre a porta que ninguém abre", 0.7, 0.7, "Cellar"),
			relic("t1_feiticos", "Livro de Feitiços", "Book", LILAC, "NorthShelf1", nil, "Na primeira estante da biblioteca", 0.2, 0.1, "Library"),
			relic("t1_fantasma", "Puff Assombrado", "Puff", GHOST, "SheetCovered", 2, "Assustando debaixo de um lençol", 0.4, 0.6, "Attic"),
			relic("t1_relogio", "Relógio da Meia-Noite", "Watch", EBONY, "GramophoneTable", nil, "Toca à meia-noite perto da música", 0.2, 0.8, "Music"),
			relic("t1_moeda", "Moeda Encantada", "GoldCoin", GOLD, "MeetingTable", nil, "Brilha onde os amigos se reúnem", 0.6, 0.4, "Meeting"),
			relic("t1_bispo", "Bispo Sombrio", "Bishop", EBONY, "Pedestal3", nil, "Escondido na vitrine", 0.3, 0.2, "Collection"),
		},
	},
}

-- Esconderijos da Relíquia do Dia (um por dia, sorteado).
local DAILY_SPOTS: { DailySpot } = {
	{ room = "GrandHall", anchor = "HallPlant1", u = 0.7, v = 0.2 },
	{ room = "GrandHall", anchor = "HallPlant3", u = 0.75, v = 0.85 },
	{ room = "Collection", anchor = "Pedestal2", u = 0.2, v = 0.5 },
	{ room = "Garden", anchor = "GardenPlant2", u = 0.3, v = 0.95 },
	{ room = "Meeting", anchor = "MeetingSofa2", u = 0.25, v = 0.5 },
	{ room = "Library", anchor = "ReadingChair2", u = 0.7, v = 0.25 },
	{ room = "Library", anchor = "NorthShelf4", u = 0.8, v = 0.1 },
	{ room = "Library", anchor = "EastShelf1", u = 0.9, v = 0.5 },
	{ room = "Music", anchor = "GramophoneTable", u = 0.2, v = 0.5 },
	{ room = "Attic", anchor = "SheetCovered", nth = 2, u = 0.4, v = 0.9 },
	{ room = "Attic", anchor = "SheetCovered", nth = 4, u = 0.6, v = 0.2 },
	{ room = "Cellar", anchor = "Barrel", nth = 4, u = 0.5, v = 0.92 },
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
local groupsById: { [string]: RelicGroup } = {}
local albumIds: { string } = {}
local everyId: { string } = {}

local function freezeGroup(entry: GroupEntry, season: boolean): RelicGroup
	assert(groupsById[entry.id] == nil, `Duplicated relic group {entry.id}`)
	local frozen: { RelicDefinition } = {}
	for _, item in ipairs(entry.relics) do
		assert(byId[item.id] == nil, `Duplicated relic id {item.id}`)
		assert(#item.id <= MAX_ID_LENGTH, `Relic id too long: {item.id}`)
		assert(item.u >= 0 and item.u <= 1 and item.v >= 0 and item.v <= 1, `Relic spot out of range: {item.id}`)
		local room = if item.room ~= "" then item.room else entry.id
		local definition: RelicDefinition = table.freeze({
			id = item.id,
			name = item.name,
			hint = item.hint,
			shape = item.shape,
			color = table.freeze(table.clone(item.color)),
			group = entry.id,
			room = room,
			anchor = item.anchor,
			nth = item.nth,
			u = item.u,
			v = item.v,
		})
		byId[item.id] = definition
		table.insert(frozen, definition)
		table.insert(everyId, item.id)
		if not season then
			table.insert(albumIds, item.id)
		end
	end
	local group: RelicGroup = table.freeze({
		id = entry.id,
		name = entry.name,
		emoji = entry.emoji,
		title = entry.title,
		tickets = entry.tickets or REWARDS.RoomTickets,
		relics = table.freeze(frozen),
		season = season,
		startsAt = entry.startsAt or 0,
		endsAt = entry.endsAt or 0,
	})
	groupsById[entry.id] = group
	return group
end

local rooms: { RelicGroup } = {}
for _, entry in ipairs(ROOMS) do
	table.insert(rooms, freezeGroup(entry, false))
end
local seasons: { RelicGroup } = {}
for _, entry in ipairs(SEASONS) do
	assert((entry.startsAt or 0) < (entry.endsAt or 0), `Season {entry.id} needs startsAt < endsAt`)
	table.insert(seasons, freezeGroup(entry, true))
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
-- Pasta em ReplicatedStorage com uma miniatura 3D de cada relíquia (o
-- Álbum mostra a foto delas).
RelicCatalog.IconsFolder = "RelicIcons"
RelicCatalog.DayAttribute = "RelicDay"
RelicCatalog.DailyName = "Relíquia do Dia"
-- Puff exclusivo de quem completa o álbum (ver PuffCatalog).
RelicCatalog.AlbumPuffId = "explorador"
RelicCatalog.AlbumTitle = "Explorador do Casarão"
RelicCatalog.DailyTitle = "Caçador de Relíquias"

-- Páginas dos cômodos (o álbum fixo), na ordem.
function RelicCatalog.rooms(): { RelicGroup }
	return rooms
end

-- Páginas de temporada, na ordem.
function RelicCatalog.seasons(): { RelicGroup }
	return seasons
end

-- Qualquer página (cômodo ou temporada).
function RelicCatalog.group(id: unknown): RelicGroup?
	if typeof(id) ~= "string" then
		return nil
	end
	return groupsById[id]
end

-- Mantido para quem só lida com cômodos.
function RelicCatalog.room(id: unknown): RelicGroup?
	local group = RelicCatalog.group(id)
	return if group ~= nil and not group.season then group else nil
end

function RelicCatalog.get(id: unknown): RelicDefinition?
	if typeof(id) ~= "string" then
		return nil
	end
	return byId[id]
end

-- Ids das 40 relíquias do álbum fixo (o Puff Explorador conta só estas).
function RelicCatalog.allIds(): { string }
	return albumIds
end

-- Todos os ids (álbum e temporadas).
function RelicCatalog.everyId(): { string }
	return everyId
end

-- Ids das relíquias de uma página.
function RelicCatalog.groupIds(groupId: string): { string }
	local ids: { string } = {}
	local group = groupsById[groupId]
	if group ~= nil then
		for _, definition in ipairs(group.relics) do
			table.insert(ids, definition.id)
		end
	end
	return ids
end

RelicCatalog.roomIds = RelicCatalog.groupIds

-- Temporada no ar em `now` (os.time).
function RelicCatalog.isActive(group: RelicGroup, now: number): boolean
	return group.season and now >= group.startsAt and now < group.endsAt
end

function RelicCatalog.dailySpots(): { DailySpot }
	return DAILY_SPOTS
end

-- Quantas relíquias de uma página estão em `owned`.
function RelicCatalog.groupCount(owned: { [string]: any }, groupId: string): number
	local count = 0
	local group = groupsById[groupId]
	if group ~= nil then
		for _, definition in ipairs(group.relics) do
			if owned[definition.id] ~= nil then
				count += 1
			end
		end
	end
	return count
end

RelicCatalog.roomCount = RelicCatalog.groupCount

-- Títulos ganhos, do mais importante para o menos: álbum completo, coleção
-- da Relíquia do Dia, temporadas e os cômodos completos.
function RelicCatalog.titlesFor(owned: { [string]: any }, dailyCount: number): { string }
	local titles: { string } = {}
	local total = 0
	for _, id in ipairs(albumIds) do
		if owned[id] ~= nil then
			total += 1
		end
	end
	if total == #albumIds then
		table.insert(titles, RelicCatalog.AlbumTitle)
	end
	if dailyCount >= REWARDS.DailyGoal then
		table.insert(titles, RelicCatalog.DailyTitle)
	end
	for _, list in ipairs({ seasons, rooms }) do
		for _, group in ipairs(list) do
			if RelicCatalog.groupCount(owned, group.id) == #group.relics then
				table.insert(titles, group.title)
			end
		end
	end
	return titles
end

return table.freeze(RelicCatalog)
