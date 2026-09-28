--!strict

-- Primeira coleção do Puffdex. Conjunto enxuto em quatro raridades:
--   * 14 conquistados jogando (nível ou façanhas), com um Lendário do
--     Barão (Fase 4.1);
--   * 8 exclusivos da Puff Machine (Fase 4.2).
-- Nada aqui dá vantagem: só muda as cores do disparo.
--
-- Para acrescentar um Puff: nova entrada em ENTRIES com um `id` NOVO (ids
-- ficam salvos nos perfis: nunca renomeie nem reaproveite um id).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)

type PuffDefinition = PuffTypes.PuffDefinition
type PuffRarity = PuffTypes.PuffRarity
type PuffStyle = PuffTypes.PuffStyle

export type RarityInfo = {
	label: string,
	color: Color3,
	order: number,
}

local DEFAULT_ID = "branco"

-- Trading: modelo de inventário preparado (uid por item, `tradable`), mas
-- sem nenhuma forma de trocar. Não ligar antes da fase própria.
local TRADING_ENABLED = false

local RARITIES: { [PuffRarity]: RarityInfo } = {
	Common = { label = "Comum", color = Color3.fromRGB(205, 205, 222), order = 1 },
	Rare = { label = "Raro", color = Color3.fromRGB(92, 200, 255), order = 2 },
	Epic = { label = "Épico", color = Color3.fromRGB(196, 120, 255), order = 3 },
	Legendary = { label = "Lendário", color = Color3.fromRGB(255, 209, 102), order = 4 },
}

local function style(trailStart: Color3, trailEnd: Color3, glow: Color3, spark: Color3): PuffStyle
	return table.freeze({ trailStart = trailStart, trailEnd = trailEnd, glow = glow, spark = spark })
end

local rgb = Color3.fromRGB

