--!strict

-- Regras puras dos postes de lampião do lado de fora: onde ficam (em volta
-- de um retângulo, como o das construções) e se estão acesos numa hora do
-- dia. Sem dependências (os testes do Lune carregam este arquivo direto).

export type Spot = {
	x: number,
	z: number,
}

local LampLayout = {}

-- Postes em volta do retângulo de (minX, minZ) a (maxX, maxZ), afastados
-- `offset` dele, um em cada canto e os outros a no máximo `spacing` entre
-- si em cada lado.
function LampLayout.around(minX: number, minZ: number, maxX: number, maxZ: number, offset: number, spacing: number): { Spot }
	local x0, z0, x1, z1 = minX - offset, minZ - offset, maxX + offset, maxZ + offset
	local spots: { Spot } = {}
	local sides = {
		{ x0, z0, x1, z0 },
		{ x1, z0, x1, z1 },
		{ x1, z1, x0, z1 },
		{ x0, z1, x0, z0 },
	}
	for _, side in ipairs(sides) do
		local ax, az, bx, bz = side[1], side[2], side[3], side[4]
		local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local steps = math.max(1, math.ceil(length / spacing))
		-- O fim de um lado é o começo do próximo: cada canto entra uma vez.
		for step = 0, steps - 1 do
			local t = step / steps
			table.insert(spots, { x = ax + (bx - ax) * t, z = az + (bz - az) * t })
		end
	end
	return spots
end

-- Os lampiões estão acesos na hora `clock`? Acendem em `onHour` e apagam
-- em `offHour` do dia seguinte.
function LampLayout.isLit(clock: number, onHour: number, offHour: number): boolean
	local hour = clock % 24
	if onHour > offHour then
		return hour >= onHour or hour < offHour
	end
	return hour >= onHour and hour < offHour
end

return table.freeze(LampLayout)
