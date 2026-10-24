--!strict

-- Telemetria do Assassinato no Casarão sobre alguém que pode ser bot (Fase
-- 5E.4). O TelemetryService não registra bots, então o evento vai pela conta
-- do próprio humano ou, se for bot, do primeiro humano da partida.

local CombatantRegistry = require(script.Parent.CombatantRegistry)
local TelemetryService = require(script.Parent.TelemetryService)

type Combatant = CombatantRegistry.Combatant

local MurderTelemetry = {}

local function reporterFor(order: { Combatant }, about: Combatant?): Player?
	if about ~= nil and about.player ~= nil then
		return about.player
	end
	for _, other in ipairs(order) do
		if other.player ~= nil then
			return other.player
		end
	end
	return nil
end

-- Contexto: "Human" ou "Bot" (com o nome do bot no detalhe).
function MurderTelemetry.event(order: { Combatant }, about: Combatant?, name: string)
	local reporter = reporterFor(order, about)
	if reporter == nil then
		return
	end
	local isBot = about ~= nil and about.player == nil
	TelemetryService.event(reporter, name, nil, if isBot then "Bot" else "Human", if isBot and about ~= nil then about.name else nil)
end

return table.freeze(MurderTelemetry)
