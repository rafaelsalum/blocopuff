--!strict

-- Relíquias e Álbum do Casarão no cliente (Fase 5C.2):
--   * as relíquias que o jogador já tem viram um contorno vazio (sem brilho
--     e sem prompt), só para ele;
--   * as faíscas das que faltam só acendem bem de perto (de longe, nada
--     entrega o esconderijo);
--   * traduz o prompt "Pegar" e o nome da relíquia;
--   * comemora o que o servidor avisou no perfil (relíquia, cômodo
--     completo, álbum completo, Relíquia do Dia) com aviso e som;
--   * abre o ÁLBUM pelo botão 📜 do cartão de perfil.
-- O cliente não concede nada.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local AlbumView = require(script.Parent.Parent.ui.AlbumView)
local ProfileController = require(script.Parent.ProfileController)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type RelicEvent = ProfileTypes.RelicEvent
type AlbumViewHandle = AlbumView.AlbumViewHandle

local WAIT_TIMEOUT = 15
local HITBOX_NAME = "Hitbox"
local PROMPT_NAME = "PickPrompt"
-- Sons da Creator Store já usados no jogo: achado (desbloqueio do Puffdex)
-- e conquista maior (subir de nível).
local FOUND_SOUND = "rbxassetid://138190748214493"
local COMPLETE_SOUND = "rbxassetid://112485797063762"
local SOUND_VOLUME = 0.6
local SPARKLES_NAME = "Sparkles"
-- Distância (studs) em que as faíscas acendem e intervalo da conferência.
local SPARKLE_RADIUS = 10
local SPARKLE_INTERVAL = 0.3

local RelicController = {}

-- Aparência original de cada peça (para voltar ao normal).
type Original = { material: Enum.Material, transparency: number }

local started = false
local view: AlbumViewHandle? = nil
local owned: { [string]: boolean } = {}
local dailyRelicDay = 0
local ghosted: { [Model]: boolean } = {}
local originals: { [BasePart]: Original } = {}

local function playSound(soundId: string)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = SOUND_VOLUME
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(6, function()
		if sound.Parent ~= nil then
			sound:Destroy()
		end
	end)
end

local function promptOf(model: Model): ProximityPrompt?
	local hitbox = model:FindFirstChild(HITBOX_NAME)
	local prompt = if hitbox ~= nil then hitbox:FindFirstChild(PROMPT_NAME) else nil
	return if prompt ~= nil and prompt:IsA("ProximityPrompt") then prompt else nil
end

-- Já pegou: contorno vazio (material de campo de força), sem brilho nem prompt.
local function setGhost(model: Model, ghost: boolean)
	if (ghosted[model] == true) == ghost then
		return
	end
	ghosted[model] = if ghost then true else nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= HITBOX_NAME then
			if ghost then
				originals[descendant] = { material = descendant.Material, transparency = descendant.Transparency }
				descendant.Material = Enum.Material.ForceField
				descendant.Transparency = 0.3
			else
				local original = originals[descendant]
				originals[descendant] = nil
				if original ~= nil then
					descendant.Material = original.material
					descendant.Transparency = original.transparency
				end
			end
		elseif descendant:IsA("ParticleEmitter") and ghost then
			descendant.Enabled = false
		end
	end
	local prompt = promptOf(model)
	if prompt ~= nil then
		prompt.Enabled = not ghost
	end
end

local function isOwned(model: Model): boolean
	if CollectionService:HasTag(model, RelicCatalog.DailyTag) then
		local day = model:GetAttribute(RelicCatalog.DayAttribute)
		return typeof(day) == "number" and day > 0 and day == dailyRelicDay
	end
	local id = model:GetAttribute(RelicCatalog.IdAttribute)
	return typeof(id) == "string" and owned[id] == true
end

local function localizePrompt(model: Model)
	local prompt = promptOf(model)
	if prompt == nil then
		return
	end
	prompt.ActionText = Lang.t("Pegar")
	local definition = RelicCatalog.get(model:GetAttribute(RelicCatalog.IdAttribute))
	prompt.ObjectText = if definition ~= nil then Lang.t(definition.name) else Lang.t(RelicCatalog.DailyName)
