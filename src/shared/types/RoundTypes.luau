--!strict

export type RoundState = "WaitingForPlayers" | "Countdown" | "Active" | "Ending"

export type RoundTypesModule = {
	WaitingForPlayers: RoundState,
	Countdown: RoundState,
	Active: RoundState,
	Ending: RoundState,
}

local RoundTypes: RoundTypesModule = {
	WaitingForPlayers = "WaitingForPlayers",
	Countdown = "Countdown",
	Active = "Active",
	Ending = "Ending",
}

return table.freeze(RoundTypes)
