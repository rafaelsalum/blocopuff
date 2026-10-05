--!strict

-- Mistérios do Barão (Fase 5C.3, parte 2): quatro quebra-cabeças do
-- Casarão, cada um resolvido uma vez por jogador (+tickets). As respostas
-- são sorteadas pelo servidor a cada servidor novo (as pistas no cenário
-- mudam junto), então "cola" de um servidor não serve no outro.
--   * Clock: acertar o relógio da torre (no Sótão) na hora pintada no
--     quadro do Salão Principal.
--   * Candles: acender as velas do Salão na ordem das cores dos vitrais.
--   * Piano: tocar a música da Vovó (partitura no Sótão).
--   * Safe: o código de 3 dígitos do cofrinho do Porão está em três quadros
--     (Biblioteca, Sala de Música e Sótão).
-- Ids ficam salvos nos perfis: nunca renomeie.

export type MysteryId = "Clock" | "Candles" | "Piano" | "Safe"

export type CandleColor = {
	name: string,
	color: Color3,
}

export type MysteryInfo = {
	name: string,
	icon: string,
	-- Lembrete curto na tela do quebra-cabeça (a pista vem do Diário).
	hint: string,
}

local MysteryConfig = {}

MysteryConfig.Ids = table.freeze({ "Clock", "Candles", "Piano", "Safe" } :: { MysteryId })

MysteryConfig.Info = table.freeze({
	Clock = table.freeze({ name = "Relógio da Torre", icon = "⏰", hint = "A hora certa está pintada num quadro do Salão Principal." }),
	Candles = table.freeze({ name = "Velas do Salão", icon = "🕯️", hint = "Acenda na ordem das cores dos vitrais, da esquerda para a direita." }),
	Piano = table.freeze({ name = "Música da Vovó", icon = "🎹", hint = "A partitura está no Sótão." }),
	Safe = table.freeze({ name = "Cofrinho do Porão", icon = "🔒", hint = "Cada número está num quadro: 1º, 2º e 3º." }),
} :: { [MysteryId]: MysteryInfo })

-- Recompensas: cada mistério uma vez; os quatro dão um título e um bônus.
MysteryConfig.Tickets = 5
MysteryConfig.AllTickets = 10
MysteryConfig.AllTitle = "Mestre dos Mistérios"

-- Cores das velas e dos vitrais (a mesma paleta; a ordem muda).
MysteryConfig.CandleColors = table.freeze({
	table.freeze({ name = "Vermelho", color = Color3.fromRGB(230, 60, 60) }),
	table.freeze({ name = "Azul", color = Color3.fromRGB(60, 120, 240) }),
	table.freeze({ name = "Verde", color = Color3.fromRGB(60, 200, 100) }),
	table.freeze({ name = "Amarelo", color = Color3.fromRGB(250, 210, 60) }),
} :: { CandleColor })

-- Teclas brancas do piano (meio tom) e o nome de cada nota.
MysteryConfig.WhiteKeys = table.freeze({ 0, 2, 4, 5, 7, 9, 11, 12 })
MysteryConfig.NoteNames = table.freeze({
	[0] = "Dó",
	[2] = "Ré",
	[4] = "Mi",
	[5] = "Fá",
	[7] = "Sol",
	[9] = "Lá",
	[11] = "Si",
	[12] = "Dó",
} :: { [number]: string })
MysteryConfig.MelodyLength = 5

-- O relógio anda de 15 em 15 minutos.
MysteryConfig.MinuteStep = 15

-- Interação: prompts com este atributo abrem o quebra-cabeça no cliente.
MysteryConfig.PromptAttribute = "MysteryId"
MysteryConfig.PromptDistance = 8
-- Folga na conferência de distância do servidor.
MysteryConfig.ServerDistance = 18
MysteryConfig.SolveCooldown = 1
-- Contra chute em massa: a cada `WrongLimit` erros seguidos num mistério,
-- ele trava por `WrongLockSeconds` (vezes quantas travas já levou).
MysteryConfig.WrongLimit = 5
MysteryConfig.WrongLockSeconds = 30
-- Piano: uma pausa maior que esta entre notas recomeça a música (tocar com
-- calma vale; despejar milhares de notas não encadeia).
MysteryConfig.MelodyGap = 3

-- Resolveu os quatro (lista de ids resolvidos do perfil)?
function MysteryConfig.allSolved(solved: { string }): boolean
	for _, id in ipairs(MysteryConfig.Ids) do
		if table.find(solved, id) == nil then
			return false
		end
	end
	return true
end

return table.freeze(MysteryConfig)
