--!strict

-- Nomes de atributos usados por ReplicatedStateService e RoundService (servidor)
-- e lidos por HudController (cliente). Fonte única para evitar strings
-- duplicadas divergindo entre quem escreve e quem lê.
export type StateAttributeNames = {
	ContainerName: string,

	RoundState: string,
	TimeRemaining: string,
	RoundId: string,
	ParticipantCount: string,
	MinimumPlayers: string,
	MaximumPlayers: string,
	WinnerUserId: string,
	WinnerName: string,
	StatusMessage: string,

	TotalBlockCount: string,
	RemainingBlockCount: string,
	DestroyedBlockCount: string,
	FinalChaos: string,

	PlayerIsParticipant: string,
	PlayerParticipatingRoundId: string,
	PlayerIsEliminated: string,
	PlayerEliminationReason: string,
	PlayerEliminatedAtRoundId: string,
	PlayerRoundsUntilTurn: string,
	PlayerRoundBlocksDestroyed: string,
	PlayerHasSecondChance: string,
	PlayerRoundKnockouts: string,
	-- Puff equipado (id do PuffCatalog), escrito pelo servidor a partir do
	-- perfil: todos os clientes veem o mesmo.
	PlayerEquippedPuff: string,
	-- Party do jogador (id), escrito pelo PartyService.
	PlayerPartyId: string,
	-- Na fila da partida (no mirante ou com alguém da Party lá), escrito
	-- pelo MatchQueueService.
	PlayerInMatchQueue: string,
	-- No Model do corpo de um bot RoboPuff (Fase 5B): id negativo dele. O
	-- corpo também leva a tag BotTag (CollectionService).
	BotId: string,
	BotTag: string,
	-- Hora (GetServerTimeNow) do último impulso aceito: efeito para todos.
	LastDashAt: string,
}

local StateAttributeNames: StateAttributeNames = {
	ContainerName = "BlocoPuffState",

	RoundState = "RoundState",
	TimeRemaining = "TimeRemaining",
	RoundId = "RoundId",
	ParticipantCount = "ParticipantCount",
	MinimumPlayers = "MinimumPlayers",
	MaximumPlayers = "MaximumPlayers",
	WinnerUserId = "WinnerUserId",
	WinnerName = "WinnerName",
	StatusMessage = "StatusMessage",

	TotalBlockCount = "TotalBlockCount",
	RemainingBlockCount = "RemainingBlockCount",
	DestroyedBlockCount = "DestroyedBlockCount",
	FinalChaos = "FinalChaos",

	PlayerIsParticipant = "IsRoundParticipant",
	PlayerParticipatingRoundId = "ParticipatingRoundId",
	PlayerIsEliminated = "IsEliminated",
	PlayerEliminationReason = "EliminationReason",
	PlayerEliminatedAtRoundId = "EliminatedAtRoundId",
	PlayerRoundsUntilTurn = "RoundsUntilTurn",
	PlayerRoundBlocksDestroyed = "RoundBlocksDestroyed",
	PlayerHasSecondChance = "HasSecondChance",
	PlayerRoundKnockouts = "RoundKnockouts",
	PlayerEquippedPuff = "EquippedPuff",
	PlayerPartyId = "PartyId",
	PlayerInMatchQueue = "InMatchQueue",
	BotId = "BotId",
	BotTag = "RoboPuff",
	LastDashAt = "LastDashAt",
}

return table.freeze(StateAttributeNames)
