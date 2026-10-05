--!strict

-- Relíquias e Álbum do Casarão (Fase 5C.2), no servidor:
--   * esconde as 40 relíquias do álbum junto aos móveis do catálogo, as
--     relíquias das temporadas no ar (entram e saem sozinhas) e a Relíquia
--     do Dia no esconderijo sorteado do dia (troca na virada);
--   * cada uma tem o prompt "Pegar"; o servidor confere a distância, limita
--     a frequência e entrega pelo perfil (tickets, bônus do cômodo, Puff
--     Explorador ao completar o álbum, coleção da Relíquia do Dia).
-- As relíquias ficam no mundo para todos; quem já pegou vê o lugar vazio
-- (o cliente apaga a dele, ver RelicController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local RelicModels = require(script.Parent.RelicModels)
local RelicSpots = require(script.Parent.RelicSpots)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local PuffInventory = require(script.Parent.Parent.data.PuffInventory)
local RelicRules = require(script.Parent.Parent.data.RelicRules)
local DailyRules = require(script.Parent.Parent.data.DailyRules)

type Profile = ProfileSchema.Profile
type RelicEvent = ProfileTypes.RelicEvent
type Level = RelicSpots.Level

local FOLDER_NAME = "MansionRelics"
local DAILY_NAME = "DailyRelic"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "RelicService"
-- Intervalo mínimo (s) entre duas relíquias do mesmo jogador.
local PICK_COOLDOWN = 0.4
-- Folga além do alcance do prompt (atraso de rede).
local DISTANCE_SLACK = 4
local DAY_CHECK_INTERVAL = 20

local RelicService = {}

local started = false
local folder: Folder? = nil
local world: Model? = nil
local dailyModel: Model? = nil
local dailyDay = 0
-- Modelos das relíquias de temporada no mundo, por temporada.
local seasonModels: { [string]: { Model } } = {}
local lastPick: { [Player]: number } = {}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Base virada para o centro do cômodo (a frente da relíquia aparece).
local function baseFor(level: Level, position: Vector3): CFrame
	local center = RelicSpots.center(level)
	local target = Vector3.new(center.X, position.Y, center.Z)
	if (target - position).Magnitude < 0.1 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, target)
end

-- Pontos já ocupados por relíquias (as peças delas não aparecem nos raios).
local function occupiedSpots(): { Vector3 }
	local list: { Vector3 } = {}
	local current = folder
	if current ~= nil then
		for _, child in ipairs(current:GetChildren()) do
			if child:IsA("Model") then
				table.insert(list, child:GetPivot().Position)
			end
		end
	end
	return list
end

-- Perto o bastante da relíquia (o prompt não confere sozinho).
local function isNear(player: Player, model: Model): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local distance = (root.Position - model:GetPivot().Position).Magnitude
	return distance <= RelicModels.PromptDistance + DISTANCE_SLACK
end

local function allowPick(player: Player): boolean
	local now = os.clock()
	local last = lastPick[player]
	if last ~= nil and now - last < PICK_COOLDOWN then
		return false
	end
	lastPick[player] = now
	return true
end

local function completedRooms(relics: { [string]: number }): number
	local count = 0
	for _, room in ipairs(RelicCatalog.rooms()) do
		if RelicCatalog.roomCount(relics, room.id) == #room.relics then
			count += 1
		end
	end
	return count
end

local function grantRelic(player: Player, relicId: string)
	local definition = RelicCatalog.get(relicId)
	local group = if definition ~= nil then RelicCatalog.group(definition.group) else nil
	if definition == nil or group == nil then
		return
	end
	-- Temporada encerrada: a relíquia já saiu do mundo (aviso atrasado).
	if group.season and not RelicCatalog.isActive(group, os.time()) then
		return
	end
	local groupIds = RelicCatalog.groupIds(group.id)
	local outcome: RelicRules.Outcome? = nil
	local saved = false
	local before = 0
	local balance = 0
	local rooms = 0
	local granted = PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, PlayerDataService.Events?)
		local now = os.time()
		local relics, result = RelicRules.collect(profile.relics, relicId, groupIds, RelicCatalog.allIds(), RelicCatalog.Rewards, group.tickets, now)
		if relics == nil or result == nil then
			return nil, nil
		end
		local updated = ProfileSchema.withTickets(profile, result.tickets)
		updated.relics = relics
		local newPuffs: { string }? = nil
		if result.albumCompleted and not PuffInventory.owns(profile.puffs, RelicCatalog.AlbumPuffId) then
			updated.puffs = PuffInventory.addPuff(profile.puffs, RelicCatalog.AlbumPuffId, "Album", now)
			newPuffs = { RelicCatalog.AlbumPuffId }
		end
		outcome = result
		saved = canSave
		before = profile.tickets
		balance = updated.tickets
		rooms = completedRooms(relics)
		local event: RelicEvent = {
			relicId = relicId,
			tickets = result.tickets,
			roomCompleted = result.roomCompleted,
			albumCompleted = result.albumCompleted,
			dailyCount = profile.dailyRelicCount,
			dailyGoal = false,
		}
		-- Comemora mesmo sem perfil salvo (o jogador vê o que pegou agora).
		return updated, { relicEvent = event, newPuffs = newPuffs }
	end, true)
	local result = outcome
	if not granted or result == nil or not saved then
		return
	end
	TelemetryService.lobbyEvent(player, "RelicFound", result.total, relicId, group.id)
	TelemetryService.ticketsEarned(player, before, balance, "Relic")
	if result.roomCompleted and group.season then
		TelemetryService.lobbyEvent(player, "SeasonCompleted", result.roomCount, group.id)
	elseif result.roomCompleted then
		TelemetryService.lobbyEvent(player, "RoomSetCompleted", rooms, group.id)
	end
	if result.albumCompleted then
		TelemetryService.lobbyEvent(player, "AlbumCompleted", result.total)
	end
