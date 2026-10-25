--!strict

-- Limites do lado de fora: uma muralha invisível em anel, antes das
-- montanhas, para ninguém sair do mapa (alta demais para pular, e funda o
-- bastante para não passar por baixo nos vales), e uma cerca invisível em
-- volta da Ala do Assassinato, para quem passeia não entrar nem atrapalhar
-- uma partida lá dentro.

local WALL_THICKNESS = 2

local OutdoorBounds = {}

local function wall(parent: Instance, name: string, from: Vector3, to: Vector3, bottom: number, top: number)
	local length = (to - from).Magnitude
	local middle = (from + to) / 2
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(WALL_THICKNESS, top - bottom, length + WALL_THICKNESS)
	part.CFrame = CFrame.lookAt(Vector3.new(middle.X, (bottom + top) / 2, middle.Z), Vector3.new(to.X, (bottom + top) / 2, to.Z))
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Parent = parent
end

-- Muralha em anel de raio `radius` em volta de (centerX, centerZ), de
-- `bottom` a `top`, em `segments` pedaços.
function OutdoorBounds.ring(parent: Instance, centerX: number, centerZ: number, radius: number, segments: number, bottom: number, top: number)
	-- Cada pedaço liga um ponto do anel ao próximo (um pouco mais comprido,
	-- para não ficar fresta nos cantos).
	local function point(index: number): Vector3
		local angle = index * 2 * math.pi / segments
		return Vector3.new(centerX + math.cos(angle) * radius, 0, centerZ + math.sin(angle) * radius)
	end
	for index = 0, segments - 1 do
		wall(parent, "MapBound", point(index), point(index + 1), bottom, top)
	end
end

-- Cerca em volta do retângulo de (minX, minZ) a (maxX, maxZ), de `bottom` a
-- `top`.
function OutdoorBounds.box(parent: Instance, minX: number, minZ: number, maxX: number, maxZ: number, bottom: number, top: number)
	local corners = {
		Vector3.new(minX, 0, minZ),
		Vector3.new(maxX, 0, minZ),
		Vector3.new(maxX, 0, maxZ),
		Vector3.new(minX, 0, maxZ),
	}
	for index, corner in ipairs(corners) do
		wall(parent, "WingFence", corner, corners[index % #corners + 1], bottom, top)
	end
end

return table.freeze(OutdoorBounds)
