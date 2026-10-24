--!strict

-- O que as armadilhas rendem para quem acionou (Fase 5.8):
--   * Momento Puff quando uma armadilha derruba alguém ("VIDRAÇA! 💨",
--     "PUXOU O TAPETE! 🧶", "LUSTRE! 💡", "ATCHIM! 🤧");
--   * conquistas secretas: Vidraceiro (5 janelas quebradas de longe na
--     mesma partida), Puxa-Tapete (derrubar alguém com o tapete) e Lustre
--     na Cabeça (2 derrubados pelo mesmo lustre);
--   * estatísticas da rodada para os desafios diários (armadilhas
--     acionadas e derrubadas de humanos por armadilha);
--   * telemetria da derrubada (TrapKnockout).
-- Bots acionam e derrubam, mas só jogadores ganham alguma coisa.

local CombatantRegistry = require(script.Parent.CombatantRegistry)
local KnockbackService = require(script.Parent.KnockbackService)
local PuffMomentService = require(script.Parent.PuffMomentService)
local RoundStatsService = require(script.Parent.RoundStatsService)
local SecretAchievementService = require(script.Parent.SecretAchievementService)
local TelemetryService = require(script.Parent.TelemetryService)
local TrapMomentRules = require(script.Parent.Parent.data.TrapMomentRules)

type Combatant = CombatantRegistry.Combatant
type HitSource = KnockbackService.HitSource

local WINDOW_KIND = "Window"

local TrapMoments = {}

-- Por rodada: janelas quebradas por jogador e vítimas por armadilha de cada
-- jogador.
local windowsBroken: { [Player]: number } = {}
local victimsByTrap: { [Player]: { [string]: number } } = {}

-- Alguém acionou uma armadilha de longe (o tiro valeu).
function TrapMoments.triggered(shooter: Combatant, trapKind: string)
	RoundStatsService.trapTriggered(shooter)
	local player = shooter.player
	if player == nil or trapKind ~= WINDOW_KIND then
		return
	end
	local count = (windowsBroken[player] or 0) + 1
	windowsBroken[player] = count
	local secret = TrapMomentRules.secretForWindows(count)
	if secret ~= nil then
		SecretAchievementService.trapFeat(player, secret)
	end
end

-- A armadilha `source`, acionada por `attacker`, derrubou `victim`.
function TrapMoments.knockout(attacker: Combatant, victim: Combatant, source: HitSource)
	if TrapMomentRules.countsForStats(CombatantRegistry.isBot(victim)) then
		RoundStatsService.trapKnockout(attacker)
	end
	local player = attacker.player
	if player == nil then
		return
	end
	TelemetryService.event(player, "TrapKnockout", 1, source.kind, source.id)
	local moment = TrapMomentRules.momentFor(source.kind)
	if moment ~= nil then
		PuffMomentService.record(player, moment :: PuffMomentService.MomentKind, source.kind)
	end
	local byTrap = victimsByTrap[player] or {}
	victimsByTrap[player] = byTrap
	local sameTrap = (byTrap[source.id] or 0) + 1
	byTrap[source.id] = sameTrap
	local secret = TrapMomentRules.secretForKnockout(source.kind, sameTrap)
	if secret ~= nil then
		SecretAchievementService.trapFeat(player, secret)
	end
end

function TrapMoments.beginRound()
	table.clear(windowsBroken)
	table.clear(victimsByTrap)
end

function TrapMoments.endRound()
	table.clear(windowsBroken)
	table.clear(victimsByTrap)
end

return table.freeze(TrapMoments)
