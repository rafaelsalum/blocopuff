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

export type SecretRoomConfig = {
	Enabled: boolean,
	OpenHoldDuration: number,
	GrabHoldDuration: number,
	SuperCharges: number,
	SuperPower: number,
	BuildCharges: number,
	BuildRange: number,
	BuildCooldown: number,
	MaxStaySeconds: number,
	StayWarningSeconds: number,
	AlertSoundId: string,
}

export type KnockbackConfig = {
	HorizontalSpeed: number,
	VerticalSpeed: number,
	Duration: number,
	SuperMultiplier: number,
	CreditWindow: number,
}

export type SecondChanceConfig = {
	Enabled: boolean,
	RespawnProtection: number,
}

export type FinalChaosConfig = {
	Duration: number,
	MaxRoundFraction: number,
	CollapseInterval: number,
	CollapseStartCount: number,
	CollapseMaxCount: number,
	WarningTime: number,
}

export type BaraoConfig = {
	Enabled: boolean,
	WakeMinFraction: number,
	WakeMaxFraction: number,
	EnragedDuration: number,
	EnragedSpeedMultiplier: number,
	PatrolSpeed: number,
	ChaseSpeed: number,
	LateralSpeed: number,
	SightRange: number,
	SwitchCorridorDelay: number,
	TunnelTravelTime: number,
	TunnelRunMultiplier: number,
	ModelScale: number,
	ContactRadius: number,
	JumpClearance: number,
	ContactCooldown: number,
	ContactPause: number,
	PushSpeed: number,
	PushLift: number,
	BarkIntervalPatrol: NumberRange,
	BarkIntervalChase: NumberRange,
	BarkSoundIds: { string },
	BarkPitch: NumberRange,
	FunnySoundIds: { string },
	FootstepSoundId: string,
	TensionSoundId: string,
	DoorSoundId: string,
}

export type TocaConfig = {
	MaxStay: number,
	WarningAt: number,
	Cooldown: number,
	EjectSpeed: number,
}

export type TelemetryConfig = {
	Enabled: boolean,
	PrintInStudio: boolean,
}

