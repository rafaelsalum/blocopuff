--!strict

-- Portas trancadas do Casarão no cliente (Fase 5C.1). Cada vão trancado tem
-- uma barreira invisível (MansionLocks); aqui ela perde a colisão para quem
-- tem acesso (atributo publicado pelo MansionLockService) e para quem já
-- está do lado de dentro (ninguém fica preso). Quem chega sem acesso vê a
-- fresta da porta (MansionDoorController) e um aviso de onde achar a chave
-- ou de qual nível falta, com uma batida na porta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local MansionLockConfig = require(ReplicatedStorage.Shared.config.MansionLockConfig)
local MansionLockLayout = require(ReplicatedStorage.Shared.modules.MansionLockLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local T = Lang.t
local CHECK_INTERVAL = 0.2
local WORLD_NAME = "BlocoPuffWorld"
local FOLDER_NAME = "MansionLocks"
-- Folga em volta do cômodo para contar como "dentro".
local INSIDE_MARGIN = 0.5

local MansionLockController = {}

local started = false
local lastHintAt: { [string]: number } = {}
local cachedBarriers: { BasePart } = {}
local searchedAt = -math.huge
-- Intervalo mínimo (s) entre duas buscas das barreiras no mundo.
local SEARCH_INTERVAL = 2

local function findBarriers(): { BasePart }
	local found: { BasePart } = {}
	local world = Workspace:FindFirstChild(WORLD_NAME)
	local folder = if world ~= nil then world:FindFirstChild(FOLDER_NAME, true) else nil
	if folder == nil then
		return found
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute(MansionLockConfig.LockAttribute) ~= nil then
			table.insert(found, child)
		end
	end
	return found
end

-- As barreiras (busca de novo quando somem, sem varrer o mundo toda vez).
local function barriers(): { BasePart }
	local first = cachedBarriers[1]
	local stale = first == nil or first.Parent == nil
	local now = os.clock()
	if stale and now - searchedAt >= SEARCH_INTERVAL then
		searchedAt = now
		cachedBarriers = findBarriers()
	end
	return cachedBarriers
end

local function knock(spot: MansionLockLayout.LockSpot)
	local sound = Instance.new("Sound")
	sound.SoundId = MansionLockConfig.RattleSoundId
	sound.Volume = 0.5
	sound.PlaybackSpeed = 1.4
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	NotificationManager.notify({
		channel = "Banner",
		category = "Progression",
		priority = "Normal",
		key = `mansion-lock-{spot.info.id}`,
		icon = "🔒",
		title = T("PORTA TRANCADA"),
		subtitle = T(spot.info.hint),
		tone = "Info",
		duration = 3,
	})
end

-- Do lado de fora, perto do vão.
local function atDoor(spot: MansionLockLayout.LockSpot, position: Vector3): boolean
	local doorway = spot.doorway
	local offset = position - doorway.center
	local side = offset:Dot(doorway.normal) * spot.outside
	return side >= 0 and Vector2.new(offset.X, offset.Z).Magnitude <= MansionLockConfig.HintDistance and math.abs(offset.Y - 3) <= doorway.size.Y
end

local function check(player: Player)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local position = if root ~= nil and root:IsA("BasePart") then root.Position else nil
	local competing = player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
	local open: { [string]: boolean } = {}
	for _, spot in ipairs(MansionLockLayout.all()) do
		local id = spot.info.id
		local access = player:GetAttribute(MansionLockConfig.AccessAttributePrefix .. id) == true
		local inside = position ~= nil and MansionLockLayout.isInside(spot, position, INSIDE_MARGIN)
		open[id] = access or inside
		if not open[id] and not competing and position ~= nil and atDoor(spot, position) then
			local now = os.clock()
			if now - (lastHintAt[id] or -math.huge) >= MansionLockConfig.HintInterval then
				lastHintAt[id] = now
				knock(spot)
			end
		end
	end
	for _, barrier in ipairs(barriers()) do
		local id = barrier:GetAttribute(MansionLockConfig.LockAttribute)
		local wanted = not (typeof(id) == "string" and open[id] == true)
		if barrier.CanCollide ~= wanted then
			barrier.CanCollide = wanted
		end
	end
end

function MansionLockController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	task.spawn(function()
		while true do
			local ok, failure = pcall(check, player)
			if not ok then
				warn(`[BlocoPuff] Mansion locks check failed: {failure}`)
				task.wait(5)
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return table.freeze(MansionLockController)
