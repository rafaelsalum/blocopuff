--!strict

-- Ranking global (Fase 3). O servidor lê os OrderedDataStores de tempos em
-- tempos e envia a todos a mesma cópia; o cliente só mostra.

export type LeaderboardEntry = {
	rank: number,
	userId: number,
	name: string,
	value: number,
}

export type Leaderboard = {
	id: string,
	title: string,
	entries: { LeaderboardEntry },
}

export type LeaderboardData = {
	boards: { Leaderboard },
	-- os.time() da última leitura (0 = ainda não carregou).
	updatedAt: number,
	-- Falso quando o DataStore está indisponível (Studio sem API, falha).
	available: boolean,
}

-- Categorias iniciais (poucas de propósito). `stat` é a chave em
-- ProfileTypes.ProfileStats.
local LeaderboardTypes = {
	Categories = table.freeze({
		table.freeze({ id = "wins", title = "VITÓRIAS", stat = "wins", icon = "🏆" }),
		table.freeze({ id = "knockouts", title = "DERRUBADAS", stat = "knockouts", icon = "👊" }),
		table.freeze({ id = "blocks", title = "BLOCOS DESTRUÍDOS", stat = "blocksDestroyed", icon = "💥" }),
		table.freeze({ id = "vaults", title = "COFRES CONQUISTADOS", stat = "vaultsConquered", icon = "🗝️" }),
	}),
	-- Categoria que define a Lenda do BlocoPuff (1º lugar).
	LegendCategory = "wins",
	TopCount = 10,
}

return table.freeze(LeaderboardTypes)