end

local function grantDaily(player: Player, day: number)
	local outcome: RelicRules.DailyOutcome? = nil
	local saved = false
	local before = 0
	local balance = 0
	local granted = PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, PlayerDataService.Events?)
		local result = RelicRules.collectDaily(profile.dailyRelicDay, profile.dailyRelicCount, day, RelicCatalog.Rewards)
		if result == nil then
			return nil, nil
		end
		local updated = ProfileSchema.withTickets(profile, result.tickets)
		updated.dailyRelicDay = day
		updated.dailyRelicCount = result.count
		outcome = result
		saved = canSave
		before = profile.tickets
		balance = updated.tickets
		local event: RelicEvent = {
			relicId = nil,
			tickets = result.tickets,
			roomCompleted = false,
			albumCompleted = false,
			dailyCount = result.count,
			dailyGoal = result.goalReached,
		}
		return updated, { relicEvent = event }
	end, true)
	local result = outcome
	if not granted or result == nil or not saved then
		return
	end
	TelemetryService.lobbyEvent(player, "DailyRelicFound", result.count, tostring(day), if result.goalReached then "Goal" else nil)
	TelemetryService.ticketsEarned(player, before, balance, "DailyRelic")
end

local function connectPrompt(model: Model, onPick: (player: Player) -> ())
	local hitbox = model.PrimaryPart
	local prompt = if hitbox ~= nil then hitbox:FindFirstChild(RelicModels.PromptName) else nil
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		if not allowPick(player) or not isNear(player, model) then
			return
		end
		onPick(player)
	end)
end

-- Índice das peças visíveis do Casarão (sem as relíquias).
-- O Casarão não muda depois de pronto: o índice é montado uma vez.
local cachedIndex: RelicSpots.Index? = nil
local function spotIndex(parent: Folder): RelicSpots.Index
	local existing = cachedIndex
	if existing ~= nil then
		return existing
	end
	local root: Instance = world or parent
	local index = RelicSpots.index(root, parent)
	cachedIndex = index
	return index
end

-- Esconderijo junto ao móvel-âncora; sem ele, a fração (u, v) do cômodo.
local function spotFor(index: RelicSpots.Index, level: Level, anchor: string, nth: number?, u: number, v: number): Vector3?
	local occupied = occupiedSpots()
	return RelicSpots.hide(index, level, anchor, nth, occupied) or RelicSpots.find(index, level, u, v, occupied)
end

-- Esconde as relíquias de uma página (menos as que já estão em `placed`).
-- Devolve os modelos criados, por id.
local function placeGroup(parent: Folder, index: RelicSpots.Index, group: RelicCatalog.RelicGroup, placed: { [string]: Model }?): { [string]: Model }
	local models: { [string]: Model } = if placed ~= nil then placed else {}
	for _, definition in ipairs(group.relics) do
		if models[definition.id] ~= nil then
			continue
		end
		local level = RelicSpots.level(definition.room)
		local position = if level ~= nil then spotFor(index, level, definition.anchor, definition.nth, definition.u, definition.v) else nil
		if level == nil or position == nil then
			warn(`[BlocoPuff] Relic {definition.id} has no free spot in {definition.room}`)
		else
			local model = RelicModels.build(
				parent,
				`Relic_{definition.id}`,
				definition.shape,
				color(definition.color),
				baseFor(level, position),
				definition.name,
				{ [RelicCatalog.IdAttribute] = definition.id },
				RelicCatalog.Tag
			)
			local relicId = definition.id
			connectPrompt(model, function(player: Player)
				grantRelic(player, relicId)
			end)
			models[definition.id] = model
		end
	end
	return models
end

local function countPlaced(models: { [string]: Model }): number
	local count = 0
	for _ in pairs(models) do
		count += 1
	end
	return count
end

local function placeRelics(parent: Folder)
	local index = spotIndex(parent)
	for _, room in ipairs(RelicCatalog.rooms()) do
		placeGroup(parent, index, room, nil)
	end
end

