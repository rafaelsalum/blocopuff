-- Testes do idioma (português/inglês) e do dicionário em inglês.
-- Rodar: lune run tests/Locale.spec

local fs = require("@lune/fs")

local LocaleCore = require("../src/shared/i18n/LocaleCore")

local failures = 0
local passed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

-- Idioma do jogador.
check("pt-br is portuguese", LocaleCore.languageFor("pt-br") == "pt")
check("pt-pt is portuguese", LocaleCore.languageFor("pt-pt") == "pt")
check("PT uppercase is portuguese", LocaleCore.languageFor("PT-BR") == "pt")
check("en-us is english", LocaleCore.languageFor("en-us") == "en")
check("spanish falls back to english", LocaleCore.languageFor("es-es") == "en")
check("missing locale is english", LocaleCore.languageFor(nil) == "en")
check("empty locale is english", LocaleCore.languageFor("") == "en")

local dict = {
	["Jogar"] = "Play",
	["FALTAM %d 🎟"] = "%d 🎟 SHORT",
	["%s venceu"] = "%s won",
	["Partida em %ds · entre agora!"] = "Match in %ds · join now!",
	["Nível %d · %.1f%%"] = "Level %d · %.1f%%",
	["Ganhe (mais) [tickets]?"] = "Earn (more) [tickets]?",
}

-- Tradução direta.
check("translates in english", LocaleCore.format(dict, "en", "Jogar") == "Play")
check("keeps portuguese", LocaleCore.format(dict, "pt", "Jogar") == "Jogar")
check("unknown text falls back", LocaleCore.format(dict, "en", "Sem tradução") == "Sem tradução")
check("formats english template", LocaleCore.format(dict, "en", "FALTAM %d 🎟", 3) == "3 🎟 SHORT")
check("formats portuguese template", LocaleCore.format(dict, "pt", "FALTAM %d 🎟", 3) == "FALTAM 3 🎟")
check("unknown template still formats", LocaleCore.format(dict, "en", "Faltam %d", 2) == "Faltam 2")
check("no args keeps percent intact", LocaleCore.format(dict, "en", "100% grátis") == "100% grátis")

