--!strict

-- Conquistas secretas (Fase 4.3). Ficam escondidas ("???") até alguém
-- conseguir; antes disso só aparece uma pista curta. Todas são detectadas
-- pelo servidor (SecretAchievementService) e dão tickets uma única vez.
--
-- Ids ficam salvos nos perfis: nunca renomeie nem reaproveite um id.

export type SecretDefinition = {
	id: string,
	name: string,
	-- O que foi feito (mostrado depois de conquistar).
	description: string,
	-- Pista curta (mostrada antes).
	hint: string,
	tickets: number,
}

local function secret(id: string, name: string, description: string, hint: string): SecretDefinition
	return table.freeze({ id = id, name = name, description = description, hint = hint, tickets = 5 })
end

local ENTRIES: { SecretDefinition } = {
	secret("passagem_oculta", "Passagem Oculta", "Atravessou uma passagem antes de ela ser revelada", "Nem toda parede é parede…"),
	secret("pula_barao", "Pula-Barão", "Pulou o Barão 3 vezes na mesma partida", "O Barão odeia gente saltitante…"),
	secret("por_um_fio", "Por um Fio", "Venceu com quase nada de arena de pé", "Vencer quando quase não sobra chão…"),
	secret("mestre_quadros", "Mestre dos Quadros", "Revelou as passagens dos dois andares na mesma partida", "Todos os quadros guardam algo…"),
	secret("puff_perdido", "Puff Perdido", "Achou o Puff escondido no lobby", "Algo brilha num canto do lobby…"),
}

local byId: { [string]: SecretDefinition } = {}
for _, entry in ipairs(ENTRIES) do
	assert(byId[entry.id] == nil, `Duplicated secret id {entry.id}`)
	byId[entry.id] = entry
end

local SecretCatalog = {}

SecretCatalog.MaxIdLength = 32

function SecretCatalog.all(): { SecretDefinition }
	return ENTRIES
end

function SecretCatalog.get(id: unknown): SecretDefinition?
	if typeof(id) ~= "string" then
		return nil
	end
	return byId[id]
end

return table.freeze(SecretCatalog)
