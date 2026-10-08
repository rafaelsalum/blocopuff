--!strict

-- Salas Secretas do Barão do cliente (Fase 5C.3, parte 3). Para quem tem
-- acesso (atributo `BaronRoom_<id>` que o servidor publica), a passagem
-- abre só na tela dele: a estante da Biblioteca gira e o lacre do vão e as
-- tábuas do túnel somem e deixam passar (a física do personagem é do
-- cliente). Amigos veem a passagem aberta enquanto alguém com acesso está
-- perto dela (ou dentro da sala) e quem está dentro sempre consegue sair
-- (BaronRoomsRules.shouldOpen). O prompt do prêmio só aparece para quem tem
-- acesso e ainda não pegou; o servidor confere tudo de novo.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local BaronRoomsConfig = require(ReplicatedStorage.Shared.config.BaronRoomsConfig)
local BaronRoomsLayout = require(ReplicatedStorage.Shared.modules.BaronRoomsLayout)
local BaronRoomsRules = require(ReplicatedStorage.Shared.modules.BaronRoomsRules)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local ProfileController = require(script.Parent.ProfileController)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type Room = BaronRoomsLayout.Room

local WAIT_TIMEOUT = 15
local CLAIM_SOUND = "rbxassetid://138190748214493"
local REFRESH_SECONDS = 3
-- Avisos de "passagem aberta" só depois que o perfil já carregou (no
-- carregamento o acesso chega de uma vez e não é novidade).
local ANNOUNCE_AFTER = 10
local LID_OPEN_DEGREES = 75
local WING_NAME = "MansionWing"
local ROOMS_NAME = "BaronRooms"

local BaronRoomsController = {}

type ShelfState = {
	model: Model,
	closed: CFrame,
	progress: number,
	target: number,
}

local started = false
local remote: RemoteEvent? = nil
local claimed: { [string]: boolean } = {}
local lastNearAt: { [string]: number? } = {}
local passageParts: { BasePart } = {}
-- Colisão original de cada peça (do servidor), para fechar de volta igual.
local originalCollide: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local prompts: { ProximityPrompt } = {}
local shelf: ShelfState? = nil
local openedLid: BasePart? = nil
local cachedWing: Instance? = nil

local function playSound(soundId: string)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.8
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function notify(key: string, icon: string, title: string, subtitle: string)
	NotificationManager.notify({
		channel = "Banner",
		category = "Progression",
		priority = "High",
		key = key,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = "Gold",
		duration = 4,
		maxWait = 30,
	})
end

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function hasAccess(player: Player, id: string): boolean
	return player:GetAttribute(BaronRoomsConfig.AccessAttributePrefix .. id) == true
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function wingModel(): Instance?
	local wing = cachedWing
	if wing ~= nil and wing.Parent ~= nil then
		return wing
	end
	local world = Workspace:FindFirstChild("BlocoPuffWorld")
	cachedWing = if world ~= nil then world:FindFirstChild(WING_NAME, true) else nil
	return cachedWing
end

-- Peças das passagens, prompts e estante (chegam e saem com o streaming).
local function refresh()
	local wing = wingModel()
	table.clear(passageParts)
	table.clear(prompts)
	if wing == nil then
		return
	end
	for _, descendant in ipairs(wing:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute(BaronRoomsConfig.PassageAttribute) ~= nil then
			if originalCollide[descendant] == nil then
				originalCollide[descendant] = descendant.CanCollide
			end
			table.insert(passageParts, descendant)
		elseif descendant:IsA("ProximityPrompt") and descendant:GetAttribute(BaronRoomsConfig.PromptAttribute) ~= nil then
			table.insert(prompts, descendant)
		elseif descendant:IsA("Model") and descendant:GetAttribute(BaronRoomsConfig.ShelfAttribute) ~= nil then
			local current = shelf
			if current == nil or current.model ~= descendant then
				-- Instância nova (o servidor sempre a monta fechada).
				shelf = { model = descendant, closed = descendant:GetPivot(), progress = 0, target = 0 }
			end
		end
	end
end

-- Distância do dono (alguém com acesso) mais perto da entrada; 0 se ele
-- está dentro da sala. nil se ninguém.
local function ownerDistance(me: Player, room: Room): number?
	local best: number? = nil
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= me and hasAccess(other, room.id) and not isCompeting(other) then
			local position = rootPosition(other)
			if position ~= nil then
				local distance: number
				if BaronRoomsLayout.isInside(room, position, BaronRoomsConfig.RoomMargin) then
					distance = 0
				elseif math.abs(position.Y - room.passage.entry.Y) <= BaronRoomsConfig.OwnerHeight + 3 then
					distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(room.passage.entry.X, 0, room.passage.entry.Z)).Magnitude
				else
					continue
				end
				if best == nil or distance < best then
					best = distance
				end
			end
		end
	end
	return best
end

local function applyPassage(id: string, open: boolean)
	for _, passagePart in ipairs(passageParts) do
		if passagePart.Parent ~= nil and passagePart:GetAttribute(BaronRoomsConfig.PassageAttribute) == id then
			passagePart.CanCollide = not open and originalCollide[passagePart] ~= false
			passagePart.LocalTransparencyModifier = if open then 1 else 0
		end
	end
	local current = shelf
	if id == "Study" and current ~= nil then
		current.target = if open then 1 else 0
	end
end

local function applyPrompts(player: Player)
	local competing = isCompeting(player)
	for _, prompt in ipairs(prompts) do
		local id = prompt:GetAttribute(BaronRoomsConfig.PromptAttribute)
		if typeof(id) == "string" then
			local enabled = not competing and hasAccess(player, id) and not claimed[id]
			if prompt.Enabled ~= enabled then
				prompt.Enabled = enabled
			end
		end
	end
