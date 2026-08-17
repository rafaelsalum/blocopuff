--!strict

local RunService = game:GetService("RunService")

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

export type RoundTimings = {
	LobbyCountdown: number,
	RoundDuration: number,
	IntermissionDuration: number,
}

export type PuffadorConfig = {
	FireCooldown: number,
	ProjectileSpeed: number,
	ProjectileLifetime: number,
	MaximumRange: number,
	MinimumAimDistance: number,
	ProjectileRadius: number,
	MuzzleForwardOffset: number,
	MuzzleUpOffset: number,
	MaximumOriginDistance: number,
	CameraShoulderOffset: Vector3,
	CameraRecoilDegrees: number,
	CameraRecoilRecovery: number,
}

export type EliminationZoneConfig = {
	DepthBelowArena: number,
	CheckInterval: number,
	VisualizeInStudio: boolean,
}

export type GameConfig = {
	GameName: string,
	MinimumPlayers: number,
	MaximumPlayers: number,
	LobbyCountdown: number,
	RoundDuration: number,
	IntermissionDuration: number,
	StudioLobbyCountdown: number,
	StudioRoundDuration: number,
	StudioIntermissionDuration: number,
	Arena: ArenaConfig,
	Lobby: LobbyConfig,
	Palette: WorldPalette,
	Puffador: PuffadorConfig,
	EliminationZone: EliminationZoneConfig,
	getRoundTimings: () -> RoundTimings,
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
	LightBlue = Color3.fromRGB(128, 174, 201),
	Yellow = Color3.fromRGB(218, 194, 126),
	Orange = Color3.fromRGB(210, 143, 108),
	Purple = Color3.fromRGB(154, 132, 188),
	Pink = Color3.fromRGB(202, 137, 168),
})

-- Valores leves e infantis: alcance e velocidade moderados, sem intenção de
-- simular uma arma real. Nenhum valor aqui se relaciona a dano ou destruição.
local Puffador: PuffadorConfig = table.freeze({
	FireCooldown = 0.65,
	ProjectileSpeed = 95,
	ProjectileLifetime = 2.5,
	MaximumRange = 180,
	MinimumAimDistance = 1,
	ProjectileRadius = 0.8,
	MuzzleForwardOffset = 2.5,
	MuzzleUpOffset = 0.5,
	MaximumOriginDistance = 12,
	CameraShoulderOffset = Vector3.new(1.8, 0.65, 0),
	CameraRecoilDegrees = 1.6,
	CameraRecoilRecovery = 14,
})

-- DepthBelowArena fica bem acima de |FallenPartsDestroyHeight| (ver
-- default.project.json) para que a eliminação autoritativa sempre aconteça
-- antes do limite global de destruição de partes.
local EliminationZone: EliminationZoneConfig = table.freeze({
	DepthBelowArena = 30,
	CheckInterval = 0.1,
	VisualizeInStudio = false,
})

local GameConfig = {} :: GameConfig

GameConfig.GameName = "BlocoPuff"
GameConfig.MinimumPlayers = 2
GameConfig.MaximumPlayers = 10
GameConfig.LobbyCountdown = 20
GameConfig.RoundDuration = 180
GameConfig.IntermissionDuration = 10

-- Tempos reduzidos usados apenas quando RunService:IsStudio() for verdadeiro.
GameConfig.StudioLobbyCountdown = 5
GameConfig.StudioRoundDuration = 20
GameConfig.StudioIntermissionDuration = 5

GameConfig.Arena = Arena
GameConfig.Lobby = Lobby
GameConfig.Palette = Palette
GameConfig.Puffador = Puffador
GameConfig.EliminationZone = EliminationZone

function GameConfig.getRoundTimings(): RoundTimings
	if RunService:IsStudio() then
		return {
			LobbyCountdown = GameConfig.StudioLobbyCountdown,
			RoundDuration = GameConfig.StudioRoundDuration,
			IntermissionDuration = GameConfig.StudioIntermissionDuration,
		}
	end

	return {
		LobbyCountdown = GameConfig.LobbyCountdown,
		RoundDuration = GameConfig.RoundDuration,
		IntermissionDuration = GameConfig.IntermissionDuration,
	}
end

table.freeze(GameConfig)

return GameConfig
