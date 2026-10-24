--!strict

-- Tempestade do Caos Final no cliente (Fase 5, entrega 5.7): enquanto o
-- Caos dura, o céu escurece e fica azulado, chove em volta do prédio, um
-- trovão abre a Tempestade e outros soam de vez em quando com um clarão
-- leve (sem flash forte), e as luzes do térreo da Arena oscilam devagar.
-- As janelas e os lustres que estouram sozinhos são do servidor
-- (TrapService.storm); aqui é só clima.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

local CONFIG = TrapConfig.Storm
local WAIT_TIMEOUT = 15
local WORLD_NAME = "BlocoPuffWorld"
-- Onde ficam as luzes do térreo da Arena (prédio e armadilhas).
local LIGHT_SOURCES = { "Building", "CasaraoTraps" }
local EFFECT_NAME = "BlocoPuffStorm"
local RAIN_NAME = "BlocoPuffStormRain"
local LIGHTNING_FADE = 0.5
-- Margem abaixo do piso de cima para contar como térreo (studs).
local FLOOR_MARGIN = 1

local StormController = {}

local started = false

type FlickerLight = {
	light: Light,
	base: number,
	phase: number,
}

local function makeSound(name: string, soundId: string, volume: number, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Looped = looped
	sound.Parent = SoundService
	return sound
end

-- Luzes do térreo da Arena, com o brilho de agora.
local function groundFloorLights(): { FlickerLight }
	local found: { FlickerLight } = {}
	local world = Workspace:FindFirstChild(WORLD_NAME)
	if world == nil then
		return found
	end
	local ceiling = GameConfig.Arena.Position.Y + GameConfig.Arena.FloorSpacing - FLOOR_MARGIN
	local random = Random.new()
	for _, name in ipairs(LIGHT_SOURCES) do
		local source = world:FindFirstChild(name)
		if source ~= nil then
			for _, descendant in ipairs(source:GetDescendants()) do
				local holder = descendant.Parent
				if descendant:IsA("Light") and holder ~= nil and holder:IsA("BasePart") and holder.Position.Y < ceiling then
					table.insert(found, { light = descendant, base = descendant.Brightness, phase = random:NextNumber(0, 100) })
				end
			end
		end
	end
	return found
end

function StormController.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local container = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, WAIT_TIMEOUT)
		if container == nil then
			warn("[BlocoPuff] StormController: state container not found")
			return
		end
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = EFFECT_NAME
		effect.Parent = Lighting
		local rain = makeSound(RAIN_NAME, TrapConfig.Window.RainSoundId, 0, true)
		local announce = makeSound("BlocoPuffStormThunder", CONFIG.AnnounceThunderId, CONFIG.ThunderVolume, false)
		local rumble = makeSound("BlocoPuffStormRumble", CONFIG.RumbleThunderId, CONFIG.ThunderVolume, false)
		local random = Random.new()

		local raging = false
		local generation = 0
		local lights: { FlickerLight } = {}
		local flicker: RBXScriptConnection? = nil

		local function darken(on: boolean)
			TweenService:Create(effect, TweenInfo.new(CONFIG.DarkenTime, Enum.EasingStyle.Sine), {
				Brightness = if on then CONFIG.DarkenBrightness else 0,
				Saturation = if on then CONFIG.DarkenSaturation else 0,
				TintColor = if on then CONFIG.DarkenTint else Color3.new(1, 1, 1),
			}):Play()
			TweenService:Create(rain, TweenInfo.new(CONFIG.DarkenTime), { Volume = if on then CONFIG.RainVolume else 0 }):Play()
		end

		-- Clarão leve: um pouco mais claro e volta ao escuro da Tempestade.
		local function lightning(sound: Sound)
			sound:Play()
			effect.Brightness = CONFIG.DarkenBrightness + CONFIG.LightningBrightness
			TweenService:Create(effect, TweenInfo.new(LIGHTNING_FADE), { Brightness = CONFIG.DarkenBrightness }):Play()
		end

		local function restoreLights()
			if flicker ~= nil then
				flicker:Disconnect()
				flicker = nil
			end
			for _, entry in ipairs(lights) do
				entry.light.Brightness = entry.base
			end
			table.clear(lights)
		end

		local function begin()
			generation += 1
			local current = generation
			if not rain.IsPlaying then
				rain:Play()
			end
			darken(true)
			lightning(announce)
			lights = groundFloorLights()
			flicker = RunService.Heartbeat:Connect(function()
				local now = os.clock() * CONFIG.FlickerSpeed
				for _, entry in ipairs(lights) do
					local wave = math.clamp(0.5 + math.noise(now, entry.phase), 0, 1)
					entry.light.Brightness = entry.base * (CONFIG.FlickerMin + (1 - CONFIG.FlickerMin) * wave)
				end
			end)
			task.spawn(function()
				while raging and generation == current do
					task.wait(random:NextNumber(CONFIG.RumbleInterval.Min, CONFIG.RumbleInterval.Max))
					if raging and generation == current then
						lightning(rumble)
					end
				end
			end)
		end

		local function finish()
			generation += 1
			darken(false)
			restoreLights()
		end

		local function refresh()
			local now = container:GetAttribute(StateAttributeNames.FinalChaos) == true
			if now == raging then
				return
			end
			raging = now
			if now then
				begin()
			else
				finish()
			end
		end
		container:GetAttributeChangedSignal(StateAttributeNames.FinalChaos):Connect(refresh)
		refresh()
	end)
end

return table.freeze(StormController)
