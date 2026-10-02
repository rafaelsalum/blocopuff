--!strict

-- Monitora, com uma única tarefa cooperativa, os participantes ativos da
-- rodada e detecta autoritativamente quando cruzam o limite vertical abaixo
-- da arena. Não decide o resultado da partida nem mata o Humanoid: apenas
-- identifica a queda e delega a eliminação ao callback fornecido pelo
-- RoundService, evitando uma dependência circular entre os dois serviços.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local EliminationTypes = require(ReplicatedStorage.Shared.types.EliminationTypes)
local ArenaService = require(script.Parent.ArenaService)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type EliminationReason = EliminationTypes.EliminationReason
type Combatant = CombatantRegistry.Combatant
export type EliminateCallback = (combatant: Combatant, reason: EliminationReason) -> ()

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

local monitored: { Combatant } = {}
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

	for _, combatant in ipairs(monitored) do
		local checkOk = pcall(function()
			if not CombatantRegistry.isPresent(combatant) then
				-- O corpo de um bot sumiu (caiu do mapa, foi destruído): ele
				-- está fora da partida. Jogador que saiu é tratado pelo
				-- RoundService (PlayerRemoving).
				if CombatantRegistry.isBot(combatant) and CombatantRegistry.getAttribute(combatant, ATTR_IS_ELIMINATED) == false then
					callback(combatant, EliminationTypes.CharacterDied)
				end
				return
			end
			if CombatantRegistry.getAttribute(combatant, ATTR_IS_PARTICIPANT) ~= true then
				return
			end
			if CombatantRegistry.getAttribute(combatant, ATTR_PARTICIPATING_ROUND_ID) ~= currentRoundId then
				return
			end
			if CombatantRegistry.getAttribute(combatant, ATTR_IS_ELIMINATED) ~= false then
				return
			end

			local humanoid = CombatantRegistry.getHumanoid(combatant)
			if humanoid == nil or humanoid.Health <= 0 then
				return
			end

			local rootPart = CombatantRegistry.getRoot(combatant)
			if rootPart == nil then
				return
			end

			if rootPart.Position.Y < eliminationY then
				callback(combatant, EliminationTypes.FellFromArena)
			end
		end)

		if not checkOk then
			warn(string.format("[BlocoPuff] Error checking elimination zone for %s", combatant.name))
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

function EliminationService.beginRound(participants: { Combatant }, roundId: number)
	table.clear(monitored)
	for _, combatant in ipairs(participants) do
		table.insert(monitored, combatant)
	end
	currentRoundId = roundId

	if not monitoring then
		monitoring = true
		task.spawn(monitorLoop)
	end
end

function EliminationService.endRound()
	monitoring = false
	table.clear(monitored)
	currentRoundId = 0
end

function EliminationService.stop()
	EliminationService.endRound()
	destroyOwnedVisual()
	currentWorldRoot = nil
	eliminateCallback = nil
end

return table.freeze(EliminationService)