export type MusicConfig = {
	SoundId: string,
	LobbyVolume: number,
	MatchVolume: number,
	FadeTime: number,
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
	Music: MusicConfig,
	SecretRoom: SecretRoomConfig,
	Knockback: KnockbackConfig,
	SecondChance: SecondChanceConfig,
	FinalChaos: FinalChaosConfig,
	Telemetry: TelemetryConfig,
	Barao: BaraoConfig,
	Toca: TocaConfig,
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
		-- Piso de baixo: pedra fosca em xadrez de tons médios. Material sem
		-- brilho para não refletir as luzes; ainda contrasta com o poço escuro.
		{
			Material = Enum.Material.Slate,
			Colors = { Color3.fromRGB(122, 116, 106), Color3.fromRGB(80, 88, 92) },
		},
		-- Piso de cima: taco de madeira em dois tons; os buracos revelam a
		-- pedra de baixo, o que facilita a leitura do mapa.
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
	-- Largura do mirante (fila da partida), com espaço para o aquecimento.
	GalleryDepth = 32,
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

-- Trilha de fundo tocada localmente em cada cliente, em loop. Fica baixa no
-- lobby e quase some enquanto o jogador está competindo, para não competir
-- com os sons da partida.
local Music: MusicConfig = table.freeze({
	SoundId = "rbxassetid://1846613120",
	LobbyVolume = 0.06,
	MatchVolume = 0.015,
	FadeTime = 1.2,
})

-- Cofre do Barão, na parede oeste do andar de baixo. Destranca no instante
-- em que o Barão acorda (GameConfig.Barao.WakeMin/MaxFraction). Dentro está
-- o Puffador do Cofre: SuperCharges disparos que quebram SuperPower blocos
-- cada e empurram mais forte, e BuildCharges construções (reconstrói um
-- bloco derrubado da grade a até BuildRange studs). AlertSoundId toca para
-- todos quando o cofre é aberto; troque por um som da Creator Store se quiser.
local SecretRoom: SecretRoomConfig = table.freeze({
	Enabled = true,
	OpenHoldDuration = 1.5,
	GrabHoldDuration = 0.8,
	SuperCharges = 15,
	SuperPower = 2,
	BuildCharges = 3,
	BuildRange = 40,
	BuildCooldown = 0.5,
	-- Tempo total que cada jogador pode passar no cofre por rodada; depois
	-- disso o Barão o expulsa de volta para o andar de baixo.
	MaxStaySeconds = 15,
	StayWarningSeconds = 10,
	AlertSoundId = "rbxasset://sounds/electronicpingshort.wav",
})

-- Empurrão do Puffador ao acertar outro jogador. A velocidade é aplicada
-- pelo cliente dono do personagem (a física do personagem é dele), mas o
-- servidor decide quando, em quem e com que força. CreditWindow: segundos
-- em que uma queda ainda conta como derrubada de quem empurrou por último.
local Knockback: KnockbackConfig = table.freeze({
	HorizontalSpeed = 62,
	VerticalSpeed = 26,
	Duration = 0.18,
	SuperMultiplier = 1.35,
	CreditWindow = 6,
})

-- Cada jogador tem uma Segunda Chance por rodada: a primeira queda para fora
-- da arena o devolve ao andar de baixo, com alguns segundos imune a empurrões.
local SecondChance: SecondChanceConfig = table.freeze({
	Enabled = true,
	RespawnProtection = 2.5,
})

-- Caos Final: nos últimos segundos da rodada a Segunda Chance é desligada e
-- blocos aleatórios piscam em vermelho e caem, cada vez em maior número.
-- MaxRoundFraction limita o Caos a uma fração da rodada (rodadas curtas do Studio).
local FinalChaos: FinalChaosConfig = table.freeze({
	Duration = 30,
	MaxRoundFraction = 0.34,
	CollapseInterval = 2,
	CollapseStartCount = 3,
	CollapseMaxCount = 9,
	WarningTime = 1.2,
})

-- Telemetria via AnalyticsService (eventos customizados no Creator
-- Dashboard). PrintInStudio escreve cada evento no Output durante testes.
local Telemetry: TelemetryConfig = table.freeze({
	Enabled = true,
	PrintInStudio = true,
})

-- Barão: mascote que patrulha os corredores secretos. Dorme no começo da
-- rodada, acorda com um latido (no mesmo instante o cofre destranca) e
-- expulsa quem encontra, sem dano. A
-- perseguição é mais lenta que o jogador (WalkSpeed 16) para dar chance de
-- fugir, e dá para pular por cima dele (JumpClearance: altura dos pés acima
-- do piso que já passa sobre ele). Os sons são provisórios, embutidos no
-- Roblox: troque por latidos reais (rbxassetid://...) quando houver.
local Barao: BaraoConfig = table.freeze({
	Enabled = true,
	-- Acorda (e destranca o cofre) entre 20% e 35% do tempo da rodada.
	WakeMinFraction = 0.2,
	WakeMaxFraction = 0.35,
	-- Quando alguém abre o cofre, o Barão fica bravo por um tempo: late
	-- mais e corre um pouco mais (ainda mais devagar que o jogador).
	EnragedDuration = 25,
	EnragedSpeedMultiplier = 1.1,
	PatrolSpeed = 8,
	ChaseSpeed = 14,
	LateralSpeed = 6,
	SightRange = 34,
	-- Só há gente no outro corredor há SwitchCorridorDelay s: ele corre até
	-- a portinhola mais perto, atravessa o túnel (TunnelTravelTime s) e sai
	-- pela portinhola do outro corredor, na ponta longe de quem está lá.
	SwitchCorridorDelay = 2.5,
	TunnelTravelTime = 2,
	TunnelRunMultiplier = 1.15,
	-- Tamanho do modelo (1 = o original, ~3,2 studs de altura).
	ModelScale = 1.35,
	ContactRadius = 3.4,
	JumpClearance = 2.9,
	ContactCooldown = 1.5,
	-- Depois de empurrar alguém ele senta e abana o rabo por esse tempo.
	ContactPause = 1.6,
	PushSpeed = 58,
	PushLift = 24,
	BarkIntervalPatrol = NumberRange.new(6, 13),
	BarkIntervalChase = NumberRange.new(2.2, 4.5),
	-- Latidos de verdade (~3 s, vários "au" seguidos). Um latido não começa
	-- enquanto o anterior ainda toca; o tom varia um pouco para não repetir.
	BarkSoundIds = table.freeze({ "rbxassetid://124017572768108" }),
	BarkPitch = NumberRange.new(0.94, 1.08),
	FunnySoundIds = table.freeze({ "rbxasset://sounds/oof.ogg", "rbxasset://sounds/ouch.ogg" }),
	FootstepSoundId = "rbxasset://sounds/action_footsteps_plastic.mp3",
	-- Batida grave, sem direção, tocada só para quem está sendo perseguido.
	TensionSoundId = "rbxasset://sounds/action_jump_land.mp3",
	-- Portinhola do túnel batendo quando ele entra ou sai.
	DoorSoundId = "rbxasset://sounds/action_jump_land.mp3",
})

-- Tocas Seguras: protegem do Barão (não do Puffador) por MaxStay segundos;
-- depois o ocupante é empurrado para fora e fica Cooldown segundos sem
-- poder usar nenhuma Toca.
local Toca: TocaConfig = table.freeze({
	MaxStay = 8,
	WarningAt = 3,
	Cooldown = 10,
	EjectSpeed = 34,
})

local GameConfig = {} :: GameConfig

GameConfig.GameName = "BlocoPuff"
GameConfig.MinimumPlayers = 2
GameConfig.MaximumPlayers = 12
GameConfig.LobbyCountdown = 20
GameConfig.RoundDuration = 210
-- Encerramento: tempo para ler o resultado antes de voltar ao lobby.
GameConfig.IntermissionDuration = 12

-- Tempos reduzidos usados apenas quando RunService:IsStudio() for verdadeiro.
GameConfig.StudioLobbyCountdown = 5
GameConfig.StudioRoundDuration = 60
GameConfig.StudioIntermissionDuration = 5

GameConfig.Arena = Arena
GameConfig.Building = Building
GameConfig.Palette = Palette
GameConfig.Puffador = Puffador
GameConfig.EliminationZone = EliminationZone
GameConfig.Music = Music
GameConfig.SecretRoom = SecretRoom
GameConfig.Knockback = Knockback
GameConfig.SecondChance = SecondChance
GameConfig.FinalChaos = FinalChaos
GameConfig.Telemetry = Telemetry
GameConfig.Barao = Barao
GameConfig.Toca = Toca

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
