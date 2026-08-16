--!strict

export type GameConfig = {
	GameName: string,
	MinimumPlayers: number,
	MaximumPlayers: number,
	LobbyCountdown: number,
	RoundDuration: number,
	IntermissionDuration: number,
}

local GameConfig: GameConfig = table.freeze({
	GameName = "BlocoPuff",
	MinimumPlayers = 2,
	MaximumPlayers = 10,
	LobbyCountdown = 20,
	RoundDuration = 180,
	IntermissionDuration = 10,
})

return GameConfig
