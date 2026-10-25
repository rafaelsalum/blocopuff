--!strict

-- Trilha sonora por clima (MusicMood): cada clima tem uma lista de faixas
-- que se revezam (nunca a mesma duas vezes seguidas) e um volume. Todas as
-- faixas são da Creator Store (APM Music, DistroKid e Pro Sound Effects,
-- liberadas para uso no Roblox). Troque os ids aqui à vontade.

export type MoodTracks = {
	Tracks: { string },
	Volume: number,
}

export type MusicConfig = {
	-- Tempo da troca suave entre faixas e entre climas.
	FadeTime: number,
	-- De quanto em quanto tempo o cliente confere onde o jogador está.
	CheckPeriod: number,
	-- Altura do raio que procura um teto em cima do jogador (dentro x fora).
	RoofProbe: number,
	Moods: { [string]: MoodTracks },
	Ambience: { [string]: MoodTracks },
	Stings: { [string]: MoodTracks },
	-- Quanto a música abaixa enquanto a vinheta do fim toca.
	StingDuck: number,
}

local function mood(tracks: { string }, volume: number): MoodTracks
	return table.freeze({ Tracks = table.freeze(tracks), Volume = volume })
end

local MusicConfig: MusicConfig = {
	FadeTime = 2,
	CheckPeriod = 1,
	RoofProbe = 250,
	Moods = table.freeze({
		-- Casarão de dia: valsa mágica, princesa encantada e o tema antigo.
		LobbyDay = mood({ "rbxassetid://1848134067", "rbxassetid://1848133079", "rbxassetid://1846613120" }, 0.07),
		-- Casarão à noite: caixinha de música misteriosa.
		LobbyNight = mood({ "rbxassetid://9040115499", "rbxassetid://1848133094", "rbxassetid://1839911004" }, 0.07),
		-- Floresta de dia: leve e natural.
		OutdoorDay = mood({ "rbxassetid://72753578325816", "rbxassetid://1838926651" }, 0.06),
		-- Floresta à noite: flauta calma.
		OutdoorNight = mood({ "rbxassetid://81454116918887", "rbxassetid://9040115499" }, 0.06),
		-- Dentro da Torre do Relógio: caixinha de música assombrada.
		Tower = mood({ "rbxassetid://1839911004", "rbxassetid://9040115499" }, 0.07),
		-- Arena: perseguição cômica com cordas em pizzicato.
		Arena = mood({ "rbxassetid://1836289689", "rbxassetid://9039543928", "rbxassetid://1841134066" }, 0.05),
		-- Caos Final / Tempestade: orquestra épica.
		Chaos = mood({ "rbxassetid://9043371844", "rbxassetid://1838626086" }, 0.06),
		-- Corrida da Torre: corrida divertida e épica.
		Race = mood({ "rbxassetid://1848134687", "rbxassetid://1846428560" }, 0.05),
		-- Assassinato no Casarão: suspense de quem anda escondido.
		Mystery = mood({ "rbxassetid://9039418011", "rbxassetid://1839911004" }, 0.05),
		Silent = mood({}, 0),
	}),
	Ambience = table.freeze({
		Birds = mood({ "rbxassetid://9113444360" }, 0.12),
		Crickets = mood({ "rbxassetid://9112764573" }, 0.1),
	}),
	Stings = table.freeze({
		Win = mood({ "rbxassetid://9039637427" }, 0.4),
		End = mood({ "rbxassetid://9045808811" }, 0.35),
	}),
	StingDuck = 0.25,
}

return table.freeze(MusicConfig)
