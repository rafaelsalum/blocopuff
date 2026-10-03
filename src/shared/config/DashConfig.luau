--!strict

-- Impulso (botão ao lado do pulo, tecla F, botão B do controle): uma
-- arrancada curta na direção do movimento. Regras em DashRules.

export type DashConfig = {
	-- Segundos entre dois impulsos.
	Cooldown: number,
	-- Velocidade horizontal (studs/s) e por quanto tempo ela é mantida:
	-- Speed × Duration ≈ distância da arrancada.
	Speed: number,
	Duration: number,
	-- Impulsos no ar por pulo (volta ao tocar o chão).
	AirDashesPerJump: number,
	-- Folga do servidor ao conferir o intervalo (latência da rede).
	ServerTolerance: number,
}

local DashConfig: DashConfig = {
	Cooldown = 3,
	Speed = 55,
	Duration = 0.2,
	AirDashesPerJump = 1,
	ServerTolerance = 0.35,
}

return table.freeze(DashConfig)
