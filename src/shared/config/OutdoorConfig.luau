--!strict

-- Lado de fora do Casarão: chão de terreno com morros, um lago, montanhas
-- em volta e a floresta de pinheiros, como um castelo no meio das Terras
-- Altas, e o céu que segue a hora de Brasília (dia, tarde e noite). Só
-- números (sem tipos do Roblox), para os testes do Lune carregarem direto.

-- Cor em RGB de 0 a 255.
export type Rgb = { number }

export type MountainConfig = {
	-- Centro do anel de montanhas (e do mapa todo).
	CenterX: number,
	CenterZ: number,
	-- O chão começa a subir aqui e chega aos picos em OuterRadius.
	InnerRadius: number,
	OuterRadius: number,
	PeakHeight: number,
}

export type LakeConfig = {
	X: number,
	Z: number,
	Radius: number,
	WaterY: number,
	Depth: number,
	-- Quanto a margem foge do círculo (fração do raio).
	ShoreWobble: number,
}

export type TerrainConfig = {
	-- Altura do chão em volta do Casarão (logo abaixo do porão da ala leste).
	GroundY: number,
	-- O terreno cobre um quadrado de 2 x HalfExtent em volta do centro das
	-- montanhas.
	HalfExtent: number,
	-- Tamanho do voxel (o Roblox só aceita 4).
	Resolution: number,
	-- Espessura do terreno embaixo da superfície (ninguém vê por baixo).
	SkinDepth: number,
	-- Morros suaves: altura máxima e largura típica.
	HillAmplitude: number,
	HillScale: number,
	Mountains: MountainConfig,
	Lake: LakeConfig,
	-- Colunas de voxels escritas por vez (o servidor respira entre elas).
	ChunkCells: number,
}

export type ForestConfig = {
	Seed: number,
	-- Uma árvore no máximo por célula da grade (com sorteio dentro dela).
	CellSize: number,
	-- Chance de árvore numa célula perto do Casarão e nas encostas.
	NearChance: number,
	FarChance: number,
	-- Distância (do centro do mapa) em que a floresta vira encosta rala.
	FarRadius: number,
	-- Largura do gramado sem árvores em volta de cada construção.
	ClearingMargin: number,
	-- Folga sem árvore dos dois lados dos caminhos de pedra.
	PathMargin: number,
	MinScale: number,
	MaxScale: number,
	-- Inclinação máxima (subida por stud) e altura máxima acima do chão.
	MaxSlope: number,
	TreeLine: number,
	-- Chance de uma árvore seca no lugar de um pinheiro.
	DeadChance: number,
	-- Só as árvores até esta distância do Casarão fazem sombra.
	ShadowRadius: number,
}

-- Postes de lampião antigos, de ferro, em volta das construções.
export type LampConfig = {
	-- Distância entre postes e afastamento das paredes.
	Spacing: number,
	WallOffset: number,
	PostHeight: number,
	LightRange: number,
	LightBrightness: number,
	LightColor: Rgb,
	-- Acendem ao entardecer e apagam de manhã (hora de Brasília).
	OnHour: number,
	OffHour: number,
}

-- Caminho de pedra do portão do jardim da Torre até a margem do lago, com
-- lampiões ao longo dele.
export type GardenPathConfig = {
	-- Pontos (x, z) depois do portão, em ordem, até a margem.
	Waypoints: { { number } },
	HalfWidth: number,
	-- Um lampião a cada LampSpacing studs, alternando os lados, a LampOffset
	-- do meio do caminho.
	LampSpacing: number,
	LampOffset: number,
}

-- Limite do mapa: muralha invisível em volta, antes das montanhas, e uma
-- cerca invisível em volta da Ala do Assassinato (ninguém de fora entra na
-- partida).
export type BoundsConfig = {
	Radius: number,
	Segments: number,
	-- A muralha vai de Depth abaixo do chão até Height acima dele.
	Depth: number,
	Height: number,
	WingMargin: number,
	WingFenceHeight: number,
}

-- Um momento do dia: o céu passa de um para o outro aos poucos.
export type LightKey = {
	hour: number,
	brightness: number,
	outdoorAmbient: Rgb,
	atmosphereColor: Rgb,
	atmosphereDecay: Rgb,
	atmosphereDensity: number,
	atmosphereHaze: number,
	atmosphereGlare: number,
}

export type DayCycleConfig = {
	-- Brasília (sem horário de verão desde 2019).
	UtcOffsetHours: number,
	UpdateSeconds: number,
	Keys: { LightKey },
}

export type OutdoorConfig = {
	Terrain: TerrainConfig,
	Forest: ForestConfig,
	Lamps: LampConfig,
	GardenPath: GardenPathConfig,
	-- Caminho da escadaria da porta principal até a margem do lago (Fase 5H.2):
	-- os pontos são depois do pé da escadaria.
	FrontPath: GardenPathConfig,
	Bounds: BoundsConfig,
	DayCycle: DayCycleConfig,
}

local GROUND_Y = 118.6

