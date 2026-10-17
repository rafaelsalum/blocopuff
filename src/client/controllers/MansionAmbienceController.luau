--!strict

-- Ambiente do Casarão no cliente (Fase 5C.4, parte 2):
--   * retratos com olhos que seguem quem passa (PortraitEyes);
--   * lustres que balançam quando uma porta bate perto (ChandelierSwing,
--     avisado pelo MansionDoorController via MansionSignals);
--   * o relógio da torre toca a cada MansionAmbienceConfig.Clock.Period
--     segundos do horário do servidor (todo mundo ouve junto). O som sai do
--     relógio no Sótão e se espalha pelo Casarão, mais baixo de longe.
--     Quem está na partida não ouve.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MansionAmbienceConfig = require(ReplicatedStorage.Shared.config.MansionAmbienceConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local AmbienceMath = require(ReplicatedStorage.Shared.modules.AmbienceMath)
local ChandelierSwing = require(script.Parent.Parent.effects.ChandelierSwing)
local MansionSignals = require(script.Parent.Parent.effects.MansionSignals)
local PortraitEyes = require(script.Parent.Parent.effects.PortraitEyes)

local CLOCK = MansionAmbienceConfig.Clock
local CLOCK_CHECK = 0.5
local MAX_STEP = 0.1

local MansionAmbienceController = {}

local started = false
local lastSlot: number? = nil
local clockSound: Sound? = nil
local clockHolder: BasePart? = nil

-- Um aviso por tipo de falha: um erro a cada quadro não lota a saída.
local warned: { [string]: boolean } = {}
local function guarded(kind: string, callback: () -> ())
	local ok, failure = pcall(callback)
	if not ok and not warned[kind] then
		warned[kind] = true
		warn(`[BlocoPuff] Mansion ambience ({kind}) failed: {failure}`)
	end
end

-- Um quadro do ambiente (sem criar funções novas a cada quadro).
local frameDt = 0
local function stepPortraits()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		PortraitEyes.step(frameDt, camera.CFrame)
	end
end
local function stepChandeliers()
	ChandelierSwing.step(frameDt)
end

local function watch(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		task.spawn(guarded, tag, function()
			add(instance)
		end)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
		task.spawn(guarded, tag, function()
			add(instance)
		end)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

-- Onde o som do relógio nasce: no relógio da torre ou, sem ele, no meio do
-- Sótão (uma peça invisível só deste cliente).
local clockModel: Model? = nil
local function clockEmitter(): Instance
	local model = clockModel
	if model == nil or model.Parent == nil then
		local found = Workspace:FindFirstChild(CLOCK.ModelName, true)
		model = if found ~= nil and found:IsA("Model") then found else nil
		clockModel = model
	end
	if model ~= nil then
		local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if part ~= nil then
			return part
		end
	end
	local holder = clockHolder
	if holder == nil or holder.Parent == nil then
		local wing = MansionWingLayout.get()
		local created = Instance.new("Part")
		created.Name = "TowerClockSound"
		created.Anchored = true
		created.CanCollide = false
		created.CanQuery = false
		created.CanTouch = false
		created.Transparency = 1
		created.Size = Vector3.one
		created.Position = Vector3.new((wing.minX + wing.maxX) / 2, wing.atticFloorY + 6, (wing.minZ + wing.maxZ) / 2)
		created.Parent = Workspace
		clockHolder = created
		holder = created
	end
	return holder :: BasePart
end

local function strike()
	if Players.LocalPlayer:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
		return
	end
	local emitter = clockEmitter()
	local sound = clockSound
	if sound == nil or sound.Parent ~= emitter then
		if sound ~= nil then
			sound:Destroy()
		end
		local created = Instance.new("Sound")
		created.Name = "TowerClockChime"
		created.SoundId = CLOCK.SoundId
		created.Volume = CLOCK.Volume
		created.RollOffMode = Enum.RollOffMode.InverseTapered
		created.RollOffMinDistance = CLOCK.RollOffMin
		created.RollOffMaxDistance = CLOCK.RollOffMax
		created.Parent = emitter
		clockSound = created
		sound = created
	end
	local current = sound :: Sound
	current.TimePosition = 0
	current:Play()
end

-- Toca quando o horário do servidor entra num novo período (não toca ao
-- entrar no jogo).
local function checkClock()
	local slot = AmbienceMath.clockSlot(Workspace:GetServerTimeNow(), CLOCK.Period)
	local previous = lastSlot
	lastSlot = slot
	if AmbienceMath.shouldStrike(previous, slot) then
		strike()
	end
end

function MansionAmbienceController.start()
	if started then
		return
	end
	started = true
	watch(MansionAmbienceConfig.Portrait.Tag, PortraitEyes.add, PortraitEyes.remove)
	watch(MansionAmbienceConfig.Chandelier.Tag, ChandelierSwing.add, ChandelierSwing.remove)
	MansionSignals.doorSlammed:Connect(function(position: Vector3)
		guarded("chandeliers", function()
			ChandelierSwing.push(position)
		end)
	end)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		frameDt = math.min(deltaTime, MAX_STEP)
		guarded("portraits", stepPortraits)
		guarded("chandelier swing", stepChandeliers)
	end)
	task.spawn(function()
		while true do
			guarded("clock", checkClock)
			task.wait(CLOCK_CHECK)
		end
	end)
end

return table.freeze(MansionAmbienceController)
