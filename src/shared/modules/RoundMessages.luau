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

	countdown = function(secondsRemaining: number): string
		return string.format("A partida começa em %d", secondsRemaining)
	end,

	winner = function(winnerName: string): string
		return string.format("%s venceu", winnerName)
	end,
}

return table.freeze(RoundMessages)
