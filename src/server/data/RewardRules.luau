--!strict

-- Regras puras de recompensa (Fase 4.2): quantos tickets uma rodada vale e
-- o sorteio da Puff Machine. Sem estado e sem DataStore: o PlayerDataService
-- aplica o resultado ao perfil de uma vez (sem pausa entre conferir o saldo
-- e gastar, então não há gasto duplo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local RewardConfig = require(ReplicatedStorage.Shared.config.RewardConfig)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)

type ProfileStats = ProfileTypes.ProfileStats
type PuffDefinition = PuffTypes.PuffDefinition
type PuffRarity = PuffTypes.PuffRarity

export type TicketLine = {
	source: string,
	tickets: number,
}

local RewardRules = {}

local RARITY_ORDER: { PuffRarity } = { "Common", "Rare", "Epic", "Legendary" }

local function isEpicOrBetter(rarity: PuffRarity): boolean
	return rarity == "Epic" or rarity == "Legendary"
end

-- Tickets da rodada. `delta` já passou por ProfileSchema.clampDelta.
-- Quem não ganhou XP (não jogou de verdade) não ganha ticket de rodada; a
-- subida de nível sempre vale.
function RewardRules.ticketsForRound(delta: ProfileStats, gainedXp: number, levelsGained: number): (number, { TicketLine })
	local lines: { TicketLine } = {}
	local function add(source: string, tickets: number)
		if tickets > 0 then
			table.insert(lines, { source = source, tickets = tickets })
		end
	end
	if delta.matches > 0 and gainedXp > 0 then
		add("Round", RewardConfig.TicketsPerRound)
		add("Top3", if delta.top3 > 0 then RewardConfig.TicketsTop3 else 0)
		add("Win", if delta.wins > 0 then RewardConfig.TicketsWin else 0)
	end
	add("LevelUp", math.max(0, levelsGained) * RewardConfig.TicketsPerLevelUp)
	local total = 0
	for _, line in ipairs(lines) do
		total += line.tickets
	end
	return math.min(total, RewardConfig.MaxTicketsPerRound), lines
end

-- Raridade sorteada pelas chances da máquina. Com `guaranteed`, sorteia só
-- entre Épico e Lendário (mantendo a proporção entre eles).
local function rollRarity(rng: Random, guaranteed: boolean): PuffRarity
	local candidates = {}
	local total = 0
	for _, weight in ipairs(RewardConfig.MachineOdds) do
		if not guaranteed or isEpicOrBetter(weight.rarity) then
			table.insert(candidates, weight)
			total += weight.percent
		end
	end
	local pick = rng:NextNumber() * total
	for _, weight in ipairs(candidates) do
		pick -= weight.percent
		if pick < 0 then
			return weight.rarity
		end
	end
	return candidates[#candidates].rarity
end

-- Um giro. `pity` = giros seguidos sem Épico ou melhor. Devolve o Puff e o
-- novo contador. Se a raridade sorteada não tiver Puff na máquina, desce
-- para a raridade abaixo (nunca fica sem prêmio); no giro garantido, nunca
-- desce abaixo de Épico.
function RewardRules.rollMachine(rng: Random, pity: number): (PuffDefinition?, number)
	local guaranteed = pity + 1 >= RewardConfig.PityThreshold
	local rarity = rollRarity(rng, guaranteed)
	local startIndex = table.find(RARITY_ORDER, rarity) or 1
	local floorIndex = if guaranteed then table.find(RARITY_ORDER, "Epic") or 1 else 1
	for index = startIndex, floorIndex, -1 do
		local pool = PuffCatalog.machinePool(RARITY_ORDER[index])
		if #pool > 0 then
			local picked = pool[rng:NextInteger(1, #pool)]
			local nextPity = if isEpicOrBetter(picked.rarity) then 0 else pity + 1
			return picked, nextPity
		end
	end
	if guaranteed then
		warn("[BlocoPuff] Puff Machine has no Epic or Legendary Puff for the guaranteed pull")
	end
	return nil, pity
end

return table.freeze(RewardRules)
