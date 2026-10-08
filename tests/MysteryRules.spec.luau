--!strict

-- Testes das regras dos Mistérios do Barão (rodar com: lune run tests/MysteryRules.spec.luau).

local MysteryPrompts = require("../src/shared/modules/MysteryPrompts")
local MysteryRules = require("../src/server/data/MysteryRules")

local passed = 0
local failures = 0
local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

local OPTIONS: MysteryRules.Options = {
	colorCount = 4,
	whiteKeys = { 0, 2, 4, 5, 7, 9, 11, 12 },
	melodyLength = 5,
	minuteStep = 15,
}
local IDS = { "Clock", "Candles", "Piano", "Safe" }

-- Sorteio: válido e determinístico, em muitos servidores.
local invalid = 0
local sameCandles = 0
local repeatedNotes = 0
local hours: { [number]: boolean } = {}
for seed = 1, 400 do
	local answers = MysteryRules.generate(seed * 7919, OPTIONS)
	if answers.hour < 1 or answers.hour > 11 or answers.minute % 15 ~= 0 or answers.minute > 45 then
		invalid += 1
	end
	hours[answers.hour] = true
	local seen: { [number]: boolean } = {}
	for _, color in ipairs(answers.windows) do
		seen[color] = true
	end
	local distinct = 0
	for _ in pairs(seen) do
		distinct += 1
	end
	if distinct ~= 4 or #answers.candles ~= 4 then
		invalid += 1
	end
	local identical = true
	for index = 1, 4 do
		identical = identical and answers.candles[index] == answers.windows[index]
	end
	if identical then
		sameCandles += 1
	end
	if #answers.melody ~= 5 then
		invalid += 1
	end
	for index = 2, #answers.melody do
		if answers.melody[index] % 12 == answers.melody[index - 1] % 12 then
			repeatedNotes += 1
		end
	end
	for _, digit in ipairs(answers.code) do
		if digit < 0 or digit > 9 or digit ~= math.floor(digit) then
			invalid += 1
		end
	end
end
check("answers are always valid", invalid == 0)
check("candles never match the windows order", sameCandles == 0)
check("melody never repeats a note in a row", repeatedNotes == 0)
local hourCount = 0
for _ in pairs(hours) do
	hourCount += 1
end
check("hours vary between servers", hourCount >= 8)
local a = MysteryRules.generate(12345, OPTIONS)
local b = MysteryRules.generate(12345, OPTIONS)
check("same seed, same answers", a.hour == b.hour and a.minute == b.minute and a.code[1] == b.code[1] and a.melody[3] == b.melody[3])

-- Relógio.
check("right time opens the clock", MysteryRules.checkClock(a, a.hour, a.minute))
check("wrong hour fails", not MysteryRules.checkClock(a, (a.hour % 12) + 1, a.minute))
check("bad input fails", not MysteryRules.checkClock(a, "3", nil))

-- Velas.
local solution = MysteryRules.candleSolution(a)
check("candle solution works", MysteryRules.checkCandles(a, solution))
check("left to right is wrong", not MysteryRules.checkCandles(a, { 1, 2, 3, 4 }))
check("repeated candle fails", not MysteryRules.checkCandles(a, { solution[1], solution[1], solution[3], solution[4] }))
check("short order fails", not MysteryRules.checkCandles(a, { solution[1] }))
check("garbage order fails", not MysteryRules.checkCandles(a, { "x", 2, 3, 4 }) and not MysteryRules.checkCandles(a, 5))

-- Cofrinho.
check("right code opens", MysteryRules.checkCode(a, { a.code[1], a.code[2], a.code[3] }))
check("wrong code fails", not MysteryRules.checkCode(a, { (a.code[1] + 1) % 10, a.code[2], a.code[3] }))
check("short code fails", not MysteryRules.checkCode(a, { a.code[1] }))

-- Piano: as últimas notas precisam ser a música inteira.
local history: { number } = {}
for _, note in ipairs({ 12, 0 }) do
	history = MysteryRules.pushNote(history, note, 8)
end
check("half the melody is not enough", not MysteryRules.melodyPlayed(a, history))
for _, note in ipairs(a.melody) do
	history = MysteryRules.pushNote(history, note, 8)
end
check("melody after noise counts", MysteryRules.melodyPlayed(a, history))
check("history keeps only the last notes", #history <= 8)
history = MysteryRules.pushNote(history, 99, 8)
check("an extra note after breaks it", not MysteryRules.melodyPlayed(a, history))
local octaveShifted: { number } = {}
for _, note in ipairs(a.melody) do
	octaveShifted = MysteryRules.pushNote(octaveShifted, if note == 0 then 12 elseif note == 12 then 0 else note, 8)
end
check("low and high C count as the same note", MysteryRules.melodyPlayed(a, octaveShifted))
check("no lock before the limit", MysteryRules.wrongLock(4, 5, 30) == 0)
check("lock at the limit", MysteryRules.wrongLock(5, 5, 30) == 30)
check("no lock between limits", MysteryRules.wrongLock(7, 5, 30) == 0)
check("lock grows each time", MysteryRules.wrongLock(10, 5, 30) == 60)
check("zero limit never locks", MysteryRules.wrongLock(10, 0, 30) == 0)
local original = { 1, 2 }
local pushed = MysteryRules.pushNote(original, 3, 8)
check("pushNote returns a new table", #original == 2 and #pushed == 3)

-- Resolver.
local solved, outcome = MysteryRules.solve({}, "Clock", IDS, 5, 10, 100)
check("first solve pays tickets", solved ~= nil and outcome ~= nil and outcome.tickets == 5 and outcome.solvedCount == 1 and not outcome.allSolved)
check("solve twice is refused", MysteryRules.solve(solved :: any, "Clock", IDS, 5, 10, 101) == nil)
check("unknown mystery is refused", MysteryRules.solve({}, "Nope", IDS, 5, 10, 100) == nil)
local three = { Clock = 1, Candles = 2, Piano = 3 }
local all, last = MysteryRules.solve(three, "Safe", IDS, 5, 10, 100)
check("last mystery pays the bonus", all ~= nil and last ~= nil and last.allSolved and last.tickets == 15 and last.solvedCount == 4)
check("solve keeps the original", three.Safe == nil)

-- Depois de resolvido, o prompt some (o quebra-cabeça não convida a repetir);
-- o piano continua tocável.
check("solved clock hides its prompt", MysteryPrompts.hidesWhenSolved("Clock"))
check("solved candles hide their prompt", MysteryPrompts.hidesWhenSolved("Candles"))
check("solved safe hides its prompt", MysteryPrompts.hidesWhenSolved("Safe"))
check("piano stays playable", not MysteryPrompts.hidesWhenSolved("Piano"))
check("unknown id keeps prompt", not MysteryPrompts.hidesWhenSolved("Nope"))

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("MysteryRules tests failed")
end
