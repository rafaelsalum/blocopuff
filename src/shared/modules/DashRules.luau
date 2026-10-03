--!strict

-- Regras puras do impulso, sem Roblox (testes no Lune:
-- tests/DashRules.spec.luau). Usadas pelo cliente (o próprio personagem),
-- pelo servidor (conferência e bots RoboPuff).
--
--   * Um impulso a cada `Cooldown` segundos.
--   * No ar, no máximo `AirDashesPerJump` impulsos por pulo; tocar o chão
--     devolve (o intervalo continua valendo).
--   * O servidor só confere o intervalo, com folga para a latência.

export type DashState = {
	-- Quando (relógio de quem simula) o próximo impulso fica pronto.
	readyAt: number,
	-- Impulsos usados no ar desde o último toque no chão.
	airDashes: number,
}

export type DashLimits = {
	Cooldown: number,
	AirDashesPerJump: number,
	ServerTolerance: number,
}

local DashRules = {}

function DashRules.new(): DashState
	return { readyAt = -math.huge, airDashes = 0 }
end

function DashRules.canDash(state: DashState, now: number, grounded: boolean, limits: DashLimits): boolean
	if now < state.readyAt then
		return false
	end
	return grounded or state.airDashes < limits.AirDashesPerJump
end

function DashRules.afterDash(state: DashState, now: number, grounded: boolean, limits: DashLimits): DashState
	return {
		readyAt = now + limits.Cooldown,
		airDashes = if grounded then state.airDashes else state.airDashes + 1,
	}
end

function DashRules.landed(state: DashState): DashState
	return { readyAt = state.readyAt, airDashes = 0 }
end

-- Segundos até o próximo impulso (0 se pronto).
function DashRules.remaining(state: DashState, now: number): number
	return math.max(0, state.readyAt - now)
end

-- O servidor aceita o impulso? `lastAccepted` nil: primeiro impulso.
function DashRules.serverAccepts(lastAccepted: number?, now: number, limits: DashLimits): boolean
	if lastAccepted == nil then
		return true
	end
	return now - lastAccepted >= limits.Cooldown - limits.ServerTolerance
end

return table.freeze(DashRules)
