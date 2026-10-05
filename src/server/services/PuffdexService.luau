--!strict

-- Pedidos do Puffdex vindos do cliente (Fase 4.1):
--   "Equip", id   → equipa um Puff que o jogador tem (validado no servidor).
--   "Opened"      → telemetria de abertura do Puffdex.
--   "ChallengesOpened" → telemetria de abertura do painel de desafios (4.3).
--   "AlbumOpened" → telemetria de abertura do Álbum do Casarão (5C.2).
-- O cliente nunca concede Puffs: desbloqueio é só pelo PlayerDataService.
-- Puffs são visuais; equipar no meio da partida só troca as cores do disparo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local PuffInventory = require(script.Parent.Parent.data.PuffInventory)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)

type Profile = ProfileSchema.Profile

local EQUIP_COOLDOWN = 0.4
local OPENED_COOLDOWN = 5

local PuffdexService = {}

local started = false
local lastEquip: { [Player]: number } = {}
local lastOpened: { [Player]: number } = {}
local lastChallengesOpened: { [Player]: number } = {}
local lastAlbumOpened: { [Player]: number } = {}

local function throttled(map: { [Player]: number }, player: Player, cooldown: number): boolean
	local clock = os.clock()
	local last = map[player]
	if last ~= nil and clock - last < cooldown then
		return true
	end
	map[player] = clock
	return false
end

-- Equipa um Puff que o jogador tem (só visual).
local function equip(player: Player, puffId: string)
	local changed = false
	PlayerDataService.update(player, function(profile: Profile): (Profile?, PlayerDataService.Events?)
		if not PuffInventory.owns(profile.puffs, puffId) or profile.equippedPuff == puffId then
			return nil, nil
		end
		local updated = table.clone(profile)
		updated.equippedPuff = puffId
		changed = true
		return updated, nil
	end)
	if changed then
		local definition = PuffCatalog.get(puffId)
		TelemetryService.lobbyEvent(player, "PuffEquipped", 1, puffId, if definition ~= nil then definition.rarity else nil)
	end
end

local function onRequest(player: Player, action: unknown, payload: unknown)
	if action == "Equip" then
		if throttled(lastEquip, player, EQUIP_COOLDOWN) then
			return
		end
		if typeof(payload) ~= "string" or #payload > PuffCatalog.MaxIdLength or PuffCatalog.get(payload) == nil then
			return
		end
		equip(player, payload)
	elseif action == "Opened" then
		if throttled(lastOpened, player, OPENED_COOLDOWN) then
			return
		end
		local snapshot = PlayerDataService.getSnapshot(player)
		local owned = if snapshot ~= nil then #snapshot.puffs else 0
		TelemetryService.lobbyEvent(player, "PuffdexOpened", owned, `Of{#PuffCatalog.all()}`)
	elseif action == "ChallengesOpened" then
		if throttled(lastChallengesOpened, player, OPENED_COOLDOWN) then
			return
		end
		local snapshot = PlayerDataService.getSnapshot(player)
		local done = 0
		if snapshot ~= nil then
			for _, state in ipairs(snapshot.challenges) do
				if state.done then
					done += 1
				end
			end
		end
		TelemetryService.lobbyEvent(player, "ChallengesOpened", done, if snapshot ~= nil then `Streak{snapshot.daily.streak}` else nil)
	elseif action == "AlbumOpened" then
		if throttled(lastAlbumOpened, player, OPENED_COOLDOWN) then
			return
		end
		local snapshot = PlayerDataService.getSnapshot(player)
		-- Só as relíquias do Álbum (temporadas e Diário ficam de fora).
		local relics = 0
		if snapshot ~= nil then
			local albumIds = RelicCatalog.allIds()
			for _, state in ipairs(snapshot.relics) do
				if table.find(albumIds, state.id) ~= nil then
					relics += 1
				end
			end
		end
		TelemetryService.lobbyEvent(player, "AlbumOpened", relics, `Of{#RelicCatalog.allIds()}`)
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
		lastChallengesOpened[player] = nil
		lastAlbumOpened[player] = nil
	end)
end

return table.freeze(PuffdexService)
