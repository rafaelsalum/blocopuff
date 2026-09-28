--!strict

-- Telemetria dos segredos da Fase 2: entrada e saída dos corredores (com o
-- andar de entrada e de saída), Tocas, encontros/contatos/fugas do Barão,
-- passagens reveladas e abandono logo depois de um encontro com o Barão.
-- Os eventos vão pelo TelemetryService (AnalyticsService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local TelemetryService = require(script.Parent.TelemetryService)

type Corridor = BuildingLayout.Corridor

type Visit = {
	corridor: string,
	enteredAt: number,
	entryFloor: number,
}

local SAMPLE_INTERVAL = 0.25
-- Sair do jogo até este tempo depois de encontrar o Barão conta como
-- "abandono após encontro".
local LEAVE_AFTER_BARAO_WINDOW = 30

local CorridorTelemetryService = {}

local started = false
local active = false
local roundId = 0
local corridors: { Corridor } = {}
local visits: { [Player]: Visit } = {}
local lastBaraoMeeting: { [Player]: number } = {}
local anyRevealThisRound = false
-- Avisado quando um participante entra num corredor (conquistas secretas).
local entryListener: ((player: Player, floor: number) -> ())? = nil
local heartbeat: RBXScriptConnection? = nil
local accumulator = 0

local function isActiveParticipant(player: Player): boolean
	return active
		and player.Parent ~= nil
		and player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) == roundId
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == false
end

-- Andar mais próximo da altura (1 = baixo, FloorCount = cima).
local function floorOf(corridor: Corridor, y: number): number
	local middle = (corridor.lowerY + corridor.upperY) / 2
	return if y < middle then 1 else GameConfig.Arena.FloorCount
end

local function findCorridor(position: Vector3): Corridor?
	for _, corridor in ipairs(corridors) do
		if BuildingLayout.isInsideCorridor(corridor, GameConfig.Building, position) then
			return corridor
		end
	end
	return nil
end

local function closeVisit(player: Player, exitFloor: number?, reason: string)
	local visit = visits[player]
	if visit == nil then
		return
	end
	visits[player] = nil
	local seconds = math.floor((os.clock() - visit.enteredAt) * 10) / 10
	local exitText = if exitFloor ~= nil then `Floor{exitFloor}` else reason
	TelemetryService.event(player, "CorridorExited", seconds, exitText, `{visit.corridor}:EnteredFloor{visit.entryFloor}`)
end

local function sample()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if not isActiveParticipant(player) or root == nil or not root:IsA("BasePart") then
			closeVisit(player, nil, "Out")
		else
			local corridor = findCorridor(root.Position)
			local visit = visits[player]
			if corridor ~= nil and visit == nil then
				local floor = floorOf(corridor, root.Position.Y)
				visits[player] = { corridor = corridor.name, enteredAt = os.clock(), entryFloor = floor }
				TelemetryService.event(player, "CorridorEntered", nil, `Floor{floor}`, corridor.name)
				local listener = entryListener
				if listener ~= nil then
					task.spawn(listener, player, floor)
				end
			elseif corridor == nil and visit ~= nil then
				local lastCorridor: Corridor? = nil
				for _, candidate in ipairs(corridors) do
					if candidate.name == visit.corridor then
						lastCorridor = candidate
					end
				end
				closeVisit(player, if lastCorridor ~= nil then floorOf(lastCorridor, root.Position.Y) else nil, "Out")
			end
		end
	end
end

function CorridorTelemetryService.setEntryListener(listener: ((player: Player, floor: number) -> ())?)
	entryListener = listener
end

function CorridorTelemetryService.baraoEvent(kind: string, player: Player, detail: string?)
	if kind == "Encounter" then
		lastBaraoMeeting[player] = os.clock()
		TelemetryService.event(player, "BaraoEncounter")
	elseif kind == "Contact" then
		lastBaraoMeeting[player] = os.clock()
		TelemetryService.event(player, "BaraoContact")
	elseif kind == "Escape" then
		TelemetryService.event(player, "BaraoEscape", nil, detail)
	end
end

function CorridorTelemetryService.tocaEvent(kind: string, player: Player, seconds: number)
	if kind == "Enter" then
		TelemetryService.event(player, "TocaEntered")
	else
		TelemetryService.event(player, "TocaLeft", math.floor(seconds * 10) / 10, kind)
	end
end

-- `floor` revelado por `player`; o primeiro da rodada marca o tempo até a
-- primeira descoberta.
function CorridorTelemetryService.passageRevealed(player: Player, floor: number)
	local first = not anyRevealThisRound
	anyRevealThisRound = true
	TelemetryService.event(player, "PassageRevealed", nil, `Floor{floor}`, if first then "FirstOfRound" else "Later")
end

-- Chamado pelo RoundService quando um participante vivo sai no meio da rodada.
function CorridorTelemetryService.leftMidRound(player: Player)
	closeVisit(player, nil, "Left")
	local met = lastBaraoMeeting[player]
	if met ~= nil and os.clock() - met <= LEAVE_AFTER_BARAO_WINDOW then
		TelemetryService.event(player, "LeftAfterBarao", math.floor(os.clock() - met))
	end
	lastBaraoMeeting[player] = nil
end

function CorridorTelemetryService.beginRound(newRoundId: number)
	roundId = newRoundId
	active = true
	accumulator = 0
	anyRevealThisRound = false
	table.clear(visits)
	table.clear(lastBaraoMeeting)
end

function CorridorTelemetryService.endRound()
	for _, player in ipairs(Players:GetPlayers()) do
		closeVisit(player, nil, "RoundEnd")
	end
	active = false
	table.clear(visits)
	table.clear(lastBaraoMeeting)
end

function CorridorTelemetryService.start()
	if started then
		return
	end
	started = true
	corridors = BuildingLayout.getCorridors(GameConfig.Arena, GameConfig.Building)
	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		if not active then
			return
		end
		accumulator += dt
		if accumulator < SAMPLE_INTERVAL then
			return
		end
		accumulator = 0
		sample()
	end)
end

function CorridorTelemetryService.stop()
	active = false
	local connection = heartbeat
	if connection ~= nil then
		connection:Disconnect()
		heartbeat = nil
	end
	table.clear(visits)
	table.clear(lastBaraoMeeting)
	started = false
end

return table.freeze(CorridorTelemetryService)
