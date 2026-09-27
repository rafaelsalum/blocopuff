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
local KnockbackService = require(script.services.KnockbackService)
local TelemetryService = require(script.services.TelemetryService)
local SecretPassageService = require(script.services.SecretPassageService)
local TocaService = require(script.services.TocaService)
local BaraoService = require(script.services.BaraoService)
local BuildModeService = require(script.services.BuildModeService)
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

TelemetryService.start(PuffadorService.getRemotesFolder())
print("[BlocoPuff] Telemetry ready")

-- Precisa do prédio (quadros marcados) e da pasta de remotes.
SecretPassageService.start(world, PuffadorService.getRemotesFolder())
print("[BlocoPuff] Secret passages ready")

KnockbackService.start(PuffadorService.sendFeedback)
print("[BlocoPuff] Puffador knockback armed")

-- Precisam dos corredores já construídos (luzes das Tocas marcadas).
TocaService.start(world, PuffadorService.sendFeedback)
BaraoService.start(world, PuffadorService.sendFeedback)
print("[BlocoPuff] Barao and safe dens ready")

-- Precisa da Arena já criada (usa ArenaService.getEliminationY) e do
-- RoundService.eliminateParticipant como callback, para não depender dele.
EliminationService.start(world, RoundService.eliminateParticipant)
print("[BlocoPuff] Elimination zone armed")

-- Depende do PuffadorService (pasta de remotes). Abrir o cofre deixa o
-- Barão bravo.
VaultService.start(world)
VaultService.setOpenedListener(function()
	BaraoService.enrage()
end)
BuildModeService.start()
print("[BlocoPuff] Baron's vault and build mode ready")

RoundService.start()
print("[BlocoPuff] Round cycle started")

-- Só ativo no Studio: cenas para capas e thumbnails da loja.
PhotoModeService.start()
