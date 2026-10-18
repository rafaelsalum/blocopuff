--!strict

-- Faca 3D do Assassinato no Casarão (Fase 5E.4): o modelo gratuito "Knife
-- model" da Creator Store (asset 3576051114, a faca clássica dos jogos de
-- assassinato), refeito aqui como uma peça com FileMesh, que dá para montar
-- por código (sem arquivo binário). Usada na mão do Assassino, no arremesso
-- (servidor) e na mão em primeira pessoa (cliente).
-- A malha original é comprida no eixo Y; `KnifeMesh.part` devolve a peça já
-- deitada com a ponta para -Z, o cabo em +Z e o centro do cabo na origem.

local KnifeMesh = {}

local MESH_ID = "rbxassetid://121944778"
local TEXTURE_ID = "rbxassetid://121944805"
-- Tamanho da peça original (escala 1 da malha).
local NATIVE_SIZE = Vector3.new(0.4, 3, 0.8)
-- A ponta da malha original fica no +Y: gira para a ponta ir para -Z.
local LAY_DOWN = CFrame.Angles(-math.pi / 2, 0, 0)
-- Do centro da malha até o meio do cabo (fração do comprimento).
local GRIP_FRACTION = 0.33

-- Peça da faca no tamanho `scale` (1 = original, 3 studs de comprimento).
function KnifeMesh.part(name: string, scale: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = NATIVE_SIZE * scale
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = MESH_ID
	mesh.TextureId = TEXTURE_ID
	mesh.Scale = Vector3.one * scale
	mesh.Parent = part
	return part
end

-- Onde pôr a peça (no espaço da mão: frente -Z, cima +Y) para o cabo ficar
-- na mão e a ponta para a frente.
function KnifeMesh.inHand(scale: number): CFrame
	return CFrame.new(0, 0, -NATIVE_SIZE.Y * scale * GRIP_FRACTION) * LAY_DOWN
end

-- Comprimento da faca no tamanho `scale`.
function KnifeMesh.length(scale: number): number
	return NATIVE_SIZE.Y * scale
end

return table.freeze(KnifeMesh)
