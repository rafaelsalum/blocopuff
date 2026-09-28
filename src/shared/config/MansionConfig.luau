--!strict

-- O Casarão: o lobby principal, um anexo grande a leste da galeria da arena
-- (ligado a ela por portas). Espaço para andar à vontade e visitar Puffdex,
-- Puff Machine, desafios, treino, o Barão e a loja. Medidas em studs.

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
}

return table.freeze(MansionConfig)