end

local function apply(model: Model)
	if not model:IsA("Model") then
		return
	end
	setGhost(model, isOwned(model))
end

local function allRelics(): { Model }
	local list: { Model } = {}
	for _, tag in ipairs({ RelicCatalog.Tag, RelicCatalog.DailyTag }) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			if instance:IsA("Model") then
				table.insert(list, instance)
			end
		end
	end
	return list
end

local function refreshAll()
	for _, model in ipairs(allRelics()) do
		apply(model)
	end
end

-- A Relíquia do Dia que está no mundo é a de hoje: já pegou?
local function foundToday(): boolean?
	for _, instance in ipairs(CollectionService:GetTagged(RelicCatalog.DailyTag)) do
		local day = instance:GetAttribute(RelicCatalog.DayAttribute)
		if typeof(day) == "number" then
			return day == dailyRelicDay
		end
	end
	return nil
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	localizePrompt(instance)
	apply(instance)
	for _, attribute in ipairs({ RelicCatalog.DayAttribute, RelicCatalog.IdAttribute }) do
		instance:GetAttributeChangedSignal(attribute):Connect(function()
			localizePrompt(instance)
			apply(instance)
		end)
	end
end

local function notify(key: string, icon: string, title: string, subtitle: string, priority: NotificationManager.Priority)
	NotificationManager.notify({
		channel = "Banner",
		category = "Progression",
		priority = priority,
		key = key,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = "Winner",
		duration = 4,
		maxWait = 30,
	})
end

