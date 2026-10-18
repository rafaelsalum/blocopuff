--!strict

-- Causas de eliminação usadas pelo RoundService (autoridade) e lidas pelo
-- HudController (cliente). Fonte única para evitar strings soltas.
-- Assassinato no Casarão (Fase 5E): Knifed (faca do Assassino), Shot (tiro
-- do Xerife ou do Herói) e Misfire (o Xerife que acertou um Inocente sai
-- junto).
export type EliminationReason = "None" | "FellFromArena" | "CharacterDied" | "PlayerLeft" | "Knifed" | "Shot" | "Misfire"

export type EliminationReasonsModule = {
	None: EliminationReason,
	FellFromArena: EliminationReason,
	CharacterDied: EliminationReason,
	PlayerLeft: EliminationReason,
	Knifed: EliminationReason,
	Shot: EliminationReason,
	Misfire: EliminationReason,
}

local EliminationTypes: EliminationReasonsModule = {
	None = "None",
	FellFromArena = "FellFromArena",
	CharacterDied = "CharacterDied",
	PlayerLeft = "PlayerLeft",
	Knifed = "Knifed",
	Shot = "Shot",
	Misfire = "Misfire",
}

return table.freeze(EliminationTypes)
