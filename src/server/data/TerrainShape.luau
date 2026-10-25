--!strict

-- Regras puras do chão do lado de fora: a altura e o material de cada ponto,
-- com morros suaves, o lago, o anel de montanhas e o chão plano em volta das
-- construções (o Casarão, a ilha da Torre e a Ala do Assassinato), onde o
-- terreno encosta na base delas sem buraco nem degrau. Sem dependências (os
-- testes do Lune carregam este arquivo direto).

-- Os mesmos campos de OutdoorConfig.Terrain usados aqui.
export type Terrain = {
	GroundY: number,
	HalfExtent: number,
	HillAmplitude: number,
	HillScale: number,
	Mountains: {
		CenterX: number,
		CenterZ: number,
		InnerRadius: number,
		OuterRadius: number,
		PeakHeight: number,
	},
	Lake: {
		X: number,
		Z: number,
		Radius: number,
		WaterY: number,
		Depth: number,
		ShoreWobble: number,
	},
}

export type ZoneKind = "Box" | "Circle" | "Segment"

-- Chão plano na altura `y` em volta de uma construção, que volta ao chão
-- natural ao longo de `blend` studs. Box: de (ax, az) a (bx, bz). Circle:
-- centro (ax, az) e `radius`. Segment: faixa de (ax, az) a (bx, bz) com meia
-- largura `radius`.
export type Zone = {
	kind: ZoneKind,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	radius: number,
	y: number,
	blend: number,
}

-- Retângulo sem terreno (o poço da Arena, que fica abaixo do chão). Sem
-- `top`, a coluna inteira fica vazia; com `top`, só abaixo dessa altura (uma
-- sala enterrada com chão por cima).
export type Carve = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	top: number?,
}

-- Caminho de pedra de (ax, az) a (bx, bz), com meia largura `halfWidth`
-- (não aplaina o chão: só troca o material).
export type Path = {
	ax: number,
	az: number,
	bx: number,
	bz: number,
	halfWidth: number,
}

export type Shape = {
	terrain: Terrain,
	zones: { Zone },
	carves: { Carve },
	paths: { Path },
}

-- Até onde a margem do lago desce suave até a água (fração do raio).
local SHORE_WIDTH = 0.5
-- Altura da margem logo acima da água.
local SHORE_LIFT = 0.4
-- Escalas do ruído das cristas das montanhas, da margem do lago e das
-- manchas de grama, folhas e terra.
local RIDGE_SCALE = 170
local SHORE_SCALE = 70
local PATCH_SCALE = 90
-- Manchinhas de terra no gramado: pequenas e raras.
local DIRT_SCALE = 35
local DIRT_THRESHOLD = 0.42
-- Inclinações (subida por stud) em que a encosta vira pedra.
local SLATE_SLOPE = 0.7
local ROCK_SLOPE = 1.1
-- Faixa de terra na beira dos caminhos de pedra.
local PATH_VERGE = 1.5
-- Alturas acima do chão em que a montanha perde a grama.
local HIGHLAND_HEIGHT = 120
local SUMMIT_HEIGHT = 210

local TerrainShape = {}

function TerrainShape.new(terrain: Terrain, zones: { Zone }, carves: { Carve }, paths: { Path }?): Shape
	return table.freeze({
		terrain = terrain,
		zones = table.freeze(table.clone(zones)),
		carves = table.freeze(table.clone(carves)),
		paths = table.freeze(table.clone(paths or {})),
	})
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Distância do ponto (x, z) até o segmento de (ax, az) a (bx, bz).
local function distanceToSegment(x: number, z: number, ax: number, az: number, bx: number, bz: number): number
	local sx, sz = bx - ax, bz - az
	local lengthSquared = sx * sx + sz * sz
	local t = if lengthSquared > 0 then math.clamp(((x - ax) * sx + (z - az) * sz) / lengthSquared, 0, 1) else 0
	local dx, dz = x - (ax + sx * t), z - (az + sz * t)
	return math.sqrt(dx * dx + dz * dz)
end

-- Distância do ponto até a zona (0 dentro dela).
local function distanceOutside(zone: Zone, x: number, z: number): number
	if zone.kind == "Box" then
		local dx = math.max(zone.ax - x, 0, x - zone.bx)
		local dz = math.max(zone.az - z, 0, z - zone.bz)
		return math.sqrt(dx * dx + dz * dz)
	elseif zone.kind == "Circle" then
		local dx, dz = x - zone.ax, z - zone.az
		return math.max(0, math.sqrt(dx * dx + dz * dz) - zone.radius)
	end
	return math.max(0, distanceToSegment(x, z, zone.ax, zone.az, zone.bx, zone.bz) - zone.radius)
end

-- Distância do ponto até o caminho de pedra mais perto (0 em cima dele).
function TerrainShape.pathDistance(shape: Shape, x: number, z: number): number
	local nearest = math.huge
	for _, path in ipairs(shape.paths) do
		nearest = math.min(nearest, math.max(0, distanceToSegment(x, z, path.ax, path.az, path.bx, path.bz) - path.halfWidth))
	end
	return nearest
end

-- Distância até o centro do lago, em raios (com a margem irregular).
function TerrainShape.lakeDistance(shape: Shape, x: number, z: number): number
	local lake = shape.terrain.Lake
	local dx, dz = x - lake.X, z - lake.Z
	local wobble = 1 + lake.ShoreWobble * 2 * math.noise(x / SHORE_SCALE, z / SHORE_SCALE, 5.5)
	return math.sqrt(dx * dx + dz * dz) / (lake.Radius * wobble)
end

