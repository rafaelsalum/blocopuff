--!strict

-- Assassinato no Casarão (Fase 5E, docs/FASE_5E_ASSASSINATO_NO_CASARAO.md):
-- o Assassino tem a faca, o Xerife tem a arma (o Puffador com um tiro e
-- recarga longa) e os Inocentes coletam moedas e fogem. O id do modo
-- continua "Mystery" (rotação, voto e telemetria). Números iniciais para o
-- playtest.

export type WingConfig = {
	-- Centro do chão do térreo da Ala (longe da Arena, do Casarão e da
	-- Torre). A planta dos cômodos é a de MurderMansionPlan.
	Center: Vector3,
	-- Luz de cada cômodo.
	LightBrightness: number,
	LightRange: number,
}

export type MysteryModeConfig = {
	Wing: WingConfig,
	Duration: number,
	-- Humanos mínimos para o modo rodar (Assassino e Xerife são sempre
	-- humanos; os bots completam como Inocentes). Com 2, o segredo é fraco,
	-- mas o voto na porta roxa precisa valer para quem joga em dupla.
	MinHumans: number,
	-- Roleta do papel na abertura (s).
	RoleRevealSeconds: number,
	-- Tempo (s) do começo sem faca nem tiro, para todos se espalharem.
	StartGrace: number,
	-- Faca: golpe (alcance em studs, ângulo à frente em graus, recarga em s)
	-- e diferença de altura máxima até o alvo.
	StabRange: number,
	StabConeDegrees: number,
	StabCooldown: number,
	StabMaxHeight: number,
	-- Faca arremessada: recarga, velocidade, alcance e raio de acerto.
	ThrowCooldown: number,
	ThrowSpeed: number,
	ThrowRange: number,
	ThrowHitRadius: number,
	-- Arma do Xerife: recarga entre tiros (s).
	SheriffReload: number,
	-- Arma caída: raio para pegar.
	PickupRadius: number,
	-- Moedas do Barão.
	CoinsPerRound: number,
	MaxCoinsPerPlayer: number,
	CoinsPerTicket: number,
	MaxCoinTickets: number,
	CoinPickupRadius: number,
	-- Só no Studio: com um jogador só, o papel dele alterna entre Xerife e
	-- Assassino a cada partida (e um bot faz o Assassino), para dar para
	-- testar. Fora do Studio o Assassino é sempre humano.
	StudioSoloTest: boolean,
}

local MysteryModeConfig: MysteryModeConfig = {
	Wing = table.freeze({
		Center = Vector3.new(-420, 100, 420),
		LightBrightness = 0.9,
		LightRange = 36,
	}),
	Duration = 180,
	MinHumans = 2,
	RoleRevealSeconds = 3,
	StartGrace = 10,
	StabRange = 5,
	StabConeDegrees = 70,
	StabCooldown = 1,
	StabMaxHeight = 5,
	ThrowCooldown = 4,
	ThrowSpeed = 90,
	ThrowRange = 110,
	ThrowHitRadius = 2.5,
	SheriffReload = 3,
	PickupRadius = 5,
	CoinsPerRound = 40,
	MaxCoinsPerPlayer = 10,
	CoinsPerTicket = 5,
	MaxCoinTickets = 2,
	CoinPickupRadius = 4,
	StudioSoloTest = true,
}

return table.freeze(MysteryModeConfig)
