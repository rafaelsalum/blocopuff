--!strict

-- Painel RANKING do cliente: recebe do servidor a cópia do ranking global
-- (atualizada de tempos em tempos) e abre o painel pelo botão 🏆 ao lado do
-- cartão de perfil. Abrir e trocar de aba avisa o servidor (telemetria e
-- pedido da cópia mais recente).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local LeaderboardTypes = require(ReplicatedStorage.Shared.types.LeaderboardTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local LeaderboardView = require(script.Parent.Parent.ui.LeaderboardView)

type LeaderboardData = LeaderboardTypes.LeaderboardData
type Leaderboard = LeaderboardTypes.Leaderboard
type LeaderboardEntry = LeaderboardTypes.LeaderboardEntry
type LeaderboardViewHandle = LeaderboardView.LeaderboardViewHandle

local WAIT_TIMEOUT = 15
local MAX_NAME_LENGTH = 40

local LeaderboardController = {}

local started = false
local view: LeaderboardViewHandle? = nil
local remote: RemoteEvent? = nil

local function asNumber(value: unknown): number?
	return if typeof(value) == "number" and value == value then value else nil
end

-- A cópia vem do servidor, mas a forma é conferida antes de desenhar.
local function parse(raw: unknown): LeaderboardData?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: any }
	if typeof(data.boards) ~= "table" then
		return nil
	end
	local boards: { Leaderboard } = {}
	for _, rawBoard in ipairs(data.boards :: { any }) do
		if typeof(rawBoard) == "table" and typeof(rawBoard.id) == "string" and typeof(rawBoard.entries) == "table" then
			local entries: { LeaderboardEntry } = {}
			for index, item in ipairs(rawBoard.entries :: { any }) do
				if index > LeaderboardTypes.TopCount then
					break
				end
				local rank, userId, value = asNumber(item.rank), asNumber(item.userId), asNumber(item.value)
				local name = if typeof(item.name) == "string" then string.sub(item.name, 1, MAX_NAME_LENGTH) else nil
				if rank ~= nil and userId ~= nil and value ~= nil and name ~= nil then
					table.insert(entries, { rank = rank, userId = userId, name = name, value = value })
				end
			end
			table.insert(boards, { id = rawBoard.id, title = if typeof(rawBoard.title) == "string" then rawBoard.title else "", entries = entries })
		end
	end
	return {
		boards = boards,
		updatedAt = asNumber(data.updatedAt) or 0,
		available = data.available == true,
	}
end

function LeaderboardController.open()
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

function LeaderboardController.start()
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
		warn("[BlocoPuff] Leaderboard controller not started: PlayerGui unavailable")
		return
	end
	view = LeaderboardView.new(playerGui, function(categoryId: string)
		local currentRemote = remote
		if currentRemote ~= nil then
			currentRemote:FireServer("Opened", categoryId)
		end
	end)

	-- Fecha o painel quando o jogador entra na partida.
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		local currentView = view
		if currentView ~= nil and player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			currentView.close()
		end
	end)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.LeaderboardRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Leaderboard controller: remote not found")
			return
		end
		remote = instance
		instance.OnClientEvent:Connect(function(raw: unknown)
			local data = parse(raw)
			local currentView = view
			if data ~= nil and currentView ~= nil then
				currentView.setData(data)
			end
		end)
	end)
end

return table.freeze(LeaderboardController)
