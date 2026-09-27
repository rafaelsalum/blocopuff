--!strict

-- Nomes compartilhados que permitem ao cliente reconhecer visualmente um
-- bloco válido sem participar da decisão autoritativa de destruição.

export type ArenaConstantsModule = {
	BlockTag: string,
	IsDestroyedAttribute: string,
	GridRowAttribute: string,
	GridColumnAttribute: string,
	BlockIdAttribute: string,
	FloorAttribute: string,
	CollapseWarningAttribute: string,
}

local ArenaConstants: ArenaConstantsModule = {
	BlockTag = "ArenaBlock",
	IsDestroyedAttribute = "IsDestroyed",
	GridRowAttribute = "GridRow",
	GridColumnAttribute = "GridColumn",
	BlockIdAttribute = "BlockId",
	FloorAttribute = "FloorIndex",
	-- Verdadeiro enquanto o bloco pisca antes de cair no Caos Final.
	CollapseWarningAttribute = "CollapseWarning",
}

return table.freeze(ArenaConstants)
