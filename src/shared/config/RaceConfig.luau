--!strict

-- Corrida da Torre do Relógio (Fase 5D.2, docs/FASE_5D_MODOS_DO_CASARAO.md):
-- subir a rampa em espiral desviando do que o Barão joga do topo. Números
-- iniciais para o playtest.

export type TowerConfig = {
	-- Centro da base da torre (longe da Arena e do Casarão).
	Center: Vector3,
	-- Distância do centro até o meio da rampa.
	Radius: number,
	RampWidth: number,
	RampThickness: number,
	Turns: number,
	ClimbPerTurn: number,
	-- Peças da rampa por volta (mais peças = curva mais lisa).
	SegmentsPerTurn: number,
	-- Raio do chão da base e altura da mureta em volta dele.
	BaseRadius: number,
	BaseWallHeight: number,
	-- Raio do patamar do topo (a chegada).
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
	-- Empurrão de quem é atingido: rampa abaixo, um pouco para fora da torre
	-- e para cima (às vezes derruba para a volta de baixo).
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
		Center = Vector3.new(-420, 100, 0),
		Radius = 30,
		RampWidth = 16,
		RampThickness = 1.5,
		Turns = 4,
		ClimbPerTurn = 26,
		SegmentsPerTurn = 20,
		BaseRadius = 52,
		BaseWallHeight = 6,
		TopRadius = 22,
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
		PushDownhill = 32,
		PushOutward = 12,
		PushVertical = 28,
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
