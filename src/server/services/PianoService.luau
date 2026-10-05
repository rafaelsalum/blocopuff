--!strict

-- Piano da Sala de Música (Fase 5C.1): cada tecla (tag
-- MansionWingConfig.Piano.Tag, atributo com o meio tom) toca uma nota para
-- todos por perto, ao clicar ou tocar na tela (ClickDetector: o motor
-- garante a distância). O som é do servidor (replica para todos); a tecla
-- afunda um pouco a cada nota.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionWingConfig = require(ReplicatedStorage.Shared.config.MansionWingConfig)

local CONFIG = MansionWingConfig.Piano
local CLICK_DISTANCE = 14
local PRESS_DEPTH = 0.15
local PRESS_TIME = 0.12

local PianoService = {}

local started = false
local lastKey: { [BasePart]: number } = {}
local lastPlayer: { [Player]: number } = {}
-- Quem quer saber das notas tocadas (Mistérios do Barão: a música da Vovó).
local noteListeners: { (player: Player, semitone: number) -> () } = {}

local function press(key: BasePart, player: Player)
	local clock = os.clock()
	if clock - (lastKey[key] or 0) < CONFIG.KeyCooldown or clock - (lastPlayer[player] or 0) < CONFIG.PlayerCooldown then
		return
	end
	lastKey[key] = clock
	lastPlayer[player] = clock
	local semitone = key:GetAttribute(CONFIG.SemitoneAttribute)
	if typeof(semitone) ~= "number" then
		return
	end
	local sound = key:FindFirstChildOfClass("Sound")
	if sound == nil then
		local newSound = Instance.new("Sound")
		newSound.SoundId = CONFIG.NoteSoundId
		newSound.Volume = CONFIG.Volume
		newSound.RollOffMaxDistance = 70
		newSound.Parent = key
		sound = newSound
	end
	local current = sound :: Sound
	current.PlaybackSpeed = 2 ^ (semitone / 12)
	current.TimePosition = 0
	current:Play()
	for _, listener in ipairs(noteListeners) do
		task.spawn(listener, player, semitone)
	end
	local rest = key:GetAttribute("RestCFrame")
	if typeof(rest) ~= "CFrame" then
		rest = key.CFrame
		key:SetAttribute("RestCFrame", rest)
	end
	local restCFrame = rest :: CFrame
	key.CFrame = restCFrame - Vector3.new(0, PRESS_DEPTH, 0)
	task.delay(PRESS_TIME, function()
		if key.Parent ~= nil then
			key.CFrame = restCFrame
		end
	end)
end

local function connectKey(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local key = instance
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = CLICK_DISTANCE
	detector.Parent = key
	detector.MouseClick:Connect(function(player: Player)
		press(key, player)
	end)
	key.Destroying:Connect(function()
		lastKey[key] = nil
	end)
end

-- Avisa `listener` a cada nota tocada (quem tocou e o meio tom).
function PianoService.onNote(listener: (player: Player, semitone: number) -> ())
	table.insert(noteListeners, listener)
end

function PianoService.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(CONFIG.Tag):Connect(connectKey)
	for _, key in ipairs(CollectionService:GetTagged(CONFIG.Tag)) do
		connectKey(key)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPlayer[player] = nil
	end)
end

return table.freeze(PianoService)
