--!strict

-- Regras puras dos Momentos Puff e das conquistas das armadilhas (Fase
-- 5.8). Sem dependências (os testes do Lune carregam este arquivo direto).

local TrapMomentRules = {}

-- Momento Puff de quem derrubou alguém com cada tipo de armadilha.
local MOMENTS: { [string]: string } = {
	Window = "TrapWindow",
	Rug = "TrapRug",
	Chandelier = "TrapChandelier",
	Fireplace = "TrapFireplace",
}

-- Vidraceiro: janelas quebradas de longe na mesma partida.
local WINDOWS_FOR_GLAZIER = 5
-- Lustre na Cabeça: vítimas derrubadas pelo mesmo lustre.
local VICTIMS_PER_CHANDELIER = 2

function TrapMomentRules.momentFor(trapKind: string): string?
	return MOMENTS[trapKind]
end

-- Conquista secreta de quem já quebrou `windows` janelas nesta partida.
function TrapMomentRules.secretForWindows(windows: number): string?
	return if windows >= WINDOWS_FOR_GLAZIER then "vidraceiro" else nil
end

-- Conquista secreta de uma derrubada pela armadilha `trapKind`; `sameTrap`
-- é quantas vítimas essa mesma armadilha já derrubou para quem acionou.
function TrapMomentRules.secretForKnockout(trapKind: string, sameTrap: number): string?
	if trapKind == "Rug" then
		return "puxa_tapete"
	elseif trapKind == "Chandelier" and sameTrap >= VICTIMS_PER_CHANDELIER then
		return "lustre_na_cabeca"
	end
	return nil
end

-- A derrubada conta nas estatísticas (desafios)? Bots não contam, como nas
-- derrubadas comuns.
function TrapMomentRules.countsForStats(victimIsBot: boolean): boolean
	return not victimIsBot
end

return table.freeze(TrapMomentRules)
