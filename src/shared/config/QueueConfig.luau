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
}

local QueueConfig: QueueConfig = {
	CheckInterval = 0.25,
	LonelyHintSeconds = 60,
	JoinCooldown = 1,
	ZoneHeight = 14,
}

return table.freeze(QueueConfig)
