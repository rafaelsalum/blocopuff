--!strict

-- Armadilhas do Casarão (Fase 5, docs/FASE_5_PARTIDA_VIVA_CASARAO_REAGE.md).
-- Números iniciais para o playtest. O empurrão é medido em múltiplos do
-- empurrão do disparo (GameConfig.Knockback).

-- Regras comuns a toda armadilha (base, 5.1).
export type TrapRules = {
	-- Distância mínima (studs) do atirador ao alvo para o efeito completo.
	-- Mais perto, a armadilha só trinca ou treme.
	MinDistance: number,
	-- Aviso antes do efeito (s).
	WarningTime: number,
	-- Tempo até voltar a ficar pronta (s).
	RechargeTime: number,
	UsesPerRound: number,
}

-- Janela Ventania (5.2).
export type WindowConfig = TrapRules & {
	-- Cone da rajada, medido no piso a partir da parede da janela.
	ConeLength: number,
	ConeHalfAngle: number,
	-- Meia largura do cone junto da parede (quem está ao lado da janela).
	ConeBaseHalfWidth: number,
	-- Até que altura acima do piso a rajada pega.
	ConeHeight: number,
	-- Empurrão perto da janela e no fim do cone.
	NearMultiplier: number,
	FarMultiplier: number,
	-- Fração do empurrão vertical do disparo (tira o jogador do chão).
	LiftFactor: number,
	-- Quanto a rajada abre para os lados (0 = reto para dentro).
	Spread: number,
	-- Blocos encostados na parede que caem: até esta distância do centro
	-- da janela, ao longo da parede.
	LooseBlocksAlong: number,
	-- Tempo piscando antes de os blocos caírem (s).
	LooseBlockDelay: number,
	-- Parte final da recarga em que a janela já está pregada com tábuas.
	BoardedFraction: number,
	-- Sons (provisórios, embutidos no Roblox; troque por áudios da Creator
	-- Store com rbxassetid://...).
	CrackSoundId: string,
	ShatterSoundId: string,
	GustSoundId: string,
}

export type TrapConfig = {
	Window: WindowConfig,
}

local Window: WindowConfig = table.freeze({
	MinDistance = 25,
	WarningTime = 0.7,
	RechargeTime = 25,
	UsesPerRound = 3,
	ConeLength = 30,
	ConeHalfAngle = 25,
	ConeBaseHalfWidth = 3,
	ConeHeight = 12,
	NearMultiplier = 1.2,
	FarMultiplier = 0.4,
	LiftFactor = 0.8,
	Spread = 0.35,
	LooseBlocksAlong = 6,
	LooseBlockDelay = 1,
	BoardedFraction = 0.3,
	CrackSoundId = "rbxasset://sounds/clickfast.wav",
	ShatterSoundId = "rbxasset://sounds/action_jump_land.mp3",
	GustSoundId = "rbxasset://sounds/swoosh.wav",
})

local TrapConfig: TrapConfig = table.freeze({
	Window = Window,
})

return TrapConfig