local OutdoorConfig: OutdoorConfig = {
	Terrain = table.freeze({
		GroundY = GROUND_Y,
		HalfExtent = 1150,
		Resolution = 4,
		SkinDepth = 12,
		HillAmplitude = 9,
		HillScale = 260,
		Mountains = table.freeze({
			CenterX = -20,
			CenterZ = 40,
			InnerRadius = 760,
			OuterRadius = 1080,
			PeakHeight = 330,
		}),
		-- A leste do Casarão, visto das janelas da ala leste e da Torre.
		Lake = table.freeze({
			X = 480,
			Z = 250,
			Radius = 150,
			WaterY = GROUND_Y - 3.5,
			Depth = 18,
			ShoreWobble = 0.18,
		}),
		ChunkCells = 32,
	}),
	Forest = table.freeze({
		Seed = 1912,
		CellSize = 30,
		NearChance = 0.62,
		FarChance = 0.16,
		FarRadius = 760,
		ClearingMargin = 45,
		PathMargin = 7,
		MinScale = 1.7,
		MaxScale = 2.6,
		MaxSlope = 0.75,
		TreeLine = 190,
		DeadChance = 0.04,
		ShadowRadius = 450,
	}),
	Lamps = table.freeze({
		Spacing = 30,
		WallOffset = 12,
		PostHeight = 11,
		LightRange = 30,
		LightBrightness = 1.4,
		LightColor = { 255, 168, 92 },
		OnHour = 17.6,
		OffHour = 6.4,
	}),
	GardenPath = table.freeze({
		Waypoints = table.freeze({
			table.freeze({ 330, -120 }),
			table.freeze({ 400, 20 }),
			table.freeze({ 425, 98 }),
		}),
		HalfWidth = 3.5,
		LampSpacing = 32,
		LampOffset = 6,
	}),
	FrontPath = table.freeze({
		Waypoints = table.freeze({
			table.freeze({ 125, 128 }),
			table.freeze({ 215, 152 }),
			table.freeze({ 330, 142 }),
			table.freeze({ 425, 98 }),
		}),
		HalfWidth = 3.5,
		LampSpacing = 32,
		LampOffset = 6,
	}),
	-- Dentro do anel das montanhas (que começam a subir a 760 do centro).
	Bounds = table.freeze({
		Radius = 700,
		Segments = 72,
		Depth = 120,
		Height = 400,
		WingMargin = 4,
		WingFenceHeight = 60,
	}),
	DayCycle = table.freeze({
		UtcOffsetHours = -3,
		UpdateSeconds = 5,
		Keys = table.freeze({
			-- Noite: luar azulado, claro o bastante para ver o mapa.
			table.freeze({
				hour = 0,
				brightness = 1.2,
				outdoorAmbient = { 140, 150, 185 },
				atmosphereColor = { 74, 86, 118 },
				atmosphereDecay = { 50, 60, 92 },
				atmosphereDensity = 0.28,
				atmosphereHaze = 0.6,
				atmosphereGlare = 0,
			}),
			table.freeze({
				hour = 4.8,
				brightness = 1.2,
				outdoorAmbient = { 140, 150, 185 },
				atmosphereColor = { 74, 86, 118 },
				atmosphereDecay = { 50, 60, 92 },
				atmosphereDensity = 0.28,
				atmosphereHaze = 0.6,
				atmosphereGlare = 0,
			}),
			-- Amanhecer rosado, com neblina no vale.
			table.freeze({
				hour = 6.2,
				brightness = 1,
				outdoorAmbient = { 118, 98, 100 },
				atmosphereColor = { 214, 172, 158 },
				atmosphereDecay = { 120, 96, 110 },
				atmosphereDensity = 0.4,
				atmosphereHaze = 1.6,
				atmosphereGlare = 0.4,
			}),
			-- Dia claro das Terras Altas.
			table.freeze({
				hour = 8.5,
				brightness = 1.8,
				outdoorAmbient = { 132, 132, 136 },
				atmosphereColor = { 199, 205, 212 },
				atmosphereDecay = { 106, 116, 132 },
				atmosphereDensity = 0.3,
				atmosphereHaze = 0.6,
				atmosphereGlare = 0,
			}),
			table.freeze({
				hour = 15.5,
				brightness = 1.8,
				outdoorAmbient = { 132, 132, 136 },
				atmosphereColor = { 199, 205, 212 },
				atmosphereDecay = { 106, 116, 132 },
				atmosphereDensity = 0.3,
				atmosphereHaze = 0.6,
				atmosphereGlare = 0,
			}),
			-- Tarde dourada.
			table.freeze({
				hour = 17.2,
				brightness = 1.5,
				outdoorAmbient = { 150, 118, 92 },
				atmosphereColor = { 232, 190, 148 },
				atmosphereDecay = { 150, 104, 82 },
				atmosphereDensity = 0.33,
				atmosphereHaze = 1.4,
				atmosphereGlare = 0.6,
			}),
			-- Pôr do sol.
			table.freeze({
				hour = 18.3,
				brightness = 0.8,
				outdoorAmbient = { 104, 76, 88 },
				atmosphereColor = { 196, 118, 104 },
				atmosphereDecay = { 88, 58, 82 },
				atmosphereDensity = 0.36,
				atmosphereHaze = 1.8,
				atmosphereGlare = 0.8,
			}),
			table.freeze({
				hour = 19.4,
				brightness = 1.2,
				outdoorAmbient = { 140, 150, 185 },
				atmosphereColor = { 74, 86, 118 },
				atmosphereDecay = { 50, 60, 92 },
				atmosphereDensity = 0.28,
				atmosphereHaze = 0.6,
				atmosphereGlare = 0,
			}),
		}),
	}),
}

return table.freeze(OutdoorConfig)
