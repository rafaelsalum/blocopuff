--!strict

-- Mistério no Casarão (Fase 5D.3, docs/FASE_5D_MODOS_DO_CASARAO.md): um
-- Fantasma disfarçado assusta os Moradores; o Detetive tem o único Puffador.
-- Números iniciais para o playtest.

export type WingConfig = {
	-- Centro do chão da Ala do Mistério (longe da Arena, do Casarão e da Torre).
	Center: Vector3,
	-- Grade de cômodos (colunas x linhas) e o tamanho de cada um.
	Columns: number,
	Rows: number,
	RoomSize: number,
	WallHeight: number,
	DoorWidth: number,
	DoorHeight: number,
	-- Luz fraca em cada cômodo (clima de mistério).
	LightBrightness: number,
	LightRange: number,
}

export type MysteryModeConfig = {
	Wing: WingConfig,
	Duration: number,
	-- Humanos mínimos para o Mistério rodar (Fantasma e Detetive são sempre
	-- humanos; os bots completam como Moradores). Com 2, o segredo é fraco,
	-- mas o voto na porta roxa precisa valer para quem joga em dupla.
	MinHumans: number,
	-- Tempo (s) do começo sem sustos, para todos se espalharem.
	StartGrace: number,
	-- Susto: alcance (studs) e recarga (s).
	ScareRange: number,
	ScareCooldown: number,
	-- Lençol Voador: recarga, velocidade, alcance e raio de acerto.
	SheetCooldown: number,
	SheetSpeed: number,
	SheetRange: number,
	SheetHitRadius: number,
	-- Detetive que acerta um Morador: fica parado (s) e derruba o Puffador.
	MisfireStun: number,
	-- Puffador caído: raio para pegar.
	PickupRadius: number,
	-- Moedas do Barão.
	CoinsPerRound: number,
	MaxCoinsPerPlayer: number,
	CoinsPerTicket: number,
	MaxCoinTickets: number,
	CoinPickupRadius: number,
	-- Só no Studio: com um jogador só, o papel dele alterna entre Fantasma e
	-- Detetive a cada partida (e um bot faz o Fantasma), para dar para testar.
	StudioSoloTest: boolean,
}

local MysteryModeConfig: MysteryModeConfig = {
	Wing = table.freeze({
		Center = Vector3.new(-420, 100, 420),
		Columns = 3,
		Rows = 3,
		RoomSize = 40,
		WallHeight = 14,
		DoorWidth = 8,
		DoorHeight = 10,
		LightBrightness = 1.4,
		LightRange = 32,
	}),
	Duration = 180,
	MinHumans = 2,
	StartGrace = 10,
	ScareRange = 6,
	ScareCooldown = 1,
	SheetCooldown = 4,
	SheetSpeed = 70,
	SheetRange = 90,
	SheetHitRadius = 3.5,
	MisfireStun = 3,
	PickupRadius = 5,
	CoinsPerRound = 40,
	MaxCoinsPerPlayer = 10,
	CoinsPerTicket = 5,
	MaxCoinTickets = 2,
	CoinPickupRadius = 4,
	StudioSoloTest = true,
}

return table.freeze(MysteryModeConfig)
