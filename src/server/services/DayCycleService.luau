--!strict

-- Céu do lado de fora na hora de Brasília: o sol (Lighting.ClockTime), a luz
-- do sol, a luz ambiente de fora e a névoa (Atmosphere) passam aos poucos
-- pelo amanhecer, dia, tarde dourada, pôr do sol e noite (DayCycle). O
-- servidor ajusta tudo e o Lighting replica para todo mundo, então todos no
-- servidor veem a mesma hora. A luz de dentro do Casarão (Lighting.Ambient,
-- do WorldVisualService) não muda: lá dentro quem ilumina são os lustres.
--
-- No Studio, o atributo ClockOverride (número de 0 a 24) no Lighting fixa a
-- hora para testar.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DayCycle = require(script.Parent.Parent.data.DayCycle)
local OutdoorConfig = require(ReplicatedStorage.Shared.config.OutdoorConfig)

local OVERRIDE_ATTRIBUTE = "ClockOverride"

local DayCycleService = {}

local started = false

local function color(rgb: { number }): Color3
	return Color3.fromRGB(math.round(rgb[1]), math.round(rgb[2]), math.round(rgb[3]))
end

local function atmosphere(): Atmosphere
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing ~= nil then
		return existing
	end
	local created = Instance.new("Atmosphere")
	created.Parent = Lighting
	return created
end

local function currentClock(): number
	local override = Lighting:GetAttribute(OVERRIDE_ATTRIBUTE)
	if typeof(override) == "number" then
		return override % 24
	end
	return DayCycle.clockAt(os.time(), OutdoorConfig.DayCycle.UtcOffsetHours)
end

local function apply()
	local clock = currentClock()
	local light = DayCycle.lightAt(clock, OutdoorConfig.DayCycle.Keys)
	Lighting.ClockTime = clock
	Lighting.Brightness = light.brightness
	Lighting.OutdoorAmbient = color(light.outdoorAmbient)
	local air = atmosphere()
	air.Color = color(light.atmosphereColor)
	air.Decay = color(light.atmosphereDecay)
	air.Density = light.atmosphereDensity
	air.Haze = light.atmosphereHaze
	air.Glare = light.atmosphereGlare
end

function DayCycleService.start()
	if started then
		return
	end
	started = true
	apply()
	Lighting:GetAttributeChangedSignal(OVERRIDE_ATTRIBUTE):Connect(apply)
	task.spawn(function()
		while true do
			task.wait(OutdoorConfig.DayCycle.UpdateSeconds)
			local ok, failure = pcall(apply)
			if not ok then
				warn(`[BlocoPuff] Day cycle update failed: {failure}`)
			end
		end
	end)
end

return table.freeze(DayCycleService)
