--!strict

-- Regras puras dos Mistérios do Barão (Fase 5C.3, parte 2): sorteio das
-- respostas de um servidor e conferência de cada tentativa. Sem estado e
-- sem Roblox (testes no Lune: tests/MysteryRules.spec.luau); devolvem
-- tabelas NOVAS.

export type Answers = {
	-- Relógio: hora de 1 a 12 e minutos (múltiplo de `minuteStep`).
	hour: number,
	minute: number,
	-- Índices das cores (1..colorCount): dos vitrais, da esquerda para a
	-- direita, e das velas, na ordem em que estão no Salão.
	windows: { number },
	candles: { number },
	-- Meios tons das notas da música da Vovó.
	melody: { number },
	-- Código do cofrinho (três dígitos de 0 a 9).
	code: { number },
}

export type Options = {
	colorCount: number,
	whiteKeys: { number },
	melodyLength: number,
	minuteStep: number,
}

export type Outcome = {
	tickets: number,
	solvedCount: number,
	allSolved: boolean,
}

local MysteryRules = {}

-- Meios tons numa oitava (Dó grave = 0, Dó agudo = 12: mesma nota).
local OCTAVE = 12

-- Gerador simples e determinístico (mesmo `seed`, mesmas respostas).
local function generator(seed: number): (number, number) -> number
	local state = math.floor(math.abs(seed)) % 2147483647
	if state == 0 then
		state = 1
	end
	return function(low: number, high: number): number
		state = (state * 48271) % 2147483647
		return low + (state % (high - low + 1))
	end
end

local function shuffled(count: number, nextInt: (number, number) -> number): { number }
	local list: { number } = {}
	for index = 1, count do
		list[index] = index
	end
	for index = count, 2, -1 do
		local other = nextInt(1, index)
		list[index], list[other] = list[other], list[index]
	end
	return list
end

local function sameOrder(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	for index = 1, #a do
		if a[index] ~= b[index] then
			return false
		end
	end
	return true
end

function MysteryRules.generate(seed: number, options: Options): Answers
	local nextInt = generator(seed)
	-- 12h00 é a hora em que o relógio parado aparece: nunca é a resposta.
	local hour = nextInt(1, 11)
	local steps = 60 // options.minuteStep
	local minute = nextInt(0, steps - 1) * options.minuteStep
	local windows = shuffled(options.colorCount, nextInt)
	-- As velas nunca ficam na mesma ordem dos vitrais (senão é só da
	-- esquerda para a direita).
	local candles = shuffled(options.colorCount, nextInt)
	while options.colorCount > 1 and sameOrder(candles, windows) do
		candles = shuffled(options.colorCount, nextInt)
	end
	local melody: { number } = {}
	local previous = -1
	for _ = 1, options.melodyLength do
		local note = options.whiteKeys[nextInt(1, #options.whiteKeys)]
		while note % OCTAVE == previous do
			note = options.whiteKeys[nextInt(1, #options.whiteKeys)]
		end
		table.insert(melody, note)
		previous = note % OCTAVE
	end
	local code = { nextInt(0, 9), nextInt(0, 9), nextInt(0, 9) }
	return { hour = hour, minute = minute, windows = windows, candles = candles, melody = melody, code = code }
end

function MysteryRules.checkClock(answers: Answers, hour: unknown, minute: unknown): boolean
	return hour == answers.hour and minute == answers.minute
end

-- `order`: posições das velas (1..n, da esquerda para a direita) na ordem
-- em que o jogador acendeu. Certo quando as cores seguem os vitrais.
function MysteryRules.checkCandles(answers: Answers, order: unknown): boolean
	if typeof(order) ~= "table" then
		return false
	end
	local list = order :: { any }
	if #list ~= #answers.windows then
		return false
	end
	local used: { [number]: boolean } = {}
	for index, position in ipairs(list) do
		if typeof(position) ~= "number" or answers.candles[position] == nil or used[position] then
			return false
		end
		used[position] = true
		if answers.candles[position] ~= answers.windows[index] then
			return false
		end
	end
	return true
end

-- Ordem certa de acender (posições das velas), para os testes.
function MysteryRules.candleSolution(answers: Answers): { number }
	local order: { number } = {}
	for _, color in ipairs(answers.windows) do
		table.insert(order, table.find(answers.candles, color) :: number)
	end
	return order
end

function MysteryRules.checkCode(answers: Answers, digits: unknown): boolean
	if typeof(digits) ~= "table" then
		return false
	end
	local list = digits :: { any }
	if #list ~= #answers.code then
		return false
	end
	for index, digit in ipairs(list) do
		if digit ~= answers.code[index] then
			return false
		end
	end
	return true
end

-- Últimas notas tocadas (as mais antigas saem), com a nova no fim.
function MysteryRules.pushNote(history: { number }, semitone: number, keep: number): { number }
	local updated = table.clone(history)
	table.insert(updated, semitone)
	while #updated > keep do
		table.remove(updated, 1)
	end
	return updated
end

-- As últimas notas tocadas são a música inteira. A partitura só diz o
-- nome da nota: o Dó grave e o agudo valem igual.
function MysteryRules.melodyPlayed(answers: Answers, history: { number }): boolean
	local length = #answers.melody
	if #history < length then
		return false
	end
	local offset = #history - length
	for index = 1, length do
		if history[offset + index] % OCTAVE ~= answers.melody[index] % OCTAVE then
			return false
		end
	end
	return true
end

-- Segundos de trava depois de `wrongCount` erros seguidos: nada até o
-- limite; a cada `limit` erros, `seconds` vezes quantas travas já foram.
function MysteryRules.wrongLock(wrongCount: number, limit: number, seconds: number): number
	if limit <= 0 or wrongCount < limit or wrongCount % limit ~= 0 then
		return 0
	end
	return seconds * (wrongCount // limit)
end

-- Marca `id` como resolvido. `ids` são todos os mistérios. Devolve o novo
-- mapa e o resultado, ou nil se já estava resolvido ou o id não existe.
function MysteryRules.solve(
	solved: { [string]: number },
	id: string,
	ids: { string },
	tickets: number,
	allTickets: number,
	now: number
): ({ [string]: number }?, Outcome?)
	if solved[id] ~= nil or table.find(ids, id) == nil then
		return nil, nil
	end
	local updated = table.clone(solved)
	updated[id] = now
	local count = 0
	for _, other in ipairs(ids) do
		if updated[other] ~= nil then
			count += 1
		end
	end
	local allSolved = count == #ids
	return updated, {
		tickets = tickets + (if allSolved then allTickets else 0),
		solvedCount = count,
		allSolved = allSolved,
	}
end

return table.freeze(MysteryRules)
