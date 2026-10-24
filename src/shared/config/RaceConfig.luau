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
	-- Saco de obstáculos (Fase 5F.3): cada rodada do saco sorteia a ordem e
	-- usa todos, então os quatro tipos aparecem na mesma corrida.
	-- "Barrel", "Cauldron", "Gears" e "Books".
	Bag: { string },
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
	-- Caldeirão que rola rampa abaixo (maior e mais lento que o barril).
	CauldronRadius: number,
	CauldronSecondsPerTurn: number,
	CauldronHitRadius: number,
	CauldronClearHeight: number,
	-- Bando de livros que cruza a rampa de dentro para fora, à frente de um
	-- corredor, depois do aviso (brilho na coluna).
	BooksPerFlock: number,
	BookWarning: number,
	BookFlightTime: number,
	-- Altura dos livros acima da rampa e tamanho da faixa que acerta.
	BookHeight: number,
	BookHalfLength: number,
	BookHalfWidth: number,
	BookClearHeight: number,
	-- Ponteiro gigante que sai da coluna e varre um trecho da rampa (em
	-- voltas), de tempos em tempos. Tem que pular na hora certa.
	ClockHandFromTurn: number,
	ClockHandToTurn: number,
	ClockHandPeriod: number,
	-- Tempo saindo da coluna (o aviso), varrendo e voltando para dentro.
	ClockHandExtendTime: number,
	ClockHandSweepTime: number,
	ClockHandRetractTime: number,
	ClockHandClearHeight: number,
	-- Empurrão de quem é atingido: rampa abaixo e um pouco para cima. A mureta
	-- e a barreira seguram quem for para fora (Fase 5F).
	PushDownhill: number,
	PushVertical: number,
	-- Tontura depois de atingido: anda devagar por um instante.
	DizzySeconds: number,
	DizzyWalkSpeed: number,
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
		Bag = table.freeze({ "Barrel", "Cauldron", "Gears", "Books", "Barrel", "Gears" }),
		BarrelRadius = 2.5,
		BarrelSecondsPerTurn = 7,
		BarrelHitRadius = 4,
		BarrelClearHeight = 4.5,
		DropWarning = 1,
		DropHeight = 30,
		DropFallTime = 0.35,
		DropHitRadius = 6,
		CauldronRadius = 3,
		CauldronSecondsPerTurn = 9,
		CauldronHitRadius = 5,
		CauldronClearHeight = 6,
		BooksPerFlock = 5,
		BookWarning = 1,
		BookFlightTime = 1.4,
		BookHeight = 2.5,
		BookHalfLength = 5.5,
		BookHalfWidth = 2,
		BookClearHeight = 6,
		ClockHandFromTurn = 2.42,
		ClockHandToTurn = 2.62,
		ClockHandPeriod = 7,
		ClockHandExtendTime = 1.2,
		ClockHandSweepTime = 1.2,
		ClockHandRetractTime = 0.6,
		ClockHandClearHeight = 4.8,
		PushDownhill = 36,
		PushVertical = 14,
		DizzySeconds = 1,
		DizzyWalkSpeed = 5,
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
