--!strict

-- Direção de arte criada somente com instâncias nativas. Os efeitos de
-- Lighting e a decoração pertencem ao serviço e podem ser removidos sem
-- interferir em conteúdo que tenha sido colocado manualmente no Studio.

local Lighting = game:GetService("Lighting")

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "WorldVisualService"
-- Nome mantido somente para limpar as nuvens geradas por versões anteriores.
local LEGACY_VISUALS_NAME = "WorldVisuals"

local ATMOSPHERE_NAME = "BlocoPuffAtmosphere"
local BLOOM_NAME = "BlocoPuffBloom"
local COLOR_CORRECTION_NAME = "BlocoPuffColorCorrection"
local SKY_NAME = "BlocoPuffSky"

-- Texturas do modelo "Sunless Blue Sky Skybox", de @Yourius, inspecionado
-- na Toolbox. O modelo contém somente uma instância Sky e nenhum script.
local SKYBOX_BACK = "rbxassetid://591058823"
local SKYBOX_DOWN = "rbxassetid://591059876"
local SKYBOX_FRONT = "rbxassetid://591058104"
local SKYBOX_LEFT = "rbxassetid://591057861"
local SKYBOX_RIGHT = "rbxassetid://591057625"
local SKYBOX_UP = "rbxassetid://591059642"

type WorldPalette = {
	LightBlue: Color3,
	Yellow: Color3,
	Orange: Color3,
	Purple: Color3,
	Pink: Color3,
}

local WorldVisualService = {}

local atmosphere: Atmosphere? = nil
local bloom: BloomEffect? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local sky: Sky? = nil

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

local function destroyExistingSkies()
	-- Lighting deve ter um único Sky para que o resultado não dependa da
	-- ordem interna dos filhos. Substituir o céu anterior faz parte explícita
	-- da configuração visual completa deste serviço.
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
end

local function stopOwnedVisuals()
	if atmosphere ~= nil and atmosphere.Parent ~= nil and isOwned(atmosphere) then
		atmosphere:Destroy()
	end
	if bloom ~= nil and bloom.Parent ~= nil and isOwned(bloom) then
		bloom:Destroy()
	end
	if colorCorrection ~= nil and colorCorrection.Parent ~= nil and isOwned(colorCorrection) then
		colorCorrection:Destroy()
	end
	if sky ~= nil and sky.Parent ~= nil and isOwned(sky) then
		sky:Destroy()
	end

	atmosphere = nil
	bloom = nil
	colorCorrection = nil
	sky = nil
end

function WorldVisualService.start(worldRoot: Model, palette: WorldPalette)
	stopOwnedVisuals()
	destroyOwned(worldRoot, LEGACY_VISUALS_NAME)
	destroyOwned(Lighting, ATMOSPHERE_NAME)
	destroyOwned(Lighting, BLOOM_NAME)
	destroyOwned(Lighting, COLOR_CORRECTION_NAME)
	destroyExistingSkies()

	local newSky = Instance.new("Sky")
	newSky.Name = SKY_NAME
	newSky.SkyboxBk = SKYBOX_BACK
	newSky.SkyboxDn = SKYBOX_DOWN
	newSky.SkyboxFt = SKYBOX_FRONT
	newSky.SkyboxLf = SKYBOX_LEFT
	newSky.SkyboxRt = SKYBOX_RIGHT
	newSky.SkyboxUp = SKYBOX_UP
	newSky.SunTextureId = "rbxasset://sky/sun.jpg"
	newSky.MoonTextureId = "rbxasset://sky/moon.jpg"
	newSky.StarCount = 3000
	newSky.CelestialBodiesShown = true
	newSky:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newSky.Parent = Lighting

	local newAtmosphere = Instance.new("Atmosphere")
	newAtmosphere.Name = ATMOSPHERE_NAME
	newAtmosphere.Color = palette.LightBlue:Lerp(Color3.fromRGB(190, 198, 210), 0.55)
	newAtmosphere.Decay = palette.Purple:Lerp(Color3.fromRGB(108, 105, 125), 0.5)
	newAtmosphere.Density = 0.24
	newAtmosphere.Offset = 0.02
	newAtmosphere.Glare = 0
	newAtmosphere.Haze = 0.75
	newAtmosphere:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newAtmosphere.Parent = Lighting

	local newBloom = Instance.new("BloomEffect")
	newBloom.Name = BLOOM_NAME
	newBloom.Intensity = 0.08
	newBloom.Size = 12
	newBloom.Threshold = 1.8
	newBloom:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newBloom.Parent = Lighting

	local newColorCorrection = Instance.new("ColorCorrectionEffect")
	newColorCorrection.Name = COLOR_CORRECTION_NAME
	newColorCorrection.Brightness = -0.055
	newColorCorrection.Contrast = 0.025
	newColorCorrection.Saturation = -0.14
	newColorCorrection.TintColor = Color3.fromRGB(244, 247, 250)
	newColorCorrection:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newColorCorrection.Parent = Lighting

	atmosphere = newAtmosphere
	bloom = newBloom
	colorCorrection = newColorCorrection
	sky = newSky
end

function WorldVisualService.stop()
	stopOwnedVisuals()
end

return table.freeze(WorldVisualService)
