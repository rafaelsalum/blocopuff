--!strict

-- Chão molhado da Chuva (Fase 5, 5.6) no próprio personagem. O servidor
-- marca nas janelas até quando chove (TrapConstants.WindowRainUntil); este
-- cliente simula o próprio personagem, então é aqui que a tração cai
-- (SlipperyGround) enquanto ele estiver no chão molhado.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SlipperyGround = require(ReplicatedStorage.Shared.modules.SlipperyGround)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local WindowGeometry = require(ReplicatedStorage.Shared.modules.WindowGeometry)

local CONFIG = TrapConfig.Window

local SlipperyController = {}

local WARN_INTERVAL = 5

local started = false
local lastWarnAt = -math.huge
local state = SlipperyGround.new()
local stateRoot: BasePart? = nil

type Rain = {
	frame: WindowGeometry.Frame,
	untilTime: number,
}

-- Janelas em que está chovendo agora (atualizado pelos atributos, sem
-- varrer todas as janelas a cada quadro).
local rains: { [BasePart]: Rain } = {}
local watched: { [BasePart]: RBXScriptConnection } = {}

local function refreshRain(glass: BasePart)
	local rainUntil = glass:GetAttribute(TrapConstants.WindowRainUntilAttribute)
	local frame = WindowGeometry.frameOf(glass)
	if typeof(rainUntil) == "number" and frame ~= nil then
		rains[glass] = { frame = frame, untilTime = rainUntil }
	else
		rains[glass] = nil
	end
end

local function watch(instance: Instance)
	if not instance:IsA("BasePart") or watched[instance] ~= nil then
		return
	end
	if instance:GetAttribute(TrapConstants.KindAttribute) ~= TrapConstants.Window then
		return
	end
	watched[instance] = instance:GetAttributeChangedSignal(TrapConstants.WindowRainUntilAttribute):Connect(function()
		refreshRain(instance)
	end)
	refreshRain(instance)
end

local function unwatch(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local connection = watched[instance]
	if connection ~= nil then
		connection:Disconnect()
		watched[instance] = nil
	end
	rains[instance] = nil
end

-- Está no chão molhado de alguma janela em que ainda chove.
local function isWet(position: Vector3): boolean
	local now = Workspace:GetServerTimeNow()
	for glass, rain in pairs(rains) do
		if now >= rain.untilTime then
			rains[glass] = nil
		elseif WindowGeometry.inRain(rain.frame, position) then
			return true
		end
	end
	return false
end

local function step(dt: number)
	if next(rains) == nil and state.attachment == nil then
		return
	end
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	local rootInstance = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if rootInstance == nil or not rootInstance:IsA("BasePart") or humanoid == nil then
		SlipperyGround.release(state)
		stateRoot = nil
		return
	end
	if stateRoot ~= rootInstance then
		-- Personagem novo: começa do zero.
		SlipperyGround.release(state)
		stateRoot = rootInstance
	end
	local wet = isWet(rootInstance.Position)
	if not wet and state.attachment == nil then
		return
	end
	SlipperyGround.step(state, rootInstance, humanoid, dt, wet, CONFIG.RainGrip)
	if not wet then
		SlipperyGround.release(state)
	end
end

function SlipperyController.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(TrapConstants.Tag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(TrapConstants.Tag):Connect(unwatch)
	for _, instance in ipairs(CollectionService:GetTagged(TrapConstants.Tag)) do
		watch(instance)
	end
	RunService.Heartbeat:Connect(function(dt: number)
		local ok, failure = pcall(step, dt)
		if not ok then
			-- Nunca deixa o personagem preso numa velocidade.
			pcall(SlipperyGround.release, state)
			if os.clock() - lastWarnAt >= WARN_INTERVAL then
				lastWarnAt = os.clock()
				warn(`[BlocoPuff] Slippery ground failed: {failure}`)
			end
		end
	end)
end

return table.freeze(SlipperyController)
