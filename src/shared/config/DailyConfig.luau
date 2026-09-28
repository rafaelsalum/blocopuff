--!strict

-- Desafios diários e retorno diário (Fase 4.3).
--
-- Desafios: 3 por dia, um de cada nível (fácil, médio, difícil), sempre de
-- gameplay (Barão, corredores, blocos, cofre, Top 3, derrubadas,
-- exploração), nunca "fique online X minutos". O progresso sai das
-- estatísticas da rodada calculadas pelo servidor. Concluir dá tickets na
-- hora, sem botão de resgatar.
--
-- Retorno diário: recompensa automática no primeiro login do dia, em ciclo
-- de 7 dias. A sequência é amigável: perder UM dia não zera nada.
--
-- Ids ficam salvos nos perfis: nunca renomeie nem reaproveite um id.

export type ChallengeTier = "Easy" | "Medium" | "Hard"

export type ChallengeDefinition = {
	id: string,
	title: string,
	stat: string,
	target: number,
	tickets: number,
	tier: ChallengeTier,
}

export type DailyConfig = {
	-- Fuso do "dia" do jogo em relação ao UTC (−3 = virada à meia-noite de Brasília).
	DayOffsetHours: number,
	-- Dias que podem faltar sem perder a sequência.
	GraceDays: number,
	-- Tickets de cada dia do ciclo (dia 1 ao 7; depois recomeça).
	DailyRewards: { number },
	Tiers: { ChallengeTier },
	Challenges: { ChallengeDefinition },
}

local function challenge(id: string, title: string, stat: string, target: number, tickets: number, tier: ChallengeTier): ChallengeDefinition
	return table.freeze({ id = id, title = title, stat = stat, target = target, tickets = tickets, tier = tier })
end

local DailyConfig: DailyConfig = {
	DayOffsetHours = -3,
	GraceDays = 1,
	DailyRewards = table.freeze({ 2, 2, 3, 3, 4, 4, 8 }),
	Tiers = table.freeze({ "Easy", "Medium", "Hard" } :: { ChallengeTier }),
	Challenges = table.freeze({
		challenge("rounds3", "Jogue 3 partidas", "matches", 3, 2, "Easy"),
		challenge("blocks60", "Derrube 60 blocos", "blocksDestroyed", 60, 2, "Easy"),
		challenge("knockouts3", "Derrube 3 jogadores", "knockouts", 3, 3, "Medium"),
		challenge("top3x2", "Fique no Top 3 em 2 partidas", "top3", 2, 3, "Medium"),
		challenge("barao1", "Fuja do Barão", "baraoEscapes", 1, 3, "Medium"),
		challenge("secret1", "Descubra uma passagem secreta", "secretsFound", 1, 3, "Medium"),
		challenge("win1", "Vença uma partida", "wins", 1, 4, "Hard"),
		challenge("vault1", "Abra o cofre do Barão", "vaultsOpened", 1, 4, "Hard"),
		challenge("build3", "Reconstrua 3 blocos", "blocksBuilt", 3, 4, "Hard"),
		challenge("comeback1", "Dê a Volta por Cima", "comebacks", 1, 4, "Hard"),
	} :: { ChallengeDefinition }),
}

local seen: { [string]: boolean } = {}
for _, definition in ipairs(DailyConfig.Challenges) do
	assert(not seen[definition.id], `Duplicated challenge id {definition.id}`)
	seen[definition.id] = true
end

return table.freeze(DailyConfig)
