--!strict

-- Escreve no Terrain o chão do lado de fora descrito por TerrainShape:
-- grama, folhas e terra nas partes planas, pedra nas encostas e no alto das
-- montanhas, lama e água no lago. Só uma casca embaixo da superfície
-- (ninguém vê por baixo). Vai em pedaços, com uma pausa entre eles, para o
-- servidor não travar.

local Workspace = game:GetService("Workspace")

local TerrainShape = require(script.Parent.Parent.data.TerrainShape)

type Shape = TerrainShape.Shape

export type Settings = {
	Resolution: number,
	SkinDepth: number,
	ChunkCells: number,
}

-- Cores dos materiais: grama mais escura e fria das Terras Altas.
local MATERIAL_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(84, 102, 56),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(70, 86, 44),
	[Enum.Material.Ground] = Color3.fromRGB(94, 80, 62),
	[Enum.Material.Mud] = Color3.fromRGB(64, 54, 44),
	[Enum.Material.Rock] = Color3.fromRGB(104, 100, 96),
	[Enum.Material.Slate] = Color3.fromRGB(86, 88, 90),
}
local WATER_COLOR = Color3.fromRGB(28, 52, 58)
local WATER_TRANSPARENCY = 0.45
local WATER_REFLECTANCE = 0.6
local WATER_WAVE_SIZE = 0.08
local WATER_WAVE_SPEED = 6
-- Abaixo desta profundidade a casca vira terra (aparece só nos barrancos).
local DEEP_DEPTH = 8
-- Distância (studs) para medir a inclinação.
local SLOPE_STEP = 4

local OutdoorTerrain = {}

local function setLook(terrain: Terrain)
	for material, color in pairs(MATERIAL_COLORS) do
		terrain:SetMaterialColor(material, color)
	end
	terrain.WaterColor = WATER_COLOR
	terrain.WaterTransparency = WATER_TRANSPARENCY
	terrain.WaterReflectance = WATER_REFLECTANCE
	terrain.WaterWaveSize = WATER_WAVE_SIZE
	terrain.WaterWaveSpeed = WATER_WAVE_SPEED
end

type Column = { height: number, material: Enum.Material, carved: boolean, wet: boolean }

local function sampleColumn(shape: Shape, x: number, z: number, half: number): Column
	if TerrainShape.isCarved(shape, x, z, half) then
		return { height = -math.huge, material = Enum.Material.Air, carved = true, wet = false }
	end
	local height = TerrainShape.heightAt(shape, x, z)
	local slope = TerrainShape.slopeAt(shape, x, z, SLOPE_STEP)
	local name = TerrainShape.materialAt(shape, x, z, height, slope)
	local wet = TerrainShape.inLake(shape, x, z) and height < shape.terrain.Lake.WaterY
	return { height = height, material = (Enum.Material :: any)[name], carved = false, wet = wet }
end

-- Escreve o pedaço que começa em (x0, z0), com `cells` colunas de lado.
local function writeChunk(terrain: Terrain, shape: Shape, settings: Settings, x0: number, z0: number, cells: number)
	local resolution = settings.Resolution
	local half = resolution / 2
	local waterY = shape.terrain.Lake.WaterY
	local columns: { { Column } } = {}
	local low, high = math.huge, -math.huge
	for i = 1, cells do
		local row = {}
		for k = 1, cells do
			local column = sampleColumn(shape, x0 + (i - 0.5) * resolution, z0 + (k - 0.5) * resolution, half)
			row[k] = column
			if not column.carved then
				low = math.min(low, column.height - settings.SkinDepth)
				high = math.max(high, if column.wet then waterY else column.height)
			end
		end
		columns[i] = row
	end
	if low == math.huge then
		return
	end
	local minY = math.floor(low / resolution) * resolution
	local maxY = math.ceil(high / resolution) * resolution + resolution
	local layers = (maxY - minY) / resolution
	local materials, occupancies = {}, {}
	for i = 1, cells do
		local materialPlane, occupancyPlane = {}, {}
		for j = 1, layers do
			local bottom = minY + (j - 1) * resolution
			local materialRow, occupancyRow = {}, {}
			for k = 1, cells do
				local column = columns[i][k]
				local material, occupancy = Enum.Material.Air, 0
				if not column.carved then
					local solid = math.clamp((column.height - bottom) / resolution, 0, 1)
					if solid > 0 then
						material = if column.height - bottom > DEEP_DEPTH + resolution then Enum.Material.Ground else column.material
						occupancy = solid
					elseif column.wet and bottom < waterY then
						material = Enum.Material.Water
						occupancy = math.clamp((waterY - bottom) / resolution, 0, 1)
					end
				end
				materialRow[k] = material
				occupancyRow[k] = occupancy
			end
			materialPlane[j] = materialRow
			occupancyPlane[j] = occupancyRow
		end
		materials[i] = materialPlane
		occupancies[i] = occupancyPlane
	end
	local region = Region3.new(Vector3.new(x0, minY, z0), Vector3.new(x0 + cells * resolution, maxY, z0 + cells * resolution))
	terrain:WriteVoxels(region, resolution, materials, occupancies)
end

-- Monta o terreno todo (espera, pedaço por pedaço).
function OutdoorTerrain.build(shape: Shape, settings: Settings)
	local terrain = Workspace.Terrain
	setLook(terrain)
	local resolution = settings.Resolution
	local mountains = shape.terrain.Mountains
	local half = shape.terrain.HalfExtent
	local chunkSize = settings.ChunkCells * resolution
	local startX = math.floor((mountains.CenterX - half) / resolution) * resolution
	local startZ = math.floor((mountains.CenterZ - half) / resolution) * resolution
	local chunks = math.ceil(2 * half / chunkSize)
	for cx = 0, chunks - 1 do
		for cz = 0, chunks - 1 do
			writeChunk(terrain, shape, settings, startX + cx * chunkSize, startZ + cz * chunkSize, settings.ChunkCells)
			task.wait()
		end
	end
end

return table.freeze(OutdoorTerrain)
