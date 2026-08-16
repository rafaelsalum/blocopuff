--!strict

-- Monitora, com uma única tarefa cooperativa, os participantes ativos da
-- rodada e detecta autoritativamente quando cruzam o limite vertical abaixo
-- da arena. Não decide o resultado da partida nem mata o Humanoid: apenas
-- identifica a queda e delega a eliminação ao callback fornecido pelo
-- RoundService, evitando uma dependência circular entre os dois serviços.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local EliminationTypes = require(ReplicatedStorage.Shared.types.EliminationTypes)
local ArenaService = require(script.Parent.ArenaService)

type EliminationReason = EliminationTypes.EliminationReason
export type EliminateCallback = (player: Player, reason: EliminationReason) -> ()

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "EliminationService"
local ZONE_VISUAL_NAME = "EliminationZoneVisual"

local ATTR_IS_PARTICIPANT = StateAttributeNames.PlayerIsParticipant
local ATTR_PARTICIPATING_ROUND_ID = StateAttributeNames.PlayerParticipatingRoundId
local ATTR_IS_ELIMINATED = StateAttributeNames.PlayerIsEliminated

local EliminationService = {}

local currentWorldRoot: Model? = nil
local eliminateCallback: EliminateCallback? = nil
local zoneVisual: Part? = nil

local monitoredPlayers: { Player } = {}
local currentRoundId = 0
local monitoring = false

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function destroyOwnedVisual()
	if zoneVisual ~= nil and zoneVisual.Parent ~= nil and isOwned(zoneVisual) then
		zoneVisual:Destroy()
	end
	zoneVisual = nil
end

-- Apenas para inspeção em Studio: nunca colide, nunca participa da
-- detecção (a comparação de posição em checkParticipants é a única fonte).
local function createVisualZoneIfNeeded()
	destroyOwnedVisual()

	if not GameConfig.EliminationZone.VisualizeInStudio then
		return
	end
	if not RunService:IsStudio() then
		return
	end
	if currentWorldRoot == nil then
		return
	end

	local arenaModel = ArenaService.getModel()
	if arenaModel == nil then
		return
	end

	local ok, eliminationY = pcall(ArenaService.getEliminationY)
	if not ok then
		return
	end

	local boundingCFrame, boundingSize = arenaModel:GetBoundingBox()

	local visual = Instance.new("Part")
	visual.Name = ZONE_VISUAL_NAME
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanTouch = false
	visual.CanQuery = false
	visual.CastShadow = false
	visual.Material = Enum.Material.ForceField
	visual.Color = Color3.fromRGB(255, 80, 80)
	visual.Transparency = 0.75
	visual.Size = Vector3.new(boundingSize.X, 1, boundingSize.Z)
	visual.CFrame = CFrame.new(boundingCFrame.Position.X, eliminationY, boundingCFrame.Position.Z)
	visual:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	visual.Parent = currentWorldRoot

	zoneVisual = visual
end

local function checkParticipants()
	local callback = eliminateCallback
	if callback == nil then
		return
	end

	local ok, eliminationY = pcall(ArenaService.getEliminationY)
	if not ok then
		return
	end

	for _, player in ipairs(monitoredPlayers) do
		local checkOk = pcall(function()
			if player.Parent == nil then
				return
			end
			if player:GetAttribute(ATTR_IS_PARTICIPANT) ~= true then
				return
			end
			if player:GetAttribute(ATTR_PARTICIPATING_ROUND_ID) ~= currentRoundId then
				return
			end
			if player:GetAttribute(ATTR_IS_ELIMINATED) ~= false then
				return
			end

			local character = player.Character
			if character == nil then
				return
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid == nil or humanoid.Health <= 0 then
				return
			end

			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart == nil or not rootPart:IsA("BasePart") then
				return
			end

			if rootPart.Position.Y < eliminationY then
				callback(player, EliminationTypes.FellFromArena)
			end
		end)

		if not checkOk then
			warn(string.format("[BlocoPuff] Error checking elimination zone for %s", player.Name))
		end
	end
end

local function monitorLoop()
	while monitoring do
		checkParticipants()
		task.wait(GameConfig.EliminationZone.CheckInterval)
	end
end

function EliminationService.start(worldRoot: Model, callback: EliminateCallback)
	currentWorldRoot = worldRoot
	eliminateCallback = callback
	createVisualZoneIfNeeded()
end

function EliminationService.beginRound(participants: { Player }, roundId: number)
	table.clear(monitoredPlayers)
	for _, player in ipairs(participants) do
		table.insert(monitoredPlayers, player)
	end
	currentRoundId = roundId

	if not monitoring then
		monitoring = true
		task.spawn(monitorLoop)
	end
end

function EliminationService.endRound()
	monitoring = false
	table.clear(monitoredPlayers)
	currentRoundId = 0
end

function EliminationService.stop()
	EliminationService.endRound()
	destroyOwnedVisual()
	currentWorldRoot = nil
	eliminateCallback = nil
end

return table.freeze(EliminationService)
