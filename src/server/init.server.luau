--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local ArenaService = require(script.services.ArenaService)
local LobbyService = require(script.services.LobbyService)
local ReplicatedStateService = require(script.services.ReplicatedStateService)
local RoundService = require(script.services.RoundService)

local WORLD_NAME = "BlocoPuffWorld"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local WORLD_OWNER = "BlocoPuffServer"

local function getOrCreateWorld(): Model
	local existing = Workspace:FindFirstChild(WORLD_NAME)
	if existing ~= nil then
		if not existing:IsA("Model") then
			error(`Cannot initialize {WORLD_NAME}: an instance with that name already exists`)
		end

		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= WORLD_OWNER then
			error(`Cannot initialize {WORLD_NAME}: the existing model is not owned by BlocoPuff`)
		end

		return existing
	end

	local world = Instance.new("Model")
	world.Name = WORLD_NAME
	world:SetAttribute(GENERATED_BY_ATTRIBUTE, WORLD_OWNER)
	world.Parent = Workspace

	return world
end

local world = getOrCreateWorld()

print("[BlocoPuff] Server initialized")

LobbyService.create(world, GameConfig.Lobby, GameConfig.Palette)
print("[BlocoPuff] Lobby created")

ArenaService.create(world, GameConfig.Arena, GameConfig.Palette)
print(string.format("[BlocoPuff] Arena created with %d blocks", #ArenaService.getBlocks()))

ReplicatedStateService.create()
print("[BlocoPuff] Replicated state initialized")

RoundService.start()
print("[BlocoPuff] Round cycle started")
