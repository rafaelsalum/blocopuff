--!strict

-- Dicionário em inglês completo: junta as tabelas de `en/` (uma por área do
-- jogo). Para traduzir um texto novo, acrescente a linha no arquivo da área
-- certa; `lune run tests/Locale.spec` aponta o que estiver faltando.

local LocaleCore = require(script.Parent.LocaleCore)

local merged: LocaleCore.Dictionary = {}

for _, child in script.Parent.en:GetChildren() do
	if child:IsA("ModuleScript") then
		local entries = (require :: any)(child) :: LocaleCore.Dictionary
		for pt, en in entries do
			if merged[pt] ~= nil and merged[pt] ~= en then
				warn(string.format("[BlocoPuff] Translation conflict for %q in %s", pt, child.Name))
			end
			merged[pt] = en
		end
	end
end

return table.freeze(merged)
