--!strict

-- Escadaria da porta principal do Casarão (pura, sem serviços, para rodar no
-- Lune): um patamar no nível do piso logo na saída da porta e degraus
-- descendo para o sul (+Z) até o chão. Quem constrói é o CastleExterior e
-- quem continua o caminho lá fora é o OutdoorService.

export type Settings = { Landing: number, Width: number, Rise: number, Run: number }

export type Step = { minZ: number, maxZ: number, top: number }

export type Plan = {
	minX: number,
	maxX: number,
	-- Patamar: de `wallZ` (face de fora da parede) até `landingEnd`.
	landingEnd: number,
	steps: { Step },
	-- Pé da escadaria, no chão (números soltos: o Lune não tem Vector3).
	foot: { x: number, y: number, z: number },
}

local FrontStairs = {}

-- Degraus iguais, cada um subindo no máximo `Rise`: o último cai no chão.
function FrontStairs.plan(doorX: number, floorY: number, wallZ: number, groundY: number, settings: Settings): Plan
	local drop = math.max(0, floorY - groundY)
	local count = math.max(1, math.ceil(drop / settings.Rise - 1e-6))
	local rise = drop / count
	local landingEnd = wallZ + settings.Landing
	local steps: { Step } = {}
	-- O degrau `count` seria o próprio chão: não precisa de peça.
	for index = 1, count - 1 do
		local minZ = landingEnd + (index - 1) * settings.Run
		table.insert(steps, { minZ = minZ, maxZ = minZ + settings.Run, top = floorY - index * rise })
	end
	local half = settings.Width / 2
	return {
		minX = doorX - half,
		maxX = doorX + half,
		landingEnd = landingEnd,
		steps = steps,
		foot = { x = doorX, y = groundY, z = landingEnd + (count - 1) * settings.Run },
	}
end

return table.freeze(FrontStairs)
