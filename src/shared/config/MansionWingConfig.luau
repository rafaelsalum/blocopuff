--!strict

-- Ala leste do Casarão (Fase 5C.1, parte 2): Biblioteca (norte), Hall da
-- Escadaria (meio) e Sala de Música (sul), com o Sótão em cima e o Porão
-- embaixo, ligados por escadas de verdade no Hall da Escadaria. Medidas em
-- studs; as profundidades são ao longo de Z, a partir da parede norte.

export type PianoConfig = {
	-- Nota Dó (C4); as outras teclas mudam a velocidade (meio tom = 2^(1/12)).
	NoteSoundId: string,
	Volume: number,
	-- Intervalo mínimo (s) entre notas da mesma tecla e do mesmo jogador.
	KeyCooldown: number,
	PlayerCooldown: number,
	Tag: string,
	SemitoneAttribute: string,
}

export type AtticConfig = {
	LanternRange: number,
	LanternBrightness: number,
	LanternColor: Color3,
	-- Escurecimento da tela enquanto se está no Sótão.
	DarkBrightness: number,
	DarkTint: Color3,
	FadeTime: number,
}

export type MansionWingConfig = {
	Width: number,
	LibraryDepth: number,
	StairHallDepth: number,
	AtticHeight: number,
	CellarHeight: number,
	-- Escadas: largura, onde começam (a partir da parede oeste da ala) e
	-- quantos degraus.
	StairWidth: number,
	StairStartInset: number,
	StairEndInset: number,
	UpSteps: number,
	DownSteps: number,
	RailHeight: number,
	-- Portas da ala (menores que os arcos dos salões).
	DoorSize: Vector2,
	-- Posição Z das portas na parede leste do Casarão, em relação ao centro.
	LibraryDoorOffset: number,
	StairHallDoorOffset: number,
	-- Portas internas da ala, a partir da parede oeste.
	InnerDoorInset: number,
	WallpaperColors: { [string]: Color3 },
	AtticColor: Color3,
	CellarColor: Color3,
	CellarFloorColor: Color3,
	CellarDripSoundId: string,
	Piano: PianoConfig,
	Attic: AtticConfig,
}

local MansionWingConfig: MansionWingConfig = {
	Width = 44,
	LibraryDepth = 40,
	StairHallDepth = 50,
	AtticHeight = 14,
	CellarHeight = 15,
	StairWidth = 6,
	StairStartInset = 10,
	StairEndInset = 5,
	UpSteps = 20,
	DownSteps = 12,
	RailHeight = 3.4,
	DoorSize = Vector2.new(8, 11),
	-- Longe da Puff Machine (Salão da Coleção) e da loja (Jardim).
	LibraryDoorOffset = -55,
	StairHallDoorOffset = -8,
	InnerDoorInset = 5,
	WallpaperColors = table.freeze({
		Library = Color3.fromRGB(62, 46, 36),
		StairHall = Color3.fromRGB(88, 60, 70),
		Music = Color3.fromRGB(70, 48, 96),
	}),
	AtticColor = Color3.fromRGB(110, 86, 64),
	CellarColor = Color3.fromRGB(96, 88, 82),
	CellarFloorColor = Color3.fromRGB(74, 70, 66),
	CellarDripSoundId = "rbxassetid://9126190654",
	Piano = table.freeze({
		NoteSoundId = "rbxassetid://96243649310055",
		Volume = 0.8,
		KeyCooldown = 0.15,
		PlayerCooldown = 0.08,
		Tag = "PianoKey",
		SemitoneAttribute = "Semitone",
	}),
	Attic = table.freeze({
		LanternRange = 18,
		LanternBrightness = 2.2,
		LanternColor = Color3.fromRGB(255, 196, 120),
		DarkBrightness = -0.18,
		DarkTint = Color3.fromRGB(200, 205, 230),
		FadeTime = 0.6,
	}),
}

return table.freeze(MansionWingConfig)