local ENTRIES: { PuffDefinition } = {
	{
		id = "branco",
		name = "Puff Branco",
		rarity = "Common",
		origin = "Starter",
		unlock = { kind = "Starter" },
		hint = "Todo mundo começa com ele",
		style = style(rgb(255, 230, 148), rgb(194, 168, 255), rgb(255, 230, 148), rgb(255, 230, 148)),
		tradable = false,
	},
	{
		id = "algodao",
		name = "Puff Algodão Doce",
		rarity = "Common",
		origin = "Level",
		unlock = { kind = "Level", target = 3 },
		hint = "Chegue ao nível 3",
		style = style(rgb(255, 170, 214), rgb(150, 210, 255), rgb(255, 190, 225), rgb(255, 170, 214)),
		tradable = false,
	},
	{
		id = "menta",
		name = "Puff Menta",
		rarity = "Common",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "matches", target = 5 },
		hint = "Jogue 5 partidas",
		style = style(rgb(170, 255, 214), rgb(79, 214, 160), rgb(150, 255, 200), rgb(120, 240, 190)),
		tradable = false,
	},
	{
		id = "pessego",
		name = "Puff Pêssego",
		rarity = "Common",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "blocksDestroyed", target = 150 },
		hint = "Derrube 150 blocos",
		style = style(rgb(255, 200, 160), rgb(255, 140, 110), rgb(255, 180, 140), rgb(255, 170, 120)),
		tradable = false,
	},
	{
		id = "gelo",
		name = "Puff Gelo",
		rarity = "Rare",
		origin = "Level",
		unlock = { kind = "Level", target = 10 },
		hint = "Chegue ao nível 10",
		style = style(rgb(230, 250, 255), rgb(110, 200, 255), rgb(170, 230, 255), rgb(200, 245, 255)),
		tradable = false,
	},
	{
		id = "eletrico",
		name = "Puff Elétrico",
		rarity = "Rare",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "knockouts", target = 15 },
		hint = "Derrube 15 jogadores",
		style = style(rgb(255, 255, 140), rgb(90, 170, 255), rgb(255, 250, 120), rgb(255, 255, 160)),
		tradable = false,
	},
	{
		id = "tijolinho",
		name = "Puff Tijolinho",
		rarity = "Rare",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "blocksBuilt", target = 10 },
		hint = "Reconstrua 10 blocos com o Puffador do Cofre",
		style = style(rgb(255, 170, 110), rgb(200, 90, 70), rgb(255, 150, 100), rgb(255, 190, 130)),
		tradable = false,
	},
	{
		id = "sussurro",
		name = "Puff Sussurro",
		rarity = "Rare",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "secretsFound", target = 3 },
		hint = "Descubra 3 passagens secretas",
		style = style(rgb(200, 255, 240), rgb(120, 110, 200), rgb(170, 240, 230), rgb(190, 255, 245)),
		tradable = false,
	},
	{
		id = "brasil",
		name = "Puff Brasil",
		rarity = "Epic",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "top3", target = 20 },
		hint = "Fique no Top 3 em 20 partidas",
		style = style(rgb(255, 223, 0), rgb(0, 156, 59), rgb(255, 230, 60), rgb(80, 150, 255)),
		tradable = false,
	},
	{
		id = "galaxia",
		name = "Puff Galáxia",
		rarity = "Epic",
		origin = "Level",
		unlock = { kind = "Level", target = 25 },
		hint = "Chegue ao nível 25",
		style = style(rgb(255, 150, 240), rgb(90, 70, 220), rgb(200, 140, 255), rgb(150, 220, 255)),
		tradable = false,
	},
	{
		id = "cofre",
		name = "Puff Cofre",
		rarity = "Epic",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "vaultsConquered", target = 3 },
		hint = "Conquiste o prêmio do cofre 3 vezes",
		style = style(rgb(255, 225, 120), rgb(150, 110, 40), rgb(255, 210, 90), rgb(255, 240, 170)),
		tradable = false,
	},
	{
		id = "barao",
		name = "Puff Barão",
		rarity = "Legendary",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "baraoEscapes", target = 25 },
		hint = "Fuja do Barão 25 vezes",
		style = style(rgb(255, 200, 120), rgb(160, 90, 40), rgb(255, 170, 90), rgb(255, 120, 90)),
		tradable = false,
	},
	{
		id = "dourado",
		name = "Puff Dourado",
		rarity = "Legendary",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "wins", target = 25 },
		hint = "Vença 25 partidas",
		style = style(rgb(255, 245, 190), rgb(214, 150, 40), rgb(255, 215, 110), rgb(255, 250, 200)),
		tradable = false,
	},
	{
		id = "fenix",
		name = "Puff Fênix",
		rarity = "Legendary",
		origin = "Feat",
		unlock = { kind = "Stat", stat = "comebacks", target = 10 },
		hint = "Dê a Volta por Cima 10 vezes",
		style = style(rgb(255, 240, 150), rgb(255, 80, 60), rgb(255, 160, 80), rgb(255, 200, 90)),
		tradable = false,
	},
	-- Exclusivos da Puff Machine (4.2): só saem girando a máquina.
	{
		id = "chiclete",
		name = "Puff Chiclete",
		rarity = "Common",
		origin = "Machine",
		unlock = { kind = "Machine" },
		hint = "Sai na Puff Machine",
		style = style(rgb(255, 160, 200), rgb(255, 110, 170), rgb(255, 150, 200), rgb(255, 200, 225)),
		tradable = false,
	},
	{
		id = "limao",
		name = "Puff Limão",
		rarity = "Common",
		origin = "Machine",
		unlock = { kind = "Machine" },
		hint = "Sai na Puff Machine",
		style = style(rgb(230, 255, 130), rgb(140, 220, 60), rgb(210, 255, 110), rgb(240, 255, 170)),
		tradable = false,
	},
	{
		id = "nuvem",
		name = "Puff Nuvem",
		rarity = "Common",
		origin = "Machine",
		unlock = { kind = "Machine" },
		hint = "Sai na Puff Machine",
		style = style(rgb(245, 248, 255), rgb(170, 190, 230), rgb(220, 230, 255), rgb(235, 240, 255)),
		tradable = false,
	},
	{
		id = "oceano",
		name = "Puff Oceano",
		rarity = "Rare",
		origin = "Machine",
		unlock = { kind = "Machine" },
		hint = "Sai na Puff Machine",
		style = style(rgb(120, 240, 255), rgb(30, 110, 220), rgb(90, 200, 255), rgb(160, 245, 255)),
		tradable = false,
	},
	{
		id = "arcoiris",
		name = "Puff Arco-Íris",
		rarity = "Rare",
		origin = "Machine",
		unlock = { kind = "Machine" },
		hint = "Sai na Puff Machine",
		style = style(rgb(255, 120, 120), rgb(120, 140, 255), rgb(255, 220, 120), rgb(140, 255, 170)),
		tradable = false,
	},
	{
		id = "neon",
		name = "Puff Neon",
		rarity = "Epic",
		origin = "Machine",
		unlock = { kind = "Machine" },
		hint = "Sai na Puff Machine",
		style = style(rgb(80, 255, 230), rgb(255, 60, 220), rgb(120, 255, 240), rgb(255, 120, 240)),
		tradable = false,
	},
	{
		id = "aurora",
		name = "Puff Aurora",
		rarity = "Epic",
		origin = "Machine",
		unlock = { kind = "Machine" },
		hint = "Sai na Puff Machine",
		style = style(rgb(140, 255, 190), rgb(150, 90, 255), rgb(150, 255, 210), rgb(200, 170, 255)),
		tradable = false,
	},
	{
		id = "cometa",
		name = "Puff Cometa",
		rarity = "Legendary",
		origin = "Machine",
		unlock = { kind = "Machine" },
		hint = "Sai na Puff Machine",
		style = style(rgb(255, 255, 235), rgb(255, 150, 60), rgb(255, 230, 160), rgb(255, 250, 210)),
		tradable = false,
	},
}

