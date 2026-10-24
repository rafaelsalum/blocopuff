--!strict

-- Regras puras do passeio até a Torre do Relógio: onde a muralha da ilha
-- abre o portão (virado para o Saguão da Torre), a inclinação da ponte e
-- quem atravessa o portão mágico da largada da rampa (só quem corre na
-- Corrida). Sem dependências (os testes do Lune carregam este arquivo
-- direto).

local TowerPathRules = {}

local RACE_MODE = "Race"

-- Ponto da borda do círculo (centro, raio) virado para (fromX, fromZ), e o
-- ângulo dele (0 = +X, cresce para +Z).
function TowerPathRules.gate(centerX: number, centerZ: number, radius: number, fromX: number, fromZ: number): (number, number, number)
	local dx, dz = fromX - centerX, fromZ - centerZ
	local angle = if dx == 0 and dz == 0 then 0 else math.atan2(dz, dx)
	return angle, centerX + math.cos(angle) * radius, centerZ + math.sin(angle) * radius
end

-- Inclinação (graus) do trecho de (ax, ay, az) a (bx, by, bz).
function TowerPathRules.slopeDegrees(ax: number, ay: number, az: number, bx: number, by: number, bz: number): number
	local horizontal = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	return math.deg(math.atan2(math.abs(by - ay), horizontal))
end

-- O portão da largada deixa passar quem está correndo agora.
function TowerPathRules.startGateOpen(isParticipant: boolean, isEliminated: boolean, roundMode: string?): boolean
	return isParticipant and not isEliminated and roundMode == RACE_MODE
end

return table.freeze(TowerPathRules)
