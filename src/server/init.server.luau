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
local TrapService = require(script.services.TrapService)
local TelemetryService = require(script.services.TelemetryService)
local SecretPassageService = require(script.services.SecretPassageService)
local TocaService = require(script.services.TocaService)
local BaraoService = require(script.services.BaraoService)
local BuildModeService = require(script.services.BuildModeService)
local PuffMomentService = require(script.services.PuffMomentService)
local CorridorTelemetryService = require(script.services.CorridorTelemetryService)
local RoundStatsService = require(script.services.RoundStatsService)
local PlayerDataService = require(script.services.PlayerDataService)
local LeaderboardService = require(script.services.LeaderboardService)
local HallOfFameService = require(script.services.HallOfFameService)
local PuffdexService = require(script.services.PuffdexService)
local PuffMachineService = require(script.services.PuffMachineService)
local SecretAchievementService = require(script.services.SecretAchievementService)
local PartyService = require(script.services.PartyService)
local MatchQueueService = require(script.services.MatchQueueService)
local WarmupService = require(script.services.WarmupService)
local ReactionService = require(script.services.ReactionService)
local LobbyStationsService = require(script.services.LobbyStationsService)
local TrainingService = require(script.services.TrainingService)
local WorldVisualService = require(script.services.WorldVisualService)
local BuildingService = require(script.services.BuildingService)
local MansionService = require(script.services.MansionService)
local AdminService = require(script.services.AdminService)
local PhotoModeService = require(script.services.PhotoModeService)
local CombatantRegistry = require(script.services.CombatantRegistry)
local BotFillService = require(script.services.BotFillService)
local MatchTestControls = require(script.services.MatchTestControls)
local ReferralService = require(script.services.ReferralService)
local OnboardingService = require(script.services.OnboardingService)

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

-- O Casarão é o lobby (o nascimento fica nele): precisa do prédio (portas
-- na parede leste) e do LobbyService (reserva as áreas dos móveis).
MansionService.create(world, GameConfig.Building)
print("[BlocoPuff] Mansion lobby built")

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

-- Precisa do prédio (janelas marcadas), da arena (tapetes sobre os blocos)
-- e do empurrão.
TrapService.start(world)
print("[BlocoPuff] Mansion traps ready")

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
VaultService.setOpenedListener(function(player)
	BaraoService.enrage()
	RoundStatsService.vaultOpened(CombatantRegistry.forPlayer(player))
end)
BuildModeService.start()
print("[BlocoPuff] Baron's vault and build mode ready")

-- Momentos Puff e telemetria dos segredos, alimentados pelos serviços acima.
PuffMomentService.start(PuffadorService.getRemotesFolder())
CorridorTelemetryService.start()
BaraoService.setEventListener(function(kind, player, detail)
	CorridorTelemetryService.baraoEvent(kind, player, detail)
	SecretAchievementService.baraoEvent(kind, player, detail)
	if kind == "Escape" then
		PuffMomentService.record(player, "BaraoEscape", detail)
		RoundStatsService.baraoEscape(CombatantRegistry.forPlayer(player))
	end
end)
TocaService.setEventListener(CorridorTelemetryService.tocaEvent)
SecretPassageService.setRevealListener(function(floor, player)
	CorridorTelemetryService.passageRevealed(player, floor)
	SecretAchievementService.passageRevealed(player, floor)
	PuffMomentService.record(player, "SecretDiscovery", `Floor{floor}`)
	RoundStatsService.secretFound(CombatantRegistry.forPlayer(player))
end)
VaultService.setPrizeListener(function(player)
	PuffMomentService.record(player, "VaultConquered")
	RoundStatsService.vaultConquered(CombatantRegistry.forPlayer(player))
end)
CorridorTelemetryService.setEntryListener(function(player, floor)
	SecretAchievementService.corridorEntered(player, SecretPassageService.isRevealed(floor))
end)
print("[BlocoPuff] Puff moments and secrets telemetry ready")

-- Perfil persistente: carrega quem já está no servidor e quem entrar.
PlayerDataService.start(PuffadorService.getRemotesFolder())
print("[BlocoPuff] Player profiles ready")

-- Funil da primeira sessão (Funil de Onboarding do Creator Dashboard).
local onboardingOk, onboardingFailure = pcall(function()
	OnboardingService.start()
end)
if not onboardingOk then
	warn(string.format("[BlocoPuff] Onboarding funnel disabled: %s", tostring(onboardingFailure)))
end

-- Convite com recompensa (prêmio para quem convidou e para o amigo).
local referralOk, referralFailure = pcall(function()
	ReferralService.start(PuffadorService.getRemotesFolder())
end)
if not referralOk then
	warn(string.format("[BlocoPuff] Referral rewards disabled: %s", tostring(referralFailure)))
end

-- Puffdex: equipar Puffs (os desbloqueios vêm do perfil).
PuffdexService.start(PuffadorService.getRemotesFolder())
PuffMachineService.start(PuffadorService.getRemotesFolder())
print("[BlocoPuff] Puffdex and Puff Machine ready")

-- Conquistas secretas (e o Puff escondido no lobby).
-- Opcional: uma falha aqui não pode impedir o resto do servidor de subir.
local secretsOk, secretsFailure = pcall(SecretAchievementService.start, world)
if secretsOk then
	print("[BlocoPuff] Secret achievements ready")
else
	warn(string.format("[BlocoPuff] Secret achievements unavailable: %s", tostring(secretsFailure)))
end

-- Ranking global (lê os perfis salvos) e os painéis do Hall da Fama no lobby.
LeaderboardService.start(PuffadorService.getRemotesFolder())
HallOfFameService.start(world, LeaderboardService.addListener)
print("[BlocoPuff] Leaderboards and Hall of Fame ready")

-- Estações nas salas do Casarão (Puff Machine, vitrine, desafios, Party,
-- loja em breve, Barão amigável) e a área de treino. Opcional: uma falha aqui não
-- impede o servidor de subir.
local stationsOk, stationsFailure = pcall(function()
	LobbyStationsService.start(world)
	TrainingService.start(world)
end)
if stationsOk then
	print("[BlocoPuff] Lobby stations and training range ready")
else
	warn(string.format("[BlocoPuff] Lobby stations unavailable: %s", tostring(stationsFailure)))
end

-- Party (entra junto nas partidas) e reações de quem está assistindo.
PartyService.start(PuffadorService.getRemotesFolder())
ReactionService.start(PuffadorService.getRemotesFolder())
print("[BlocoPuff] Party and spectator reactions ready")

-- Fila da partida (quem está no mirante). Antes do RoundService, que só
-- conta e escala quem está nela.
MatchQueueService.start(world, PuffadorService.getRemotesFolder())
print("[BlocoPuff] Match queue ready")

-- Bots RoboPuff que completam a partida (Fase 5B). Depois da fila, que
-- eles leem para saber quantos humanos estão esperando.
BotFillService.start(world)
print("[BlocoPuff] RoboPuff bots ready")

-- Aquecimento no mirante (balões e trampolins). Opcional: uma falha aqui
-- não impede a fila nem as partidas.
local warmupOk, warmupFailure = pcall(WarmupService.start, world)
if warmupOk then
	print("[BlocoPuff] Overlook warm-up ready")
else
	warn(string.format("[BlocoPuff] Overlook warm-up unavailable: %s", tostring(warmupFailure)))
end

RoundService.start()
print("[BlocoPuff] Round cycle started")

-- Comandos de teste da partida no painel admin (só administradores).
MatchTestControls.start()

-- Só ativo no Studio: cenas para capas e thumbnails da loja.
PhotoModeService.start()
