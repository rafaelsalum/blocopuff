--!strict

-- Telemetria mínima da Fase 1, via AnalyticsService (eventos customizados do
-- Creator Dashboard). Eventos pontuais (queda, Segunda Chance, eliminação,
-- Caos Final, abandono) são enviados na hora; contadores de combate (tiros,
-- acertos, blocos) são somados no servidor e enviados uma vez no fim da
-- rodada, para não gerar um evento por tiro.
--
-- Campos customizados (sempre na mesma ordem, para filtrar no Dashboard):
--   CustomField01 = dispositivo (Mobile, Desktop, Gamepad, Unknown)
--   CustomField02 = contexto do evento (motivo, resultado, zona...)
--   CustomField03 = detalhe extra (quando houver)
--
-- Nenhuma chamada aqui pode quebrar o jogo: tudo roda em pcall.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

export type Device = "Mobile" | "Desktop" | "Gamepad" | "Unknown"

type Counters = {
	shots: number,
	playerHits: number,
	blockHits: number,
	blocksDestroyed: number,
	vaultShots: number,
}

local DEVICE_REPORT_COOLDOWN = 5
local FLOOR_SAMPLE_INTERVAL = 0.5
local VALID_DEVICES: { [string]: Device } = {
	Mobile = "Mobile",
	Desktop = "Desktop",
	Gamepad = "Gamepad",
}

local TelemetryService = {}

local devices: { [Player]: Device } = {}
local lastDeviceReport: { [Player]: number } = {}
local counters: { [Player]: Counters } = {}
local roundStartClock = 0
-- Bots RoboPuff na rodada em andamento.
local roundBots = 0
local roundActive = false
local lastRoundParticipants: { [Player]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local lastFloor: { [Player]: number } = {}
local roundToken = 0

local function getDevice(player: Player): Device
	return devices[player] or "Unknown"
end

local function log(player: Player, eventName: string, value: number?, context: string?, detail: string?)
	if not GameConfig.Telemetry.Enabled or player.Parent == nil then
		return
	end
	local fields: { [string]: string } = {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = getDevice(player),
	}
	if context ~= nil then
		fields[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = context
	end
	if detail ~= nil then
		fields[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = detail
	end

	if RunService:IsStudio() and GameConfig.Telemetry.PrintInStudio then
		print(string.format("[BlocoPuff][Telemetry] %s %s value=%s %s %s", player.Name, eventName, tostring(value), context or "", detail or ""))
	end
	local ok, failure = pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1, fields)
	end)
	if not ok and not RunService:IsStudio() then
		warn(string.format("[BlocoPuff] Telemetry event %s failed: %s", eventName, tostring(failure)))
	end
end

local function elapsed(): number
	return math.floor(os.clock() - roundStartClock)
end

local function getCounters(player: Player): Counters?
	return counters[player]
end

-- Zona da arena onde a posição está (para mapear onde as quedas acontecem).
local function getZone(position: Vector3): string
	local arena = GameConfig.Arena
	local width = arena.Columns * (arena.BlockSize.X + arena.BlockGap)
	local depth = arena.Rows * (arena.BlockSize.Z + arena.BlockGap)
	local dx = (position.X - arena.Position.X) / (width / 2)
	local dz = (position.Z - arena.Position.Z) / (depth / 2)
	if math.abs(dx) < 0.4 and math.abs(dz) < 0.4 then
		return "Center"
	end
	return (if dz < 0 then "North" else "South") .. (if dx < 0 then "West" else "East")
end

-- Andar em que a altura está: acima do meio do vão entre dois pisos conta
-- como o de cima.
local function getFloor(y: number): number
	local arena = GameConfig.Arena
	local relative = (y - arena.Position.Y) / arena.FloorSpacing
	return math.clamp(math.floor(relative + 0.5) + 1, 1, arena.FloorCount)
end

-- Registra quedas de um andar para o de baixo (não eliminam, mas mostram
-- onde a arena está sendo destruída).
local function sampleFloors(token: number, participants: { Player })
	while roundActive and roundToken == token do
		for _, player in ipairs(participants) do
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if root ~= nil and root:IsA("BasePart") and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == false then
				local floor = getFloor(root.Position.Y)
				local previous = lastFloor[player]
				if previous ~= nil and floor < previous then
					log(player, "FloorDrop", elapsed(), getZone(root.Position), string.format("F%d>F%d", previous, floor))
				end
				lastFloor[player] = floor
			end
		end
		task.wait(FLOOR_SAMPLE_INTERVAL)
	end
end

-- `participants` são os jogadores; `bots`, os RoboPuffs que completaram a
-- partida (Fase 5B). O contexto `Bots{n}` separa as partidas com bots nas
-- análises de retenção e vitória.
function TelemetryService.roundStarted(participants: { Player }, bots: number?)
	roundActive = true
	roundStartClock = os.clock()
	roundBots = bots or 0
	table.clear(counters)
	for _, player in ipairs(participants) do
		counters[player] = { shots = 0, playerHits = 0, blockHits = 0, blocksDestroyed = 0, vaultShots = 0 }
		log(player, "RoundStarted", #participants + roundBots, `Bots{roundBots}`)
		-- Rematch: jogou a rodada anterior e continuou para esta.
		if lastRoundParticipants[player] then
			log(player, "Rematch", 1)
		end
	end
	table.clear(lastRoundParticipants)
	for _, player in ipairs(participants) do
		lastRoundParticipants[player] = true
	end
	roundToken += 1
	table.clear(lastFloor)
	task.spawn(sampleFloors, roundToken, table.clone(participants))
end

function TelemetryService.shot(player: Player, withVaultPuffador: boolean?)
	local current = getCounters(player)
	if current ~= nil then
		current.shots += 1
		if withVaultPuffador then
			current.vaultShots += 1
		end
	end
end

-- Evento avulso de outros serviços (corredores, Barão, Tocas, Momentos
-- Puff). `value` padrão: segundos desde o início da rodada.
function TelemetryService.event(player: Player, eventName: string, value: number?, context: string?, detail: string?)
	if not roundActive then
		return
	end
	log(player, eventName, if value ~= nil then value else elapsed(), context, detail)
end

-- Passo do Funil de Onboarding nativo do Creator Dashboard. Quem garante
-- que cada passo vai uma vez só é o OnboardingService (perfil).
function TelemetryService.onboardingStep(player: Player, step: number, stepName: string)
	if not GameConfig.Telemetry.Enabled or player.Parent == nil then
		return
	end
	if RunService:IsStudio() and GameConfig.Telemetry.PrintInStudio then
		print(string.format("[BlocoPuff][Telemetry] %s Onboarding %d %s", player.Name, step, stepName))
	end
	local ok, failure = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = getDevice(player),
		})
	end)
	if not ok and not RunService:IsStudio() then
		warn(string.format("[BlocoPuff] Onboarding step %s failed: %s", stepName, tostring(failure)))
	end
