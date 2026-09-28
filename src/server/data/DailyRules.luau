--!strict

-- Regras puras do dia (Fase 4.3): número do dia do jogo, retorno diário
-- com sequência amigável, sorteio dos desafios do dia e progresso a partir
-- da soma de uma rodada. Sem estado; devolvem tabelas NOVAS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyConfig = require(ReplicatedStorage.Shared.config.DailyConfig)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)

type ChallengeDefinition = DailyConfig.ChallengeDefinition
type ChallengeState = ProfileTypes.ChallengeState
type DailyState = ProfileTypes.DailyState
type DailyReward = ProfileTypes.DailyReward

export type Challenges = {
	day: number,
	list: { ChallengeState },
}

local SECONDS_PER_DAY = 86400
local MAX_PROGRESS = 1e6

local DailyRules = {}

local byId: { [string]: ChallengeDefinition } = {}
for _, definition in ipairs(DailyConfig.Challenges) do
	byId[definition.id] = definition
end

function DailyRules.challenge(id: string): ChallengeDefinition?
	return byId[id]
end

local function shifted(now: number): number
	return now + DailyConfig.DayOffsetHours * 3600
end

-- Dia do jogo (inteiro que sobe 1 a cada virada).
function DailyRules.dayIndex(now: number): number
	return math.floor(shifted(now) / SECONDS_PER_DAY)
end

-- os.time() da próxima virada.
function DailyRules.nextResetAt(now: number): number
	return (DailyRules.dayIndex(now) + 1) * SECONDS_PER_DAY - DailyConfig.DayOffsetHours * 3600
end

function DailyRules.emptyDaily(): DailyState
	return { lastDay = 0, streak = 0, best = 0 }
end

-- Retorno diário. Devolve o novo estado e a recompensa (nil se já recebeu
-- hoje). Faltar até GraceDays dias não quebra a sequência.
function DailyRules.claimDaily(daily: DailyState, today: number): (DailyState, DailyReward?)
	if daily.lastDay >= today then
		return daily, nil
	end
	local gap = today - daily.lastDay
	local continues = daily.lastDay > 0 and gap <= 1 + DailyConfig.GraceDays
	local streak = if continues then daily.streak + 1 else 1
	local rewards = DailyConfig.DailyRewards
	local tickets = rewards[((streak - 1) % #rewards) + 1]
	return { lastDay = today, streak = streak, best = math.max(daily.best, streak) }, { streak = streak, tickets = tickets }
end

-- Os desafios do dia: um de cada nível, sorteados de forma fixa por
-- jogador e dia (o mesmo em qualquer servidor).
function DailyRules.assign(userId: number, day: number): Challenges
	local rng = Random.new((userId % 1e9) * 7919 + day)
	local list: { ChallengeState } = {}
	for _, tier in ipairs(DailyConfig.Tiers) do
		local pool: { ChallengeDefinition } = {}
		for _, definition in ipairs(DailyConfig.Challenges) do
			if definition.tier == tier then
				table.insert(pool, definition)
			end
		end
		if #pool > 0 then
			local picked = pool[rng:NextInteger(1, #pool)]
			table.insert(list, { id = picked.id, progress = 0, done = false })
		end
	end
	return { day = day, list = list }
end

-- Garante os desafios de hoje. Devolve os desafios e se foram trocados.
function DailyRules.ensureToday(challenges: Challenges, userId: number, today: number): (Challenges, boolean)
	if challenges.day == today and #challenges.list > 0 then
		return challenges, false
	end
	return DailyRules.assign(userId, today), true
end

-- Soma o progresso de uma rodada. Devolve os novos desafios, os ids
-- concluídos agora e os tickets desses desafios.
function DailyRules.applyRound(challenges: Challenges, delta: { [string]: number }): (Challenges, { string }, number)
	local list: { ChallengeState } = {}
	local completed: { string } = {}
	local tickets = 0
	for _, state in ipairs(challenges.list) do
		local definition = byId[state.id]
		if definition == nil or state.done then
			table.insert(list, table.clone(state))
		else
			local progress = math.min(MAX_PROGRESS, state.progress + (delta[definition.stat] or 0))
			local done = progress >= definition.target
			table.insert(list, { id = state.id, progress = math.min(progress, definition.target), done = done })
			if done then
				table.insert(completed, state.id)
				tickets += definition.tickets
			end
		end
	end
	return { day = challenges.day, list = list }, completed, tickets
end

local function readCount(value: unknown): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_PROGRESS)
end

function DailyRules.readDaily(raw: unknown): DailyState
	if typeof(raw) ~= "table" then
		return DailyRules.emptyDaily()
	end
	local data = raw :: { [string]: unknown }
	local lastDay = if typeof(data.lastDay) == "number" and data.lastDay == data.lastDay then math.max(0, math.floor(data.lastDay :: number)) else 0
	return { lastDay = lastDay, streak = readCount(data.streak), best = readCount(data.best) }
end

function DailyRules.readChallenges(raw: unknown): Challenges
	local result: Challenges = { day = 0, list = {} }
	if typeof(raw) ~= "table" then
		return result
	end
	local data = raw :: { [string]: unknown }
	if typeof(data.day) == "number" and data.day == data.day then
		result.day = math.max(0, math.floor(data.day :: number))
	end
	if typeof(data.list) == "table" then
		for index, item in ipairs(data.list :: { unknown }) do
			if index > #DailyConfig.Tiers then
				break
			end
			if typeof(item) == "table" then
				local state = item :: { [string]: unknown }
				local definition = if typeof(state.id) == "string" then byId[state.id :: string] else nil
				if definition ~= nil then
					table.insert(result.list, {
						id = definition.id,
						progress = math.min(readCount(state.progress), definition.target),
						done = state.done == true,
					})
				end
			end
		end
	end
	return result
end

function DailyRules.toStoredChallenges(challenges: Challenges): { [string]: any }
	local list = {}
	for _, state in ipairs(challenges.list) do
		table.insert(list, table.clone(state))
	end
	return { day = challenges.day, list = list }
end

return table.freeze(DailyRules)
