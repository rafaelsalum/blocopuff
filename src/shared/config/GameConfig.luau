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
	-- Indexado pelo piso (1 = mais baixo); pisos sem entrada usam o último.
	FloorStyles: { FloorStyle },
}

export type FloorStyle = {
	Material: Enum.Material,
	Colors: { Color3 },
}

-- Paleta de interior no estilo mansão: papel de parede, lambri de madeira,
-- molduras, porão de tijolos e luz quente de arandelas e lustres.
export type BuildingConfig = {
	WallThickness: number,
	CeilingClearance: number,
	PitDepth: number,
	GalleryDepth: number,
	GalleryRise: number,
	-- Indexado pelo piso (1 = mais baixo).
	StoryWallpaperColors: { Color3 },
	GalleryWallpaperColor: Color3,
	WainscotColor: Color3,
	TrimColor: Color3,
	BaseboardColor: Color3,
	CeilingColor: Color3,
	CeilingBeamColor: Color3,
	BasementBrickColor: Color3,
	PitFloorColor: Color3,
	GalleryCarpetColor: Color3,
	RugColor: Color3,
	UpholsteryColor: Color3,
	FrameColor: Color3,
	BrassColor: Color3,
	WindowColor: Color3,
	LampColor: Color3,
	ArtColors: { Color3 },
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
	MaximumAimOriginDistance: number,
	ProjectileConvergeDistance: number,
	CameraShoulderOffset: Vector3,
	CombatCameraZoom: number,
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
	FloorStyles = {
		-- Piso de baixo: cerâmica em xadrez claro, contrastando com o poço escuro.
		{
			Material = Enum.Material.CeramicTiles,
			Colors = { Color3.fromRGB(176, 166, 146), Color3.fromRGB(84, 98, 100) },
		},
		-- Piso de cima: taco de madeira em dois tons; os buracos revelam a
		-- cerâmica clara de baixo, o que facilita a leitura do mapa.
		{
			Material = Enum.Material.WoodPlanks,
			Colors = { Color3.fromRGB(168, 116, 68), Color3.fromRGB(116, 76, 46) },
		},
	},
})

-- Prédio fechado ao redor da arena: paredes e teto em cores sólidas para não
-- passar a sensação de mapa aberto. PitDepth precisa ser maior que
-- EliminationZone.DepthBelowArena para a eliminação ocorrer antes do fundo.
local Building: BuildingConfig = table.freeze({
	WallThickness = 2,
	CeilingClearance = 26,
	PitDepth = 45,
	GalleryDepth = 20,
	GalleryRise = 6,
	StoryWallpaperColors = {
		Color3.fromRGB(112, 50, 54),
		Color3.fromRGB(74, 98, 80),
	},
	GalleryWallpaperColor = Color3.fromRGB(52, 78, 86),
	WainscotColor = Color3.fromRGB(86, 56, 38),
	TrimColor = Color3.fromRGB(150, 108, 66),
	BaseboardColor = Color3.fromRGB(58, 38, 28),
	CeilingColor = Color3.fromRGB(196, 184, 160),
	CeilingBeamColor = Color3.fromRGB(80, 52, 34),
	BasementBrickColor = Color3.fromRGB(92, 62, 52),
	PitFloorColor = Color3.fromRGB(34, 30, 32),
	GalleryCarpetColor = Color3.fromRGB(122, 34, 40),
	RugColor = Color3.fromRGB(176, 136, 70),
	UpholsteryColor = Color3.fromRGB(64, 40, 70),
	FrameColor = Color3.fromRGB(178, 138, 64),
	BrassColor = Color3.fromRGB(196, 154, 82),
	WindowColor = Color3.fromRGB(26, 36, 64),
	LampColor = Color3.fromRGB(255, 226, 192),
	ArtColors = {
		Color3.fromRGB(58, 84, 120),
		Color3.fromRGB(140, 92, 50),
		Color3.fromRGB(92, 120, 72),
		Color3.fromRGB(150, 60, 56),
		Color3.fromRGB(196, 170, 120),
	},
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
	ProjectileSpeed = 220,
	ProjectileLifetime = 1.5,
	MaximumRange = 220,
	MinimumAimDistance = 1,
	ProjectileRadius = 0.8,
	MuzzleForwardOffset = 2.5,
	MuzzleUpOffset = 0.5,
	MaximumOriginDistance = 12,
	-- Como em jogos de tiro, o acerto segue o raio da câmera (o que está sob
	-- a mira). O servidor só aceita uma origem de câmera próxima da cabeça e
	-- com linha livre até ela.
	MaximumAimOriginDistance = 24,
	-- Distância em que o projétil visual sai do cano e encontra o raio da mira.
	ProjectileConvergeDistance = 10,
	CameraShoulderOffset = Vector3.new(1.8, 0.65, 0),
	CombatCameraZoom = 10,
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
