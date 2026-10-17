--!strict

-- Rotação de modos no mesmo servidor (Fase 5D, docs/FASE_5D_MODOS_DO_CASARAO.md).
-- Um modo da sequência que ainda não existe (não registrado no servidor) é
-- pulado, então a sequência já pode citar os modos que vêm nas próximas
-- entregas: até lá, toda partida é Arena.

export type ModeId = "Arena" | "Race" | "Mystery"

export type ModeRotationConfig = {
	-- Modo base: o mais frequente, o dos novatos e o que sempre pode entrar.
	BaseMode: ModeId,
	Sequence: { ModeId },
	-- Primeiras partidas da vida do jogador, sempre na Arena (para aprender
	-- o Puffador).
	BeginnerArenaMatches: number,
	-- Modo de cada porta do mirante (na ordem de MansionLayout.passages, de
	-- −Z para +Z): entrar por ela é votar nele.
	DoorModes: { ModeId },
}

local ModeRotationConfig: ModeRotationConfig = {
	BaseMode = "Arena",
	Sequence = table.freeze({ "Arena", "Race", "Arena", "Mystery" } :: { ModeId }),
	BeginnerArenaMatches = 3,
	DoorModes = table.freeze({ "Race", "Arena", "Mystery" } :: { ModeId }),
}

return table.freeze(ModeRotationConfig)