-- Especificadores.
local specs = LocaleCore.specifiers("Nível %d · %.1f%% de %s")
check("specifiers list", #specs == 3 and specs[1] == "%d" and specs[2] == "%.1f" and specs[3] == "%s")
check("escaped percent is not a specifier", #LocaleCore.specifiers("100%% grátis") == 0)

-- Tradução de texto já montado (placas do servidor).
local patterns = LocaleCore.compile(dict)
check("localize exact", LocaleCore.localize(dict, patterns, "en", "Jogar") == "Play")
check("localize template with number", LocaleCore.localize(dict, patterns, "en", "Partida em 12s · entre agora!") == "Match in 12s · join now!")
check("localize template with name", LocaleCore.localize(dict, patterns, "en", "Ana Clara venceu") == "Ana Clara won")
check("localize negative number", LocaleCore.localize(dict, patterns, "en", "FALTAM -1 🎟") == "-1 🎟 SHORT")
check("localize float", LocaleCore.localize(dict, patterns, "en", "Nível 3 · 42.5%") == "Level 3 · 42.5%")
check("localize magic characters", LocaleCore.localize(dict, patterns, "en", "Ganhe (mais) [tickets]?") == "Earn (more) [tickets]?")
check("localize unknown keeps text", LocaleCore.localize(dict, patterns, "en", "Outra coisa") == "Outra coisa")
check("localize in portuguese is identity", LocaleCore.localize(dict, patterns, "pt", "Ana venceu") == "Ana venceu")
check("localize does not match partial", LocaleCore.localize(dict, patterns, "en", "Partida em 12s · entre agora! extra") == "Partida em 12s · entre agora! extra")
-- Posições (1º / 1st).
check("ordinal pt", LocaleCore.ordinal("pt", 4) == "4º")
check("ordinal en 1st", LocaleCore.ordinal("en", 1) == "1st")
check("ordinal en 2nd", LocaleCore.ordinal("en", 2) == "2nd")
check("ordinal en 3rd", LocaleCore.ordinal("en", 3) == "3rd")
check("ordinal en 4th", LocaleCore.ordinal("en", 4) == "4th")
check("ordinal en 11th-13th", LocaleCore.ordinal("en", 11) == "11th" and LocaleCore.ordinal("en", 12) == "12th" and LocaleCore.ordinal("en", 13) == "13th")
check("ordinal en 21st 22nd 23rd", LocaleCore.ordinal("en", 21) == "21st" and LocaleCore.ordinal("en", 22) == "22nd" and LocaleCore.ordinal("en", 23) == "23rd")
check("ordinal en 111th", LocaleCore.ordinal("en", 111) == "111th")
check("localize server ordinal", LocaleCore.localize(dict, patterns, "en", "6º") == "6th")

-- Placas montadas em partes ("✨ Nome · Raro", "🏆 VITÓRIAS").
local parts = {
	["Puff Branco"] = "White Puff",
	["Raro"] = "Rare",
	["VITÓRIAS"] = "WINS",
	["%s vitórias"] = "%s wins",
}
local partPatterns = LocaleCore.compile(parts)
check("localize emoji prefix", LocaleCore.localize(parts, partPatterns, "en", "🏆 VITÓRIAS") == "🏆 WINS")
check("localize segments", LocaleCore.localize(parts, partPatterns, "en", "✨ Puff Branco · Raro") == "✨ White Puff · Rare")
check("localize partial segments", LocaleCore.localize(parts, partPatterns, "en", "Puff Branco · Desconhecido") == "White Puff · Desconhecido")
check("localize template segment", LocaleCore.localize(parts, partPatterns, "en", "12 vitórias") == "12 wins")
check("localize keeps emoji-only text", LocaleCore.localize(parts, partPatterns, "en", "🏆") == "🏆")
check("localize keeps unknown segments", LocaleCore.localize(parts, partPatterns, "en", "Ana · Rafa") == "Ana · Rafa")
check("localize ignores translated text",LocaleCore.localize(dict, patterns, "en", "Match in 12s · join now!") == "Match in 12s · join now!")

-- Dicionário real: cada arquivo de src/shared/i18n/en é uma tabela pura.
local EN_DIR = "src/shared/i18n/en"
local english: { [string]: string } = {}
local sources: { [string]: string } = {}
for _, file in fs.readDir(EN_DIR) do
	if string.sub(file, -5) == ".luau" then
		local area = string.sub(file, 1, -6)
		local entries = require(`../{EN_DIR}/{area}`) :: { [string]: string }
		for pt, en in entries do
			local previous = english[pt]
			check(`"{pt}" has one translation ({sources[pt] or area} x {area})`, previous == nil or previous == en)
			english[pt] = en
			sources[pt] = area
		end
	end
end

local function sameSpecifiers(a: string, b: string): boolean
	local left, right = LocaleCore.specifiers(a), LocaleCore.specifiers(b)
	if #left ~= #right then
		return false
	end
	for index, spec in left do
		if spec ~= right[index] then
			return false
		end
	end
	return true
end

for pt, en in english do
	check(`"{pt}" keeps the same placeholders`, sameSpecifiers(pt, en))
	check(`"{pt}" is translated`, en ~= "")
end

-- Toda chamada T("...") / Lang.t("...") / Lang.forPlayer(p, "...") no código
-- precisa ter tradução.
local function unescape(literal: string): string
	return (string.gsub(literal, "\\(.)", function(char: string): string
		if char == "n" then
			return "\n"
		elseif char == "t" then
			return "\t"
		end
		return char
	end))
end

-- Padrões Lua não têm alternância: extrai o literal andando caractere a
-- caractere depois do início da chamada.
local function literalAt(source: string, quote: number): string?
	local index = quote + 1
	local parts = {}
	while index <= #source do
		local char = string.sub(source, index, index)
		if char == "\\" then
			table.insert(parts, string.sub(source, index, index + 1))
			index += 2
		elseif char == '"' then
			return unescape(table.concat(parts))
		else
			table.insert(parts, char)
			index += 1
		end
	end
	return nil
end

local STARTS = { "[^%w_%.]T%(%s*()\"", "Lang%.t%(%s*()\"", "Lang%.forPlayer%([^,%)]+,%s*()\"" }
local missing = 0
local function scan(dir: string)
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			scan(path)
		elseif string.sub(name, -5) == ".luau" then
			-- Linhas de comentário não contam (exemplos de uso).
			local lines = {}
			for line in string.gmatch(fs.readFile(path), "[^\n]*") do
				table.insert(lines, if string.match(line, "^%s*%-%-") then "" else line)
			end
			local source = table.concat(lines, "\n")
			-- T(string.format(...)) traduz o texto já preenchido, que nunca é chave.
			if string.find(source, "[^%w_%.]T%(%s*string%.format") or string.find(source, "Lang%.t%(%s*string%.format") then
				missing += 1
				print(`FORMAT-BEFORE-TRANSLATE {path}: pass the template and values to T()`)
			end
			for _, start in STARTS do
				for quote in string.gmatch(source, start) do
					local key = literalAt(source, quote :: number)
					if key ~= nil and english[key] == nil then
						missing += 1
						print(`MISSING {path}: "{key}"`)
					end
				end
			end
		end
	end
end
scan("src")
check("every T() call has an english translation", missing == 0)

-- Textos de catálogo exibidos por variável (o scan acima não os vê).
local function literalArgs(source: string, call: string): { string }
	local found = {}
	for args in string.gmatch(source, call .. "(%b())") do
		for literal in string.gmatch(args, '"([^"]*)"') do
			table.insert(found, literal)
		end
	end
	return found
end

local function fieldValues(source: string, fields: { string }): { string }
	local found = {}
	for _, field in fields do
		for literal in string.gmatch(source, "[%s{,]" .. field .. '%s*=%s*"([^"]*)"') do
			table.insert(found, literal)
		end
	end
	return found
end

local CATALOGS: { { path: string, texts: (string) -> { string } } } = {
	{
		path = "src/shared/config/PuffCatalog.luau",
		texts = function(source)
			return fieldValues(source, { "name", "hint", "lore", "label" })
		end,
	},
	{
		path = "src/shared/config/DailyConfig.luau",
		texts = function(source)
			local titles = {}
			for args in string.gmatch(source, "challenge(%b())") do
				local title = string.match(args, '^%(%s*"[^"]*"%s*,%s*"([^"]*)"')
				if title ~= nil then
					table.insert(titles, title)
				end
			end
			return titles
		end,
	},
	{
		path = "src/shared/config/SecretCatalog.luau",
		texts = function(source)
			local texts = {}
			for _, literal in literalArgs(source, "secret") do
				-- O primeiro literal de cada chamada é o id (sem espaço nem acento).
				if string.find(literal, "[%s\128-\255]") ~= nil then
					table.insert(texts, literal)
				end
			end
			return texts
		end,
	},
	{
		path = "src/shared/config/RelicCatalog.luau",
		texts = function(source)
			local texts = fieldValues(source, { "name", "title", "AlbumTitle", "DailyTitle", "DailyName" })
			for _, literal in literalArgs(source, "relic") do
				-- O primeiro literal de cada chamada é o id (sem espaço nem acento).
				if string.find(literal, "[%s\128-\255]") ~= nil then
					table.insert(texts, literal)
				end
			end
			-- Páginas do Diário: título, cômodo, âncora, pista e texto.
			for _, literal in literalArgs(source, "page") do
				if string.find(literal, "[%s\128-\255]") ~= nil then
					table.insert(texts, literal)
				end
			end
			for literal in string.gmatch(source, 'return "([^"]*)"') do
				table.insert(texts, literal)
			end
			return texts
		end,
	},
	{
		path = "src/shared/config/MysteryConfig.luau",
		texts = function(source)
			return fieldValues(source, { "name", "hint", "AllTitle" })
		end,
	},
	{
		path = "src/server/services/MysteryProps.luau",
		texts = function(source)
			-- Em prompt(peça, id, ação, objeto) o primeiro literal é o id.
			local texts = {}
			for _, literal in literalArgs(source, "prompt") do
				if string.find(literal, "[%s\128-\255]") ~= nil then
					table.insert(texts, literal)
				end
			end
			table.insert(texts, "♪ Música da Vovó ♪")
			return texts
		end,
	},
	{
		path = "src/shared/modules/PuffEffects.luau",
		texts = function(source)
			return fieldValues(source, { "label" })
		end,
	},
	{
		path = "src/client/controllers/PartyController.luau",
		texts = function(source)
			return fieldValues(source, { "text" })
		end,
	},
	{
		path = "src/shared/types/LeaderboardTypes.luau",
		texts = function(source)
			return fieldValues(source, { "title" })
		end,
	},
}

for _, catalog in CATALOGS do
	local texts = catalog.texts(fs.readFile(catalog.path))
	check(`{catalog.path} has texts`, #texts > 0)
	for _, text in texts do
		check(`{catalog.path}: "{text}" has an english translation`, english[text] ~= nil)
	end
end

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("Locale tests failed")
end
