--!strict

-- Monta o resultado da rodada a partir dos participantes, das posições de
-- eliminação e dos atributos da rodada (blocos e derrubadas). Sem efeitos
-- colaterais: quem envia é o RoundService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResultTypes = require(ReplicatedStorage.Shared.types.ResultTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

type ResultEntry = ResultTypes.ResultEntry
type Highlight = ResultTypes.Highlight
type RoundResult = ResultTypes.RoundResult

export type ParticipantSnapshot = {
	combatant: Combatant,
	alive: boolean,
	eliminatedPosition: number?,
	eliminatedAt: number?,
	-- Contadores da rodada que não estão em atributos (RoundStatsService).
	vaultsOpened: number,
	vaultsConquered: number,
	baraoEscapes: number,
	secretsFound: number,
	comebacks: number,
}

-- Mínimo para ganhar o destaque (evita "Demolidor" com 1 bloco).
local DEMOLISHER_MIN_BLOCKS = 5
local MAX_HIGHLIGHTS = 5

-- Eliminações com menos que isso de diferença contam como simultâneas.
local SIMULTANEOUS_WINDOW = 0.05

local RoundResultBuilder = {}

-- Combatentes eliminados por último (mesmo instante, dentro da janela).
function RoundResultBuilder.getLastEliminated(times: { [Combatant]: number }): { Combatant }
	local latest = -math.huge
	for _, clock in pairs(times) do
		latest = math.max(latest, clock)
	end
	local last: { Combatant } = {}
	for combatant, clock in pairs(times) do
		if latest - clock <= SIMULTANEOUS_WINDOW then
			table.insert(last, combatant)
		end
	end
	return last
end

-- Quedas simultâneas dividem a melhor posição do grupo (empate). A posição 1
-- fica para o vencedor; sem vencedor, um grupo empatado no topo divide o 1º.
local function resolveTies(snapshots: { ParticipantSnapshot }): { [Combatant]: number }
	local eliminated: { ParticipantSnapshot } = {}
	for _, snapshot in ipairs(snapshots) do
		if not snapshot.alive and snapshot.eliminatedAt ~= nil then
			table.insert(eliminated, snapshot)
		end
	end
	table.sort(eliminated, function(a, b)
		return (a.eliminatedAt :: number) > (b.eliminatedAt :: number)
	end)

	local positions: { [Combatant]: number } = {}
	local index = 1
	while index <= #eliminated do
		local groupEnd = index
		local anchor = eliminated[index].eliminatedAt :: number
		while groupEnd + 1 <= #eliminated and anchor - (eliminated[groupEnd + 1].eliminatedAt :: number) <= SIMULTANEOUS_WINDOW do
			groupEnd += 1
		end
		local best = math.huge
		for member = index, groupEnd do
			best = math.min(best, eliminated[member].eliminatedPosition or #snapshots)
		end
		for member = index, groupEnd do
			positions[eliminated[member].combatant] = best
		end
		index = groupEnd + 1
	end
	return positions
end

-- Maior valor entre as entradas; nil se ninguém pontuou.
local function pickHighlight(entries: { ResultEntry }, kind: string, title: string, minimum: number, read: (ResultEntry) -> number): Highlight?
	local best: ResultEntry? = nil
	for _, entry in ipairs(entries) do
		local value = read(entry)
		if value >= math.max(1, minimum) and (best == nil or value > read(best)) then
			best = entry
		end
	end
	if best == nil then
		return nil
	end
	return { kind = kind, title = title, userId = best.userId, name = best.name, value = read(best) }
end

function RoundResultBuilder.build(roundId: number, snapshots: { ParticipantSnapshot }, winner: Combatant?): RoundResult
	local entries: { ResultEntry } = {}
	local comebacks: { [number]: number } = {}
	local tiedPositions = resolveTies(snapshots)
	local survivors = 0
	local sharedFirst = 0
	for _, snapshot in ipairs(snapshots) do
		if snapshot.alive then
			survivors += 1
		end
	end

	for _, snapshot in ipairs(snapshots) do
		local combatant = snapshot.combatant
		local position = if snapshot.alive then 1 else (tiedPositions[combatant] or snapshot.eliminatedPosition or #snapshots)
		if not snapshot.alive and position == 1 and (winner == nil or winner ~= combatant) then
			sharedFirst += 1
		end
		table.insert(entries, {
			userId = combatant.id,
			name = combatant.name,
			position = position,
			blocks = CombatantRegistry.readCount(combatant, StateAttributeNames.PlayerRoundBlocksDestroyed),
			knockouts = CombatantRegistry.readCount(combatant, StateAttributeNames.PlayerRoundKnockouts),
			survived = snapshot.alive,
			vault = if snapshot.vaultsConquered > 0 then 2 elseif snapshot.vaultsOpened > 0 then 1 else 0,
			baraoEscapes = snapshot.baraoEscapes,
			secretsFound = snapshot.secretsFound,
		})
		comebacks[combatant.id] = snapshot.comebacks
	end

	table.sort(entries, function(a, b)
		if a.position ~= b.position then
			return a.position < b.position
		end
		if a.knockouts ~= b.knockouts then
			return a.knockouts > b.knockouts
		end
		if a.blocks ~= b.blocks then
			return a.blocks > b.blocks
		end
		return a.userId < b.userId
	end)

	local highlights: { Highlight } = {}
	local function consider(highlight: Highlight?)
		if highlight ~= nil and #highlights < MAX_HIGHLIGHTS then
			table.insert(highlights, highlight)
		end
	end
	-- table.pack guarda os nil (quem não tem destaque) sem cortar a lista.
	local candidates = table.pack(
		pickHighlight(entries, "Demolisher", "DEMOLIDOR", DEMOLISHER_MIN_BLOCKS, function(entry)
			return entry.blocks
		end),
		pickHighlight(entries, "Knockouts", "MAIS DERRUBADAS", 1, function(entry)
			return entry.knockouts
		end),
		pickHighlight(entries, "Vault", "DONO DO COFRE", 1, function(entry)
			return entry.vault
		end),
		pickHighlight(entries, "BaraoEscapes", "ESCAPOU DO BARÃO", 1, function(entry)
			return entry.baraoEscapes
		end),
		pickHighlight(entries, "Secrets", "DESCOBRIDOR", 1, function(entry)
			return entry.secretsFound
		end),
		pickHighlight(entries, "Comeback", "VOLTA POR CIMA", 1, function(entry)
			return comebacks[entry.userId] or 0
		end)
	)
	for index = 1, candidates.n do
		consider(candidates[index])
	end

	return {
		roundId = roundId,
		winnerUserId = if winner ~= nil then winner.id else 0,
		winnerName = if winner ~= nil then winner.name else "",
		draw = winner == nil and (survivors > 1 or sharedFirst > 1),
		participantCount = #snapshots,
		entries = entries,
		highlights = highlights,
	}
end

return table.freeze(RoundResultBuilder)
