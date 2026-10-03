--!strict

-- Impulso no servidor (regras em DashRules, valores em DashConfig).
--
--   * Jogador: o próprio cliente aplica a arrancada na hora (o personagem é
--     simulado por ele) e avisa aqui. O servidor confere o intervalo, com
--     folga de rede; aceito, marca LastDashAt no jogador para todos verem o
--     efeito. Impulso fora do intervalo não aparece para ninguém e é contado
--     na telemetria (DashRejected). A física do personagem continua sendo do
--     cliente, como andar e pular.
--   * Bot RoboPuff: o servidor simula o corpo, então aplica a arrancada aqui
--     mesmo, com as mesmas regras (BotBrainService chama `dashBot`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DashConfig = require(ReplicatedStorage.Shared.config.DashConfig)
local DashRules = require(ReplicatedStorage.Shared.modules.DashRules)
local CharacterImpulse = require(ReplicatedStorage.Shared.modules.CharacterImpulse)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local TelemetryService = require(script.Parent.TelemetryService)

type Combatant = CombatantRegistry.Combatant
type DashState = DashRules.DashState

-- Telemetria de impulsos recusados: no máximo um evento por jogador neste
-- intervalo (spam não vira enxurrada de eventos).
local REJECT_REPORT_INTERVAL = 30

local DashService = {}

local started = false
local lastAccepted: { [Player]: number } = {}
local lastRejectReport: { [Player]: number } = {}
local botStates: { [number]: DashState } = {}

local function isAlive(character: Model?): boolean
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0
end

local function onDash(player: Player)
	if not isAlive(player.Character) then
		return
	end
	local clock = os.clock()
	if not DashRules.serverAccepts(lastAccepted[player], clock, DashConfig) then
		local lastReport = lastRejectReport[player]
		if lastReport == nil or clock - lastReport >= REJECT_REPORT_INTERVAL then
			lastRejectReport[player] = clock
			TelemetryService.lobbyEvent(player, "DashRejected", 1)
		end
		return
	end
	lastAccepted[player] = clock
	player:SetAttribute(StateAttributeNames.LastDashAt, Workspace:GetServerTimeNow())
	TelemetryService.dash(player)
end

-- Impulso de um bot na direção `direction`. Devolve se aconteceu.
function DashService.dashBot(bot: Combatant, direction: Vector3): boolean
	local model = bot.model
	local root = CombatantRegistry.getRoot(bot)
	local humanoid = CombatantRegistry.getHumanoid(bot)
	if model == nil or root == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	if CharacterImpulse.isBeingPushed(root) then
		return false
	end
	local now = os.clock()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local state = botStates[bot.id] or DashRules.new()
	if grounded then
		state = DashRules.landed(state)
	end
	if not DashRules.canDash(state, now, grounded, DashConfig) then
		botStates[bot.id] = state
		return false
	end
	CharacterImpulse.dash(root, direction, DashConfig.Speed, DashConfig.Duration)
	botStates[bot.id] = DashRules.afterDash(state, now, grounded, DashConfig)
	model:SetAttribute(StateAttributeNames.LastDashAt, Workspace:GetServerTimeNow())
	return true
end

-- Esquece o estado dos bots que foram embora.
function DashService.forgetBot(bot: Combatant)
	botStates[bot.id] = nil
end

function DashService.start(remotesFolder: Folder?)
	if started then
		return
	end
	started = true
	if remotesFolder ~= nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = PuffadorConstants.DashRemoteName
		remote.Parent = remotesFolder
		remote.OnServerEvent:Connect(onDash)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastAccepted[player] = nil
		lastRejectReport[player] = nil
	end)
end

return table.freeze(DashService)
