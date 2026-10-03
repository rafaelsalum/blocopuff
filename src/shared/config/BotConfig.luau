--!strict

-- Bots RoboPuff (Fase 5B, docs/FASE_5B_BOTS_PUFF.md): completam a partida
-- quando faltam jogadores. Números iniciais para o playtest.

export type FillConfig = {
	Enabled: boolean,
	-- Tamanho mínimo divertido da partida (humanos + bots).
	TargetCombatants: number,
	MaxBots: number,
	-- Espera (s) com gente no mirante antes de os bots chegarem.
	WaitSeconds: number,
}

export type BodyConfig = {
	-- Prefixo do nome e ícone no painel e no resultado (deixa claro que é
	-- bot, em todo lugar).
	Tag: string,
	WalkSpeed: number,
	-- Cores do corpo (uma por bot, em ordem).
	Colors: { Color3 },
	AntennaColor: Color3,
}

export type LevelName = "Easy" | "Normal" | "Hard"

-- Como um nível de bot joga.
export type LevelConfig = {
	-- Tempo (s) entre ver um alvo e atirar nele.
	ReactionTime: number,
	-- Erro máximo da mira (graus).
	AimErrorDegrees: number,
	-- Cadência: múltiplo do FireCooldown do Puffador (maior = mais lento).
	FireCooldownFactor: number,
	WalkSpeed: number,
	-- Chance de ficar parado em vez de escolher um novo destino.
	IdleChance: number,
	-- Chance de mirar no chão embaixo do alvo (em vez do corpo).
	FloorShotChance: number,
	-- Foge dos blocos piscando (Caos Final, janela) e da área das armadilhas.
	DodgeWarnings: boolean,
	-- Quanto prefere chegar perto do alvo ao escolher para onde andar.
	ChaseWeight: number,
	-- Chance, por tiro, de mirar numa armadilha pronta com alguém perto.
	TrapChance: number,
	-- Usa o impulso para sair de um bloco piscando ou de área de armadilha.
	UsesDash: boolean,
}

export type BrainConfig = {
	TickSeconds: number,
	-- Intervalo (s) entre trocas de destino.
	GoalMinSeconds: number,
	GoalMaxSeconds: number,
	-- Distância máxima (studs) de um novo destino.
	MoveRadius: number,
	-- Alcance (studs) em que o bot procura alvos.
	SightRange: number,
	-- Tempo (s) com o mesmo alvo antes de reconsiderar.
	RetargetSeconds: number,
	-- Distância (studs) de alguém à armadilha para valer a pena acioná-la.
	TrapVictimRadius: number,
}

-- Recompensas em partidas com bots (BotRewardRules).
export type RewardConfig = {
	-- Humanos mínimos para vitória e top 3 contarem no perfil.
	MinHumansForStats: number,
	-- Piso do multiplicador de XP numa partida com bots.
	BotMatchMinMultiplier: number,
	-- Fração do XP de derrubada quando quem caiu é um bot.
	BotKnockoutXpFactor: number,
	-- Tickets por dia de partidas sem outro humano (participação, torcida e
	-- vitória; subir de nível não conta). Depois disso, só XP.
	SoloBotTicketsPerDay: number,
}

export type BotConfig = {
	Fill: FillConfig,
	-- No Studio os bots chegam rápido, para testar.
	StudioWaitSeconds: number,
	-- Depois de uma partida com bots, quanto tempo (s) eles voltam ao
	-- mirante sem a espera inicial.
	WarmSeconds: number,
	Body: BodyConfig,
	-- Nomes curtos e divertidos (nunca de usuários reais).
	Names: { string },
	Brain: BrainConfig,
	Levels: { [LevelName]: LevelConfig },
	-- Escolha do nível (BotLevelRules): novatos só enfrentam bots fáceis.
	-- `BeginnerMatches` também vale para a recompensa cheia do novato.
	LevelRules: {
		BeginnerMatches: number,
		ExperiencedLevel: number,
	},
	Rewards: RewardConfig,
}

local BotConfig: BotConfig = {
	Fill = table.freeze({
		Enabled = true,
		TargetCombatants = 4,
		MaxBots = 3,
		WaitSeconds = 12,
	}),
	StudioWaitSeconds = 3,
	WarmSeconds = 45,
	Body = table.freeze({
		Tag = "🤖",
		WalkSpeed = 14,
		Colors = table.freeze({
			Color3.fromRGB(255, 170, 200),
			Color3.fromRGB(140, 210, 255),
			Color3.fromRGB(170, 235, 150),
			Color3.fromRGB(255, 215, 120),
			Color3.fromRGB(200, 170, 255),
			Color3.fromRGB(255, 180, 130),
		}),
		AntennaColor = Color3.fromRGB(255, 90, 90),
	}),
	Names = table.freeze({
		"Pipoca",
		"Biscoito",
		"Trovão",
		"Jujuba",
		"Paçoca",
		"Faísca",
		"Bolota",
		"Cometa",
		"Tampinha",
		"Fofura",
		"Pudim",
		"Rojão",
	}),
	Brain = table.freeze({
		TickSeconds = 0.2,
		GoalMinSeconds = 1.5,
		GoalMaxSeconds = 3.5,
		MoveRadius = 30,
		SightRange = 90,
		RetargetSeconds = 2.5,
		TrapVictimRadius = 14,
	}),
	Levels = table.freeze({
		Easy = table.freeze({
			ReactionTime = 0.9,
			AimErrorDegrees = 14,
			FireCooldownFactor = 2.2,
			WalkSpeed = 12,
			IdleChance = 0.3,
			FloorShotChance = 0.6,
			DodgeWarnings = false,
			ChaseWeight = 0.2,
			TrapChance = 0,
			UsesDash = false,
		}),
		Normal = table.freeze({
			ReactionTime = 0.5,
			AimErrorDegrees = 8,
			FireCooldownFactor = 1.6,
			WalkSpeed = 14,
			IdleChance = 0.15,
			FloorShotChance = 0.5,
			DodgeWarnings = true,
			ChaseWeight = 0.4,
			TrapChance = 0.15,
			UsesDash = true,
		}),
		Hard = table.freeze({
			ReactionTime = 0.3,
			AimErrorDegrees = 4,
			FireCooldownFactor = 1.25,
			WalkSpeed = 16,
			IdleChance = 0.05,
			FloorShotChance = 0.45,
			DodgeWarnings = true,
			ChaseWeight = 0.6,
			TrapChance = 0.25,
			UsesDash = true,
		}),
	}),
	LevelRules = table.freeze({
		BeginnerMatches = 3,
		ExperiencedLevel = 5,
	}),
	Rewards = table.freeze({
		MinHumansForStats = 2,
		BotMatchMinMultiplier = 0.8,
		BotKnockoutXpFactor = 0.5,
		SoloBotTicketsPerDay = 6,
	}),
}

return table.freeze(BotConfig)
