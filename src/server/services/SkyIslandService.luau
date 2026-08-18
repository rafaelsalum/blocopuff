--!strict

-- Reconstrói de forma controlada o modelo "sky island map" auditado na
-- Toolbox. O original contém somente três MeshParts e nenhum script. A ilha
-- é um cenário visual: jogadores e projéteis atravessam suas malhas para que
-- a zona de eliminação e as regras da arena continuem autoritativas.

local Workspace = game:GetService("Workspace")

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "SkyIslandService"
local MODEL_NAME = "SkyIslandBackdrop"
local SOURCE_ASSET_NAME = "sky island map"

local SOURCE_COLOR = Color3.fromRGB(163, 162, 165)

type MeshDefinition = {
	name: string,
	size: Vector3,
	offset: Vector3,
	meshId: string,
	textureId: string,
}

type IslandPlacement = {
	name: string,
	scale: number,
	pivot: CFrame,
}

local MESH_DEFINITIONS: { MeshDefinition } = {
	{
		name = "TopDetails",
		size = Vector3.new(1.6795371, 0.3279262, 1.587363),
		offset = Vector3.new(0.1296594, 0.1935635, 0.4387748),
		meshId = "rbxassetid://14435559954",
		textureId = "rbxassetid://14435560072",
	},
	{
		name = "IslandSurface",
		size = Vector3.new(1.9149196, 0.5154669, 1.7800651),
		offset = Vector3.new(0.0629193, -0.1277063, 0.3960604),
		meshId = "rbxassetid://14435560594",
		textureId = "rbxassetid://14435560197",
	},
	{
		name = "RockFoundation",
		size = Vector3.new(1.8845371, 0.6995198, 1.6928991),
		offset = Vector3.new(0.0676168, -0.2788017, 0.4190286),
		meshId = "rbxassetid://14435560393",
		textureId = "rbxassetid://14435560456",
	},
}

-- Os pivôs compensam o centro deslocado das malhas originais. A superfície
-- visual fica alguns studs abaixo das plataformas e nunca participa da
-- colisão: ArenaIsland sustenta o palco e LobbyIsland sustenta o lobby.
local ISLAND_PLACEMENTS: { IslandPlacement } = {
	{
		name = "ArenaIsland",
		scale = 80,
		pivot = CFrame.new(-5.03, 14.4, -31.68),
	},
	{
		name = "LobbyIsland",
		scale = 45,
		pivot = CFrame.new(-2.83, 39.9, -147.82),
	},
}

local SkyIslandService = {}

local islandModel: Model? = nil

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function removeDefaultBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate ~= nil and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
end

local function createMesh(
	definition: MeshDefinition,
	placement: IslandPlacement,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = definition.name
	part.Size = definition.size * placement.scale
	part.CFrame = placement.pivot * CFrame.new(definition.offset * placement.scale)
	part.Color = SOURCE_COLOR
	part.Material = Enum.Material.Plastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Parent = parent

	-- MeshPart.MeshId é somente leitura durante a partida. SpecialMesh mantém
	-- os mesmos recursos visuais auditados e pode ser configurado no servidor.
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "VisualMesh"
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = definition.meshId
	mesh.TextureId = definition.textureId
	mesh.Scale = Vector3.one * placement.scale
	mesh.Parent = part

	return part
end

local function createIsland(placement: IslandPlacement, parent: Instance)
	local model = Instance.new("Model")
	model.Name = placement.name
	model.Parent = parent

	for _, definition in ipairs(MESH_DEFINITIONS) do
		createMesh(definition, placement, model)
	end
end

function SkyIslandService.start(worldRoot: Model)
	SkyIslandService.stop()
	removeDefaultBaseplate()

	local existing = worldRoot:FindFirstChild(MODEL_NAME)
	if existing ~= nil then
		if not isOwned(existing) then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	model:SetAttribute("SourceAssetName", SOURCE_ASSET_NAME)
	model.Parent = worldRoot

	for _, placement in ipairs(ISLAND_PLACEMENTS) do
		createIsland(placement, model)
	end

	islandModel = model
end

function SkyIslandService.stop()
	if islandModel ~= nil and islandModel.Parent ~= nil and isOwned(islandModel) then
		islandModel:Destroy()
	end
	islandModel = nil
end

return table.freeze(SkyIslandService)
