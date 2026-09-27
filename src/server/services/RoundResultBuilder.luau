--!strict

-- Monta o resultado da rodada a partir dos participantes, das posições de
-- eliminação e dos atributos da rodada (blocos e derrubadas). Sem efeitos
-- colaterais: quem envia é o RoundService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResultTypes = require(ReplicatedStorage.Shared.types.ResultTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

type ResultEntry = ResultTypes.ResultEntry
type Highlight = ResultTypes.Highlight
type RoundResult = ResultTypes.RoundResult

export type ParticipantSnapshot = {
	player: Player,
	alive: boolean,
	eliminatedPosition: number?,
	eliminatedAt: number?,
}

-- Eliminações com menos que isso de diferença contam como simultâneas.
local SIMULTANEOUS_WINDOW = 0.05

local RoundResultBuilder = {}

-- Jogadores eliminados por último (mesmo instante, dentro da janela).
function RoundResultBuilder.getLastEliminated(times: { [Player]: number }): { Player }
	local latest = -math.huge
	for _, clock in pairs(times) do
		latest = math.max(latest, clock)
	end
	local last: { Player } = {}
	for player, clock in pairs(times) do
		if latest - clock <= SIMULTANEOUS_WINDOW then
			table.insert(last, player)
		end
	end
	return last
end

-- Quedas simultâneas dividem a melhor posição do grupo (empate). A posição 1
-- fica para o vencedor; sem vencedor, um grupo empatado no topo divide o 1º.
local function resolveTies(snapshots: { ParticipantSnapshot }): { [Player]: number }
	local eliminated: { ParticipantSnapshot } = {}
	for _, snapshot in ipairs(snapshots) do
		if not snapshot.alive and snapshot.eliminatedAt ~= nil then
			table.insert(eliminated, snapshot)
		end
	end
	table.sort(eliminated, function(a, b)
		return (a.eliminatedAt :: number) > (b.eliminatedAt :: number)
	end)

	local positions: { [Player]: number } = {}
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
			positions[eliminated[member].player] = best
		end
		index = groupEnd + 1
	end
	return positions
end

local function readCount(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then math.max(0, math.floor(value)) else 0
end

-- Maior valor entre as entradas; nil se ninguém pontuou.
local function pickHighlight(entries: { ResultEntry }, title: string, read: (ResultEntry) -> number): Highlight?
	local best: ResultEntry? = nil
	for _, entry in ipairs(entries) do
		local value = read(entry)
		if value > 0 and (best == nil or value > read(best)) then
			best = entry
		end
	end
	if best == nil then
		return nil
	end
	return { title = title, userId = best.userId, name = best.name, value = read(best) }
end

function RoundResultBuilder.build(roundId: number, snapshots: { ParticipantSnapshot }, winner: Player?): RoundResult
	local entries: { ResultEntry } = {}
	local tiedPositions = resolveTies(snapshots)
	local survivors = 0
	local sharedFirst = 0
	for _, snapshot in ipairs(snapshots) do
		if snapshot.alive then
			survivors += 1
		end
	end

	for _, snapshot in ipairs(snapshots) do
		local player = snapshot.player
		local position = if snapshot.alive then 1 else (tiedPositions[player] or snapshot.eliminatedPosition or #snapshots)
		if not snapshot.alive and position == 1 and (winner == nil or winner ~= player) then
			sharedFirst += 1
		end
		table.insert(entries, {
			userId = player.UserId,
			name = player.DisplayName,
			position = position,
			blocks = readCount(player, StateAttributeNames.PlayerRoundBlocksDestroyed),
			knockouts = readCount(player, StateAttributeNames.PlayerRoundKnockouts),
			survived = snapshot.alive,
		})
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
	local mostBlocks = pickHighlight(entries, "MAIS BLOCOS", function(entry)
		return entry.blocks
	end)
	if mostBlocks ~= nil then
		table.insert(highlights, mostBlocks)
	end
	local mostKnockouts = pickHighlight(entries, "MAIS DERRUBADAS", function(entry)
		return entry.knockouts
	end)
	if mostKnockouts ~= nil then
		table.insert(highlights, mostKnockouts)
	end

	return {
		roundId = roundId,
		winnerUserId = if winner ~= nil then winner.UserId else 0,
		winnerName = if winner ~= nil then winner.DisplayName else "",
		draw = winner == nil and (survivors > 1 or sharedFirst > 1),
		participantCount = #snapshots,
		entries = entries,
		highlights = highlights,
	}
end

return table.freeze(RoundResultBuilder)
