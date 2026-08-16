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

	PlayerIsParticipant: string,
	PlayerParticipatingRoundId: string,
	PlayerIsEliminated: string,
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

	PlayerIsParticipant = "IsRoundParticipant",
	PlayerParticipatingRoundId = "ParticipatingRoundId",
	PlayerIsEliminated = "IsEliminated",
}

return table.freeze(StateAttributeNames)
