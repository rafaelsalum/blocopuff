--!strict

-- Mostra o pós-partida quando o servidor envia o resultado da rodada e
-- mantém o rodapé com o que vem a seguir (volta ao lobby, fila e contagem
-- da próxima rodada). Fecha no botão OK, quando a próxima rodada está para
-- começar ou quando ela começa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ResultTypes = require(ReplicatedStorage.Shared.types.ResultTypes)
local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ResultsView = require(script.Parent.Parent.ui.ResultsView)

type RoundResult = ResultTypes.RoundResult
type ResultEntry = ResultTypes.ResultEntry
type Highlight = ResultTypes.Highlight
type ResultsViewHandle = ResultsView.ResultsViewHandle

local WAIT_TIMEOUT = 15
local CLOSE_AT_COUNTDOWN = 3
local MAX_ENTRIES = 12

local ResultsController = {}

local started = false
local view: ResultsViewHandle? = nil

local function asNumber(value: unknown): number?
	return if typeof(value) == "number" and value == value then value else nil
end

local function asString(value: unknown): string?
	return if typeof(value) == "string" and #value <= 60 then value else nil
end

-- O resultado vem do servidor, mas a forma é conferida antes de desenhar.
local function parseResult(raw: unknown): RoundResult?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: any }
	local rawEntries = data.entries
	local rawHighlights = data.highlights
	if typeof(rawEntries) ~= "table" or typeof(rawHighlights) ~= "table" then
		return nil
	end

	local entries: { ResultEntry } = {}
	for index, item in ipairs(rawEntries :: { any }) do
		if index > MAX_ENTRIES or typeof(item) ~= "table" then
			break
		end
		local userId, name, position = asNumber(item.userId), asString(item.name), asNumber(item.position)
		local blocks, knockouts = asNumber(item.blocks), asNumber(item.knockouts)
		if userId == nil or name == nil or position == nil or blocks == nil or knockouts == nil then
			return nil
		end
		table.insert(entries, {
			userId = userId,
			name = name,
			position = position,
			blocks = blocks,
			knockouts = knockouts,
			survived = item.survived == true,
		})
	end

	local highlights: { Highlight } = {}
	for _, item in ipairs(rawHighlights :: { any }) do
		if typeof(item) == "table" then
			local titleText, userId, name, value = asString(item.title), asNumber(item.userId), asString(item.name), asNumber(item.value)
			if titleText ~= nil and userId ~= nil and name ~= nil and value ~= nil then
				table.insert(highlights, { title = titleText, userId = userId, name = name, value = value })
			end
		end
	end

	local roundId, winnerUserId, participantCount = asNumber(data.roundId), asNumber(data.winnerUserId), asNumber(data.participantCount)
	if roundId == nil or winnerUserId == nil or participantCount == nil then
		return nil
	end
	return {
		roundId = roundId,
		winnerUserId = winnerUserId,
		winnerName = asString(data.winnerName) or "",
		draw = data.draw == true,
		participantCount = participantCount,
		entries = entries,
		highlights = highlights,
	}
end

local function footerText(container: Instance, player: Player): string
	local state = container:GetAttribute(StateAttributeNames.RoundState)
	local remaining = asNumber(container:GetAttribute(StateAttributeNames.TimeRemaining)) or 0
	local roundsUntilTurn = asNumber(player:GetAttribute(StateAttributeNames.PlayerRoundsUntilTurn)) or 0
	local queueNote = if roundsUntilTurn >= 2
		then string.format("Você entra em %d rodadas", roundsUntilTurn)
		else "Você joga a próxima rodada"

	if state == RoundTypes.Ending then
		return string.format("Voltando ao lobby em %d s\n%s", remaining, queueNote)
	elseif state == RoundTypes.Countdown then
		return string.format("Próxima rodada em %d s\n%s", remaining, queueNote)
	end
	return "Aguardando jogadores para a próxima rodada"
end

function ResultsController.start()
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
		warn("[BlocoPuff] Results controller not started: PlayerGui unavailable")
		return
	end
	local container = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, WAIT_TIMEOUT)
	if container == nil then
		warn("[BlocoPuff] Results controller not started: state container unavailable")
		return
	end

	local currentView = ResultsView.new(playerGui, function()
		local shown = view
		if shown ~= nil then
			shown.hide()
		end
	end)
	view = currentView

	local function refresh()
		if not currentView.isVisible() then
			return
		end
		local state = container:GetAttribute(StateAttributeNames.RoundState)
		local remaining = asNumber(container:GetAttribute(StateAttributeNames.TimeRemaining)) or 0
		if state == RoundTypes.Active or (state == RoundTypes.Countdown and remaining <= CLOSE_AT_COUNTDOWN) then
			currentView.hide()
			return
		end
		currentView.setFooter(footerText(container, player))
	end

	container:GetAttributeChangedSignal(StateAttributeNames.RoundState):Connect(refresh)
	container:GetAttributeChangedSignal(StateAttributeNames.TimeRemaining):Connect(refresh)
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerRoundsUntilTurn):Connect(refresh)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local remote = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.RoundResultRemoteName, WAIT_TIMEOUT) else nil
		if remote == nil or not remote:IsA("RemoteEvent") then
			warn("[BlocoPuff] Results controller: RoundResult remote not found")
			return
		end
		remote.OnClientEvent:Connect(function(raw: unknown)
			local result = parseResult(raw)
			if result == nil then
				warn("[BlocoPuff] Ignoring malformed round result")
				return
			end
			currentView.show(result, player.UserId)
			refresh()
		end)
	end)
end

return table.freeze(ResultsController)
