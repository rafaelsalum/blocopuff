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

-- Tapete Puxado (5.3): onde fica cada tapete do térreo, em células da grade
-- da arena (linha = Z, coluna = X, a partir de 1), e para que lado ele é
-- puxado (é o lado da franja, que é o alvo).
export type RugPull = "+Column" | "-Column" | "+Row" | "-Row"
export type RugLayout = {
	row: number,
	column: number,
	rows: number,
	columns: number,
	pull: RugPull,
	color: Color3,
}

export type RugConfig = TrapRules & {
	-- Andar dos tapetes (1 = térreo).
	Floor: number,
	Rugs: { RugLayout },
	-- Escorregão: velocidade (múltiplo do empurrão horizontal do disparo) e
	-- quanto tempo dura. Só na horizontal, sem pulo.
	SlideMultiplier: number,
	SlideDuration: number,
	-- Até que altura acima do tapete conta como "em cima" dele.
	StandHeight: number,
	FringeColor: Color3,
	StretchSoundId: string,
	PullSoundId: string,
}

-- Lustre Despencando (5.4): cada lustre fica pendurado embaixo de um bloco
-- do andar de cima (o bloco de apoio, na mesma linha e coluna da grade),
-- sobre o térreo.
export type ChandelierSpot = {
	row: number,
	column: number,
}

export type ChandelierConfig = TrapRules & {
	-- Andar sobre o qual o lustre fica (o de apoio é o de cima).
	Floor: number,
	Spots: { ChandelierSpot },
	-- Altura do corpo do lustre acima do chão do térreo e raio dele.
	HangHeight: number,
	Radius: number,
	-- Parte final do aviso em que o lustre já está caindo (só desenho).
	FallTime: number,
	-- Empurrão do impacto para fora do círculo.
	ImpactRadius: number,
	ImpactMultiplier: number,
	ImpactLift: number,
	-- Blocos do chão que caem (centro a até HoleRadius do impacto; 6,5 é
	-- uma cruz de 5 blocos) e quanto tempo piscam antes.
	HoleRadius: number,
	HoleDelay: number,
	CreakSoundId: string,
	CrashSoundId: string,
}

-- Lareira de Fuligem (5.5): fica numa parede externa do térreo, no lugar
-- de um detalhe da decoração (a parede tem de ser "West", "North" ou
-- "South"; o centro da oeste é o cofre).
export type FireplaceWall = "West" | "North" | "South"

export type FireplaceConfig = TrapRules & {
	Floor: number,
	Wall: FireplaceWall,
	-- Posição ao longo da parede (studs a partir do centro dela) e largura
	-- total da lareira (a decoração da parede deixa esse trecho livre).
	Offset: number,
	Width: number,
	-- Nuvem de fuligem: centro a CloudOffset studs da parede, raio, altura
	-- e quanto tempo fica.
	CloudOffset: number,
	CloudRadius: number,
	CloudHeight: number,
	CloudDuration: number,
	-- Espirro: pulinho para longe do centro da nuvem (múltiplo do empurrão
	-- do disparo), no máximo um a cada SneezeCooldown por jogador.
	SneezeMultiplier: number,
	SneezeLift: number,
	SneezeCooldown: number,
	-- Tela embaçada de quem espirrou (s).
	BlurTime: number,
	CoughSoundId: string,
	PuffSoundId: string,
	SneezeSoundId: string,
}

export type TrapConfig = {
	Window: WindowConfig,
	Rug: RugConfig,
	Chandelier: ChandelierConfig,
	Fireplace: FireplaceConfig,
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
	-- Sons que vêm com o Roblox (o antigo swoosh.wav não carrega mais).
	-- Para um "whoosh" de verdade, troque por um áudio do Creator Store.
	GustSoundId = "rbxasset://sounds/action_get_up.mp3",
})

local Rug: RugConfig = table.freeze({
	MinDistance = 20,
	WarningTime = 0.8,
	RechargeTime = 20,
	UsesPerRound = 4,
	Floor = 1,
	-- Um em cada metade do térreo, puxados para o centro (onde costuma ter
	-- buraco).
	Rugs = table.freeze({
		table.freeze({
			row = 3,
			column = 3,
			rows = 3,
			columns = 4,
			pull = "+Column" :: RugPull,
			color = Color3.fromRGB(150, 40, 55),
		}),
		table.freeze({
			row = 11,
			column = 10,
			rows = 3,
			columns = 4,
			pull = "-Column" :: RugPull,
			color = Color3.fromRGB(40, 70, 140),
		}),
	}),
	-- Cerca de 31 studs/s por 0,45 s: uns 14 studs (pouco mais de 2 blocos).
	SlideMultiplier = 0.5,
	SlideDuration = 0.45,
	StandHeight = 6,
	FringeColor = Color3.fromRGB(240, 226, 190),
	StretchSoundId = "rbxasset://sounds/action_get_up.mp3",
	PullSoundId = "rbxasset://sounds/action_get_up.mp3",
})

local Chandelier: ChandelierConfig = table.freeze({
	MinDistance = 20,
	WarningTime = 1,
	-- Cai uma vez por rodada; a recarga só marca quando ele fica gasto.
	RechargeTime = 1,
	UsesPerRound = 1,
	Floor = 1,
	-- Longe dos tapetes, um em cada metade do térreo.
	Spots = table.freeze({
		table.freeze({ row = 6, column = 11 }),
		table.freeze({ row = 10, column = 5 }),
	}),
	HangHeight = 13,
	Radius = 1.8,
	FallTime = 0.4,
	ImpactRadius = 7,
	ImpactMultiplier = 1,
	ImpactLift = 0.6,
	HoleRadius = 6.5,
	HoleDelay = 0.6,
	CreakSoundId = "rbxasset://sounds/clickfast.wav",
	CrashSoundId = "rbxasset://sounds/action_jump_land.mp3",
})

local Fireplace: FireplaceConfig = table.freeze({
	MinDistance = 15,
	WarningTime = 0.6,
	RechargeTime = 18,
	UsesPerRound = 4,
	Floor = 1,
	-- No centro da parede sul, no lugar da porta falsa.
	Wall = "South" :: FireplaceWall,
	Offset = 0,
	Width = 8.4,
	CloudOffset = 4,
	CloudRadius = 10,
	CloudHeight = 8,
	CloudDuration = 4,
	SneezeMultiplier = 0.35,
	SneezeLift = 0.5,
	SneezeCooldown = 1.5,
	BlurTime = 1.5,
	CoughSoundId = "rbxasset://sounds/action_jump_land.mp3",
	PuffSoundId = "rbxasset://sounds/action_get_up.mp3",
	SneezeSoundId = "rbxasset://sounds/ouch.ogg",
})

local TrapConfig: TrapConfig = table.freeze({
	Window = Window,
	Rug = Rug,
	Chandelier = Chandelier,
	Fireplace = Fireplace,
})

return TrapConfig
