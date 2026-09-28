--!strict

-- Perfil persistente do jogador (Fase 3). O servidor calcula e salva tudo;
-- o cliente só recebe uma cópia para mostrar.

export type ProfileStats = {
	matches: number,
	wins: number,
	top3: number,
	knockouts: number,
	blocksDestroyed: number,
	vaultsOpened: number,
	vaultsConquered: number,
	baraoEscapes: number,
	secretsFound: number,
	blocksBuilt: number,
	comebacks: number,
}

-- XP de uma rodada, por fonte (para o pós-partida e o aviso de nível).
export type XpLine = {
	source: string,
	xp: number,
}

export type XpAward = {
	-- Rodada a que o XP pertence (o cliente só mostra no painel dessa rodada).
	roundId: number,
	total: number,
	lines: { XpLine },
	levelBefore: number,
	levelAfter: number,
}

-- Cópia enviada ao cliente. `saved` = falso quando o progresso desta sessão
-- não está sendo salvo (DataStore indisponível ou perfil preso em outro
-- servidor).
export type ProfileSnapshot = {
	stats: ProfileStats,
	xp: number,
	level: number,
	prestige: number,
	saved: boolean,
	-- Presente só na atualização logo depois de uma rodada.
	award: XpAward?,
}

-- Nomes das estatísticas, na ordem usada por schema, validação e interface.
local ProfileTypes = {
	StatKeys = table.freeze({
		"matches",
		"wins",
		"top3",
		"knockouts",
		"blocksDestroyed",
		"vaultsOpened",
		"vaultsConquered",
		"baraoEscapes",
		"secretsFound",
		"blocksBuilt",
		"comebacks",
	}),
}

return table.freeze(ProfileTypes)
