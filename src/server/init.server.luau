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
local VaultService = require(script.services.VaultService)
local WorldVisualService = require(script.services.WorldVisualService)
local BuildingService = require(script.services.BuildingService)
local AdminService = require(script.services.AdminService)
local PhotoModeService = require(script.services.PhotoModeService)

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

ReplicatedStateService.create()
print("[BlocoPuff] Replicated state initialized")

WorldVisualService.start(world, GameConfig.Palette)
print("[BlocoPuff] World visuals created")

BuildingService.create(world, GameConfig.Arena, GameConfig.Building)
print("[BlocoPuff] Building created")

LobbyService.create(world, GameConfig.Arena, GameConfig.Building)
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

-- Depende do PuffadorService (pasta de remotes) e usa a mesma eliminação
-- centralizada do RoundService para quem leva tiro dentro do cofre.
VaultService.start(world, RoundService.eliminateParticipant)
print("[BlocoPuff] Baron's vault ready")

RoundService.start()
print("[BlocoPuff] Round cycle started")

-- Só ativo no Studio: cenas para capas e thumbnails da loja.
PhotoModeService.start()
