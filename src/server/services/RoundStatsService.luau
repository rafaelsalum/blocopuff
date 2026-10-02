--!strict

-- Contadores da rodada que não estão nos atributos do jogador (cofre,
-- Barão, segredos, construções e Volta por Cima). Alimentado pelos
-- serviços da Fase 2 e lido pelo RoundService no fim da rodada para montar
-- a soma do perfil.

local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

export type RoundCounters = {
	vaultsOpened: number,
	vaultsConquered: number,
	baraoEscapes: number,
	secretsFound: number,
	blocksBuilt: number,
	comebacks: number,
	shots: number,
	-- Derrubadas de bots RoboPuff (valem menos XP e não contam no perfil).
	botKnockouts: number,
}

local RoundStatsService = {}

local active = false
local counters: { [Combatant]: RoundCounters } = {}

local function empty(): RoundCounters
	return {
		vaultsOpened = 0,
		vaultsConquered = 0,
		baraoEscapes = 0,
		secretsFound = 0,
		blocksBuilt = 0,
		comebacks = 0,
		shots = 0,
		botKnockouts = 0,
	}
end

local function add(combatant: Combatant, key: string)
	if not active then
		return
	end
	local current = counters[combatant]
	if current == nil then
		current = empty()
		counters[combatant] = current
	end
	local record = current :: any
	record[key] += 1
end

function RoundStatsService.vaultOpened(combatant: Combatant)
	add(combatant, "vaultsOpened")
end

function RoundStatsService.vaultConquered(combatant: Combatant)
	add(combatant, "vaultsConquered")
end

function RoundStatsService.baraoEscape(combatant: Combatant)
	add(combatant, "baraoEscapes")
end

function RoundStatsService.secretFound(combatant: Combatant)
	add(combatant, "secretsFound")
end

function RoundStatsService.blockBuilt(combatant: Combatant)
	add(combatant, "blocksBuilt")
end

-- Puffs disparados (só para saber se o jogador participou de verdade).
function RoundStatsService.shot(combatant: Combatant)
	add(combatant, "shots")
end

function RoundStatsService.comeback(combatant: Combatant)
	add(combatant, "comebacks")
end

function RoundStatsService.botKnockout(combatant: Combatant)
	add(combatant, "botKnockouts")
end

-- Cópia dos contadores do combatente nesta rodada (zeros se não fez nada).
function RoundStatsService.get(combatant: Combatant): RoundCounters
	local current = counters[combatant]
	return if current ~= nil then table.clone(current) else empty()
end

function RoundStatsService.beginRound()
	active = true
	table.clear(counters)
end

function RoundStatsService.endRound()
	active = false
	table.clear(counters)
end

return table.freeze(RoundStatsService)
