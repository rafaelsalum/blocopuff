--!strict

-- Direção de arte criada somente com instâncias nativas. Os efeitos de
-- Lighting e a decoração pertencem ao serviço e podem ser removidos sem
-- interferir em conteúdo que tenha sido colocado manualmente no Studio.

local Lighting = game:GetService("Lighting")

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "WorldVisualService"
local VISUALS_NAME = "WorldVisuals"

local ATMOSPHERE_NAME = "BlocoPuffAtmosphere"
local BLOOM_NAME = "BlocoPuffBloom"
local COLOR_CORRECTION_NAME = "BlocoPuffColorCorrection"

local CLOUD_COUNT = 8
local CLOUD_CENTER = Vector3.new(0, 0, -60)
local CLOUD_RADIUS = 135

type WorldPalette = {
	LightBlue: Color3,
	Yellow: Color3,
	Orange: Color3,
	Purple: Color3,
	Pink: Color3,
}

local WorldVisualService = {}

local visualsModel: Model? = nil
local atmosphere: Atmosphere? = nil
local bloom: BloomEffect? = nil
local colorCorrection: ColorCorrectionEffect? = nil

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function destroyOwned(parent: Instance, name: string)
	local existing = parent:FindFirstChild(name)
	if existing == nil then
		return
	end

	if not isOwned(existing) then
		error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
	end

	existing:Destroy()
end

local function createCloudPart(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(255, 252, 246)
	part.Transparency = 0.3
	part.Parent = parent
	return part
end

local function createCloud(index: number, parent: Instance)
	local angle = ((index - 1) / CLOUD_COUNT) * math.pi * 2
	local heightOffset = ((index * 17) % 28) - 8
	local center = CLOUD_CENTER
		+ Vector3.new(math.cos(angle) * CLOUD_RADIUS, 92 + heightOffset, math.sin(angle) * CLOUD_RADIUS)

	local cloud = Instance.new("Model")
	cloud.Name = string.format("Cloud%02d", index)
	cloud.Parent = parent

	createCloudPart("Center", Vector3.new(18, 9, 10), center, cloud)
	createCloudPart("Left", Vector3.new(11, 7, 8), center + Vector3.new(-8, -1, 0), cloud)
	createCloudPart("Right", Vector3.new(13, 8, 9), center + Vector3.new(8, -0.5, 1), cloud)
end

local function stopOwnedVisuals()
	if visualsModel ~= nil and visualsModel.Parent ~= nil and isOwned(visualsModel) then
		visualsModel:Destroy()
	end
	if atmosphere ~= nil and atmosphere.Parent ~= nil and isOwned(atmosphere) then
		atmosphere:Destroy()
	end
	if bloom ~= nil and bloom.Parent ~= nil and isOwned(bloom) then
		bloom:Destroy()
	end
	if colorCorrection ~= nil and colorCorrection.Parent ~= nil and isOwned(colorCorrection) then
		colorCorrection:Destroy()
	end

	visualsModel = nil
	atmosphere = nil
	bloom = nil
	colorCorrection = nil
end

function WorldVisualService.start(worldRoot: Model, palette: WorldPalette)
	stopOwnedVisuals()
	destroyOwned(worldRoot, VISUALS_NAME)
	destroyOwned(Lighting, ATMOSPHERE_NAME)
	destroyOwned(Lighting, BLOOM_NAME)
	destroyOwned(Lighting, COLOR_CORRECTION_NAME)

	local newVisuals = Instance.new("Model")
	newVisuals.Name = VISUALS_NAME
	newVisuals:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newVisuals.Parent = worldRoot

	local clouds = Instance.new("Folder")
	clouds.Name = "Clouds"
	clouds.Parent = newVisuals
	for index = 1, CLOUD_COUNT do
		createCloud(index, clouds)
	end

	local newAtmosphere = Instance.new("Atmosphere")
	newAtmosphere.Name = ATMOSPHERE_NAME
	newAtmosphere.Color = palette.LightBlue:Lerp(Color3.new(1, 1, 1), 0.38)
	newAtmosphere.Decay = palette.Purple:Lerp(palette.Pink, 0.35)
	newAtmosphere.Density = 0.18
	newAtmosphere.Offset = 0.1
	newAtmosphere.Glare = 0.08
	newAtmosphere.Haze = 1.25
	newAtmosphere:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newAtmosphere.Parent = Lighting

	local newBloom = Instance.new("BloomEffect")
	newBloom.Name = BLOOM_NAME
	newBloom.Intensity = 0.32
	newBloom.Size = 22
	newBloom.Threshold = 1.05
	newBloom:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newBloom.Parent = Lighting

	local newColorCorrection = Instance.new("ColorCorrectionEffect")
	newColorCorrection.Name = COLOR_CORRECTION_NAME
	newColorCorrection.Brightness = 0.025
	newColorCorrection.Contrast = 0.06
	newColorCorrection.Saturation = 0.1
	newColorCorrection.TintColor = Color3.fromRGB(255, 249, 244)
	newColorCorrection:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newColorCorrection.Parent = Lighting

	visualsModel = newVisuals
	atmosphere = newAtmosphere
	bloom = newBloom
	colorCorrection = newColorCorrection
end

function WorldVisualService.stop()
	stopOwnedVisuals()
end

return table.freeze(WorldVisualService)
