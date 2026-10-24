--!strict

-- Enfeites animados da Torre do Relógio Encantada no cliente (Fase 5F.2):
-- velas que flutuam subindo e descendo devagar e morcegos que voam em volta
-- do campanário, batendo as asas. Só anima quando a câmera está perto da
-- torre (celular).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TowerAmbienceNames = require(ReplicatedStorage.Shared.modules.TowerAmbienceNames)

local CANDLE_BOB_HEIGHT = 0.6
local CANDLE_BOB_SPEED = 1.3
local CANDLE_SWAY = math.rad(4)
local BAT_FLAP_SPEED = 14
local BAT_FLAP_ANGLE = math.rad(25)
local BAT_BOB_HEIGHT = 1.5
local ACTIVE_DISTANCE = 450

type Candle = {
	part: BasePart,
	home: CFrame,
	-- Peças presas à vela (a chama), relativas a ela.
	children: { [BasePart]: CFrame },
	phase: number,
}

type Bat = {
	part: BasePart,
	center: Vector3,
	radius: number,
	speed: number,
	phase: number,
}

local TowerAmbienceController = {}

local candles: { [BasePart]: Candle } = {}
local bats: { [BasePart]: Bat } = {}
local towerCenter: Vector3? = nil
local started = false

local function addCandle(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local children: { [BasePart]: CFrame } = {}
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("BasePart") then
			children[child] = instance.CFrame:ToObjectSpace(child.CFrame)
		end
	end
	candles[instance] = { part = instance, home = instance.CFrame, children = children, phase = math.random() * math.pi * 2 }
end

local function addBat(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local center = instance:GetAttribute(TowerAmbienceNames.OrbitCenter)
	local radius = instance:GetAttribute(TowerAmbienceNames.OrbitRadius)
	local speed = instance:GetAttribute(TowerAmbienceNames.OrbitSpeed)
	local phase = instance:GetAttribute(TowerAmbienceNames.Phase)
	if typeof(center) ~= "Vector3" or type(radius) ~= "number" or type(speed) ~= "number" or type(phase) ~= "number" then
		return
	end
	bats[instance] = { part = instance, center = center, radius = radius, speed = speed, phase = phase }
	towerCenter = center
end

local function watch(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

local function nearTower(): boolean
	local camera = Workspace.CurrentCamera
	local center = towerCenter
	if camera == nil then
		return false
	end
	if center == nil then
		return next(candles) ~= nil
	end
	local offset = camera.CFrame.Position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude < ACTIVE_DISTANCE
end

local function stepCandles(now: number)
	for candlePart, candle in pairs(candles) do
		if candlePart.Parent == nil then
			candles[candlePart] = nil
			continue
		end
		local t = now * CANDLE_BOB_SPEED + candle.phase
		local cframe = candle.home * CFrame.new(0, math.sin(t) * CANDLE_BOB_HEIGHT, 0) * CFrame.Angles(math.sin(t * 0.7) * CANDLE_SWAY, 0, math.cos(t * 0.6) * CANDLE_SWAY)
		candlePart.CFrame = cframe
		for child, offset in pairs(candle.children) do
			child.CFrame = cframe * offset
		end
	end
end

local function stepBats(now: number)
	for batPart, bat in pairs(bats) do
		if batPart.Parent == nil then
			bats[batPart] = nil
			continue
		end
		local angle = bat.phase + now * bat.speed
		local position = bat.center + Vector3.new(math.cos(angle) * bat.radius, math.sin(now * 2 + bat.phase) * BAT_BOB_HEIGHT, math.sin(angle) * bat.radius)
		-- Voa na tangente da órbita, inclinado para dentro da curva.
		local direction = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * math.sign(bat.speed)
		local flap = math.sin(now * BAT_FLAP_SPEED + bat.phase) * BAT_FLAP_ANGLE
		batPart.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, 0, flap - math.sign(bat.speed) * math.rad(15))
	end
end

function TowerAmbienceController.start()
	if started then
		return
	end
	started = true
	watch(TowerAmbienceNames.CandleTag, addCandle, function(instance)
		if instance:IsA("BasePart") then
			candles[instance] = nil
		end
	end)
	watch(TowerAmbienceNames.BatTag, addBat, function(instance)
		if instance:IsA("BasePart") then
			bats[instance] = nil
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not nearTower() then
			return
		end
		local now = os.clock()
		stepCandles(now)
		stepBats(now)
	end)
end

return table.freeze(TowerAmbienceController)
