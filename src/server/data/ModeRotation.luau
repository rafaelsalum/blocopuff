--!strict

-- Rotação de modos no mesmo servidor (Fase 5D.1), sem Roblox: escolhe o modo
-- da próxima partida. Os testes rodam no Lune (tests/ModeRotation.spec.luau).
--
-- Regras:
-- - segue a sequência da config, voltando ao começo;
-- - pula o modo que não pode rodar agora (não registrado ou sem gente);
-- - um modo novo nunca se repete duas vezes seguidas (a Arena pode);
-- - com um novato na fila, joga-se a Arena e a rotação não anda, para o
--   modo novo vir logo depois;
-- - se nada servir, a Arena (o modo base) sempre pode entrar.

export type Cursor = {
	-- Posição (1-based) na sequência do próximo modo a tentar.
	index: number,
	-- Último modo jogado (nil antes da primeira partida).
	last: string?,
}

export type Input = {
	sequence: { string },
	baseMode: string,
	-- Modos que podem rodar agora.
	available: { [string]: boolean },
	hasBeginner: boolean,
}

local ModeRotation = {}

function ModeRotation.initialCursor(): Cursor
	return { index = 1, last = nil }
end

local function normalizedIndex(index: number, length: number): number
	if length == 0 then
		return 1
	end
	return ((math.floor(index) - 1) % length) + 1
end

-- Modo da próxima partida e o cursor seguinte (não altera `cursor`).
function ModeRotation.pick(cursor: Cursor, input: Input): (string, Cursor)
	local sequence = input.sequence
	local length = #sequence
	local start = normalizedIndex(cursor.index, length)

	if input.hasBeginner or length == 0 then
		return input.baseMode, { index = start, last = input.baseMode }
	end

	for offset = 0, length - 1 do
		local position = normalizedIndex(start + offset, length)
		local mode = sequence[position]
		local repeatsNewMode = mode ~= input.baseMode and mode == cursor.last
		if input.available[mode] == true and not repeatsNewMode then
			return mode, { index = normalizedIndex(position + 1, length), last = mode }
		end
	end

	return input.baseMode, { index = normalizedIndex(start + 1, length), last = input.baseMode }
end

-- Novato: ainda nas primeiras partidas da vida, que são sempre na Arena.
function ModeRotation.isBeginner(matchesPlayed: number, beginnerMatches: number): boolean
	return matchesPlayed < beginnerMatches
end

return table.freeze(ModeRotation)
