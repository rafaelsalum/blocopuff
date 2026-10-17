--!strict

-- Ambiente do Casarão (Fase 5C.4, parte 2): tudo roda no cliente de cada um,
-- sem custo de rede.
--   * Retratos da família Puff com olhos que seguem quem passa (e piscam).
--   * Lustres que balançam e tilintam quando uma porta bate perto.
--   * O relógio da torre (Sótão) toca de tantos em tantos minutos, no mesmo
--     instante para todo mundo (horário do servidor).
-- Sons: só da biblioteca licenciada da Roblox (ProSoundEffects), que não
-- some nem tem problema de direitos.

export type Portrait = {
	id: string,
	-- Nome na plaquinha (texto em português; o inglês fica em i18n/en).
	name: string,
	-- Cômodo (MansionLayout / MansionWingLayout, ou "Attic"), parede ("N",
	-- "S", "W", "E": a parede do lado de menor Z, maior Z, menor X, maior X)
	-- e a distância (studs) do começo da parede até o centro do retrato.
	room: string,
	wall: "N" | "S" | "W" | "E",
	offset: number,
	-- Estilo do desenho (MansionPortraitArt).
	style: string,
	body: Color3,
	background: Color3,
}

export type ChandelierConfig = {
	Tag: string,
	-- Até onde a batida de uma porta mexe um lustre (studs, no plano).
	Radius: number,
	-- Balanço máximo (graus) bem do lado da porta; cai devagar com a
	-- distância (quadrado), para os lustres do cômodo todo mexerem.
	MaxAngle: number,
	-- Tempo (s) até o balanço quase parar e período de uma ida e volta.
	Damping: number,
	Period: number,
	SoundId: string,
	SoundVolume: number,
	-- Um tilintar por lustre a cada tantos segundos, no máximo.
	SoundCooldown: number,
}

export type ClockConfig = {
	-- De quantos em quantos segundos (horário do servidor) o relógio toca.
	Period: number,
	SoundId: string,
	Volume: number,
	RollOffMin: number,
	RollOffMax: number,
	-- Modelo do relógio da torre (MysteryProps).
	ModelName: string,
}

export type PortraitTuning = {
	Tag: string,
	IdAttribute: string,
	-- Distância (studs) em que os olhos começam a seguir.
	FollowDistance: number,
	-- Quanto a pupila anda dentro do olho (fração do raio do olho).
	PupilTravel: number,
	FollowRate: number,
	BlinkMin: number,
	BlinkMax: number,
	BlinkTime: number,
	-- Base do retrato acima do piso (acima do rodameio) e tamanho da tela.
	Bottom: number,
	CanvasSize: Vector2,
}

local MansionAmbienceConfig = {}

local function portrait(id: string, name: string, room: string, wall: "N" | "S" | "W" | "E", offset: number, style: string, body: Color3, background: Color3): Portrait
	return table.freeze({ id = id, name = name, room = room, wall = wall, offset = offset, style = style, body = body, background = background })
end

-- Galeria da família Puff (lugares livres conferidos no Studio).
MansionAmbienceConfig.Portraits = table.freeze({
	portrait("vovo", "Vovô Puff", "GrandHall", "S", 12, "Grandpa", Color3.fromRGB(150, 200, 255), Color3.fromRGB(150, 78, 100)),
	portrait("vovoa", "Vovó Puff", "GrandHall", "S", 55, "Grandma", Color3.fromRGB(255, 182, 214), Color3.fromRGB(110, 104, 190)),
	portrait("bisavo", "Bisavô Explorador", "Library", "W", 31, "Explorer", Color3.fromRGB(255, 214, 140), Color3.fromRGB(70, 132, 104)),
	portrait("tia", "Tia Puff, a Cantora", "Music", "S", 9, "Singer", Color3.fromRGB(196, 150, 255), Color3.fromRGB(170, 80, 120)),
	portrait("barao", "Barão Filhote", "StairHall", "E", 24, "Puppy", Color3.fromRGB(176, 110, 60), Color3.fromRGB(96, 150, 196)),
	portrait("fantasma", "Primo Fantasma", "Attic", "W", 60, "Ghost", Color3.fromRGB(236, 242, 255), Color3.fromRGB(70, 64, 120)),
} :: { Portrait })

MansionAmbienceConfig.Portrait = table.freeze({
	Tag = "MansionPortrait",
	IdAttribute = "PortraitId",
	FollowDistance = 36,
	PupilTravel = 0.32,
	FollowRate = 8,
	BlinkMin = 2.5,
	BlinkMax = 6,
	BlinkTime = 0.14,
	Bottom = 5.4,
	CanvasSize = Vector2.new(3.6, 4.6),
}) :: PortraitTuning

MansionAmbienceConfig.Chandelier = table.freeze({
	Tag = "MansionChandelier",
	Radius = 40,
	MaxAngle = 11,
	Damping = 2.2,
	Period = 2.4,
	-- "Chandelier Shakes Tinkles Glass Rattle 1" (ProSoundEffects).
	SoundId = "rbxassetid://9113782484",
	SoundVolume = 0.35,
	SoundCooldown = 4,
}) :: ChandelierConfig

MansionAmbienceConfig.Clock = table.freeze({
	Period = 300,
	-- "Clock Chimes 1": melodia e badaladas (ProSoundEffects).
	SoundId = "rbxassetid://9113816347",
	Volume = 0.7,
	RollOffMin = 18,
	RollOffMax = 220,
	ModelName = "MysteryTowerClock",
}) :: ClockConfig

return table.freeze(MansionAmbienceConfig)
