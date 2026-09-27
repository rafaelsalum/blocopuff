--!strict

-- Resultado de uma rodada, montado pelo RoundService e enviado a todos os
-- clientes no início do encerramento. Só dados da rodada (sem progresso
-- persistente nesta fase).

export type ResultEntry = {
	userId: number,
	name: string,
	-- 1 = vencedor. Em empate (tempo esgotado com vários vivos), todos os
	-- sobreviventes ficam em 1.
	position: number,
	blocks: number,
	knockouts: number,
	survived: boolean,
}

export type Highlight = {
	title: string,
	userId: number,
	name: string,
	value: number,
}

export type RoundResult = {
	roundId: number,
	winnerUserId: number,
	winnerName: string,
	draw: boolean,
	participantCount: number,
	entries: { ResultEntry },
	highlights: { Highlight },
}

return {}
