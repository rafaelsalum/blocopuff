--!strict

-- Assassinato no Casarão (Fase 5E, docs/FASE_5E_ASSASSINATO_NO_CASARAO.md):
-- o Assassino tem a faca, o Xerife tem a arma (o Puffador com um tiro e
-- recarga longa) e os Inocentes coletam Cartas do Barão e fogem. O id do modo
-- continua "Mystery" (rotação, voto e telemetria). Números iniciais para o
-- playtest.

export type WingConfig = {
	-- Centro do chão do térreo da Ala (longe da Arena, do Casarão e da
	-- Torre). A planta dos cômodos é a de MurderMansionPlan.
	Center: Vector3,
}

-- Som curto (biblioteca licenciada ProSoundEffects).
export type KnifeSound = {
	Id: string,
	Volume: number,
	-- Mais rápido encurta o som.
	Speed: number,
}

export type SoundsConfig = {
	-- Faca: sacar, golpe no ar, golpe que acerta e arremesso.
	Draw: KnifeSound,
	Swing: KnifeSound,
	Hit: KnifeSound,
	Throw: KnifeSound,
	-- Pegar uma Carta do Barão (papel), só para quem pegou.
	LetterPickup: KnifeSound,
	-- Música (APM) dos últimos segundos da partida, só para quem joga.
	FinalMusicId: string,
	FinalMusicSeconds: number,
	FinalMusicVolume: number,
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
	-- Colado no Assassino (studs), o golpe pega até quem está do lado.
	StabCloseRange: number,
	-- Compensação da rede (s): o golpe confere os alvos onde estavam até o
	-- ping do Assassino mais `StabRewindBase` atrás, no máximo
	-- `StabRewindMax` (MurderStabHistory).
	StabRewindBase: number,
	StabRewindMax: number,
	-- Até quantos studs da posição que o servidor conhece vale a que o
	-- cliente do Assassino manda no golpe (quem corre chega atrasado).
	StabOriginTolerance: number,
	-- Faca arremessada: recarga, velocidade, alcance e raio de acerto.
	ThrowCooldown: number,
	ThrowSpeed: number,
	ThrowRange: number,
	ThrowHitRadius: number,
	-- Depois do último ataque, a faca volta a ficar guardada (s).
	DrawnSeconds: number,
	-- Segurar o ataque por isso (s) vira arremesso; menos é golpe.
	ThrowHoldSeconds: number,
	-- Campo de visão da primeira pessoa (graus).
	FirstPersonFov: number,
	-- Arma do Xerife: recarga entre tiros (s).
	SheriffReload: number,
	-- Arma caída: raio para pegar.
	PickupRadius: number,
	-- Cartas do Barão (eram moedas; os nomes seguem "Coin").
	CoinsPerRound: number,
	MaxCoinsPerPlayer: number,
	CoinsPerTicket: number,
	MaxCoinTickets: number,
	CoinPickupRadius: number,
	-- Só no Studio: com um jogador só, o papel dele alterna entre Xerife e
	-- Assassino a cada partida (e um bot faz o Assassino), para dar para
	-- testar. Fora do Studio o Assassino é sempre humano.
	StudioSoloTest: boolean,
	Sounds: SoundsConfig,
}

local MysteryModeConfig: MysteryModeConfig = {
	Wing = table.freeze({
		Center = Vector3.new(-420, 100, 420),
	}),
	Duration = 180,
	MinHumans = 2,
	RoleRevealSeconds = 3,
	StartGrace = 10,
	StabRange = 7.5,
	StabConeDegrees = 100,
	StabCooldown = 0.5,
	StabMaxHeight = 5,
	StabCloseRange = 3.5,
	StabRewindBase = 0.1,
	StabRewindMax = 0.4,
	StabOriginTolerance = 4,
	ThrowCooldown = 4,
	ThrowSpeed = 70,
	ThrowRange = 110,
	ThrowHitRadius = 2.5,
	DrawnSeconds = 4,
	ThrowHoldSeconds = 0.3,
	FirstPersonFov = 80,
	SheriffReload = 3,
	PickupRadius = 5,
	CoinsPerRound = 40,
	MaxCoinsPerPlayer = 10,
	CoinsPerTicket = 5,
	MaxCoinTickets = 2,
	CoinPickupRadius = 4,
	StudioSoloTest = true,
	Sounds = table.freeze({
		Draw = table.freeze({ Id = "rbxassetid://9113453296", Volume = 0.6, Speed = 1.6 }),
		Swing = table.freeze({ Id = "rbxassetid://9125620110", Volume = 0.7, Speed = 1.8 }),
		Hit = table.freeze({ Id = "rbxassetid://9119747138", Volume = 0.6, Speed = 1.2 }),
		Throw = table.freeze({ Id = "rbxassetid://9125619884", Volume = 0.8, Speed = 1.3 }),
		LetterPickup = table.freeze({ Id = "rbxassetid://9125557068", Volume = 0.7, Speed = 1.5 }),
		FinalMusicId = "rbxassetid://1846059805",
		FinalMusicSeconds = 30,
		FinalMusicVolume = 0.45,
	}),
}

return table.freeze(MysteryModeConfig)