-- Coloca as temporadas que entraram no ar (e as relíquias que ainda não
-- acharam lugar) e tira as que acabaram.
local function refreshSeasons(parent: Folder)
	local now = os.time()
	for _, season in ipairs(RelicCatalog.seasons()) do
		local active = RelicCatalog.isActive(season, now)
		local placed = seasonModels[season.id]
		if active and (placed == nil or countPlaced(placed) < #season.relics) then
			seasonModels[season.id] = placeGroup(parent, spotIndex(parent), season, placed)
		elseif not active and placed ~= nil then
			seasonModels[season.id] = nil
			for _, model in pairs(placed) do
				model:Destroy()
			end
		end
	end
end

-- Relíquia do Dia no esconderijo sorteado de `day` (troca a anterior).
-- `dailyDay` só muda quando ela é colocada (senão o laço tenta de novo).
local function placeDaily(parent: Folder, day: number)
	local previous = dailyModel
	dailyModel = nil
	if previous ~= nil then
		previous:Destroy()
	end
	local spots = RelicCatalog.dailySpots()
	local index = spotIndex(parent)
	local first = RelicRules.dailySpotIndex(day, #spots)
	local yesterday = RelicRules.dailySpotIndex(day - 1, #spots)
	-- Se o esconderijo do dia não couber, tenta os seguintes (menos o de ontem).
	for attempt = 0, #spots - 1 do
		local spotNumber = ((first - 1 + attempt) % #spots) + 1
		local spot = spots[spotNumber]
		local level = if spotNumber ~= yesterday or #spots == 1 then RelicSpots.level(spot.room) else nil
		local position = if level ~= nil then spotFor(index, level, spot.anchor, spot.nth, spot.u, spot.v) else nil
		if level ~= nil and position ~= nil then
			local model = RelicModels.build(
				parent,
				DAILY_NAME,
				"Daily",
				Color3.new(1, 1, 1),
				baseFor(level, position),
				RelicCatalog.DailyName,
				{ [RelicCatalog.DayAttribute] = day },
				RelicCatalog.DailyTag
			)
			dailyModel = model
			dailyDay = day
			connectPrompt(model, function(player: Player)
				-- Só vale a do dia atual (na virada ela muda de lugar).
				if model.Parent ~= nil and day == DailyRules.dayIndex(os.time()) then
					grantDaily(player, day)
				end
			end)
			return
		end
	end
	warn("[BlocoPuff] Daily relic has no free spot")
end

-- Miniaturas 3D de todas as relíquias (álbum e temporadas) para as fotos do
-- Álbum. Montadas de uma vez e só então publicadas (o cliente vê a pasta
-- completa).
local function publishIcons()
	if ReplicatedStorage:FindFirstChild(RelicCatalog.IconsFolder) ~= nil then
		return
	end
	local icons = Instance.new("Folder")
	icons.Name = RelicCatalog.IconsFolder
	for _, relicId in ipairs(RelicCatalog.everyId()) do
		local definition = RelicCatalog.get(relicId)
		if definition ~= nil then
			-- Uma miniatura com problema não leva as outras junto.
			local ok, err = pcall(RelicModels.icon, icons, relicId, definition.shape, color(definition.color))
			if not ok then
				warn(`[BlocoPuff] Relic icon {relicId} failed: {err}`)
			end
		end
	end
	icons.Parent = ReplicatedStorage
end

local function createFolder(worldRoot: Model): Folder
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
	return newFolder
end

-- Precisa do Casarão e da ala leste já construídos (as relíquias se
-- acomodam em cima dos móveis).
function RelicService.start(worldRoot: Model)
	if started then
		return
	end
	started = true
	world = worldRoot
	local parent = createFolder(worldRoot)
	folder = parent

	Players.PlayerRemoving:Connect(function(player: Player)
		lastPick[player] = nil
	end)

	-- Fora do caminho da inicialização: carregar as malhas pode demorar.
	task.spawn(function()
		RelicModels.preload()
		local iconsOk, iconsErr = pcall(publishIcons)
		if not iconsOk then
			warn(`[BlocoPuff] Relic icons failed: {iconsErr}`)
		end
		local ok, err = pcall(function()
			placeRelics(parent)
			refreshSeasons(parent)
			placeDaily(parent, DailyRules.dayIndex(os.time()))
		end)
		if not ok then
			warn(`[BlocoPuff] Relic placement failed: {err}`)
		end
		while parent.Parent ~= nil do
			task.wait(DAY_CHECK_INTERVAL)
			local today = DailyRules.dayIndex(os.time())
			if today ~= dailyDay or dailyModel == nil then
				local ok, err = pcall(placeDaily, parent, today)
				if not ok then
					warn(`[BlocoPuff] Daily relic move failed: {err}`)
				end
			end
			local seasonsOk, seasonsErr = pcall(refreshSeasons, parent)
			if not seasonsOk then
				warn(`[BlocoPuff] Season relics refresh failed: {seasonsErr}`)
			end
		end
	end)
end

return table.freeze(RelicService)
