--!strict

-- Progressão da Fase 3: XP por rodada, curva de nível e Prestígio. Tudo aqui
-- é visual/status: nível e prestígio nunca mudam a força no jogo.

export type XpSources = {
	Participation: number,
	PlacementMax: number,
	Win: number,
	PerKnockout: number,
	MaxKnockouts: number,
	BlocksPerXp: number,
	MaxBlockXp: number,
	PerSecretFound: number,
	VaultOpened: number,
	VaultConquered: number,
	PerBaraoEscape: number,
	MaxBaraoEscapes: number,
	Comeback: number,
	PerBlockBuilt: number,
}

export type ProgressionConfig = {
	Xp: XpSources,
	-- Multiplicador pelo número de participantes (anti-farming em partidas
	-- pequenas); índice = participantes, o último vale para mais.
	ParticipantMultipliers: { number },
	-- Quem não disparou nenhum Puff na rodada não ganha XP de participação.
	RequireActivity: boolean,
	-- XP para ir do nível N ao N+1: LevelBaseXp + LevelGrowthXp × (N − 1).
	LevelBaseXp: number,
	LevelGrowthXp: number,
	MaxLevel: number,
	-- Prestígio: preparado, mas só liberado quando validado em playtest.
	PrestigeEnabled: boolean,
	MaxPrestige: number,
}

local ProgressionConfig: ProgressionConfig = {
	Xp = table.freeze({
		Participation = 20,
		PlacementMax = 30,
		Win = 40,
		PerKnockout = 8,
		MaxKnockouts = 5,
		BlocksPerXp = 2,
		MaxBlockXp = 20,
		PerSecretFound = 10,
		VaultOpened = 10,
		VaultConquered = 15,
		PerBaraoEscape = 8,
		MaxBaraoEscapes = 2,
		Comeback = 15,
		PerBlockBuilt = 2,
	}),
	ParticipantMultipliers = table.freeze({ 0.6, 0.6, 0.8, 1 }),
	RequireActivity = true,
	LevelBaseXp = 100,
	LevelGrowthXp = 25,
	MaxLevel = 50,
	PrestigeEnabled = false,
	MaxPrestige = 10,
}

return table.freeze(ProgressionConfig)