-- Página do Diário: aviso curto e a leitura aberta na hora.
local function celebratePage(definition: RelicCatalog.RelicDefinition, diary: RelicCatalog.RelicGroup, count: number, completed: boolean)
	notify(
		`page-{definition.id}`,
		"📖",
		Lang.t("PÁGINA DO DIÁRIO!"),
		Lang.t("%s · %d/%d · +%d 🎟", Lang.t(definition.name), count, #diary.relics, RelicCatalog.Rewards.RelicTickets),
		"Normal"
	)
	if completed then
		notify("page-diary-complete", "🏅", Lang.t("DIÁRIO COMPLETO!"), Lang.t("Título: %s · +%d 🎟", Lang.t(diary.title), diary.tickets), "High")
	end
	playSound(if completed then COMPLETE_SOUND else FOUND_SOUND)
	local current = view
	if current ~= nil then
		current.readPage(definition.id)
	end
end

local function celebrate(event: RelicEvent)
	local relicId = event.relicId
	if relicId == nil then
		local rewards = RelicCatalog.Rewards
		notify(
			`daily-relic-{event.dailyCount}`,
			"🌟",
			Lang.t("RELÍQUIA DO DIA!"),
			Lang.t("Relíquias do Dia: %d de %d · +%d 🎟", math.min(event.dailyCount, rewards.DailyGoal), rewards.DailyGoal, event.tickets),
			"High"
		)
		if event.dailyGoal then
			notify("daily-relic-goal", "🏅", Lang.t("NOVO TÍTULO!"), Lang.t(RelicCatalog.DailyTitle), "High")
		end
		playSound(if event.dailyGoal then COMPLETE_SOUND else FOUND_SOUND)
		return
	end
	local definition = RelicCatalog.get(relicId)
	local room = if definition ~= nil then RelicCatalog.group(definition.group) else nil
	if definition == nil or room == nil then
		return
	end
	local count = RelicCatalog.roomCount(owned, room.id)
	if room.diary then
		celebratePage(definition, room, count, event.roomCompleted)
		return
	end
	notify(
		`relic-{relicId}`,
		"📜",
		Lang.t("RELÍQUIA ENCONTRADA!"),
		Lang.t("%s · %s %d/%d · +%d 🎟", Lang.t(definition.name), Lang.t(room.name), count, #room.relics, RelicCatalog.Rewards.RelicTickets),
		"Normal"
	)
	if event.roomCompleted then
		notify(
			`relic-room-{room.id}`,
			"🏅",
			if room.season then Lang.t("TEMPORADA COMPLETA!") else Lang.t("CÔMODO COMPLETO!"),
			Lang.t("Título: %s · +%d 🎟", Lang.t(room.title), room.tickets),
			"High"
		)
	end
	if event.albumCompleted then
		notify("relic-album", "📖", Lang.t("ÁLBUM COMPLETO!"), Lang.t("Título: %s", Lang.t(RelicCatalog.AlbumTitle)), "High")
	end
	playSound(if event.roomCompleted or event.albumCompleted then COMPLETE_SOUND else FOUND_SOUND)
end

local function onProfile(snapshot: ProfileSnapshot, initial: boolean?)
	local set: { [string]: boolean } = {}
	for _, state in ipairs(snapshot.relics) do
		set[state.id] = true
	end
	owned = set
	dailyRelicDay = snapshot.dailyRelicDay
	refreshAll()
	local current = view
	if current ~= nil then
		current.setProfile(snapshot, foundToday())
	end
	local event = snapshot.relicEvent
	-- O perfil guardado de antes do controlador subir não comemora de novo.
	if event ~= nil and initial ~= true then
		celebrate(event)
	end
end

-- Faíscas só de perto e só nas que faltam.
local function refreshSparkles()
	local localPlayer = Players.LocalPlayer
	local character = if localPlayer ~= nil then localPlayer.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local origin = if root ~= nil and root:IsA("BasePart") then root.Position else nil
	for _, model in ipairs(allRelics()) do
		local hitbox = model:FindFirstChild(HITBOX_NAME)
		local sparkles = if hitbox ~= nil then hitbox:FindFirstChild(SPARKLES_NAME) else nil
		if sparkles ~= nil and sparkles:IsA("ParticleEmitter") and hitbox ~= nil and hitbox:IsA("BasePart") then
			local near = origin ~= nil and (hitbox.Position - origin).Magnitude <= SPARKLE_RADIUS
			local wanted = near and ghosted[model] ~= true
			if sparkles.Enabled ~= wanted then
				sparkles.Enabled = wanted
			end
		end
	end
end

function RelicController.openAlbum()
	local current = view
	if current == nil then
		return
	end
	if current.isOpen() then
		current.close()
	else
		local snapshot = ProfileController.get()
		if snapshot ~= nil then
			current.setProfile(snapshot, foundToday())
		end
		current.open()
	end
end

function RelicController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		warn("[BlocoPuff] Relic controller not started: PlayerGui unavailable")
		return
	end
	NotificationManager.init(playerGui)

	-- Abrir o álbum só vira telemetria (pelo remote do Puffdex, que já
	-- limita a frequência).
	local newView = AlbumView.new(playerGui, function()
		local remotes = ReplicatedStorage:FindFirstChild(PuffadorConstants.RemotesContainerName)
		local remote = if remotes ~= nil then remotes:FindFirstChild(PuffadorConstants.PuffdexRemoteName) else nil
		if remote ~= nil and remote:IsA("RemoteEvent") then
			remote:FireServer("AlbumOpened")
		end
	end)
	view = newView

	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			newView.close()
		end
	end)

	for _, tag in ipairs({ RelicCatalog.Tag, RelicCatalog.DailyTag }) do
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance)
			if instance:IsA("Model") then
				ghosted[instance] = nil
				for _, descendant in ipairs(instance:GetDescendants()) do
					if descendant:IsA("BasePart") then
						originals[descendant] = nil
					end
				end
			end
		end)
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			watch(instance)
		end
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < SPARKLE_INTERVAL then
			return
		end
		elapsed = 0
		refreshSparkles()
	end)

	ProfileController.Changed:Connect(onProfile)
	local current = ProfileController.get()
	if current ~= nil then
		onProfile(current, true)
	end
end

return table.freeze(RelicController)
