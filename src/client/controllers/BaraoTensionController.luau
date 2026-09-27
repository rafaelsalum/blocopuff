--!strict

-- Trilha de tensão do Barão: quando ele está perseguindo o próprio jogador
-- (atributo BaraoTarget do modelo), toca uma batida grave sem direção, que
-- acelera e fica mais alta quanto mais a perseguição dura. Ela não diz de
-- onde ele vem nem a que distância está: a pista de posição continua sendo
-- só o som 3D dos passos e latidos.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

local BARAO_TAG = "Barao"
local TARGET_ATTRIBUTE = "BaraoTarget"
-- Intervalo entre batidas: começa lento e acelera até o mínimo em RAMP_TIME.
local SLOW_INTERVAL = 0.95
local FAST_INTERVAL = 0.42
local RAMP_TIME = 6
local MIN_VOLUME = 0.25
local MAX_VOLUME = 0.7

local BaraoTensionController = {}

local started = false
local chaseToken = 0

local function thump(volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = GameConfig.Barao.TensionSoundId
	sound.PlaybackSpeed = 0.55
	sound.Volume = volume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	-- Garantia caso o som não toque (Ended nunca dispararia).
	task.delay(4, function()
		if sound.Parent ~= nil then
			sound:Destroy()
		end
	end)
	sound:Play()
end

local function startTension()
	chaseToken += 1
	local token = chaseToken
	task.spawn(function()
		local startedAt = os.clock()
		while chaseToken == token do
			local progress = math.clamp((os.clock() - startedAt) / RAMP_TIME, 0, 1)
			local volume = MIN_VOLUME + ((MAX_VOLUME - MIN_VOLUME) * progress)
			thump(volume)
			task.delay(0.16, function()
				if chaseToken == token then
					thump(volume * 0.7)
				end
			end)
			task.wait(SLOW_INTERVAL + ((FAST_INTERVAL - SLOW_INTERVAL) * progress))
		end
	end)
end

local function stopTension()
	chaseToken += 1
end

local function watch(model: Instance)
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local chasing = false
	local function update()
		local isMe = model:GetAttribute(TARGET_ATTRIBUTE) == player.UserId
		if isMe and not chasing then
			chasing = true
			startTension()
		elseif not isMe and chasing then
			chasing = false
			stopTension()
		end
	end
	model:GetAttributeChangedSignal(TARGET_ATTRIBUTE):Connect(update)
	model.Destroying:Connect(function()
		if chasing then
			chasing = false
			stopTension()
		end
	end)
	update()
end

function BaraoTensionController.start()
	if started then
		return
	end
	started = true
	for _, model in ipairs(CollectionService:GetTagged(BARAO_TAG)) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal(BARAO_TAG):Connect(watch)
end

return table.freeze(BaraoTensionController)