end

-- Tampa do baú aberta na tela de quem já pegou o tesouro.
local function applyLid()
	if not claimed.Treasure then
		return
	end
	local wing = wingModel()
	local rooms = if wing ~= nil then wing:FindFirstChild(ROOMS_NAME) else nil
	local chest = if rooms ~= nil then rooms:FindFirstChild("BaronChest") else nil
	local lid = if chest ~= nil then chest:FindFirstChild("ChestLid") else nil
	if lid == nil or not lid:IsA("BasePart") or lid == openedLid then
		return
	end
	local hinge = lid.CFrame * CFrame.new(0, -lid.Size.Y / 2, lid.Size.Z / 2)
	lid.CFrame = hinge * CFrame.Angles(math.rad(LID_OPEN_DEGREES), 0, 0) * hinge:Inverse() * lid.CFrame
	openedLid = lid
end

local function step(player: Player)
	local position = rootPosition(player)
	local now = os.clock()
	local layout = BaronRoomsLayout.get()
	for _, room in ipairs({ layout.Study, layout.Treasure }) do
		local id = room.id
		local inside = position ~= nil and BaronRoomsLayout.isInside(room, position, BaronRoomsConfig.RoomMargin)
		local open, nearAt = BaronRoomsRules.shouldOpen(
			hasAccess(player, id),
			inside,
			ownerDistance(player, room),
			BaronRoomsConfig.OwnerRadius,
			lastNearAt[id],
			now,
			BaronRoomsConfig.CloseDelay
		)
		lastNearAt[id] = nearAt
		applyPassage(id, open)
	end
	applyPrompts(player)
end

-- Gira a estante na dobradiça (canto da frente, lado sul).
local function animateShelf(deltaTime: number)
	local current = shelf
	if current == nil or current.progress == current.target then
		return
	end
	if current.model.Parent == nil then
		shelf = nil
		return
	end
	local speed = deltaTime / BaronRoomsConfig.ShelfTurnSeconds
	if current.target > current.progress then
		current.progress = math.min(current.target, current.progress + speed)
	else
		current.progress = math.max(current.target, current.progress - speed)
	end
	-- Suave no começo e no fim.
	local eased = current.progress * current.progress * (3 - 2 * current.progress)
	local hinge = CFrame.new(BaronRoomsLayout.get().shelfHinge)
	local turn = CFrame.Angles(0, math.rad(BaronRoomsConfig.ShelfOpenDegrees) * eased, 0)
	current.model:PivotTo(hinge * turn * hinge:Inverse() * current.closed)
end

local function onClaimed(id: unknown, tickets: unknown)
	local info = if typeof(id) == "string" then (BaronRoomsConfig.Info :: any)[id] else nil
	if info == nil then
		return
	end
	local roomId = id :: string
	claimed[roomId] = true
	local amount = if typeof(tickets) == "number" then math.clamp(math.floor(tickets), 0, 99) else BaronRoomsConfig.Tickets
	notify(`baron-room-{roomId}`, info.icon, Lang.t("SALA SECRETA!"), Lang.t("%s · +%d 🎟", Lang.t(info.name), amount))
	notify(`baron-room-title-{roomId}`, "🏅", Lang.t("NOVO TÍTULO!"), Lang.t("Título: %s", Lang.t(info.title)))
	playSound(CLAIM_SOUND)
	applyLid()
end

local function onProfile(snapshot: ProfileSnapshot)
	for _, id in ipairs(snapshot.baronRooms) do
		claimed[id] = true
	end
	applyLid()
end

function BaronRoomsController.start()
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
		warn("[BlocoPuff] Baron rooms controller not started: PlayerGui unavailable")
		return
	end
	NotificationManager.init(playerGui)
	local startedAt = os.clock()

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeredBy: Player)
		local id = prompt:GetAttribute(BaronRoomsConfig.PromptAttribute)
		local currentRemote = remote
		if triggeredBy ~= player or typeof(id) ~= "string" or claimed[id] or currentRemote == nil then
			return
		end
		currentRemote:FireServer("Claim", id)
	end)

	-- Passagem que acabou de abrir (última página do Diário, cofrinho).
	for _, id in ipairs(BaronRoomsConfig.Ids) do
		player:GetAttributeChangedSignal(BaronRoomsConfig.AccessAttributePrefix .. id):Connect(function()
			local info = BaronRoomsConfig.Info[id :: BaronRoomsConfig.RoomId]
			if hasAccess(player, id) and os.clock() - startedAt >= ANNOUNCE_AFTER then
				notify(`baron-open-{id}`, info.icon, Lang.t("PASSAGEM SECRETA!"), Lang.t(info.hint))
			end
		end)
	end

	ProfileController.Changed:Connect(onProfile)
	local current = ProfileController.get()
	if current ~= nil then
		onProfile(current)
	end

	refresh()
	task.spawn(function()
		while player.Parent ~= nil do
			task.wait(REFRESH_SECONDS)
			refresh()
			applyLid()
		end
	end)
	task.spawn(function()
		while player.Parent ~= nil do
			step(player)
			task.wait(BaronRoomsConfig.CheckInterval)
		end
	end)
	RunService.Heartbeat:Connect(animateShelf)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.BaronRoomsRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Baron rooms controller: remote not found")
			return
		end
		remote = instance
		instance.OnClientEvent:Connect(function(kind: unknown, id: unknown, tickets: unknown)
			if kind == "Claimed" then
				onClaimed(id, tickets)
			end
		end)
	end)
end

return table.freeze(BaronRoomsController)