local byId: { [string]: PuffDefinition } = {}
for index, entry in ipairs(ENTRIES) do
	assert(byId[entry.id] == nil, `Duplicated Puff id {entry.id}`)
	assert(RARITIES[entry.rarity] ~= nil, `Unknown rarity for Puff {entry.id}`)
	assert(#entry.id <= 32, `Puff id too long: {entry.id}`)
	local stat = entry.unlock.stat
	assert(stat == nil or table.find(ProfileTypes.StatKeys, stat) ~= nil, `Unknown stat for Puff {entry.id}`)
	table.freeze(entry.unlock)
	byId[entry.id] = table.freeze(entry)
	ENTRIES[index] = byId[entry.id]
end
assert(byId[DEFAULT_ID] ~= nil and byId[DEFAULT_ID].unlock.kind == "Starter", "Default Puff must be a Starter")

local PuffCatalog = {}

PuffCatalog.DefaultId = DEFAULT_ID
PuffCatalog.TradingEnabled = TRADING_ENABLED
PuffCatalog.MaxIdLength = 32

-- Todos, na ordem do Puffdex.
function PuffCatalog.all(): { PuffDefinition }
	return ENTRIES
end

-- Os que saem na Puff Machine, de uma raridade.
function PuffCatalog.machinePool(rarity: PuffRarity): { PuffDefinition }
	local pool: { PuffDefinition } = {}
	for _, entry in ipairs(ENTRIES) do
		if entry.unlock.kind == "Machine" and entry.rarity == rarity then
			table.insert(pool, entry)
		end
	end
	return pool
end

function PuffCatalog.get(id: unknown): PuffDefinition?
	if typeof(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function PuffCatalog.rarity(rarity: PuffRarity): RarityInfo
	return RARITIES[rarity]
end

-- Estilo do disparo para um id (qualquer coisa inválida vira o padrão).
function PuffCatalog.styleFor(id: unknown): PuffStyle
	local entry = PuffCatalog.get(id) or byId[DEFAULT_ID]
	return entry.style
end

-- Progresso até desbloquear (para mostrar "7/15"). `stats` é a tabela de
-- estatísticas do perfil. Devolve nil quando não há progresso mensurável.
function PuffCatalog.progress(entry: PuffDefinition, stats: { [string]: number }, level: number): (number?, number?)
	local rule = entry.unlock
	local target = rule.target
	if target == nil then
		return nil, nil
	end
	if rule.kind == "Level" then
		return math.min(level, target), target
	elseif rule.kind == "Stat" and rule.stat ~= nil then
		return math.min(stats[rule.stat] or 0, target), target
	end
	return nil, nil
end

-- Verdadeiro se o perfil (estatísticas + nível) já cumpre a regra.
function PuffCatalog.meetsRule(entry: PuffDefinition, stats: { [string]: number }, level: number): boolean
	local rule = entry.unlock
	if rule.kind == "Starter" then
		return true
	end
	local current, target = PuffCatalog.progress(entry, stats, level)
	return current ~= nil and target ~= nil and current >= target
end

return table.freeze(PuffCatalog)
