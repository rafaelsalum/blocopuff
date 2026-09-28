--!strict

-- Paredes sólidas (com colisão) e vãos atravessando a espessura. Usado pelo
-- prédio da arena (BuildingService) e pelo Casarão (MansionService).

local BuildingDecor = require(script.Parent.BuildingDecor)

export type Box = { min: Vector3, max: Vector3 }

local WallBuilder = {}

function WallBuilder.createBox(parent: Instance, name: string, box: Box, color: Color3, material: Enum.Material): Part?
	local size = box.max - box.min
	if size.X <= 0.01 or size.Y <= 0.01 or size.Z <= 0.01 then
		return nil
	end
	return BuildingDecor.createPart(parent, name, size, CFrame.new((box.min + box.max) / 2), color, {
		material = material,
		collide = true,
	})
end

-- Parede sólida com vãos atravessando toda a espessura. Os vãos devem
-- estar contidos na parede e não se sobrepor ao longo dela. Vira colunas
-- inteiras entre os vãos e, em cada vão, uma peça abaixo e outra acima.
function WallBuilder.createWallWithHoles(parent: Instance, name: string, wall: Box, holes: { Box }, color: Color3, material: Enum.Material)
	local runsAlongX = (wall.max.X - wall.min.X) > (wall.max.Z - wall.min.Z)
	local function withAlong(v: Vector3, value: number): Vector3
		return if runsAlongX then Vector3.new(value, v.Y, v.Z) else Vector3.new(v.X, v.Y, value)
	end
	local function along(v: Vector3): number
		return if runsAlongX then v.X else v.Z
	end

	local sorted = table.clone(holes)
	table.sort(sorted, function(a, b)
		return along(a.min) < along(b.min)
	end)

	local cursor = along(wall.min)
	for index, hole in ipairs(sorted) do
		WallBuilder.createBox(parent, `{name}Span{index}`, { min = withAlong(wall.min, cursor), max = withAlong(wall.max, along(hole.min)) }, color, material)
		local columnMin = withAlong(wall.min, along(hole.min))
		local columnMax = withAlong(wall.max, along(hole.max))
		WallBuilder.createBox(parent, `{name}Below{index}`, { min = columnMin, max = Vector3.new(columnMax.X, hole.min.Y, columnMax.Z) }, color, material)
		WallBuilder.createBox(parent, `{name}Above{index}`, { min = Vector3.new(columnMin.X, hole.max.Y, columnMin.Z), max = columnMax }, color, material)
		cursor = along(hole.max)
	end
	WallBuilder.createBox(parent, `{name}Span{#sorted + 1}`, { min = withAlong(wall.min, cursor), max = wall.max }, color, material)
end

-- Vão (largura × altura) atravessando a parede inteira, centrado em `point`
-- (face interna, no nível do piso). Passa meio stud de cada lado da parede.
function WallBuilder.hole(point: Vector3, inward: Vector3, along: Vector3, thickness: number, size: Vector2): Box
	local cornerA = point + (along * (size.X / 2)) - (inward * (thickness + 0.5))
	local cornerB = point - (along * (size.X / 2)) + (inward * 0.5) + Vector3.new(0, size.Y, 0)
	return { min = cornerA:Min(cornerB), max = cornerA:Max(cornerB) }
end

return table.freeze(WallBuilder)
