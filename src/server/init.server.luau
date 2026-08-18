--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local ArenaService = require(script.services.ArenaService)
local LobbyService = require(script.services.LobbyService)
local ReplicatedStateService = require(script.services.ReplicatedStateService)
local PuffadorService = require(script.services.PuffadorService)
local EliminationService = require(script.services.EliminationService)
local RoundService = require(script.services.RoundService)
local WorldVisualService = require(script.services.WorldVisualService)
local SkyIslandService = require(script.services.SkyIslandService)
local AdminService = require(script.services.AdminService)

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

-- Publica o estado antes de carregar meshes remotas. Na primeira execução,
-- a criação da ilha pode levar alguns segundos e o HUD não deve expirar.
ReplicatedStateService.create()
print("[BlocoPuff] Replicated state initialized")

WorldVisualService.start(world, GameConfig.Palette)
print("[BlocoPuff] World visuals created")

SkyIslandService.start(world)
print("[BlocoPuff] Walkable sky island created")

LobbyService.create(world, GameConfig.Lobby, GameConfig.Palette)
print("[BlocoPuff] Lobby created")

AdminService.start()
print("[BlocoPuff] Secure admin panel initialized")

ArenaService.create(world, GameConfig.Arena, GameConfig.Palette)
print(string.format("[BlocoPuff] Arena created with %d blocks", #ArenaService.getBlocks()))

PuffadorService.start(world)
print("[BlocoPuff] Puffador system started")

-- Precisa da Arena já criada (usa ArenaService.getEliminationY) e do
-- RoundService.eliminateParticipant como callback, para não depender dele.
EliminationService.start(world, RoundService.eliminateParticipant)
print("[BlocoPuff] Elimination zone armed")

RoundService.start()
print("[BlocoPuff] Round cycle started")
