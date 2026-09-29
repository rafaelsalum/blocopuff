--!strict

-- Fila da partida: quem está no mirante (a galeria envidraçada) entra na
-- fila; a contagem começa com GameConfig.MinimumPlayers na fila.

export type QueueConfig = {
	-- Intervalo (s) entre as verificações de quem está no mirante.
	CheckInterval: number,
	-- Sozinho na fila por este tempo (s): aviso para chamar um amigo.
	LonelyHintSeconds: number,
	-- Intervalo mínimo (s) entre pedidos do botão JOGAR.
	JoinCooldown: number,
	-- Folga de altura (studs) acima do piso do mirante que ainda conta.
	ZoneHeight: number,
	-- Nos últimos segundos da contagem as portas do mirante fecham.
	BoardingLockSeconds: number,
	-- Aquecimento no mirante (WarmupService): balões-Puff para estourar.
	BalloonCount: number,
	BalloonRiseTime: NumberRange,
	BalloonRespawnDelay: number,
	-- Trampolins Puff: velocidade vertical e intervalo entre impulsos.
	TrampolineVelocity: number,
	TrampolineCooldown: number,
}

local QueueConfig: QueueConfig = {
	CheckInterval = 0.25,
	LonelyHintSeconds = 60,
	JoinCooldown = 1,
	ZoneHeight = 14,
	BoardingLockSeconds = 5,
	BalloonCount = 8,
	BalloonRiseTime = NumberRange.new(7, 11),
	BalloonRespawnDelay = 1,
	TrampolineVelocity = 62,
	TrampolineCooldown = 0.5,
}

return table.freeze(QueueConfig)
