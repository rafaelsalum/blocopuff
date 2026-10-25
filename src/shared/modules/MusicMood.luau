--!strict

-- Regras puras da trilha sonora (sem serviços, para rodar no Lune): qual
-- clima de música toca para o jogador agora, qual som de ambiente entra por
-- baixo, qual faixa da lista vem depois e qual vinheta toca no fim da
-- partida. Quem aplica é o MusicController no cliente.

-- Onde o jogador está: dentro do Casarão (ou da Arena), do lado de fora ou
-- dentro da Torre do Relógio.
export type Place = "Indoors" | "Outdoors" | "Tower"

export type Mood =
	"LobbyDay"
	| "LobbyNight"
	| "OutdoorDay"
	| "OutdoorNight"
	| "Tower"
	| "Arena"
	| "Chaos"
	| "Race"
	| "Mystery"
	| "Silent"

export type Ambience = "Birds" | "Crickets" | "None"

export type Sting = "Win" | "End"

export type Input = {
	-- RoundState e RoundMode do contêiner de estado (podem faltar).
	roundState: string?,
	roundMode: string?,
	-- Caos Final / Tempestade ligado.
	finalChaos: boolean,
	-- Escalado para a partida e ainda não eliminado.
	competing: boolean,
	-- Últimos segundos do Assassinato para quem está nele, vivo ou
	-- assistindo (a música de tensão do MysteryFinalMusic assume sozinha).
	mysteryFinal: boolean,
	place: Place,
	-- Hora do céu (Lighting.ClockTime) e a faixa da noite.
	clock: number,
	nightFrom: number,
	nightUntil: number,
}

local MusicMood = {}

-- Noite quando a hora passou de `from` ou ainda não chegou em `untilHour`
-- (a noite atravessa a meia-noite).
function MusicMood.isNight(clock: number, from: number, untilHour: number): boolean
	return clock >= from or clock < untilHour
end

local function matchMood(input: Input): Mood
	if input.roundMode == "Mystery" then
		return "Mystery"
	elseif input.roundMode == "Race" then
		return "Race"
	end
	return if input.finalChaos then "Chaos" else "Arena"
end

-- O clima da música para o jogador agora.
function MusicMood.pick(input: Input): Mood
	if input.mysteryFinal then
		return "Silent"
	end
	local inMatch = input.roundState == "Countdown" or input.roundState == "Active" or input.roundState == "Ending"
	if input.competing and inMatch then
		return matchMood(input)
	end
	local night = MusicMood.isNight(input.clock, input.nightFrom, input.nightUntil)
	if input.place == "Tower" then
		return "Tower"
	elseif input.place == "Outdoors" then
		return if night then "OutdoorNight" else "OutdoorDay"
	end
	return if night then "LobbyNight" else "LobbyDay"
end

-- Som de ambiente por baixo da música: passarinhos de dia e grilos à noite,
-- só do lado de fora.
function MusicMood.ambienceFor(mood: Mood): Ambience
	if mood == "OutdoorDay" then
		return "Birds"
	elseif mood == "OutdoorNight" then
		return "Crickets"
	end
	return "None"
end

-- Próxima faixa de uma lista de `count` faixas: sorteada com `roll` em
-- [0, 1), nunca repetindo a anterior quando há mais de uma.
function MusicMood.nextIndex(count: number, previous: number?, roll: number): number
	if count <= 1 then
		return 1
	end
	if previous == nil or previous < 1 or previous > count then
		return math.clamp(math.floor(roll * count) + 1, 1, count)
	end
	-- Sorteia entre as outras count - 1 e pula a anterior.
	local index = math.clamp(math.floor(roll * (count - 1)) + 1, 1, count - 1)
	return if index >= previous then index + 1 else index
end

-- Vinheta do fim da partida para quem jogou: vitória para o vencedor,
-- encerramento para os outros, nada para quem só estava no lobby.
function MusicMood.stingFor(played: boolean, winnerUserId: number?, userId: number): Sting?
	if not played then
		return nil
	end
	return if winnerUserId == userId then "Win" else "End"
end

return table.freeze(MusicMood)
