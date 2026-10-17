--!strict

-- Causas de eliminação usadas pelo RoundService (autoridade) e lidas pelo
-- HudController (cliente). Fonte única para evitar strings soltas.
-- Scared: assustado pelo Fantasma (ou acertado pelo Detetive por engano);
-- Captured: o Fantasma capturado pelo Puffador (Mistério, Fase 5D.3).
export type EliminationReason = "None" | "FellFromArena" | "CharacterDied" | "PlayerLeft" | "Scared" | "Captured"

export type EliminationReasonsModule = {
	None: EliminationReason,
	FellFromArena: EliminationReason,
	CharacterDied: EliminationReason,
	PlayerLeft: EliminationReason,
	Scared: EliminationReason,
	Captured: EliminationReason,
}

local EliminationTypes: EliminationReasonsModule = {
	None = "None",
	FellFromArena = "FellFromArena",
	CharacterDied = "CharacterDied",
	PlayerLeft = "PlayerLeft",
	Scared = "Scared",
	Captured = "Captured",
}

return table.freeze(EliminationTypes)
