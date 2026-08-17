--!strict

-- Nomes compartilhados que permitem ao cliente reconhecer visualmente um
-- bloco válido sem participar da decisão autoritativa de destruição.

export type ArenaConstantsModule = {
	BlockTag: string,
	IsDestroyedAttribute: string,
	GridRowAttribute: string,
	GridColumnAttribute: string,
	BlockIdAttribute: string,
}

local ArenaConstants: ArenaConstantsModule = {
	BlockTag = "ArenaBlock",
	IsDestroyedAttribute = "IsDestroyed",
	GridRowAttribute = "GridRow",
	GridColumnAttribute = "GridColumn",
	BlockIdAttribute = "BlockId",
}

return table.freeze(ArenaConstants)
