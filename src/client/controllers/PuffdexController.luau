--!strict

-- Puffdex do cliente (Fase 4.1): abre o painel pelo botão ✨ do cartão de
-- perfil, mostra a coleção vinda do perfil (ProfileController), pede ao
-- servidor para equipar e comemora Puffs novos com um aviso. O cliente não
-- concede nada: só mostra o que o servidor mandou.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local PuffdexView = require(script.Parent.Parent.ui.PuffdexView)
local ProfileController = require(script.Parent.ProfileController)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type PuffdexViewHandle = PuffdexView.PuffdexViewHandle

local WAIT_TIMEOUT = 15

local PuffdexController = {}

local started = false
local view: PuffdexViewHandle? = nil
local remote: RemoteEvent? = nil

local function send(action: string, payload: string?)
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireServer(action, payload)
	end
end

-- Um aviso por Puff novo (o NotificationManager enfileira).
local function celebrate(ids: { string })
	for _, id in ipairs(ids) do
		local definition = PuffCatalog.get(id)
		-- O Puff inicial chega com o primeiro perfil: não é conquista.
		if definition ~= nil and definition.unlock.kind ~= "Starter" then
			local rarity = PuffCatalog.rarity(definition.rarity)
			NotificationManager.notify({
				channel = "Banner",
				category = "Progression",
				priority = if definition.rarity == "Legendary" or definition.rarity == "Epic" then "High" else "Normal",
				key = `puff-{id}`,
				icon = "✨",
				title = "NOVO PUFF!",
				subtitle = `{definition.name} · {rarity.label} — veja no Puffdex`,
				tone = "Winner",
				duration = 4,
				maxWait = 30,
			})
		end
	end
end

function PuffdexController.open()
	local current = view
	if current == nil then
		return
	end
	if current.isOpen() then
		current.close()
	else
		current.open()
	end
end

function PuffdexController.start()
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
		warn("[BlocoPuff] Puffdex controller not started: PlayerGui unavailable")
		return
	end
	NotificationManager.init(playerGui)
	local newView = PuffdexView.new(playerGui, function(id: string)
		send("Equip", id)
	end, function()
		send("Opened")
	end)
	view = newView

	-- Fecha o painel quando o jogador entra na partida.
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			newView.close()
		end
	end)

	local function onProfile(snapshot: ProfileSnapshot)
		newView.setProfile(snapshot)
		local newPuffs = snapshot.newPuffs
		if newPuffs ~= nil then
			newView.markNew(newPuffs)
			celebrate(newPuffs)
		end
	end
	ProfileController.Changed:Connect(onProfile)
	local current = ProfileController.get()
	if current ~= nil then
		newView.setProfile(current)
	end

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.PuffdexRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Puffdex controller: remote not found")
			return
		end
		remote = instance
	end)
end

return table.freeze(PuffdexController)
