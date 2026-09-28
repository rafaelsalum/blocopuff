--!strict

-- Pedidos do Puffdex vindos do cliente (Fase 4.1):
--   "Equip", id   → equipa um Puff que o jogador tem (validado no servidor).
--   "Opened"      → telemetria de abertura do Puffdex.
-- O cliente nunca concede Puffs: desbloqueio é só pelo PlayerDataService.
-- Puffs são visuais; equipar no meio da partida só troca as cores do disparo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)

local EQUIP_COOLDOWN = 0.4
local OPENED_COOLDOWN = 5

local PuffdexService = {}

local started = false
local lastEquip: { [Player]: number } = {}
local lastOpened: { [Player]: number } = {}

local function throttled(map: { [Player]: number }, player: Player, cooldown: number): boolean
	local clock = os.clock()
	local last = map[player]
	if last ~= nil and clock - last < cooldown then
		return true
	end
	map[player] = clock
	return false
end

local function onRequest(player: Player, action: unknown, payload: unknown)
	if action == "Equip" then
		if throttled(lastEquip, player, EQUIP_COOLDOWN) then
			return
		end
		if typeof(payload) ~= "string" or #payload > PuffCatalog.MaxIdLength or PuffCatalog.get(payload) == nil then
			return
		end
		PlayerDataService.equipPuff(player, payload)
	elseif action == "Opened" then
		if throttled(lastOpened, player, OPENED_COOLDOWN) then
			return
		end
		local snapshot = PlayerDataService.getSnapshot(player)
		local owned = if snapshot ~= nil then #snapshot.puffs else 0
		TelemetryService.lobbyEvent(player, "PuffdexOpened", owned, `Of{#PuffCatalog.all()}`)
	end
end

function PuffdexService.start(remotesFolder: Folder)
	if started then
		return
	end
	started = true
	local remote = Instance.new("RemoteEvent")
	remote.Name = PuffadorConstants.PuffdexRemoteName
	remote.Parent = remotesFolder
	remote.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastEquip[player] = nil
		lastOpened[player] = nil
	end)
end

return table.freeze(PuffdexService)
