--!strict

-- Mapa do Casarão no cliente (Fase 5C.4): abre pelo botão 🗺️ do cartão do
-- perfil, mostra os cômodos já visitados (perfil) e, enquanto está aberto,
-- atualiza onde você e os amigos da Party estão. Fecha sozinho quando a
-- partida começa para o jogador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local MansionMapView = require(script.Parent.Parent.ui.MansionMapView)
local ProfileController = require(script.Parent.ProfileController)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot

local WAIT_TIMEOUT = 15
local DOTS_INTERVAL = 0.25

local MansionMapController = {}

local started = false
local view: MansionMapView.MansionMapViewHandle? = nil

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- Você e quem está na mesma Party.
local function collectDots(me: Player): { MansionMapView.MapDot }
	local dots: { MansionMapView.MapDot } = {}
	local party = me:GetAttribute(StateAttributeNames.PlayerPartyId)
	for _, player in ipairs(Players:GetPlayers()) do
		local isSelf = player == me
		local friend = not isSelf and party ~= nil and party ~= "" and party ~= 0 and player:GetAttribute(StateAttributeNames.PlayerPartyId) == party
		local position = if isSelf or friend then rootPosition(player) else nil
		if position ~= nil then
			table.insert(dots, { position = position, isSelf = isSelf })
		end
	end
	return dots
end

local function onProfile(snapshot: ProfileSnapshot)
	local current = view
	if current ~= nil then
		current.setVisited(snapshot.rooms)
	end
end

function MansionMapController.open()
	local current = view
	if current == nil then
		return
	end
	if current.isOpen() then
		current.close()
		return
	end
	local snapshot = ProfileController.get()
	if snapshot ~= nil then
		current.setVisited(snapshot.rooms)
	end
	current.open()
	local me = Players.LocalPlayer
	task.spawn(function()
		while current.isOpen() do
			current.setDots(collectDots(me))
			task.wait(DOTS_INTERVAL)
		end
	end)
end

function MansionMapController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		warn("[BlocoPuff] Mansion map not started: PlayerGui unavailable")
		return
	end
	local newView = MansionMapView.new(playerGui, function() end)
	view = newView
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			newView.close()
		end
	end)
	ProfileController.Changed:Connect(onProfile)
	local current = ProfileController.get()
	if current ~= nil then
		onProfile(current)
	end
end

return table.freeze(MansionMapController)
