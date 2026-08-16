--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)

type RoundState = RoundTypes.RoundState

local STATE_NAME = "BlocoPuffState"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "ReplicatedStateService"

local ATTR_ROUND_STATE = "RoundState"
local ATTR_TIME_REMAINING = "TimeRemaining"
local ATTR_ROUND_ID = "RoundId"
local ATTR_PARTICIPANT_COUNT = "ParticipantCount"
local ATTR_MINIMUM_PLAYERS = "MinimumPlayers"
local ATTR_MAXIMUM_PLAYERS = "MaximumPlayers"
local ATTR_WINNER_USER_ID = "WinnerUserId"
local ATTR_WINNER_NAME = "WinnerName"
local ATTR_STATUS_MESSAGE = "StatusMessage"

local ReplicatedStateService = {}

local stateContainer: Configuration? = nil
local lastValues: { [string]: any } = {}

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function setAttribute(name: string, value: any)
	if stateContainer == nil then
		return
	end

	if lastValues[name] == value then
		return
	end

	lastValues[name] = value
	stateContainer:SetAttribute(name, value)
end

function ReplicatedStateService.destroy()
	if stateContainer ~= nil and stateContainer.Parent ~= nil and isOwned(stateContainer) then
		stateContainer:Destroy()
	else
		local existing = ReplicatedStorage:FindFirstChild(STATE_NAME)
		if existing ~= nil and isOwned(existing) then
			existing:Destroy()
		end
	end

	stateContainer = nil
	table.clear(lastValues)
end

function ReplicatedStateService.create(): Configuration
	ReplicatedStateService.destroy()

	local existing = ReplicatedStorage:FindFirstChild(STATE_NAME)
	if existing ~= nil then
		if not isOwned(existing) then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end

	local container = Instance.new("Configuration")
	container.Name = STATE_NAME
	container:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	container.Parent = ReplicatedStorage

	stateContainer = container
	table.clear(lastValues)

	setAttribute(ATTR_ROUND_STATE, RoundTypes.WaitingForPlayers)
	setAttribute(ATTR_TIME_REMAINING, 0)
	setAttribute(ATTR_ROUND_ID, 0)
	setAttribute(ATTR_PARTICIPANT_COUNT, 0)
	setAttribute(ATTR_MINIMUM_PLAYERS, GameConfig.MinimumPlayers)
	setAttribute(ATTR_MAXIMUM_PLAYERS, GameConfig.MaximumPlayers)
	setAttribute(ATTR_WINNER_USER_ID, 0)
	setAttribute(ATTR_WINNER_NAME, "")
	setAttribute(ATTR_STATUS_MESSAGE, "")

	return container
end

function ReplicatedStateService.setRoundState(state: RoundState)
	setAttribute(ATTR_ROUND_STATE, state)
end

function ReplicatedStateService.setTimeRemaining(seconds: number)
	setAttribute(ATTR_TIME_REMAINING, math.max(0, math.floor(seconds)))
end

function ReplicatedStateService.setRoundId(id: number)
	setAttribute(ATTR_ROUND_ID, id)
end

function ReplicatedStateService.setParticipantCount(count: number)
	setAttribute(ATTR_PARTICIPANT_COUNT, count)
end

function ReplicatedStateService.setWinner(userId: number, name: string)
	setAttribute(ATTR_WINNER_USER_ID, userId)
	setAttribute(ATTR_WINNER_NAME, name)
end

function ReplicatedStateService.clearWinner()
	setAttribute(ATTR_WINNER_USER_ID, 0)
	setAttribute(ATTR_WINNER_NAME, "")
end

function ReplicatedStateService.setStatusMessage(message: string)
	setAttribute(ATTR_STATUS_MESSAGE, message)
end

function ReplicatedStateService.getContainer(): Configuration?
	return stateContainer
end

return table.freeze(ReplicatedStateService)
