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
}

local ModeRotationConfig: ModeRotationConfig = {
	BaseMode = "Arena",
	Sequence = table.freeze({ "Arena", "Race", "Arena", "Mystery" } :: { ModeId }),
	BeginnerArenaMatches = 3,
}

return table.freeze(ModeRotationConfig)