-- Altura do chão sem as construções: morros, montanhas e o lago.
function TerrainShape.naturalHeight(shape: Shape, x: number, z: number): number
	local terrain = shape.terrain
	local scale = terrain.HillScale
	local hills = math.noise(x / scale, z / scale, 0.31) + 0.5 * math.noise(x * 2.7 / scale, z * 2.7 / scale, 1.7)
	local height = terrain.GroundY + hills * terrain.HillAmplitude

	local mountains = terrain.Mountains
	local mx, mz = x - mountains.CenterX, z - mountains.CenterZ
	local rise = math.clamp((math.sqrt(mx * mx + mz * mz) - mountains.InnerRadius) / (mountains.OuterRadius - mountains.InnerRadius), 0, 1)
	if rise > 0 then
		local ridge = 1 - math.min(1, math.abs(math.noise(x / RIDGE_SCALE, z / RIDGE_SCALE, 2.3)) * 2)
		height += ease(rise) * mountains.PeakHeight * (0.55 + 0.45 * ridge)
	end

	local lake = terrain.Lake
	local distance = TerrainShape.lakeDistance(shape, x, z)
	if distance < 1 then
		height = math.min(height, lake.WaterY - lake.Depth * (1 - distance * distance))
	elseif distance < 1 + SHORE_WIDTH then
		height = mix(lake.WaterY + SHORE_LIFT, height, ease((distance - 1) / SHORE_WIDTH))
	end
	return height
end

-- Altura do chão no ponto, já assentado em volta das construções.
function TerrainShape.heightAt(shape: Shape, x: number, z: number): number
	local height = TerrainShape.naturalHeight(shape, x, z)
	for _, zone in ipairs(shape.zones) do
		local distance = distanceOutside(zone, x, z)
		if distance < zone.blend then
			height = mix(height, zone.y, ease(1 - distance / zone.blend))
		end
	end
	return height
end

-- Distância até a construção mais perto (0 em cima de uma).
function TerrainShape.clearance(shape: Shape, x: number, z: number): number
	local nearest = math.huge
	for _, zone in ipairs(shape.zones) do
		nearest = math.min(nearest, distanceOutside(zone, x, z))
	end
	return nearest
end

-- A coluna de terreno com centro em (x, z) e meia largura `half` encosta em
-- algum retângulo sem terreno?
-- Até que altura a coluna em (x, z), com meia largura `half`, fica sem
-- terreno: nil (nada escavado), math.huge (a coluna inteira) ou o `top` mais
-- alto dos recortes que ela encosta.
function TerrainShape.carveTop(shape: Shape, x: number, z: number, half: number): number?
	local top: number? = nil
	for _, carve in ipairs(shape.carves) do
		if x + half > carve.minX and x - half < carve.maxX and z + half > carve.minZ and z - half < carve.maxZ then
			local reach = carve.top or math.huge
			top = if top == nil then reach else math.max(top, reach)
		end
	end
	return top
end

function TerrainShape.isCarved(shape: Shape, x: number, z: number, half: number): boolean
	for _, carve in ipairs(shape.carves) do
		if x + half > carve.minX and x - half < carve.maxX and z + half > carve.minZ and z - half < carve.maxZ then
			return true
		end
	end
	return false
end

-- O ponto está na bacia do lago (onde a água enche até o nível dela)?
function TerrainShape.inLake(shape: Shape, x: number, z: number): boolean
	return TerrainShape.lakeDistance(shape, x, z) < 1 + SHORE_WIDTH
end

-- O ponto está dentro do quadrado coberto pelo terreno?
function TerrainShape.inBounds(shape: Shape, x: number, z: number): boolean
	local terrain = shape.terrain
	local half = terrain.HalfExtent
	return math.abs(x - terrain.Mountains.CenterX) <= half and math.abs(z - terrain.Mountains.CenterZ) <= half
end

-- Inclinação do chão (subida por stud) medida a `step` studs para cada lado.
function TerrainShape.slopeAt(shape: Shape, x: number, z: number, step: number): number
	local dx = TerrainShape.heightAt(shape, x + step, z) - TerrainShape.heightAt(shape, x - step, z)
	local dz = TerrainShape.heightAt(shape, x, z + step) - TerrainShape.heightAt(shape, x, z - step)
	return math.sqrt(dx * dx + dz * dz) / (2 * step)
end

-- Nome do material do terreno (Enum.Material) na superfície do ponto.
function TerrainShape.materialAt(shape: Shape, x: number, z: number, height: number, slope: number): string
	local terrain = shape.terrain
	local lake = TerrainShape.lakeDistance(shape, x, z)
	if lake < 1 + SHORE_WIDTH / 3 and height < terrain.Lake.WaterY + 1.5 then
		return if lake < 1 then "Mud" else "Ground"
	end
	local path = TerrainShape.pathDistance(shape, x, z)
	if path == 0 then
		return "Cobblestone"
	elseif path < PATH_VERGE then
		return "Ground"
	end
	if slope > ROCK_SLOPE then
		return "Rock"
	elseif slope > SLATE_SLOPE then
		return "Slate"
	end
	local above = height - terrain.GroundY
	if above > SUMMIT_HEIGHT then
		return "Rock"
	end
	local patch = math.noise(x / PATCH_SCALE, z / PATCH_SCALE, 7.7)
	if above > HIGHLAND_HEIGHT then
		return if patch > 0 then "Rock" else "Ground"
	elseif patch > 0.22 then
		return "LeafyGrass"
	elseif math.noise(x / DIRT_SCALE, z / DIRT_SCALE, 3.9) < -DIRT_THRESHOLD then
		return "Ground"
	end
	return "Grass"
end

return table.freeze(TerrainShape)
