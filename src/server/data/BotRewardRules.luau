--!strict

-- Recompensas de um jogador numa partida com bots RoboPuff (Fase 5B), sem
-- Roblox. Os testes rodam no Lune (tests/BotRewardRules.spec.luau).
--
-- Bot completa a partida, mas não paga como gente:
--   * estatísticas do perfil (ranking, Puffdex, desafio "Derrube 3"):
--     derrubar bot não conta; vitória e top 3 só contam com pelo menos
--     `MinHumansForStats` humanos. A vitória sem outros humanos vira
--     `botWins` (mostrada ao jogador, sem misturar com `wins`);
--   * XP: multiplicador pelo número de humanos, com piso
--     `BotMatchMinMultiplier`; derrubar bot vale `BotKnockoutXpFactor`;
--   * tickets: sem top 3; numa partida sem outro humano todos os tickets
--     da rodada (participação, torcida e vitória) entram num limite por dia
--     (`cappedTickets`: quem aplica é o perfil, que sabe quantos já foram).
--     Os tickets de subir de nível ficam de fora (vêm do XP).
-- Novatos (`beginner`) recebem XP e tickets cheios; as estatísticas
-- continuam filtradas.

export type RoundInput = {
	won: boolean,
	-- Top 3 pela regra da partida (sem olhar se havia bots).
	podium: boolean,
	humans: number,
	bots: number,
	-- Derrubadas na rodada (humanos + bots) e quantas foram de bots.
	knockouts: number,
	botKnockouts: number,
	beginner: boolean,
}

export type RewardConfig = {
	MinHumansForStats: number,
	BotMatchMinMultiplier: number,
	BotKnockoutXpFactor: number,
}

export type Outcome = {
	-- O que soma no perfil.
	stats: { wins: number, top3: number, knockouts: number, botWins: number },
	-- O que rende ticket.
	ticketWins: number,
	ticketTop3: number,
	-- Partida sem outro humano: tickets da rodada sujeitos ao limite do dia.
	cappedTickets: boolean,
	-- Ajustes do XpCalculator (nil = regra normal).
	xp: {
		knockouts: number,
		botKnockouts: number,
		botKnockoutFactor: number,
		multiplierCount: number?,
		minMultiplier: number?,
	},
}

local BotRewardRules = {}

local function flag(value: boolean): number
	return if value then 1 else 0
end

function BotRewardRules.evaluate(input: RoundInput, config: RewardConfig): Outcome
	local total = math.max(0, input.knockouts)
	if input.bots <= 0 then
		return {
			stats = { wins = flag(input.won), top3 = flag(input.podium), knockouts = total, botWins = 0 },
			ticketWins = flag(input.won),
			ticketTop3 = flag(input.podium),
			cappedTickets = false,
			xp = { knockouts = total, botKnockouts = 0, botKnockoutFactor = 1, multiplierCount = nil, minMultiplier = nil },
		}
	end

	local botKnockouts = math.clamp(input.botKnockouts, 0, total)
	local humanKnockouts = total - botKnockouts
	local counts = input.humans >= config.MinHumansForStats
	local stats = {
		wins = flag(input.won and counts),
		top3 = flag(input.podium and counts),
		knockouts = humanKnockouts,
		botWins = flag(input.won and not counts),
	}
	if input.beginner then
		return {
			stats = stats,
			ticketWins = flag(input.won),
			ticketTop3 = flag(input.podium),
			cappedTickets = false,
			xp = {
				knockouts = total,
				botKnockouts = 0,
				botKnockoutFactor = 1,
				multiplierCount = input.humans + input.bots,
				minMultiplier = nil,
			},
		}
	end
	return {
		stats = stats,
		ticketWins = flag(input.won),
		ticketTop3 = stats.top3,
		cappedTickets = not counts,
		xp = {
			knockouts = humanKnockouts,
			botKnockouts = botKnockouts,
			botKnockoutFactor = config.BotKnockoutXpFactor,
			multiplierCount = input.humans,
			minMultiplier = config.BotMatchMinMultiplier,
		},
	}
end

return table.freeze(BotRewardRules)
