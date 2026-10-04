--!strict

-- Núcleo do idioma, sem acesso ao jogo (testável no Lune). O texto em
-- português do próprio código é a chave: o dicionário em inglês mapeia
-- "texto em português" -> "texto em inglês", com os mesmos %d/%s na mesma
-- ordem. Sem tradução, fica o português.
--
-- Quem tem o Roblox em português vê português; qualquer outro idioma vê
-- inglês.

export type Language = "pt" | "en"
export type Dictionary = { [string]: string }

-- Um texto do dicionário com %d/%s, pronto para reconhecer o texto já
-- montado (ex.: "Partida em 12s · entre agora!").
export type Pattern = {
	pattern: string,
	specifiers: { string },
	translated: string,
}

local LocaleCore = {}

local SPECIFIER = "%%[%-%+ #0]*%d*%.?%d*[dfisxX]"

function LocaleCore.languageFor(localeId: string?): Language
	if localeId ~= nil and string.lower(string.sub(localeId, 1, 2)) == "pt" then
		return "pt"
	end
	return "en"
end

function LocaleCore.translate(dictionary: Dictionary, language: Language, text: string): string
	if language == "en" then
		return dictionary[text] or text
	end
	return text
end

-- Traduz e preenche os valores. Sem valores, não passa pelo string.format
-- (textos de dados podem ter "%" solto).
function LocaleCore.format(dictionary: Dictionary, language: Language, template: string, ...: any): string
	local text = LocaleCore.translate(dictionary, language, template)
	if select("#", ...) == 0 then
		return text
	end
	return string.format(text, ...)
end

-- Os %d/%s/%.1f de um texto, na ordem (o "%%" não conta).
function LocaleCore.specifiers(template: string): { string }
	local found = {}
	local cleaned = string.gsub(template, "%%%%", "")
	for spec in string.gmatch(cleaned, SPECIFIER) do
		table.insert(found, spec)
	end
	return found
end

local function captureFor(spec: string): string
	local kind = string.sub(spec, -1)
	if kind == "s" then
		return "(.-)"
	elseif kind == "f" then
		return "(%-?%d+%.?%d*)"
	end
	return "(%-?%d+)"
end

local function escape(literal: string): string
	return (string.gsub(literal, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Monta o padrão Lua que reconhece o texto já preenchido.
local function patternFor(template: string): (string, { string })
	local parts = { "^" }
	local specs = {}
	local index = 1
	while index <= #template do
		local first, last = string.find(template, SPECIFIER, index)
		local escaped = string.find(template, "%%%%", index)
		if escaped ~= nil and (first == nil or escaped < first) then
			table.insert(parts, escape(string.sub(template, index, escaped - 1)))
			table.insert(parts, "%%")
			index = escaped + 2
		elseif first ~= nil and last ~= nil then
			local spec = string.sub(template, first, last)
			table.insert(parts, escape(string.sub(template, index, first - 1)))
			table.insert(parts, captureFor(spec))
			table.insert(specs, spec)
			index = last + 1
		else
			table.insert(parts, escape(string.sub(template, index)))
			break
		end
	end
	table.insert(parts, "$")
	return table.concat(parts), specs
end

function LocaleCore.compile(dictionary: Dictionary): { Pattern }
	local patterns = {}
	for template, translated in dictionary do
		local specs = LocaleCore.specifiers(template)
		if #specs > 0 then
			local pattern = patternFor(template)
			table.insert(patterns, { pattern = pattern, specifiers = specs, translated = translated })
		end
	end
	-- Padrões mais longos primeiro: o mais específico vence.
	table.sort(patterns, function(a: Pattern, b: Pattern): boolean
		return #a.pattern > #b.pattern
	end)
	return patterns
end

local SEPARATOR = " · "

local function localizeWhole(dictionary: Dictionary, patterns: { Pattern }, text: string): string
	local exact = dictionary[text]
	if exact ~= nil then
		return exact
	end
	for _, entry in patterns do
		local captures = { string.match(text, entry.pattern) }
		if #captures == #entry.specifiers and #captures > 0 then
			local values = table.create(#captures)
			for index, capture in captures do
				local kind = string.sub(entry.specifiers[index], -1)
				values[index] = if kind == "s" then capture else tonumber(capture)
			end
			local ok, result = pcall(string.format, entry.translated, table.unpack(values))
			if ok then
				return result
			end
		end
	end
	return text
end

-- Um trecho com ou sem ícone na frente ("🏆 VITÓRIAS"): o ícone (tudo antes
-- da primeira letra ou número) fica, o resto é traduzido.
local function localizePiece(dictionary: Dictionary, patterns: { Pattern }, piece: string): string
	local whole = localizeWhole(dictionary, patterns, piece)
	if whole ~= piece then
		return whole
	end
	local prefix, rest = string.match(piece, "^([^%w\195]-%s+)(.+)$")
	if prefix == nil or rest == nil then
		return piece
	end
	return prefix .. localizeWhole(dictionary, patterns, rest)
end

-- Traduz um texto que já chegou montado (placas e avisos do servidor). Sem
-- tradução do texto inteiro, tenta cada trecho separado por " · ".
function LocaleCore.localize(dictionary: Dictionary, patterns: { Pattern }, language: Language, text: string): string
	if language ~= "en" then
		return text
	end
	local whole = localizePiece(dictionary, patterns, text)
	if whole ~= text or string.find(text, SEPARATOR, 1, true) == nil then
		return whole
	end
	local pieces = {}
	local start = 1
	while true do
		local first, last = string.find(text, SEPARATOR, start, true)
		if first == nil or last == nil then
			table.insert(pieces, localizePiece(dictionary, patterns, string.sub(text, start)))
			break
		end
		table.insert(pieces, localizePiece(dictionary, patterns, string.sub(text, start, first - 1)))
		start = last + 1
	end
	return table.concat(pieces, SEPARATOR)
end

return table.freeze(LocaleCore)
