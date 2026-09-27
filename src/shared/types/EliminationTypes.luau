--!strict

-- Causas de eliminação usadas pelo RoundService (autoridade) e lidas pelo
-- HudController (cliente). Fonte única para evitar strings soltas.
export type EliminationReason = "None" | "FellFromArena" | "CharacterDied" | "PlayerLeft"

export type EliminationReasonsModule = {
	None: EliminationReason,
	FellFromArena: EliminationReason,
	CharacterDied: EliminationReason,
	PlayerLeft: EliminationReason,
}

local EliminationTypes: EliminationReasonsModule = {
	None = "None",
	FellFromArena = "FellFromArena",
	CharacterDied = "CharacterDied",
	PlayerLeft = "PlayerLeft",
}

return table.freeze(EliminationTypes)
