--!strict

-- Resultado de uma rodada, montado pelo RoundService e enviado a todos os
-- clientes no início do encerramento. Só dados da rodada; o XP ganho chega
-- pelo perfil (ProfileSnapshot.award).

export type ResultEntry = {
	userId: number,
	name: string,
	-- 1 = vencedor. Em empate (tempo esgotado com vários vivos), todos os
	-- sobreviventes ficam em 1.
	position: number,
	blocks: number,
	knockouts: number,
	survived: boolean,
	-- 0 = nada, 1 = abriu o cofre, 2 = conquistou o Puffador do Cofre.
	vault: number,
	baraoEscapes: number,
	secretsFound: number,
}

-- Tipos de destaque: Demolisher, Knockouts, Vault, BaraoEscapes, Secrets,
-- Comeback. Nenhum premia comportamento antijogo (esconder-se, fugir da
-- partida): todos vêm de jogar de verdade.
export type Highlight = {
	kind: string,
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
