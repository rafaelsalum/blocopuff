--!strict

-- Direção de arte de interior criada somente com instâncias nativas. Os
-- efeitos de Lighting pertencem ao serviço e podem ser removidos sem
-- interferir em conteúdo que tenha sido colocado manualmente no Studio.

local Lighting = game:GetService("Lighting")

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "WorldVisualService"
-- Nome mantido somente para limpar as nuvens geradas por versões anteriores.
local LEGACY_VISUALS_NAME = "WorldVisuals"

local BLOOM_NAME = "BlocoPuffBloom"
local COLOR_CORRECTION_NAME = "BlocoPuffColorCorrection"
-- Instâncias criadas por versões anteriores (céu aberto com skybox e
-- atmosfera). O jogo agora acontece dentro de um prédio fechado.
local LEGACY_LIGHTING_NAMES = { "BlocoPuffSky", "BlocoPuffAtmosphere" }

-- Base de interior suave e uniforme: a luz ambiente e o difuso do ambiente
-- iluminam a cena por igual; lustres e arandelas (BuildingService) são só
-- acentos fracos. Brilho especular baixo evita reflexos estourados nos
-- personagens com a tecnologia Future.
-- Lighting.Technology = Future é definido em default.project.json.
local INTERIOR_AMBIENT = Color3.fromRGB(96, 90, 86)
local INTERIOR_OUTDOOR_AMBIENT = Color3.fromRGB(96, 90, 86)
local INTERIOR_BRIGHTNESS = 0.5
local INTERIOR_ENVIRONMENT_DIFFUSE = 0.3
local INTERIOR_ENVIRONMENT_SPECULAR = 0.08

type LightingSnapshot = {
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Brightness: number,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
}

type WorldPalette = {
	LightBlue: Color3,
	Yellow: Color3,
	Orange: Color3,
	Purple: Color3,
	Pink: Color3,
}

local WorldVisualService = {}

local bloom: BloomEffect? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local previousLighting: LightingSnapshot? = nil

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

local function stopOwnedVisuals()
	if bloom ~= nil and bloom.Parent ~= nil and isOwned(bloom) then
		bloom:Destroy()
	end
	if colorCorrection ~= nil and colorCorrection.Parent ~= nil and isOwned(colorCorrection) then
		colorCorrection:Destroy()
	end

	bloom = nil
	colorCorrection = nil

	local snapshot = previousLighting
	if snapshot ~= nil then
		Lighting.Ambient = snapshot.Ambient
		Lighting.OutdoorAmbient = snapshot.OutdoorAmbient
		Lighting.Brightness = snapshot.Brightness
		Lighting.EnvironmentDiffuseScale = snapshot.EnvironmentDiffuseScale
		Lighting.EnvironmentSpecularScale = snapshot.EnvironmentSpecularScale
		previousLighting = nil
	end
end

local function applyInteriorLighting()
	previousLighting = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	}
	Lighting.Ambient = INTERIOR_AMBIENT
	Lighting.OutdoorAmbient = INTERIOR_OUTDOOR_AMBIENT
	Lighting.Brightness = INTERIOR_BRIGHTNESS
	Lighting.EnvironmentDiffuseScale = INTERIOR_ENVIRONMENT_DIFFUSE
	Lighting.EnvironmentSpecularScale = INTERIOR_ENVIRONMENT_SPECULAR
end

function WorldVisualService.start(worldRoot: Model, _palette: WorldPalette)
	stopOwnedVisuals()
	destroyOwned(worldRoot, LEGACY_VISUALS_NAME)
	for _, name in ipairs(LEGACY_LIGHTING_NAMES) do
		destroyOwned(Lighting, name)
	end
	destroyOwned(Lighting, BLOOM_NAME)
	destroyOwned(Lighting, COLOR_CORRECTION_NAME)
	applyInteriorLighting()

	local newBloom = Instance.new("BloomEffect")
	newBloom.Name = BLOOM_NAME
	newBloom.Intensity = 0.1
	newBloom.Size = 12
	newBloom.Threshold = 1.6
	newBloom:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newBloom.Parent = Lighting

	local newColorCorrection = Instance.new("ColorCorrectionEffect")
	newColorCorrection.Name = COLOR_CORRECTION_NAME
	newColorCorrection.Brightness = 0
	newColorCorrection.Contrast = 0.05
	newColorCorrection.Saturation = 0
	newColorCorrection.TintColor = Color3.fromRGB(255, 248, 240)
	newColorCorrection:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newColorCorrection.Parent = Lighting

	bloom = newBloom
	colorCorrection = newColorCorrection
end

function WorldVisualService.stop()
	stopOwnedVisuals()
end

return table.freeze(WorldVisualService)
