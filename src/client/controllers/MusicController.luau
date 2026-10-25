--!strict

-- Trilha sonora de fundo, local, que muda com o momento (MusicMood): uma
-- para o Casarão de dia e outra à noite, a floresta lá fora (com
-- passarinhos de dia e grilos à noite por baixo), o interior da Torre do
-- Relógio e uma para cada modo da partida, com o Caos Final mais épico.
-- Cada clima tem várias faixas que se revezam, com troca suave. No fim da
-- partida quem jogou ouve uma vinheta (vitória ou encerramento). Fica em
-- SoundService (som não posicional) e não depende do servidor.

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MusicConfig = require(ReplicatedStorage.Shared.config.MusicConfig)
local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local OutdoorConfig = require(ReplicatedStorage.Shared.config.OutdoorConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local MusicMood = require(ReplicatedStorage.Shared.modules.MusicMood)

local FOLDER_NAME = "BlocoPuffMusic"
local WORLD_NAME = "BlocoPuffWorld"
local OUTDOORS_NAME = "Outdoors"
local TOWER_NAME = "RaceTower"
local WAIT_TIMEOUT = 30
local STING_DELAY = 0.6

type Mood = MusicMood.Mood
type Place = MusicMood.Place

local MusicController = {}

local started = false
local folder: Folder? = nil
local currentMood: Mood? = nil
local currentSound: Sound? = nil
local lastIndex: { [string]: number } = {}
local ambienceKind: MusicMood.Ambience = "None"
local ambienceSound: Sound? = nil
local place: Place = "Indoors"
local random = Random.new()

local function fade(sound: Sound, volume: number, after: (() -> ())?)
	local tween = TweenService:Create(sound, TweenInfo.new(MusicConfig.FadeTime, Enum.EasingStyle.Sine), { Volume = volume })
	if after ~= nil then
		tween.Completed:Connect(after)
	end
	tween:Play()
end

local function fadeOutAndDestroy(sound: Sound)
	fade(sound, 0, function()
		sound:Destroy()
	end)
end

local function newSound(name: string, soundId: string, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = looped
	sound.Volume = 0
	sound.Parent = folder
	-- Se o áudio não carregar (removido ou sem permissão nesta experiência),
	-- avisa no Output em vez de falhar em silêncio.
	task.spawn(function()
		ContentProvider:PreloadAsync({ sound }, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success then
				warn(`[BlocoPuff] Music {soundId} failed to load: {status.Name}`)
			end
		end)
	end)
	return sound
end

-- Toca a próxima faixa do clima `mood`, trocando suave com a que tocava.
local function playNext(mood: Mood)
	local settings = MusicConfig.Moods[mood]
	local previous = currentSound
	currentSound = nil
	if previous ~= nil then
		fadeOutAndDestroy(previous)
	end
	if settings == nil or #settings.Tracks == 0 then
		return
	end
	local index = MusicMood.nextIndex(#settings.Tracks, lastIndex[mood], random:NextNumber())
	lastIndex[mood] = index
	local sound = newSound(`Music_{mood}`, settings.Tracks[index], false)
	currentSound = sound
	-- Quando a faixa acaba, entra outra do mesmo clima.
	sound.Ended:Connect(function()
		if currentSound == sound and currentMood == mood then
			playNext(mood)
		end
	end)
	sound:Play()
	fade(sound, settings.Volume)
end

local function setAmbience(kind: MusicMood.Ambience)
	if kind == ambienceKind then
		return
	end
	ambienceKind = kind
	local previous = ambienceSound
	ambienceSound = nil
	if previous ~= nil then
		fadeOutAndDestroy(previous)
	end
	local settings = MusicConfig.Ambience[kind]
	if settings == nil or #settings.Tracks == 0 then
		return
	end
	local sound = newSound(`Ambience_{kind}`, settings.Tracks[1], true)
	ambienceSound = sound
	sound:Play()
	fade(sound, settings.Volume)
end

local function setMood(mood: Mood)
	setAmbience(MusicMood.ambienceFor(mood))
	if mood == currentMood then
		return
	end
	currentMood = mood
	playNext(mood)
end

-- Dentro ou fora: procura um teto em cima do jogador, ignorando a floresta
-- e os personagens. Teto da Torre conta como Torre.
local function findPlace(localPlayer: Player): Place
	local character = localPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return place
	end
	local world = Workspace:FindFirstChild(WORLD_NAME)
	local exclude: { Instance } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character ~= nil then
			table.insert(exclude, player.Character)
		end
	end
	local outdoors = if world ~= nil then world:FindFirstChild(OUTDOORS_NAME) else nil
	if outdoors ~= nil then
		table.insert(exclude, outdoors)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, MusicConfig.RoofProbe, 0), params)
	if hit == nil or hit.Instance:IsA("Terrain") then
		return "Outdoors"
	end
	local tower = if world ~= nil then world:FindFirstChild(TOWER_NAME) else nil
	if tower ~= nil and hit.Instance:IsDescendantOf(tower) then
		return "Tower"
	end
	return "Indoors"
end

local function isParticipant(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
end

local function isCompeting(player: Player): boolean
	return isParticipant(player) and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function isMysteryFinal(container: Instance, player: Player): boolean
	local remaining = container:GetAttribute(StateAttributeNames.TimeRemaining)
	return container:GetAttribute(StateAttributeNames.RoundState) == "Active"
		and container:GetAttribute(StateAttributeNames.RoundMode) == "Mystery"
		and isParticipant(player)
		and typeof(remaining) == "number"
		and remaining > 0
		and remaining <= MysteryModeConfig.Sounds.FinalMusicSeconds
end

local function readString(container: Instance, name: string): string?
	local value = container:GetAttribute(name)
	return if typeof(value) == "string" then value else nil
end

local function refresh(container: Instance, localPlayer: Player)
	local lamps = OutdoorConfig.Lamps
	setMood(MusicMood.pick({
		roundState = readString(container, StateAttributeNames.RoundState),
		roundMode = readString(container, StateAttributeNames.RoundMode),
		finalChaos = container:GetAttribute(StateAttributeNames.FinalChaos) == true,
		competing = isCompeting(localPlayer),
		mysteryFinal = isMysteryFinal(container, localPlayer),
		place = place,
		clock = Lighting.ClockTime,
		nightFrom = lamps.OnHour,
		nightUntil = lamps.OffHour,
	}))
end

-- Vinheta do fim da partida, com a música abaixada enquanto toca.
local function playSting(kind: MusicMood.Sting)
	local settings = MusicConfig.Stings[kind]
	if settings == nil or #settings.Tracks == 0 then
		return
	end
	local sting = newSound(`Sting_{kind}`, settings.Tracks[1], false)
	sting.Volume = settings.Volume
	local ducked = currentSound
	local moodSettings = if currentMood ~= nil then MusicConfig.Moods[currentMood] else nil
	if ducked ~= nil and moodSettings ~= nil then
		ducked.Volume = moodSettings.Volume * MusicConfig.StingDuck
	end
	sting.Ended:Connect(function()
		sting:Destroy()
		if ducked ~= nil and ducked.Parent ~= nil and ducked == currentSound and moodSettings ~= nil then
			fade(ducked, moodSettings.Volume)
		end
	end)
	sting:Play()
end

function MusicController.start()
	if started then
		return
	end
	started = true
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return
	end

	local existing = SoundService:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = SoundService
	folder = created

	task.spawn(function()
		local container = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, WAIT_TIMEOUT)
		if container == nil then
			warn("[BlocoPuff] Music not started: state container unavailable")
			return
		end
		local function update()
			refresh(container, localPlayer)
		end

		-- Quem estava na partida quando ela começou a acabar ouve a vinheta.
		local lastState = readString(container, StateAttributeNames.RoundState)
		container:GetAttributeChangedSignal(StateAttributeNames.RoundState):Connect(function()
			local state = readString(container, StateAttributeNames.RoundState)
			if state == "Ending" and lastState ~= "Ending" then
				-- O servidor grava o vencedor logo depois de mudar o estado.
				local played = isParticipant(localPlayer)
				task.delay(STING_DELAY, function()
					local winner = container:GetAttribute(StateAttributeNames.WinnerUserId)
					local sting = MusicMood.stingFor(played, if typeof(winner) == "number" then winner else nil, localPlayer.UserId)
					if sting ~= nil then
						playSting(sting)
					end
				end)
			end
			lastState = state
		end)

		container.AttributeChanged:Connect(update)
		localPlayer.AttributeChanged:Connect(update)
		local warned = false
		while true do
			local ok, failure = pcall(function()
				place = findPlace(localPlayer)
				update()
			end)
			-- Um aviso só: um erro a cada segundo não lota a saída.
			if not ok and not warned then
				warned = true
				warn(`[BlocoPuff] Music refresh failed: {failure}`)
			end
			task.wait(MusicConfig.CheckPeriod)
		end
	end)
end

return table.freeze(MusicController)
