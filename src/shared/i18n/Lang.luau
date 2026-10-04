--!strict

-- Idioma do jogo (português ou inglês) a partir do idioma do Roblox de cada
-- jogador. Uso:
--   * cliente: `Lang.t("FALTAM %d 🎟", n)` no idioma do jogador local;
--   * servidor: `Lang.forPlayer(player, "Você está banido.")` para textos
--     de um jogador só;
--   * `Lang.localize(texto)` traduz um texto que já chegou montado (placas
--     do servidor vistas por todos).
-- O texto em português é a chave (ver `LocaleCore`).

local Players = game:GetService("Players")

local English = require(script.Parent.English)
local LocaleCore = require(script.Parent.LocaleCore)

export type Language = LocaleCore.Language

local Lang = {}

local patterns: { LocaleCore.Pattern }? = nil

local function compiled(): { LocaleCore.Pattern }
	if patterns == nil then
		patterns = LocaleCore.compile(English)
	end
	return patterns :: { LocaleCore.Pattern }
end

function Lang.languageOf(player: Player): Language
	return LocaleCore.languageFor(player.LocaleId)
end

-- Idioma do jogador local; no servidor, o português do código.
function Lang.current(): Language
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return "pt"
	end
	return Lang.languageOf(localPlayer)
end

function Lang.t(template: string, ...: any): string
	return LocaleCore.format(English, Lang.current(), template, ...)
end

function Lang.forPlayer(player: Player, template: string, ...: any): string
	return LocaleCore.format(English, Lang.languageOf(player), template, ...)
end

function Lang.ordinal(position: number): string
	return LocaleCore.ordinal(Lang.current(), position)
end

function Lang.localize(text: string): string
	return LocaleCore.localize(English, compiled(), Lang.current(), text)
end

return table.freeze(Lang)
