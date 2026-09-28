--!strict

-- Reconhece erros do DataStore que não adianta tentar de novo.

local DataStoreErrors = {}

-- Studio com "Enable Studio Access to API Services" desligado (erro 11).
function DataStoreErrors.isStudioAccessDenied(failure: unknown): boolean
	local message = tostring(failure)
	return string.find(message, "Studio access to APIs is not allowed", 1, true) ~= nil
end

DataStoreErrors.StudioHint = "ative Game Settings > Security > Enable Studio Access to API Services para testar o salvamento"

return table.freeze(DataStoreErrors)
