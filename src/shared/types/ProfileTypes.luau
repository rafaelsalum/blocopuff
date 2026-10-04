--!strict

-- Perfil persistente do jogador (Fase 3). O servidor calcula e salva tudo;
-- o cliente só recebe uma cópia para mostrar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)

type OwnedPuff = PuffTypes.OwnedPuff

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
	-- Vitórias em partidas sem outro humano, só contra bots RoboPuff (5B).
	-- Não entram em `wins` (ranking, Puffdex).
	botWins: number,
}

-- Desafio do dia (4.3): progresso e se já foi concluído (os tickets saem
-- na hora da conclusão).
export type ChallengeState = {
	id: string,
	progress: number,
	done: boolean,
}

-- Retorno diário: último dia com recompensa, sequência atual e recorde.
export type DailyState = {
	lastDay: number,
	streak: number,
	best: number,
}

-- Recompensa de retorno diário recém-entregue (para comemorar).
export type DailyReward = {
	streak: number,
	tickets: number,
}

export type SecretState = {
	id: string,
	obtainedAt: number,
}

-- Relíquia do Casarão que o jogador já pegou (5C.2).
export type RelicState = {
	id: string,
	obtainedAt: number,
}

-- Relíquia recém-pegada (para comemorar). `relicId` nil = Relíquia do Dia.
export type RelicEvent = {
	relicId: string?,
	tickets: number,
	roomCompleted: boolean,
	albumCompleted: boolean,
	-- Relíquia do Dia: total já pegas e se completou a coleção agora.
	dailyCount: number,
	dailyGoal: boolean,
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
	-- Tickets ganhos na rodada (4.2).
	tickets: number,
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
	-- Puffdex: Puffs que o jogador tem (só os do catálogo) e o equipado.
	puffs: { OwnedPuff },
	equippedPuff: string,
	-- Tickets da Puff Machine e giros seguidos sem Épico ou melhor.
	tickets: number,
	machinePity: number,
	-- Desafios e retorno diário (4.3). `nextResetAt` = os.time() da virada
	-- do dia do jogo (novos desafios).
	daily: DailyState,
	challenges: { ChallengeState },
	nextResetAt: number,
	secrets: { SecretState },
	-- Relíquias do álbum e a Relíquia do Dia (dia do jogo em que pegou a
	-- última e quantas no total).
	relics: { RelicState },
	dailyRelicDay: number,
	dailyRelicCount: number,
	-- Eventos desta atualização (para comemorar uma vez só).
	dailyReward: DailyReward?,
	completedChallenges: { string }?,
	newSecrets: { string }?,
	relicEvent: RelicEvent?,
	-- Presente só na atualização logo depois de uma rodada.
	award: XpAward?,
	-- Puffs recém-desbloqueados nesta atualização (para comemorar).
	newPuffs: { string }?,
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
		"botWins",
	}),
}

return table.freeze(ProfileTypes)
