--!strict

-- Contas puras do ambiente do Casarão (Fase 5C.4, parte 2), sem Roblox:
-- quando o relógio da torre toca, quanto um lustre balança e para onde os
-- olhos de um retrato olham. Testes: tests/AmbienceMath.spec.luau.

local AmbienceMath = {}

-- Período do relógio em que `now` (horário do servidor) está.
function AmbienceMath.clockSlot(now: number, period: number): number
	return math.floor(now / period)
end

-- Toca ao entrar num período novo; nunca na primeira conferência.
function AmbienceMath.shouldStrike(previous: number?, slot: number): boolean
	return previous ~= nil and slot > previous
end

-- Força (0..1) do balanço de um lustre a `distance` da porta: cai devagar
-- (quadrado), zero a partir de `radius`.
function AmbienceMath.swingStrength(distance: number, radius: number): number
	if radius <= 0 or distance >= radius then
		return 0
	end
	return 1 - (math.max(distance, 0) / radius) ^ 2
end

-- Ângulo (graus) do balanço `t` segundos depois da batida: oscila e vai
-- parando.
function AmbienceMath.swingAngle(amplitude: number, t: number, damping: number, period: number): number
	if t < 0 or damping <= 0 or period <= 0 then
		return 0
	end
	return amplitude * math.exp(-t / damping) * math.sin(2 * math.pi * t / period)
end

-- Para onde o retrato olha (−1..1 na tela: x para a direita de quem olha,
-- y para baixo), dado o alvo no espaço da tela (x, y, z; a frente é −z).
-- Atrás da tela ou longe: olha para a frente (0, 0).
function AmbienceMath.lookOffset(x: number, y: number, z: number, followDistance: number, soften: number): (number, number)
	local depth = -z
	if depth <= 0 or math.sqrt(x * x + y * y + z * z) > followDistance then
		return 0, 0
	end
	-- A direita de quem olha a face da frente é o −X da peça.
	local lookX = -x / (depth + soften)
	local lookY = -y / (depth + soften)
	local length = math.sqrt(lookX * lookX + lookY * lookY)
	if length > 1 then
		return lookX / length, lookY / length
	end
	return lookX, lookY
end

return table.freeze(AmbienceMath)
