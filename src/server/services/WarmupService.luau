--!strict

-- Aquecimento no mirante enquanto a partida não começa: quem está na fila
-- (no mirante, com o embarque aberto) recebe o Puffador de treino e estoura
-- balões-Puff que sobem na frente do vidro; há dois trampolins nas pontas
-- (o impulso é aplicado no cliente, MatchQueueController). Sem prêmio: o
-- placar da espera só aparece nos painéis ("🎈 Ana 7 · Rafa 5") e zera
-- quando o embarque fecha. Os disparos de treino só acertam superfícies
-- (ver ProjectileService/PuffadorService): nada quebra nem empurra ninguém.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local QueueConfig = require(ReplicatedStorage.Shared.config.QueueConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local MatchQueueService = require(script.Parent.MatchQueueService)
local ProjectileService = require(script.Parent.ProjectileService)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local PuffadorService = require(script.Parent.PuffadorService)
local TelemetryService = require(script.Parent.TelemetryService)

local FOLDER_NAME = "Warmup"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "WarmupService"
local BALLOON_ATTRIBUTE = "WarmupBalloon"
local HANDLER_KEY = "Warmup"
-- Tag lida pelo cliente para aplicar o impulso do trampolim.
local TRAMPOLINE_TAG = "PuffTrampoline"
local CHECK_INTERVAL = 0.25
local BALLOON_SIZE = 2.2
local TOP_SCORES = 3
local POP_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local BALLOON_COLORS = {
	Color3.fromRGB(255, 160, 200),
	Color3.fromRGB(150, 220, 255),
	Color3.fromRGB(196, 170, 255),
	Color3.fromRGB(255, 220, 130),
	Color3.fromRGB(150, 235, 190),
}

local WarmupService = {}

local started = false
local folder: Folder? = nil
local rng = Random.new()
-- Quem recebeu o Puffador de treino aqui (só esses perdem ao sair).
local warmers: { [Player]: boolean } = {}
local scores: { [Player]: number } = {}
local balloons: { [Part]: Tween } = {}
local balloonCount = 0
local active = false
local accumulator = 0

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function publishScores()
	local ranking: { { name: string, score: number } } = {}
	for player, score in pairs(scores) do
		if score > 0 and player.Parent ~= nil then
			table.insert(ranking, { name = player.DisplayName, score = score })
		end
	end
	table.sort(ranking, function(a, b)
		return a.score > b.score
	end)
	local parts: { string } = {}
	for index = 1, math.min(TOP_SCORES, #ranking) do
		table.insert(parts, `{ranking[index].name} {ranking[index].score}`)
	end
	MatchQueueService.setWarmupLine(if #parts > 0 then `🎈 {table.concat(parts, " · ")}` else "🎈 Estoure os balões enquanto espera!")
end

local function removeBalloon(balloon: Part)
	local tween = balloons[balloon]
	if tween ~= nil then
		tween:Cancel()
	end
	balloons[balloon] = nil
	balloonCount = math.max(0, balloonCount - 1)
	balloon:Destroy()
end

-- Um balão nasce perto do piso, em algum ponto do mirante, e sobe até
-- perto do teto; ao chegar lá (ou estourar) outro toma o lugar.
local function spawnBalloon()
	local parent = folder
	if parent == nil or not active or balloonCount >= QueueConfig.BalloonCount then
		return
	end
	local gallery = BuildingLayout.getGallery(GameConfig.Arena, GameConfig.Building)
	local depth = GameConfig.Building.GalleryDepth
	local halfLength = gallery.size.Z / 2 - 8
	local x = gallery.innerX + 3 + rng:NextNumber() * (depth * 0.45)
	local z = gallery.center.Z + rng:NextNumber(-halfLength, halfLength)
	local balloon = Instance.new("Part")
	balloon.Name = "Balloon"
	balloon.Shape = Enum.PartType.Ball
	balloon.Anchored = true
	balloon.CanCollide = false
	balloon.CanTouch = false
	balloon.CastShadow = false
	balloon.Size = Vector3.new(BALLOON_SIZE, BALLOON_SIZE, BALLOON_SIZE)
	balloon.Position = Vector3.new(x, gallery.floorY + 3, z)
	balloon.Color = BALLOON_COLORS[rng:NextInteger(1, #BALLOON_COLORS)]
	balloon.Material = Enum.Material.SmoothPlastic
	balloon:SetAttribute(BALLOON_ATTRIBUTE, true)
	balloon.Parent = parent
	balloonCount += 1
	local rise = QueueConfig.BalloonRiseTime
	local tween = TweenService:Create(balloon, TweenInfo.new(rng:NextNumber(rise.Min, rise.Max), Enum.EasingStyle.Linear), {
		Position = balloon.Position + Vector3.new(rng:NextNumber(-1.5, 1.5), 14, 0),
	})
	balloons[balloon] = tween
	tween.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and balloons[balloon] ~= nil then
			removeBalloon(balloon)
			spawnBalloon()
		end
	end)
	tween:Play()
end

local function setActive(value: boolean)
	if active == value then
		return
	end
	active = value
	if value then
		table.clear(scores)
		publishScores()
		for _ = balloonCount + 1, QueueConfig.BalloonCount do
			spawnBalloon()
		end
	else
		local list: { Part } = {}
		for balloon in pairs(balloons) do
			table.insert(list, balloon)
		end
		for _, balloon in ipairs(list) do
			removeBalloon(balloon)
		end
		MatchQueueService.setWarmupLine("")
	end
end

-- Só jogadores (bots não atiram aqui).
local function onSurfaceHit(combatant: CombatantRegistry.Combatant, instance: Instance, _position: Vector3)
	local shooter = combatant.player
	if shooter == nil then
		return
	end
	if instance:GetAttribute(BALLOON_ATTRIBUTE) ~= true or not instance:IsA("Part") or not warmers[shooter] then
		return
	end
	local balloon = instance
	if balloons[balloon] == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = POP_SOUND
	sound.Volume = 0.5
	sound.PlaybackSpeed = rng:NextNumber(1.4, 1.7)
	sound.Parent = folder
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 3)
	sound:Play()
	removeBalloon(balloon)
	scores[shooter] = (scores[shooter] or 0) + 1
	PuffadorService.sendFeedback(shooter, "Hit", nil)
	publishScores()
	task.delay(QueueConfig.BalloonRespawnDelay, spawnBalloon)
end

local function release(player: Player)
	if warmers[player] then
		warmers[player] = nil
		if not isCompeting(player) then
			PuffadorService.setTraining(player, false)
		end
		TelemetryService.lobbyEvent(player, "WarmupSession", scores[player] or 0)
	end
end

local function check()
	local boardingOpen = MatchQueueService.isBoardingOpen()
	local anyone = false
	for _, player in ipairs(Players:GetPlayers()) do
		local eligible = boardingOpen and MatchQueueService.isInZone(player) and not isCompeting(player)
		if eligible then
			anyone = true
			warmers[player] = true
			-- Também devolve o de treino depois de uma partida (o
			-- PuffadorService recolhe todos no fim).
			if not PuffadorService.isTraining(player) then
				PuffadorService.setTraining(player, true)
			end
		elseif warmers[player] then
			release(player)
		end
	end
	setActive(anyone)
end

local function buildTrampolines(parent: Instance)
	local gallery = BuildingLayout.getGallery(GameConfig.Arena, GameConfig.Building)
	local halfLength = gallery.size.Z / 2
	for index, side in ipairs({ -1, 1 }) do
		-- Entre as colunas de nascimento do mirante (ver getGallerySpawnCFrames).
		local center = Vector3.new(gallery.center.X + 5, gallery.floorY, gallery.center.Z + side * (halfLength - 6))
		local rim = Instance.new("Part")
		rim.Name = `TrampolineRim{index}`
		rim.Shape = Enum.PartType.Cylinder
		rim.Anchored = true
		rim.Size = Vector3.new(0.8, 6.4, 6.4)
		rim.CFrame = CFrame.new(center + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
		rim.Color = Color3.fromRGB(104, 76, 204)
		rim.Material = Enum.Material.SmoothPlastic
		rim.Parent = parent
		local pad = Instance.new("Part")
		pad.Name = `Trampoline{index}`
		pad.Shape = Enum.PartType.Cylinder
		pad.Anchored = true
		pad.CanCollide = false
		pad.Size = Vector3.new(0.3, 5.4, 5.4)
		pad.CFrame = CFrame.new(center + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pad.Color = Color3.fromRGB(255, 122, 186)
		pad.Material = Enum.Material.Fabric
		pad.Parent = parent
		CollectionService:AddTag(pad, TRAMPOLINE_TAG)
	end
end

function WarmupService.start(worldRoot: Model)
	if started then
		return
	end
	started = true
	local existing = worldRoot:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	newFolder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newFolder.Parent = worldRoot
	folder = newFolder
	buildTrampolines(newFolder)

	ProjectileService.setSurfaceHitHandler(HANDLER_KEY, onSurfaceHit)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0
		check()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		warmers[player] = nil
		scores[player] = nil
	end)
end

return table.freeze(WarmupService)
