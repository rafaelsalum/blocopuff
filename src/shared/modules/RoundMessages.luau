--!strict

export type RoundMessagesModule = {
	WaitingForPlayers: string,
	Active: string,
	EndedNoWinner: string,
	countdown: (secondsRemaining: number) -> string,
	winner: (winnerName: string) -> string,
}

local RoundMessages: RoundMessagesModule = {
	WaitingForPlayers = "Aguardando jogadores",
	Active = "Partida em andamento",
	EndedNoWinner = "Partida encerrada",

	-- O número da contagem regressiva já aparece no badge do cronômetro do
	-- HUD; esta mensagem não o repete para evitar mostrar o mesmo valor
	-- duas vezes na tela ao mesmo tempo.
	countdown = function(_secondsRemaining: number): string
		return "A partida vai começar"
	end,

	winner = function(winnerName: string): string
		return string.format("%s venceu", winnerName)
	end,
}

return table.freeze(RoundMessages)
