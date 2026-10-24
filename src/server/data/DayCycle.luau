--!strict

-- Regras puras do céu do lado de fora: que horas são em Brasília e como fica
-- a luz nessa hora, passando aos poucos de um momento do dia para o outro.
-- Sem dependências (os testes do Lune carregam este arquivo direto).

-- Cor em RGB de 0 a 255.
export type Rgb = { number }

-- Um momento do dia (o mesmo formato de OutdoorConfig.DayCycle.Keys).
export type LightKey = {
	hour: number,
	brightness: number,
	outdoorAmbient: Rgb,
	atmosphereColor: Rgb,
	atmosphereDecay: Rgb,
	atmosphereDensity: number,
	atmosphereHaze: number,
	atmosphereGlare: number,
}

export type Phase = "Morning" | "Afternoon" | "Night"

export type Light = {
	brightness: number,
	outdoorAmbient: Rgb,
	atmosphereColor: Rgb,
	atmosphereDecay: Rgb,
	atmosphereDensity: number,
	atmosphereHaze: number,
	atmosphereGlare: number,
}

local SECONDS_PER_HOUR = 3600
local HOURS_PER_DAY = 24
local MORNING_START = 6
local AFTERNOON_START = 12
local NIGHT_START = 18

local DayCycle = {}

-- Hora do dia (0 a 24, com fração) no fuso `utcOffsetHours` para o instante
-- `epochSeconds` (segundos desde 1970 em UTC, como os.time()).
function DayCycle.clockAt(epochSeconds: number, utcOffsetHours: number): number
	local localSeconds = epochSeconds + utcOffsetHours * SECONDS_PER_HOUR
	return (localSeconds % (HOURS_PER_DAY * SECONDS_PER_HOUR)) / SECONDS_PER_HOUR
end

-- Dia (6h às 12h), tarde (12h às 18h) ou noite.
function DayCycle.phaseOf(clock: number): Phase
	if clock >= MORNING_START and clock < AFTERNOON_START then
		return "Morning"
	elseif clock >= AFTERNOON_START and clock < NIGHT_START then
		return "Afternoon"
	end
	return "Night"
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function mixRgb(a: Rgb, b: Rgb, t: number): Rgb
	return { mix(a[1], b[1], t), mix(a[2], b[2], t), mix(a[3], b[3], t) }
end

-- Luz na hora `clock`, entre os momentos `keys` (em ordem de hora). Depois do
-- último momento a luz volta para o primeiro, no dia seguinte.
function DayCycle.lightAt(clock: number, keys: { LightKey }): Light
	assert(#keys > 0, "DayCycle needs at least one light key")
	local hour = clock % HOURS_PER_DAY
	-- Último momento que já passou (0: nenhum hoje, vale o último de ontem).
	local last = 0
	for index, key in ipairs(keys) do
		if key.hour <= hour then
			last = index
		end
	end
	local before = if last > 0 then keys[last] else keys[#keys]
	local beforeHour = if last > 0 then before.hour else before.hour - HOURS_PER_DAY
	local after = if last < #keys then keys[last + 1] else keys[1]
	local afterHour = if last < #keys then after.hour else after.hour + HOURS_PER_DAY
	local span = afterHour - beforeHour
	local t = if span > 0 then ease(math.clamp((hour - beforeHour) / span, 0, 1)) else 0
	return {
		brightness = mix(before.brightness, after.brightness, t),
		outdoorAmbient = mixRgb(before.outdoorAmbient, after.outdoorAmbient, t),
		atmosphereColor = mixRgb(before.atmosphereColor, after.atmosphereColor, t),
		atmosphereDecay = mixRgb(before.atmosphereDecay, after.atmosphereDecay, t),
		atmosphereDensity = mix(before.atmosphereDensity, after.atmosphereDensity, t),
		atmosphereHaze = mix(before.atmosphereHaze, after.atmosphereHaze, t),
		atmosphereGlare = mix(before.atmosphereGlare, after.atmosphereGlare, t),
	}
end

return table.freeze(DayCycle)
