--!strict

-- Vida no Casarão (Fase 5C.4, parte 1):
--   * Fantasminha Puff: de tempos em tempos aparece flutuando num cômodo
--     aleatório, com um risinho e um aviso discreto para quem está no
--     lobby. O primeiro a encostar nele ganha tickets (limite por dia).
--   * Barão passeando: o Barão do Jardim sai da caminha de vez em quando,
--     dá uma volta pelos salões e volta a dormir. O carinho funciona onde
--     ele estiver, com uma pequena chance de presente (limite por dia).

export type GhostConfig = {
	-- Intervalo (s) entre um Fantasminha e outro (sorteado no intervalo).
	MinInterval: number,
	MaxInterval: number,
	-- Primeiro Fantasminha depois que o servidor sobe (s).
	FirstDelay: number,
	-- Quanto tempo ele espera alguém antes de sumir (s).
	Lifetime: number,
	Tickets: number,
	DailyLimit: number,
	-- Distância (studs) do centro dele até a raiz de quem encosta.
	TouchRadius: number,
	-- Altura do centro acima do piso.
	HoverHeight: number,
	-- Cômodos onde ele aparece (ids das páginas do Álbum, RelicCatalog).
	Rooms: { string },
	Tag: string,
	-- Atributos do modelo: centro de onde ele flutua (CFrame) e o cômodo.
	BaseAttribute: string,
	RoomAttribute: string,
	-- Som do risinho ("" = sem som até escolhermos um).
	GiggleSoundId: string,
	ClaimSoundId: string,
}

export type BaraoWalkConfig = {
	-- Tempo dormindo (s) entre um passeio e outro (sorteado no intervalo).
	MinRest: number,
	MaxRest: number,
	FirstDelay: number,
	-- Velocidade do passeio (studs/s): um trote calmo.
	Speed: number,
	GiftChance: number,
	GiftTickets: number,
	GiftDailyLimit: number,
	-- Atributos do modelo: início do passeio (horário do servidor, 0 =
	-- dormindo) e tempo de passeio parado no carinho (−1 = andando).
	StartAttribute: string,
	PauseAttribute: string,
}

local MansionLifeConfig = {}

MansionLifeConfig.Ghost = table.freeze({
	MinInterval = 180,
	MaxInterval = 300,
	FirstDelay = 90,
	Lifetime = 45,
	Tickets = 2,
	DailyLimit = 5,
	TouchRadius = 4.5,
	HoverHeight = 3.2,
	Rooms = table.freeze({ "GrandHall", "Collection", "Garden", "Meeting", "Library", "Music", "Attic", "Cellar" }),
	Tag = "MansionGhost",
	BaseAttribute = "GhostBase",
	RoomAttribute = "GhostRoom",
	GiggleSoundId = "",
	ClaimSoundId = "rbxassetid://138190748214493",
}) :: GhostConfig

MansionLifeConfig.Barao = table.freeze({
	MinRest = 90,
	MaxRest = 150,
	FirstDelay = 40,
	Speed = 5,
	GiftChance = 0.1,
	GiftTickets = 2,
	GiftDailyLimit = 3,
	StartAttribute = "BaraoWalkStart",
	PauseAttribute = "BaraoWalkPause",
}) :: BaraoWalkConfig

return table.freeze(MansionLifeConfig)
