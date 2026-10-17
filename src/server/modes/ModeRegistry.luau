--!strict

-- Modos de partida que existem neste servidor (Fase 5D). Um modo da sequência
-- de `ModeRotationConfig` que não está aqui é pulado pela rotação.

local RoundModeTypes = require(script.Parent.RoundModeTypes)
local ArenaMode = require(script.Parent.ArenaMode)
local RaceMode = require(script.Parent.RaceMode)
local MysteryMode = require(script.Parent.MysteryMode)

type RoundMode = RoundModeTypes.RoundMode

local MODES: { [string]: RoundMode } = table.freeze({
	[ArenaMode.id] = ArenaMode,
	[RaceMode.id] = RaceMode,
	[MysteryMode.id] = MysteryMode,
})

local ModeRegistry = {}

function ModeRegistry.get(id: string): RoundMode?
	return MODES[id]
end

function ModeRegistry.all(): { [string]: RoundMode }
	return MODES
end

return table.freeze(ModeRegistry)