end

-- Tipo de transação da economia nativa por origem dos tickets.
local TICKET_TRANSACTION_TYPES: { [string]: string } = {
	Daily = "TimedReward",
	DuplicateRefund = "Shop",
	PuffMachine = "Shop",
}

-- Tickets na economia nativa do Creator Dashboard (entradas e saídas, com
-- o saldo depois da transação). `source` vira o item (SKU).
local function logTickets(player: Player, flow: Enum.AnalyticsEconomyFlowType, amount: number, balance: number, source: string)
	if not GameConfig.Telemetry.Enabled or player.Parent == nil or amount <= 0 then
		return
	end
	local transactionType = TICKET_TRANSACTION_TYPES[source] or "Gameplay"
	if RunService:IsStudio() and GameConfig.Telemetry.PrintInStudio then
		print(string.format("[BlocoPuff][Telemetry] %s Tickets %s %d (%s) balance=%d", player.Name, flow.Name, amount, source, balance))
	end
	local ok, failure = pcall(function()
		AnalyticsService:LogEconomyEvent(player, flow, "Tickets", amount, math.max(0, balance), transactionType, source, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = getDevice(player),
		})
	end)
	if not ok and not RunService:IsStudio() then
		warn(string.format("[BlocoPuff] Economy event %s failed: %s", source, tostring(failure)))
	end
end

-- Entrada de tickets pelo saldo antes e depois: com a carteira no teto,
-- vale só o que de fato entrou (nada entrou: nenhum evento).
function TelemetryService.ticketsEarned(player: Player, before: number, after: number, source: string)
	logTickets(player, Enum.AnalyticsEconomyFlowType.Source, after - before, after, source)
end

