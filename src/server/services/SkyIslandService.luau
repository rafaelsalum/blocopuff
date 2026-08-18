--!strict

-- Reconstrói de forma controlada o modelo "sky island map" auditado na
-- Toolbox. O original contém três MeshParts e nenhum script. Esta versão usa
-- uma envoltória de colisão estável no terreno para transformar a ilha em um
-- lobby explorável, sem depender de uma plataforma visual separada.

local AssetService = game:GetService("AssetService")
local Workspace = game:GetService("Workspace")

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "SkyIslandService"
local MODEL_NAME = "SkyIslandLobby"
local LEGACY_MODEL_NAME = "SkyIslandBackdrop"
local SOURCE_ASSET_NAME = "sky island map"

local ISLAND_SCALE = 100
-- Compensa o pivô deslocado do modelo e mantém a base visual centralizada.
local ISLAND_PIVOT = CFrame.new(-6.29, 24.25, -39.61)
local SOURCE_COLOR = Color3.fromRGB(163, 162, 165)

type MeshDefinition = {
	name: string,
	size: Vector3,
	offset: Vector3,
	meshId: string,
	textureId: string,
	useHullCollision: boolean,
}

local MESH_DEFINITIONS: { MeshDefinition } = {
	{
		name = "TopDetails",
		size = Vector3.new(1.6795371, 0.3279262, 1.587363),
		offset = Vector3.new(0.1296594, 0.1935635, 0.4387748),
		meshId = "rbxassetid://14435559954",
		textureId = "rbxassetid://14435560072",
		useHullCollision = false,
	},
	{
		name = "IslandSurface",
		size = Vector3.new(1.9149196, 0.5154669, 1.7800651),
		offset = Vector3.new(0.0629193, -0.1277063, 0.3960604),
		meshId = "rbxassetid://14435560594",
		textureId = "rbxassetid://14435560197",
		useHullCollision = true,
	},
	{
		name = "RockFoundation",
		size = Vector3.new(1.8845371, 0.6995198, 1.6928991),
		offset = Vector3.new(0.0676168, -0.2788017, 0.4190286),
		meshId = "rbxassetid://14435560393",
		textureId = "rbxassetid://14435560456",
		useHullCollision = true,
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

local function destroyOwnedModel(worldRoot: Model, name: string)
	local existing = worldRoot:FindFirstChild(name)
	if existing == nil then
		return
	end
	if not isOwned(existing) then
		error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
	end
	existing:Destroy()
end

local function createMesh(definition: MeshDefinition, parent: Instance): MeshPart
	local collisionFidelity = if definition.useHullCollision
		then Enum.CollisionFidelity.Hull
		else Enum.CollisionFidelity.PreciseConvexDecomposition
	local mesh = AssetService:CreateMeshPartAsync(Content.fromUri(definition.meshId), {
		CollisionFidelity = collisionFidelity,
		RenderFidelity = Enum.RenderFidelity.Automatic,
	})
	mesh.Name = definition.name
	mesh.TextureID = definition.textureId
	mesh.Size = definition.size * ISLAND_SCALE
	mesh.CFrame = ISLAND_PIVOT * CFrame.new(definition.offset * ISLAND_SCALE)
	mesh.Color = SOURCE_COLOR
	mesh.Material = Enum.Material.Plastic
	mesh.Anchored = true
	mesh.CanCollide = true
	mesh.CanTouch = false
	mesh.CanQuery = true
	mesh.CastShadow = true
	mesh.Parent = parent
	return mesh
end

function SkyIslandService.start(worldRoot: Model)
	SkyIslandService.stop()
	removeDefaultBaseplate()
	destroyOwnedModel(worldRoot, LEGACY_MODEL_NAME)
	destroyOwnedModel(worldRoot, MODEL_NAME)

	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	model:SetAttribute("SourceAssetName", SOURCE_ASSET_NAME)

	local ok, failure = pcall(function()
		for _, definition in ipairs(MESH_DEFINITIONS) do
			createMesh(definition, model)
		end
	end)
	if not ok then
		model:Destroy()
		error(`Cannot create sky island lobby: {tostring(failure)}`)
	end

	model.Parent = worldRoot
	islandModel = model
end

function SkyIslandService.stop()
	if islandModel ~= nil and islandModel.Parent ~= nil and isOwned(islandModel) then
		islandModel:Destroy()
	end
	islandModel = nil
end

return table.freeze(SkyIslandService)
