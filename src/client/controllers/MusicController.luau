--!strict

-- Toca a trilha de fundo localmente, em loop e com volume baixo fixo. Fica
-- em SoundService (som não posicional), então soa igual em qualquer lugar
-- do mapa e não depende do servidor.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

local SOUND_NAME = "BlocoPuffMusic"

local MusicController = {}

local started = false

function MusicController.start()
	if started then
		return
	end
	started = true

	local existing = SoundService:FindFirstChild(SOUND_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local music = Instance.new("Sound")
	music.Name = SOUND_NAME
	music.SoundId = GameConfig.Music.SoundId
	music.Volume = GameConfig.Music.Volume
	music.Looped = true
	music.Parent = SoundService

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
