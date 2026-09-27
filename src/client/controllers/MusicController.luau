--!strict

-- Toca a trilha de fundo localmente, em loop. O volume acompanha o estado do
-- jogador: baixo no lobby e bem mais baixo enquanto ele está competindo,
-- com uma transição suave. Fica em SoundService (som não posicional), então
-- soa igual em qualquer lugar do mapa e não depende do servidor.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

local SOUND_NAME = "BlocoPuffMusic"
local ATTR_IS_PARTICIPANT = StateAttributeNames.PlayerIsParticipant
local ATTR_IS_ELIMINATED = StateAttributeNames.PlayerIsEliminated

local MusicController = {}

local started = false

-- Competindo = escalado para a rodada e ainda não eliminado. Eliminados
-- voltam ao lobby, então a música volta ao volume do lobby.
local function isCompeting(player: Player): boolean
	return player:GetAttribute(ATTR_IS_PARTICIPANT) == true and player:GetAttribute(ATTR_IS_ELIMINATED) ~= true
end

function MusicController.start()
	if started then
		return
	end
	started = true

	local existing = SoundService:FindFirstChild(SOUND_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local config = GameConfig.Music
	local localPlayer = Players.LocalPlayer

	local music = Instance.new("Sound")
	music.Name = SOUND_NAME
	music.SoundId = config.SoundId
	music.Volume = if localPlayer ~= nil and isCompeting(localPlayer) then config.MatchVolume else config.LobbyVolume
	music.Looped = true
	music.Parent = SoundService

	if localPlayer ~= nil then
		local function updateVolume()
			local target = if isCompeting(localPlayer) then config.MatchVolume else config.LobbyVolume
			TweenService:Create(music, TweenInfo.new(config.FadeTime, Enum.EasingStyle.Sine), { Volume = target }):Play()
		end
		localPlayer:GetAttributeChangedSignal(ATTR_IS_PARTICIPANT):Connect(updateVolume)
		localPlayer:GetAttributeChangedSignal(ATTR_IS_ELIMINATED):Connect(updateVolume)
	end

	task.spawn(function()
		-- Se o áudio não puder ser carregado (removido ou sem permissão de
		-- uso nesta experiência), avisa no Output em vez de falhar em silêncio.
		ContentProvider:PreloadAsync({ music }, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success then
				warn(string.format("[BlocoPuff] Background music %s failed to load: %s", music.SoundId, status.Name))
			end
		end)
		if music.Parent ~= nil then
			music:Play()
		end
	end)
end

return table.freeze(MusicController)
