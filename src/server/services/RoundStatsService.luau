--!strict

-- Contadores da rodada que não estão nos atributos do jogador (cofre,
-- Barão, segredos, construções e Volta por Cima). Alimentado pelos
-- serviços da Fase 2 e lido pelo RoundService no fim da rodada para montar
-- a soma do perfil.

export type RoundCounters = {
	vaultsOpened: number,
	vaultsConquered: number,
	baraoEscapes: number,
	secretsFound: number,
	blocksBuilt: number,
	comebacks: number,
}

local RoundStatsService = {}

local active = false
local counters: { [Player]: RoundCounters } = {}

local function empty(): RoundCounters
	return { vaultsOpened = 0, vaultsConquered = 0, baraoEscapes = 0, secretsFound = 0, blocksBuilt = 0, comebacks = 0 }
end

local function add(player: Player, key: string)
	if not active then
		return
	end
	local current = counters[player]
	if current == nil then
		current = empty()
		counters[player] = current
	end
	local record = current :: any
	record[key] += 1
end

function RoundStatsService.vaultOpened(player: Player)
	add(player, "vaultsOpened")
end

function RoundStatsService.vaultConquered(player: Player)
	add(player, "vaultsConquered")
end

function RoundStatsService.baraoEscape(player: Player)
	add(player, "baraoEscapes")
end

function RoundStatsService.secretFound(player: Player)
	add(player, "secretsFound")
end

function RoundStatsService.blockBuilt(player: Player)
	add(player, "blocksBuilt")
end

function RoundStatsService.comeback(player: Player)
	add(player, "comebacks")
end

-- Cópia dos contadores do jogador nesta rodada (zeros se não fez nada).
function RoundStatsService.get(player: Player): RoundCounters
	local current = counters[player]
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
