--!strict

-- Regras de preenchimento com bots RoboPuff (Fase 5B), sem Roblox: quantos
-- bots completam a partida e quando eles podem chegar ao mirante. Os testes
-- rodam no Lune (tests/BotFillRules.spec.luau).
--
-- Bot completa, não substitui: só entra para chegar a `TargetCombatants`
-- combatentes, nunca passa de `MaxBots` e some quando há humanos
-- suficientes. Também nunca há partida só de bots.

export type FillConfig = {
	Enabled: boolean,
	-- Tamanho mínimo divertido da partida (humanos + bots).
	TargetCombatants: number,
	MaxBots: number,
	-- Espera (s) com gente na fila antes de os bots chegarem pela primeira vez.
	WaitSeconds: number,
}

local BotFillRules = {}

-- Bots que completam uma partida com `humans` humanos na fila.
function BotFillRules.desiredBots(humans: number, config: FillConfig): number
	if not config.Enabled or humans < 1 or humans >= config.TargetCombatants then
		return 0
	end
	return math.clamp(config.TargetCombatants - humans, 0, config.MaxBots)
end

-- Os bots podem vir agora? `waited` é há quanto tempo (s) há gente na fila
-- sem completar a partida; `warm` diz que a partida anterior já teve bots
-- (quem volta para o mirante não espera de novo).
function BotFillRules.canFill(humans: number, waited: number, warm: boolean, config: FillConfig): boolean
	if BotFillRules.desiredBots(humans, config) <= 0 then
		return false
	end
	return warm or waited >= config.WaitSeconds
end

-- Quantos bots entram (positivo) ou saem (negativo) do mirante, com `pool`
-- bots já lá. Sem permissão para chegar, os bots que já estão ficam, mas o
-- excesso (humanos chegaram) sai.
function BotFillRules.adjustment(humans: number, pool: number, allowed: boolean, config: FillConfig): number
	local difference = BotFillRules.desiredBots(humans, config) - pool
	if allowed then
		return difference
	end
	return math.min(0, difference)
end

return table.freeze(BotFillRules)
