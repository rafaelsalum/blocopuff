--!strict

-- Corrida da Torre do Relógio (Fase 5D.2, docs/FASE_5D_MODOS_DO_CASARAO.md):
-- subir a rampa em espiral desviando do que o Barão joga do topo. Números
-- iniciais para o playtest.

export type TowerConfig = {
	-- Centro da base da torre, numa ilha de pedra ao norte do Casarão (Fase 5F).
	Center: Vector3,
	-- Distância do centro até o meio da rampa.
	Radius: number,
	RampWidth: number,
	RampThickness: number,
	Turns: number,
	ClimbPerTurn: number,
	-- Peças da rampa por volta (mais peças = curva mais lisa).
	SegmentsPerTurn: number,
	-- Mureta de pedra na borda de fora da rampa e do terraço do topo.
	ParapetHeight: number,
	ParapetThickness: number,
	-- Folga entre o alto da barreira invisível e a volta de cima da rampa.
	BarrierHeadroom: number,
	-- Altura da barreira invisível em volta do terraço do topo.
	TopBarrierHeight: number,
	-- Raio da ilha de pedra em volta da torre.
	IslandRadius: number,
	-- Distância máxima do centro para contar a chegada no topo.
	TopRadius: number,
}

export type HazardConfig = {
	-- Intervalo (s) entre obstáculos no começo e no fim da corrida.
	SlowInterval: number,
	FastInterval: number,
	-- Chance de o obstáculo ser um barril (o resto cai do alto).
	BarrelChance: number,
	BarrelRadius: number,
	-- Tempo (s) para o barril descer uma volta inteira.
	BarrelSecondsPerTurn: number,
	BarrelHitRadius: number,
	-- Quem está mais alto que isso em relação ao centro do barril pulou por cima.
	BarrelClearHeight: number,
	-- Aviso (sombra no chão) antes de um objeto cair.
	DropWarning: number,
	DropHeight: number,
	DropFallTime: number,
	DropHitRadius: number,
	-- Empurrão de quem é atingido: rampa abaixo e um pouco para cima. A mureta
	-- e a barreira seguram quem for para fora (Fase 5F).
	PushDownhill: number,
	PushOutward: number,
	PushVertical: number,
	-- Imunidade (s) depois de ser atingido, para não levar dois seguidos.
	HitProtection: number,
}

export type RaceConfig = {
	Tower: TowerConfig,
	Hazards: HazardConfig,
	-- Duração máxima da corrida (s).
	Duration: number,
	CheckpointCount: number,
	-- Altura abaixo do checkpoint que leva o jogador de volta a ele.
	ReturnTolerance: number,
	-- Folga de altura para contar checkpoint e chegada.
	ReachTolerance: number,
	-- Subida máxima (studs/s) entre checagens; acima disso é teletransporte
	-- ou voo, e o corredor volta ao checkpoint sem ganhar nada.
	MaxRiseSpeed: number,
	-- A corrida acaba quando estes chegam ao topo.
	PodiumSize: number,
	-- Força do Puffador na Corrida (1 = a mesma da Arena).
	PuffadorForce: number,
	-- Intervalo (s) da checagem de posição dos corredores.
	TickSeconds: number,
}

local RaceConfig: RaceConfig = {
	Tower = table.freeze({
		Center = Vector3.new(180, 120, -230),
		Radius = 42,
		RampWidth = 24,
		RampThickness = 2,
		Turns = 4,
		ClimbPerTurn = 30,
		SegmentsPerTurn = 24,
		ParapetHeight = 3.5,
		ParapetThickness = 2,
		BarrierHeadroom = 1,
		TopBarrierHeight = 14,
		IslandRadius = 85,
		TopRadius = 36,
	}),
	Hazards = table.freeze({
		SlowInterval = 3,
		FastInterval = 1.2,
		BarrelChance = 0.5,
		BarrelRadius = 2.5,
		BarrelSecondsPerTurn = 7,
		BarrelHitRadius = 4,
		BarrelClearHeight = 4.5,
		DropWarning = 1,
		DropHeight = 30,
		DropFallTime = 0.35,
		DropHitRadius = 6,
		PushDownhill = 36,
		PushOutward = 0,
		PushVertical = 14,
		HitProtection = 1.5,
	}),
	Duration = 150,
	CheckpointCount = 3,
	ReturnTolerance = 12,
	ReachTolerance = 0,
	MaxRiseSpeed = 60,
	PodiumSize = 3,
	PuffadorForce = 0.5,
	TickSeconds = 0.2,
}

return table.freeze(RaceConfig)
