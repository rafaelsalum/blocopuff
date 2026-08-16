--!strict

export type ArenaConfig = {
	Rows: number,
	Columns: number,
	BlockSize: Vector3,
	BlockGap: number,
	Position: Vector3,
}

export type LobbyConfig = {
	PlatformSize: Vector3,
	Position: Vector3,
}

export type WorldPalette = {
	LightBlue: Color3,
	Yellow: Color3,
	Orange: Color3,
	Purple: Color3,
	Pink: Color3,
}

export type GameConfig = {
	GameName: string,
	MinimumPlayers: number,
	MaximumPlayers: number,
	LobbyCountdown: number,
	RoundDuration: number,
	IntermissionDuration: number,
	Arena: ArenaConfig,
	Lobby: LobbyConfig,
	Palette: WorldPalette,
}

local Arena: ArenaConfig = table.freeze({
	Rows = 15,
	Columns = 15,
	BlockSize = Vector3.new(6, 1, 6),
	BlockGap = 0.2,
	Position = Vector3.new(0, 50, 0),
})

local Lobby: LobbyConfig = table.freeze({
	PlatformSize = Vector3.new(40, 2, 40),
	Position = Vector3.new(0, 60, -130),
})

local Palette: WorldPalette = table.freeze({
	LightBlue = Color3.fromRGB(151, 211, 255),
	Yellow = Color3.fromRGB(255, 230, 148),
	Orange = Color3.fromRGB(255, 181, 132),
	Purple = Color3.fromRGB(194, 168, 255),
	Pink = Color3.fromRGB(255, 174, 211),
})

local GameConfig: GameConfig = table.freeze({
	GameName = "BlocoPuff",
	MinimumPlayers = 2,
	MaximumPlayers = 10,
	LobbyCountdown = 20,
	RoundDuration = 180,
	IntermissionDuration = 10,
	Arena = Arena,
	Lobby = Lobby,
	Palette = Palette,
})

return GameConfig
