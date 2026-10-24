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
-- - se nada servir, a Arena (o modo base) sempre pode entrar;
-- - com votos (as portas do mirante), vence o modo mais votado entre os que
--   podem rodar, sem as regras do novato e da repetição (os jogadores
--   escolheram); empate segue a ordem da rotação; a posição na rotação não
--   anda, para ela seguir de onde estava quando ninguém votar.

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
	-- Votos por modo de quem vai jogar (nil = ninguém votou).
	votes: { [string]: number }?,
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

-- Modo mais votado entre os que podem rodar; empate na ordem da rotação a
-- partir de `start`. nil se nenhum voto vale.
local function mostVoted(input: Input, start: number): string?
	local votes = input.votes
	if votes == nil then
		return nil
	end
	local best: string? = nil
	local bestCount = 0
	local sequence = input.sequence
	local seen: { [string]: boolean } = {}
	for offset = 0, #sequence - 1 do
		local mode = sequence[normalizedIndex(start + offset, #sequence)]
		local count = votes[mode] or 0
		if not seen[mode] and input.available[mode] == true and count > bestCount then
			best = mode
			bestCount = count
		end
		seen[mode] = true
	end
	return best
end

-- Modo da próxima partida e o cursor seguinte (não altera `cursor`).
function ModeRotation.pick(cursor: Cursor, input: Input): (string, Cursor)
	local sequence = input.sequence
	local length = #sequence
	local start = normalizedIndex(cursor.index, length)

	local voted = mostVoted(input, start)
	if voted ~= nil then
		return voted, { index = start, last = voted }
	end

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

-- O modo da vez na rotação (`cursor`) ficou de fora? Devolve esse modo e o
-- motivo ("Vote", "Beginner", "Unavailable" ou "Repeat"); nil se ele é o
-- escolhido (`picked`) ou se não há sequência. Para a telemetria
-- (ModeSkipped).
function ModeRotation.skipped(cursor: Cursor, input: Input, picked: string): (string?, string?)
	local sequence = input.sequence
	if #sequence == 0 then
		return nil, nil
	end
	local start = normalizedIndex(cursor.index, #sequence)
	local scheduled = sequence[start]
	if scheduled == picked then
		return nil, nil
	end
	if mostVoted(input, start) ~= nil then
		return scheduled, "Vote"
	elseif input.hasBeginner then
		return scheduled, "Beginner"
	elseif input.available[scheduled] ~= true then
		return scheduled, "Unavailable"
	end
	return scheduled, "Repeat"
end

-- Porta do mirante por onde o jogador entrou: a de `z` mais perto da
-- posição dele (as portas ficam na mesma parede). nil sem portas.
function ModeRotation.nearestDoor(passages: { number }, z: number): number?
	local best: number? = nil
	local bestGap = math.huge
	for index, passageZ in ipairs(passages) do
		local gap = math.abs(z - passageZ)
		if gap < bestGap then
			best = index
			bestGap = gap
		end
	end
	return best
end

-- Votos por modo a partir do voto de cada jogador ("" = sem voto).
function ModeRotation.tally(choices: { string }): { [string]: number }
	local votes: { [string]: number } = {}
	for _, choice in ipairs(choices) do
		if choice ~= "" then
			votes[choice] = (votes[choice] or 0) + 1
		end
	end
	return votes
end

-- Novato: ainda nas primeiras partidas da vida, que são sempre na Arena.
function ModeRotation.isBeginner(matchesPlayed: number, beginnerMatches: number): boolean
	return matchesPlayed < beginnerMatches
end

return table.freeze(ModeRotation)
