--!strict

-- Bots RoboPuff no mirante (Fase 5B, entrega 5B.2). Quando há gente na
-- fila e falta gente para uma partida divertida, depois de uma espera curta
-- os bots chegam ao mirante e completam a partida (BotFillRules). Quem
-- chega ocupa a vaga de um bot; sem humanos na fila, os bots vão embora.
--
-- O RoundService conta os bots do mirante (`count`), leva os que couberem
-- para a partida (`takeForRound`) e avisa quando ela acaba (`endRound`):
-- os corpos são desfeitos e, por `BotConfig.WarmSeconds`, os bots voltam ao
-- mirante sem a espera inicial (quem jogou com bots volta direto à fila).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local QueueConfig = require(ReplicatedStorage.Shared.config.QueueConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local BotFillRules = require(script.Parent.Parent.data.BotFillRules)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local DashService = require(script.Parent.DashService)
local MatchQueueService = require(script.Parent.MatchQueueService)
local TelemetryService = require(script.Parent.TelemetryService)
local BotBody = require(script.Parent.bots.BotBody)

type Combatant = CombatantRegistry.Combatant

local FOLDER_NAME = "RoboPuffs"
-- Lugares candidatos no mirante (sorteados entre os livres).
local MIRANTE_SLOTS = 24
local SPAWN_RETRY_SECONDS = 5

local BotFillService = {}

local started = false
local folder: Folder? = nil
-- Bots esperando no mirante, na ordem em que chegaram.
local pool: { Combatant } = {}
-- Bots na partida em andamento.
local inRound: { Combatant } = {}
local usedNames: { [string]: boolean } = {}
local nameOf: { [Combatant]: string } = {}
local nextId = -1
local nextColor = 1
local waitingSince: number? = nil
local warmUntil = 0
local accumulator = 0
-- Muda quando os bots em montagem não servem mais (stop, fila sem humanos).
local spawnGeneration = 0
-- Depois de uma falha ao montar um bot, só tenta de novo a partir daqui.
local retryAt = 0
-- Para a telemetria: quanto tempo a fila esperou até os bots chegarem.
local fillWaited = 0
-- Quantos bots estão sendo montados agora (CreateHumanoidModelFromDescription
-- pode demorar): contam como já chegando, para não montar a mais.
local building = 0

-- Painel admin: liga ou desliga os bots neste servidor (nil = config).
local enabledOverride: boolean? = nil

local function fillConfig(): BotFillRules.FillConfig
	local base = BotConfig.Fill
	local enabled = enabledOverride
	return {
		Enabled = if enabled ~= nil then enabled else base.Enabled,
		TargetCombatants = base.TargetCombatants,
		MaxBots = base.MaxBots,
		WaitSeconds = if RunService:IsStudio() then BotConfig.StudioWaitSeconds else base.WaitSeconds,
	}
end

local function pickName(): string
	for _, name in ipairs(BotConfig.Names) do
		if not usedNames[name] then
			return name
		end
	end
	return `Puff{-nextId}`
end

local function freeSlot(): CFrame
	local slots = BuildingLayout.getGallerySpawnCFrames(GameConfig.Arena, GameConfig.Building, MIRANTE_SLOTS)
	local occupied: { Vector3 } = {}
	for _, bot in ipairs(pool) do
		local root = CombatantRegistry.getRoot(bot)
		if root ~= nil then
			table.insert(occupied, root.Position)
		end
	end
	local best = slots[1]
	local bestDistance = -1
	for _, slot in ipairs(slots) do
		local nearest = math.huge
		for _, position in ipairs(occupied) do
			nearest = math.min(nearest, (slot.Position - position).Magnitude)
		end
		if nearest > bestDistance then
			best = slot
			bestDistance = nearest
		end
	end
	return best or CFrame.new()
end

local function logQueued(eventName: string, value: number)
	for _, player in ipairs(MatchQueueService.queuedPlayers()) do
		TelemetryService.lobbyEvent(player, eventName, math.floor(value))
	end
end

local function publish()
	MatchQueueService.setBotCount(#pool)
end

local function destroyBot(bot: Combatant)
	local name = nameOf[bot]
	if name ~= nil then
		usedNames[name] = nil
		nameOf[bot] = nil
	end
	CombatantRegistry.unregisterBot(bot)
	DashService.forgetBot(bot)
	local model = bot.model
	if model ~= nil then
		model:Destroy()
	end
end

local function spawnBot()
	local target = folder
	if target == nil then
		return
	end
	local id = nextId
	nextId -= 1
	local name = pickName()
	usedNames[name] = true
	local colorIndex = nextColor
	nextColor += 1
	local token = spawnGeneration
	building += 1
	local ok, result = pcall(BotBody.build, id, name, colorIndex, target, freeSlot() + Vector3.new(0, 3, 0))
	building -= 1
	local model = if ok then result else nil
	if not ok then
		warn(`[BlocoPuff] RoboPuff {name} failed to spawn: {result}`)
	end
	-- Montado tarde demais (serviço parado, ou a fila mudou de vez).
	if model ~= nil and token ~= spawnGeneration then
		model:Destroy()
		model = nil
	end
	if model == nil then
		usedNames[name] = nil
		-- O Roblox não conseguiu montar o avatar: espera antes de tentar de novo.
		retryAt = os.clock() + SPAWN_RETRY_SECONDS
		return
	end
	local bot = CombatantRegistry.registerBot(id, `{BotConfig.Body.Tag} {name}`, model)
	nameOf[bot] = name
	local wasEmpty = #pool == 0
	table.insert(pool, bot)
	publish()
	if wasEmpty then
		MatchQueueService.notifyQueued("BotsArriving")
		logQueued("BotFillStarted", fillWaited)
	end
end

-- O último a chegar é o primeiro a sair.
local function sendAway(count: number)
	for _ = 1, count do
		local bot = table.remove(pool)
		if bot == nil then
			break
		end
		destroyBot(bot)
	end
	publish()
end

-- Tira do grupo bots cujo corpo sumiu (caiu do mapa, foi destruído).
local function prune()
	local removed = false
	for index = #pool, 1, -1 do
		local bot = pool[index]
		local humanoid = CombatantRegistry.getHumanoid(bot)
		if not CombatantRegistry.isPresent(bot) or humanoid == nil or humanoid.Health <= 0 then
			table.remove(pool, index)
			destroyBot(bot)
			removed = true
		end
	end
	if removed then
		publish()
	end
end

local function update()
	-- Com o embarque fechado a partida já vai começar: ninguém entra nem sai.
	if not MatchQueueService.isBoardingOpen() then
		return
	end
	prune()
	local config = fillConfig()
	local humans = MatchQueueService.count()
	local clock = os.clock()
	if BotFillRules.desiredBots(humans, config) > 0 then
		waitingSince = waitingSince or clock
	else
		waitingSince = nil
	end
	local since = waitingSince
	local waited = if since ~= nil then clock - since else 0
	local allowed = BotFillRules.canFill(humans, waited, clock < warmUntil, config)
	local change = BotFillRules.adjustment(humans, #pool + building, allowed, config)
	if humans == 0 then
		-- Ninguém mais espera: bots ainda em montagem são descartados.
		spawnGeneration += 1
	end
	if change > 0 and clock >= retryAt then
		fillWaited = waited
		for _ = 1, change do
			task.spawn(spawnBot)
		end
	elseif change < 0 then
		local leaving = math.min(-change, #pool)
		if humans > 0 and leaving > 0 then
			logQueued("BotReplacedByHuman", leaving)
		end
		sendAway(leaving)
	end
end

-- Bots esperando no mirante (entram na conta da fila).
function BotFillService.count(): number
	prune()
	return #pool
end

-- Leva até `slots` bots do mirante para a partida que vai começar.
function BotFillService.takeForRound(slots: number): { Combatant }
	local taken: { Combatant } = {}
	prune()
	while #taken < slots and #pool > 0 do
		table.insert(taken, table.remove(pool, 1) :: Combatant)
	end
	for _, bot in ipairs(taken) do
		table.insert(inRound, bot)
	end
	publish()
	return taken
end

-- Fim da partida: os corpos da partida são desfeitos. Se ela teve bots,
-- eles voltam ao mirante sem a espera inicial por um tempo.
function BotFillService.endRound()
	if #inRound > 0 then
		warmUntil = os.clock() + BotConfig.WarmSeconds
	end
	for _, bot in ipairs(inRound) do
		destroyBot(bot)
	end
	table.clear(inRound)
end

-- Comandos de teste (painel admin).
function BotFillService.setEnabled(enabled: boolean)
	enabledOverride = enabled
	if not enabled then
		spawnGeneration += 1
		sendAway(#pool)
	end
end

function BotFillService.isEnabled(): boolean
	return fillConfig().Enabled
end

-- Os bots vêm já, sem a espera inicial.
function BotFillService.rush()
	warmUntil = os.clock() + BotConfig.WarmSeconds
end

function BotFillService.start(worldRoot: Model)
	if started then
		return
	end
	started = true
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	newFolder.Parent = worldRoot
	folder = newFolder
	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < QueueConfig.CheckInterval then
			return
		end
		accumulator = 0
		update()
	end)
end

function BotFillService.stop()
	spawnGeneration += 1
	BotFillService.endRound()
	sendAway(#pool)
	warmUntil = 0
	waitingSince = nil
end

return table.freeze(BotFillService)
