--!strict

-- Prompts dos Mistérios do Barão depois de resolvidos. Quem já resolveu um
-- quebra-cabeça não vê mais o prompt dele (o cenário mudado já mostra que
-- acabou: velas acesas, cofrinho aberto, relógio andando). O piano continua
-- tocável: é instrumento antes de ser mistério.

local MysteryPrompts = {}

local HIDES_WHEN_SOLVED: { [string]: boolean } = table.freeze({
	Clock = true,
	Candles = true,
	Safe = true,
})

function MysteryPrompts.hidesWhenSolved(id: string): boolean
	return HIDES_WHEN_SOLVED[id] == true
end

return table.freeze(MysteryPrompts)
