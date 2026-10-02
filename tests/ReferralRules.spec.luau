-- Testes das regras de convite com recompensa.
-- Rodar: lune run tests/ReferralRules.spec

local ReferralRules = require("../src/server/data/ReferralRules")

local failures = 0
local passed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

local config = {
	InviterMaxPerDay = 3,
	InviterMaxTotal = 20,
}

-- Quem convidou fica registrado só para quem nunca jogou.
check("new player records the inviter", ReferralRules.canRecordInviter(0, 0, 111, 222))
check("veteran never records an inviter", not ReferralRules.canRecordInviter(5, 0, 111, 222))
check("inviter is never replaced", not ReferralRules.canRecordInviter(0, 333, 111, 222))
check("no self invite", not ReferralRules.canRecordInviter(0, 0, 222, 222))
check("invalid inviter id", not ReferralRules.canRecordInviter(0, 0, 0, 222) and not ReferralRules.canRecordInviter(0, 0, -5, 222))

-- Prêmio de quem convidou: uma vez por amigo, limite por dia e no total.
local function range(first: number, last: number): { number }
	local list = {}
	for id = first, last do
		table.insert(list, id)
	end
	return list
end

local granted, state = ReferralRules.inviterGrant({ day = 10, dayCount = 0, friends = {} }, 10, { 1, 2 }, config)
check("two friends on a fresh day", #granted == 2 and state.dayCount == 2 and #state.friends == 2)
granted, state = ReferralRules.inviterGrant({ day = 10, dayCount = 2, friends = { 1, 2 } }, 10, { 3, 4, 5 }, config)
check("daily cap stops at three", #granted == 1 and granted[1] == 3 and state.dayCount == 3)
granted, state = ReferralRules.inviterGrant({ day = 10, dayCount = 3, friends = { 1, 2, 3 } }, 11, { 4 }, config)
check("new day resets the daily count", #granted == 1 and state.day == 11 and state.dayCount == 1 and #state.friends == 4)
granted, state = ReferralRules.inviterGrant({ day = 10, dayCount = 0, friends = range(1, 19) }, 10, { 50, 51 }, config)
check("lifetime cap stops at twenty", #granted == 1 and #state.friends == 20)
granted = ReferralRules.inviterGrant({ day = 10, dayCount = 0, friends = range(1, 20) }, 10, { 50 }, config)
check("nothing after the lifetime cap", #granted == 0)
granted = ReferralRules.inviterGrant({ day = 10, dayCount = 0, friends = { 7 } }, 10, { 7, 8, 8 }, config)
check("same friend never pays twice", #granted == 1 and granted[1] == 8)
local before = { 1 }
ReferralRules.inviterGrant({ day = 10, dayCount = 0, friends = before }, 10, { 2 }, config)
check("does not mutate the stored list", #before == 1)

-- Lista de convidados pendentes (sem repetir, com limite).
local pending = ReferralRules.addPending({ 1, 2 }, 3, 5)
check("adds a new invitee", #pending == 3 and pending[3] == 3)
pending = ReferralRules.addPending({ 1, 2 }, 2, 5)
check("never repeats an invitee", #pending == 2)
pending = ReferralRules.addPending({ 1, 2, 3 }, 4, 3)
check("keeps the newest when full", #pending == 3 and pending[1] == 2 and pending[3] == 4)
pending = ReferralRules.addPending("garbage" :: any, 7, 3)
check("bad stored data starts fresh", #pending == 1 and pending[1] == 7)
pending = ReferralRules.readPending({ 5, 5, -1, 2.5, "x", 9 } :: any, 10)
check("reads only valid unique ids", #pending == 2 and pending[1] == 5 and pending[2] == 9)
pending = ReferralRules.readPending(nil, 10)
check("nothing stored reads empty", #pending == 0)

print(`ReferralRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} ReferralRules checks failed`)
end
