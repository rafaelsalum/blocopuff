--!strict

-- Puff Machine (Fase 4.2). Pedidos do cliente pelo remote "PuffMachine":
--   "Pull", pedido → um giro (custa RewardConfig.MachineCost tickets);
--   "Opened"       → telemetria de abertura.
-- Respostas ao cliente: ("Result", MachineResult, pedido) ou ("Failed",
-- motivo, pedido). `pedido` é o número que o cliente mandou, devolvido para
-- ele saber a qual giro a resposta pertence.
--
-- Tudo é decidido aqui e no PlayerDataService: saldo, sorteio (Random do
-- servidor), garantia de Épico e devolução de repetidos. Só no lobby (quem
-- está competindo não gira), com intervalo mínimo entre giros. Não existe
-- nenhuma forma de comprar giros ou tickets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardConfig = require(ReplicatedStorage.Shared.config.RewardConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)

local OPENED_COOLDOWN = 5
local MAX_REQUEST_ID = 1e9

local PuffMachineService = {}

local started = false
local rng = Random.new()
local lastPull: { [Player]: number } = {}
local lastOpened: { [Player]: number } = {}

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function readRequestId(value: unknown): number
	if typeof(value) == "number" and value == value and value >= 0 and value <= MAX_REQUEST_ID then
		return math.floor(value)
	end
	return 0
end

local function onRequest(remote: RemoteEvent, player: Player, action: unknown, requestValue: unknown)
	if action == "Pull" then
		local requestId = readRequestId(requestValue)
		local clock = os.clock()
		local last = lastPull[player]
		if last ~= nil and clock - last < RewardConfig.MachineCooldown then
			-- Responde (sem gastar nada) para o cliente parar a animação. A
			-- janela conta do último giro aceito, não dos recusados.
			remote:FireClient(player, "Failed", "Cooldown", requestId)
			return
		end
		lastPull[player] = clock
		if isCompeting(player) then
			remote:FireClient(player, "Failed", "Competing", requestId)
			return
		end
		local result, failure = PlayerDataService.machinePull(player, rng)
		if result ~= nil then
			remote:FireClient(player, "Result", result, requestId)
		else
			remote:FireClient(player, "Failed", failure or "Empty", requestId)
		end
	elseif action == "Opened" then
		local clock = os.clock()
		local last = lastOpened[player]
		if last ~= nil and clock - last < OPENED_COOLDOWN then
			return
		end
		lastOpened[player] = clock
		local snapshot = PlayerDataService.getSnapshot(player)
		TelemetryService.lobbyEvent(player, "PuffMachineOpened", if snapshot ~= nil then snapshot.tickets else 0)
	end
end

function PuffMachineService.start(remotesFolder: Folder)
	if started then
		return
	end
	started = true
	local remote = Instance.new("RemoteEvent")
	remote.Name = PuffadorConstants.PuffMachineRemoteName
	remote.Parent = remotesFolder
	remote.OnServerEvent:Connect(function(player: Player, action: unknown, requestValue: unknown)
		onRequest(remote, player, action, requestValue)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPull[player] = nil
		lastOpened[player] = nil
	end)
end

return table.freeze(PuffMachineService)