function TelemetryService.ticketsSpent(player: Player, amount: number, balance: number, item: string)
	logTickets(player, Enum.AnalyticsEconomyFlowType.Sink, amount, balance, item)
end

-- Evento fora da rodada (lobby: ranking, Hall da Fama, Puffdex).
function TelemetryService.lobbyEvent(player: Player, eventName: string, value: number?, context: string?, detail: string?)
	log(player, eventName, value, context, detail)
end

function TelemetryService.roundElapsed(): number
	return elapsed()
end

-- Um tiro que derrubou pelo menos um bloco conta um acerto em bloco;
-- cada bloco derrubado conta em blocksDestroyed.
function TelemetryService.blocksDestroyed(player: Player, count: number, firstForShot: boolean)
	local current = getCounters(player)
	if current ~= nil then
		current.blocksDestroyed += count
		if firstForShot then
			current.blockHits += 1
		end
	end
end

function TelemetryService.playerHit(shooter: Player)
	local current = getCounters(shooter)
	if current ~= nil then
		current.playerHits += 1
	end
end

function TelemetryService.fell(player: Player, position: Vector3, usedSecondChance: boolean)
	if roundActive then
		log(player, "Fell", elapsed(), getZone(position), if usedSecondChance then "SecondChance" else "Eliminated")
	end
end

function TelemetryService.secondChanceUsed(player: Player)
	if roundActive then
		log(player, "SecondChanceUsed", elapsed())
	end
end

function TelemetryService.eliminated(player: Player, reason: string, position: number)
	if roundActive then
		log(player, "Eliminated", position, reason, tostring(elapsed()))
	end
end

function TelemetryService.finalChaosStarted(alivePlayers: { Player })
	for _, player in ipairs(alivePlayers) do
		log(player, "FinalChaosStarted", #alivePlayers)
	end
end

-- Eventos do cofre e do Puffador do Cofre.
function TelemetryService.vaultOpened(player: Player)
	log(player, "VaultOpened", elapsed())
end

function TelemetryService.vaultPrizeTaken(player: Player)
	log(player, "VaultPrizeTaken", elapsed())
end

function TelemetryService.blockBuilt(player: Player, floor: number)
	log(player, "BlockBuilt", 1, `Floor{floor}`)
end

function TelemetryService.leftMidRound(player: Player)
	if roundActive then
		log(player, "LeftMidRound", elapsed())
	end
	counters[player] = nil
	lastRoundParticipants[player] = nil
end

-- `outcome` por jogador: "Win", "Draw" ou "Loss".
function TelemetryService.roundFinished(outcomes: { [Player]: string })
	if not roundActive then
		return
	end
	local duration = elapsed()
	for player, outcome in pairs(outcomes) do
		local current = counters[player]
		log(player, "RoundFinished", duration, outcome, `Bots{roundBots}`)
		if outcome == "Win" then
			log(player, "RoundWon", duration, `Bots{roundBots}`)
		end
		if current ~= nil then
			log(player, "RoundShots", current.shots)
			log(player, "RoundPlayerHits", current.playerHits)
			log(player, "RoundBlockHits", current.blockHits)
			log(player, "RoundBlocksDestroyed", current.blocksDestroyed)
			if current.vaultShots > 0 then
				log(player, "RoundVaultShots", current.vaultShots)
			end
		end
	end
	roundActive = false
	roundToken += 1
	table.clear(counters)
end

local function onDeviceReport(player: Player, raw: unknown)
	local now = os.clock()
	local last = lastDeviceReport[player]
	if last ~= nil and now - last < DEVICE_REPORT_COOLDOWN then
		return
	end
	lastDeviceReport[player] = now
	if typeof(raw) ~= "string" then
		return
	end
	local device = VALID_DEVICES[raw]
	if device ~= nil then
		devices[player] = device
	end
end

function TelemetryService.start(remotesFolder: Folder?)
	if remotesFolder ~= nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = PuffadorConstants.ReportDeviceRemoteName
		remote.Parent = remotesFolder
		table.insert(connections, remote.OnServerEvent:Connect(onDeviceReport))
	else
		warn("[BlocoPuff] Telemetry: remotes folder not found; device reports disabled")
	end
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		devices[player] = nil
		lastDeviceReport[player] = nil
		counters[player] = nil
		lastRoundParticipants[player] = nil
	end))
end

function TelemetryService.stop()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	roundActive = false
	table.clear(counters)
end

return table.freeze(TelemetryService)
