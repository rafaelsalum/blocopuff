--!strict

-- O Casarão: o lobby principal, um anexo grande a leste da galeria da arena
-- (ligado a ela por portas). Espaço para andar à vontade e visitar Puffdex,
-- Puff Machine, desafios, treino, o Barão e a loja. Medidas em studs.

-- Portas duplas nos arcos do Casarão (Fase 5C.1). Abrem sozinhas quando
-- alguém chega perto (só no cliente: não seguram ninguém) com rangido e
-- batem ao fechar. Sons da Creator Store (gratuitos).
export type DoorConfig = {
	Tag: string,
	-- No Model de cada folha: CFrame da dobradiça (eixo vertical).
	HingeAttribute: string,
	-- No Model da porta: normal da parede (Vector3).
	NormalAttribute: string,
	-- No Model de cada folha: quantas peças ela tem (o cliente espera todas
	-- chegarem antes de animar).
	PartCountAttribute: string,
	-- Alguém a esta distância horizontal (studs) abre a porta.
	OpenRadius: number,
	-- Ninguém perto por este tempo (s): fecha.
	CloseDelay: number,
	OpenAngle: number,
	OpenTime: number,
	CloseTime: number,
	Thickness: number,
	Color: Color3,
	PanelColor: Color3,
	KnobColor: Color3,
	CreakSoundId: string,
	CreakSpeed: number,
	SlamSoundId: string,
	SlamSpeed: number,
	SoundVolume: number,
	SoundRange: number,
}

export type MansionConfig = {
	Width: number,
	Depth: number,
	CeilingHeight: number,
	-- Distância das paredes norte/sul até as divisórias das alas.
	WingDepth: number,
	-- Largura do Salão Principal (a partir da parede da galeria).
	HallWidth: number,
	ArchWidth: number,
	ArchHeight: number,
	PartitionThickness: number,
	-- Portas na parede entre a galeria e o Salão (posição Z em relação ao
	-- centro). Coincidem com os vãos entre os sofás da galeria.
	PassageOffsets: { number },
	-- Largura e altura das portas da galeria (abaixo do Hall da Fama).
	PassageSize: Vector2,
	FloorColor: Color3,
	HallRugColor: Color3,
	WallpaperColors: { [string]: Color3 },
	CeilingColor: Color3,
	ChandelierRange: number,
	ChandelierBrightness: number,
	Door: DoorConfig,
}

local MansionConfig: MansionConfig = {
	Width = 110,
	Depth = 130,
	CeilingHeight = 24,
	WingDepth = 35,
	HallWidth = 60,
	ArchWidth = 16,
	ArchHeight = 13,
	PartitionThickness = 1.5,
	PassageOffsets = table.freeze({ -22.5, 0, 22.5 }),
	PassageSize = Vector2.new(8, 10.5),
	FloorColor = Color3.fromRGB(140, 96, 60),
	HallRugColor = Color3.fromRGB(122, 34, 40),
	WallpaperColors = table.freeze({
		GrandHall = Color3.fromRGB(96, 52, 60),
		Collection = Color3.fromRGB(52, 60, 104),
		Garden = Color3.fromRGB(58, 96, 72),
		Meeting = Color3.fromRGB(104, 80, 52),
		Training = Color3.fromRGB(56, 84, 96),
	}),
	CeilingColor = Color3.fromRGB(214, 200, 176),
	ChandelierRange = 26,
	ChandelierBrightness = 0.8,
	Door = table.freeze({
		Tag = "MansionDoor",
		HingeAttribute = "DoorHinge",
		NormalAttribute = "DoorNormal",
		PartCountAttribute = "DoorParts",
		OpenRadius = 10,
		CloseDelay = 1.2,
		OpenAngle = 95,
		OpenTime = 0.45,
		CloseTime = 0.55,
		Thickness = 0.35,
		Color = Color3.fromRGB(92, 56, 34),
		PanelColor = Color3.fromRGB(66, 38, 22),
		KnobColor = Color3.fromRGB(255, 209, 102),
		CreakSoundId = "rbxassetid://9120839174",
		CreakSpeed = 1,
		SlamSoundId = "rbxassetid://111763202035471",
		SlamSpeed = 1,
		SoundVolume = 0.8,
		SoundRange = 60,
	}),
}

return table.freeze(MansionConfig)
