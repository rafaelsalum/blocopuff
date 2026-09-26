--!strict

local RunService = game:GetService("RunService")

export type ArenaConfig = {
	Rows: number,
	Columns: number,
	BlockSize: Vector3,
	BlockGap: number,
	Position: Vector3,
	FloorCount: number,
	FloorSpacing: number,
}

export type BuildingConfig = {
	WallThickness: number,
	CeilingClearance: number,
	PitDepth: number,
	GalleryDepth: number,
	GalleryRise: number,
	WallColor: Color3,
	LowerWallColor: Color3,
	CeilingColor: Color3,
	PitColor: Color3,
	TrimColor: Color3,
	GalleryFloorColor: Color3,
	LightColor: Color3,
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
	CameraRecoilDistance: number,
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
	Building: BuildingConfig,
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
	-- Centro do piso mais baixo. Os demais pisos ficam FloorSpacing studs
	-- acima um do outro; os jogadores começam no piso de cima.
	Position = Vector3.new(0, 100, 0),
	FloorCount = 2,
	FloorSpacing = 28,
})

-- Prédio fechado ao redor da arena: paredes e teto em cores sólidas para não
-- passar a sensação de mapa aberto. PitDepth precisa ser maior que
-- EliminationZone.DepthBelowArena para a eliminação ocorrer antes do fundo.
local Building: BuildingConfig = table.freeze({
	WallThickness = 2,
	CeilingClearance = 26,
	PitDepth = 45,
	GalleryDepth = 16,
	GalleryRise = 6,
	WallColor = Color3.fromRGB(196, 200, 212),
	LowerWallColor = Color3.fromRGB(150, 156, 176),
	CeilingColor = Color3.fromRGB(228, 230, 236),
	PitColor = Color3.fromRGB(46, 44, 60),
	TrimColor = Color3.fromRGB(116, 108, 150),
	GalleryFloorColor = Color3.fromRGB(176, 160, 206),
	LightColor = Color3.fromRGB(255, 244, 226),
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
	-- O recuo desloca a câmera levemente para trás, sem alterar a direção
	-- central da mira ou acumular inclinação entre disparos.
	CameraRecoilDistance = 0.16,
	CameraRecoilRecovery = 18,
})

-- DepthBelowArena é medido a partir do piso mais baixo e fica bem acima de |FallenPartsDestroyHeight| (ver
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
GameConfig.Building = Building
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
