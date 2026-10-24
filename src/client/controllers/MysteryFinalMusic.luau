--!strict

-- Música dos últimos segundos do Assassinato no Casarão (Fase 5E.4): quando
-- faltam MysteryModeConfig.Sounds.FinalMusicSeconds, entra uma trilha de
-- tensão só para quem está na partida (vivo ou assistindo), com fade, e sai
-- quando a partida acaba. Toca local, em SoundService, por cima da trilha
-- de fundo.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

local SOUND_NAME = "BlocoPuffMysteryFinalMusic"
local FADE_IN = 1.5
local FADE_OUT = 1

local MysteryFinalMusic = {}

local started = false

function MysteryFinalMusic.start(container: Instance)
	if started then
		return
	end
	started = true
	local localPlayer = Players.LocalPlayer
	local config = MysteryModeConfig.Sounds
	local music = Instance.new("Sound")
	music.Name = SOUND_NAME
	music.SoundId = config.FinalMusicId
	music.Looped = true
	music.Volume = 0
	music.Parent = SoundService
	task.spawn(function()
		ContentProvider:PreloadAsync({ music }, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success then
				warn(string.format("[BlocoPuff] Mystery final music %s failed to load: %s", music.SoundId, status.Name))
			end
		end)
	end)

	local playing = false
	local function shouldPlay(): boolean
		local remaining = container:GetAttribute(StateAttributeNames.TimeRemaining)
		return container:GetAttribute(StateAttributeNames.RoundState) == "Active"
			and container:GetAttribute(StateAttributeNames.RoundMode) == "Mystery"
			and localPlayer:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
			and typeof(remaining) == "number"
			and remaining > 0
			and remaining <= config.FinalMusicSeconds
	end
	local function refresh()
		local wanted = shouldPlay()
		if wanted == playing then
			return
		end
		playing = wanted
		if wanted then
			music.TimePosition = 0
			music:Play()
			TweenService:Create(music, TweenInfo.new(FADE_IN), { Volume = config.FinalMusicVolume }):Play()
		else
			local fade = TweenService:Create(music, TweenInfo.new(FADE_OUT), { Volume = 0 })
			fade.Completed:Connect(function()
				if not playing then
					music:Stop()
				end
			end)
			fade:Play()
		end
	end
	container.AttributeChanged:Connect(refresh)
	localPlayer.AttributeChanged:Connect(refresh)
	refresh()
end

return table.freeze(MysteryFinalMusic)
