--!strict

-- Quem está na partida em andamento: os escalados (IsRoundParticipant),
-- inclusive os já eliminados, que seguem assistindo pelo espectador. Avisos
-- da partida (cofre, passagens, Momentos Puff, resultado) só vão para eles:
-- quem está no lobby (Casarão ou mirante) não é interrompido.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

local MatchAudience = {}

function MatchAudience.isInMatch(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
end

function MatchAudience.players(): { Player }
	local list: { Player } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if MatchAudience.isInMatch(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- FireClient para cada jogador da partida (no lugar de FireAllClients).
function MatchAudience.fire(remote: RemoteEvent, ...: any)
	for _, player in ipairs(MatchAudience.players()) do
		remote:FireClient(player, ...)
	end
end

return table.freeze(MatchAudience)
