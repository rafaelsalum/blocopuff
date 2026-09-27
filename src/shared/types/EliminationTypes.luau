--!strict

-- Causas de eliminação usadas pelo RoundService (autoridade) e lidas pelo
-- HudController (cliente). Fonte única para evitar strings soltas.
export type EliminationReason = "None" | "FellFromArena" | "CharacterDied" | "PlayerLeft" | "ShotInSecretRoom"

export type EliminationReasonsModule = {
	None: EliminationReason,
	FellFromArena: EliminationReason,
	CharacterDied: EliminationReason,
	PlayerLeft: EliminationReason,
	ShotInSecretRoom: EliminationReason,
}

local EliminationTypes: EliminationReasonsModule = {
	None = "None",
	FellFromArena = "FellFromArena",
	CharacterDied = "CharacterDied",
	PlayerLeft = "PlayerLeft",
	-- Atingido por um tiro enquanto estava dentro da sala secreta.
	ShotInSecretRoom = "ShotInSecretRoom",
}

return table.freeze(EliminationTypes)
