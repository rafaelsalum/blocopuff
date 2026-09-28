--!strict

-- Seleção de participantes que mantém cada Party junta (Fase 4.4). Pura:
-- recebe a fila de rotação e devolve quem joga, a nova fila e as Parties
-- que não couberam.
--
-- Regras:
--   * a fila continua mandando: percorre da frente para trás;
--   * uma Party entra inteira ou não entra (usa a posição do membro mais
--     à frente na fila);
--   * se a Party não cabe nas vagas que sobram, ela espera na FRENTE da
--     fila (entra primeiro na próxima) e quem vem atrás pode ocupar as vagas;
--   * quem jogou vai para o fim da fila, como antes;
--   * com `eligible` (fila da partida), só joga o grupo em que algum
--     membro é elegível; os demais ficam na fila, na mesma posição, sem
--     contar como adiados.

export type GroupOf = (player: Player) -> { Player }
export type Eligible = (player: Player) -> boolean

local PartySelection = {}

function PartySelection.select(queue: { Player }, groupOf: GroupOf, maxPlayers: number, eligible: Eligible?): ({ Player }, { Player }, { { Player } })
	local inQueue: { [Player]: boolean } = {}
	for _, player in ipairs(queue) do
		inQueue[player] = true
	end

	local processed: { [Player]: boolean } = {}
	local selected: { Player } = {}
	local waiting: { Player } = {}
	local deferredParties: { { Player } } = {}

	for _, player in ipairs(queue) do
		if not processed[player] then
			-- Membros do grupo que estão na fila, na ordem da fila.
			local members: { [Player]: boolean } = {}
			for _, member in ipairs(groupOf(player)) do
				members[member] = true
			end
			members[player] = true
			local group: { Player } = {}
			for _, candidate in ipairs(queue) do
				if members[candidate] and inQueue[candidate] and not processed[candidate] then
					table.insert(group, candidate)
					processed[candidate] = true
				end
			end

			local groupEligible = eligible == nil
			if eligible ~= nil then
				for _, member in ipairs(group) do
					if eligible(member) then
						groupEligible = true
						break
					end
				end
			end

			if not groupEligible then
				for _, member in ipairs(group) do
					table.insert(waiting, member)
				end
			elseif #selected + #group <= maxPlayers then
				for _, member in ipairs(group) do
					table.insert(selected, member)
				end
			else
				for _, member in ipairs(group) do
					table.insert(waiting, member)
				end
				if #group > 1 then
					table.insert(deferredParties, group)
				end
			end
		end
	end

	for _, player in ipairs(selected) do
		table.insert(waiting, player)
	end
	return selected, waiting, deferredParties
end

return table.freeze(PartySelection)
