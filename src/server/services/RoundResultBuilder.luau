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
}

local RoundResultBuilder = {}

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
	local survivors = 0
	for _, snapshot in ipairs(snapshots) do
		if snapshot.alive then
			survivors += 1
		end
	end

	for _, snapshot in ipairs(snapshots) do
		local player = snapshot.player
		local position = if snapshot.alive then 1 else (snapshot.eliminatedPosition or #snapshots)
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
		draw = winner == nil and survivors > 1,
		participantCount = #snapshots,
		entries = entries,
		highlights = highlights,
	}
end

return table.freeze(RoundResultBuilder)
