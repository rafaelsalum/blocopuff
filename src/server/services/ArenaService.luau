--!strict

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ReplicatedState = require(script.Parent.ReplicatedStateService)

type ArenaConfig = GameConfig.ArenaConfig
type WorldPalette = GameConfig.WorldPalette

-- Dados mínimos para restaurar um bloco à sua aparência e comportamento
-- originais depois de uma destruição temporária.
export type BlockDestructionContext = {
	position: Vector3,
	normal: Vector3,
	ownerPlayer: Player,
	ownerUserId: number,
	roundId: number,
	projectileId: number,
}

type BlockRecord = {
	part: Part,
	gridRow: number,
	gridColumn: number,
	blockId: string,
	originalCFrame: CFrame,
	originalSize: Vector3,
	originalColor: Color3,
	originalMaterial: Enum.Material,
	originalTransparency: number,
	originalCanCollide: boolean,
	originalCanTouch: boolean,
	originalCanQuery: boolean,
	generation: number,
	isDestroyed: boolean,
}

local ARENA_NAME = "Arena"
local BLOCKS_NAME = "Blocks"
local EFFECTS_NAME = "Effects"
local VISUALS_NAME = "Visuals"
local BLOCK_TAG = ArenaConstants.BlockTag
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "ArenaService"
local ATTR_IS_DESTROYED = ArenaConstants.IsDestroyedAttribute

local SPAWN_HEIGHT_OFFSET = 5
local SPAWN_MARGIN_RATIO = 0.15
local ENERGY_NODE_SIZE = 1.35
local ENERGY_HEIGHT_OFFSET = 1.15
local ENERGY_BEAM_WIDTH = 0.34
local COLLAPSE_DURATION = 0.34
local RESTORE_FADE_DURATION = 0.22

local ArenaService = {}

local currentWorldRoot: Model? = nil
local arenaModel: Model? = nil
local arenaBlocks: { Part } = {}
local currentArenaConfig: ArenaConfig? = nil
local effectsFolder: Folder? = nil
local energyNodes: { Part } = {}
local energyLights: { PointLight } = {}
local energyBeams: { Beam } = {}

local blockRecords: { [Part]: BlockRecord } = {}
local arenaGeneration = 0
local destructionEnabled = false
local activeRoundId = 0
local remainingBlockCount = 0

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function destroyOwnedChild(worldRoot: Model)
	local existing = worldRoot:FindFirstChild(ARENA_NAME)
	if existing == nil then
		return
	end

	if not isOwned(existing) then
		error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
	end

	existing:Destroy()
end

local function getArenaColors(palette: WorldPalette): { Color3 }
	return {
		palette.LightBlue,
		palette.Yellow,
		palette.Orange,
		palette.Purple,
		palette.Pink,
	}
end

local function setArenaEnergy(active: boolean)
	local nodeTransparency = if active then 0.22 else 0.58
	local lightBrightness = if active then 0.85 else 0.18
	local beamTransparency = if active then 0.38 else 0.72

	for _, node in ipairs(energyNodes) do
		TweenService:Create(node, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
			Transparency = nodeTransparency,
		}):Play()
	end
	for _, light in ipairs(energyLights) do
		TweenService:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
			Brightness = lightBrightness,
		}):Play()
	end
	for _, beam in ipairs(energyBeams) do
		beam.Transparency = NumberSequence.new(beamTransparency)
	end
end

local function createArenaVisuals(
	parent: Model,
	config: ArenaConfig,
	palette: WorldPalette,
	totalWidth: number,
	totalDepth: number
)
	local visuals = Instance.new("Model")
	visuals.Name = VISUALS_NAME
	visuals.Parent = parent

	local energyY = config.Position.Y - (config.BlockSize.Y / 2) - ENERGY_HEIGHT_OFFSET
	local halfWidth = (totalWidth / 2) + 0.5
	local halfDepth = (totalDepth / 2) + 0.5
	local cornerOffsets = {
		Vector3.new(-halfWidth, 0, -halfDepth),
		Vector3.new(halfWidth, 0, -halfDepth),
		Vector3.new(halfWidth, 0, halfDepth),
		Vector3.new(-halfWidth, 0, halfDepth),
	}

	for index, offset in ipairs(cornerOffsets) do
		local node = Instance.new("Part")
		node.Name = string.format("EnergyNode%02d", index)
		node.Shape = Enum.PartType.Ball
		node.Size = Vector3.new(ENERGY_NODE_SIZE, ENERGY_NODE_SIZE, ENERGY_NODE_SIZE)
		node.Position = Vector3.new(config.Position.X, energyY, config.Position.Z) + offset
		node.Anchored = true
		node.CanCollide = false
		node.CanTouch = false
		node.CanQuery = false
		node.CastShadow = false
		node.Material = Enum.Material.Neon
		node.Color = palette.Purple:Lerp(palette.LightBlue, 0.35)
		node.Transparency = 0.58
		node.Parent = visuals

		local attachment = Instance.new("Attachment")
		attachment.Name = "EnergyAttachment"
		attachment.Parent = node

		local light = Instance.new("PointLight")
		light.Name = "EnergyLight"
		light.Color = node.Color
		light.Brightness = 0.18
		light.Range = 9
		light.Shadows = false
		light.Parent = node

		table.insert(energyNodes, node)
		table.insert(energyLights, light)
	end

	for index = 1, #energyNodes do
		local nextIndex = if index == #energyNodes then 1 else index + 1
		local attachment0 = energyNodes[index]:FindFirstChild("EnergyAttachment")
		local attachment1 = energyNodes[nextIndex]:FindFirstChild("EnergyAttachment")
		if attachment0 ~= nil and attachment0:IsA("Attachment") and attachment1 ~= nil and attachment1:IsA("Attachment") then
			local beam = Instance.new("Beam")
			beam.Name = string.format("EnergyEdge%02d", index)
			beam.Attachment0 = attachment0
			beam.Attachment1 = attachment1
			beam.Width0 = ENERGY_BEAM_WIDTH
			beam.Width1 = ENERGY_BEAM_WIDTH
			beam.FaceCamera = true
			beam.LightEmission = 0.45
			beam.Color = ColorSequence.new(palette.Purple, palette.LightBlue)
			beam.Transparency = NumberSequence.new(0.72)
			beam.Parent = visuals
			table.insert(energyBeams, beam)
		end
	end
end

local function publishBlockCounts()
	local total = #arenaBlocks
	local remaining = remainingBlockCount
	local destroyed = total - remaining
	ReplicatedState.setBlockCounts(total, remaining, destroyed)
end

function ArenaService.destroy()
	if arenaModel ~= nil and arenaModel.Parent ~= nil and isOwned(arenaModel) then
		arenaModel:Destroy()
	elseif currentWorldRoot ~= nil then
		local existing = currentWorldRoot:FindFirstChild(ARENA_NAME)
		if existing ~= nil and isOwned(existing) then
			existing:Destroy()
		end
	end

	arenaModel = nil
	currentWorldRoot = nil
	currentArenaConfig = nil
	effectsFolder = nil
	table.clear(arenaBlocks)
	table.clear(blockRecords)
	table.clear(energyNodes)
	table.clear(energyLights)
	table.clear(energyBeams)
	remainingBlockCount = 0
	destructionEnabled = false
	activeRoundId = 0
	publishBlockCounts()
end

function ArenaService.create(worldRoot: Model, config: ArenaConfig, palette: WorldPalette): Model
	ArenaService.destroy()
	destroyOwnedChild(worldRoot)

	currentWorldRoot = worldRoot
	arenaGeneration += 1

	local newArena = Instance.new("Model")
	newArena.Name = ARENA_NAME
	newArena:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newArena.Parent = worldRoot

	local blocksFolder = Instance.new("Folder")
	blocksFolder.Name = BLOCKS_NAME
	blocksFolder.Parent = newArena

	local newEffectsFolder = Instance.new("Folder")
	newEffectsFolder.Name = EFFECTS_NAME
	newEffectsFolder.Parent = newArena

	local colors = getArenaColors(palette)
	local stepX = config.BlockSize.X + config.BlockGap
	local stepZ = config.BlockSize.Z + config.BlockGap
	local totalWidth = (config.Columns * config.BlockSize.X) + ((config.Columns - 1) * config.BlockGap)
	local totalDepth = (config.Rows * config.BlockSize.Z) + ((config.Rows - 1) * config.BlockGap)
	local startX = config.Position.X - (totalWidth / 2) + (config.BlockSize.X / 2)
	local startZ = config.Position.Z - (totalDepth / 2) + (config.BlockSize.Z / 2)

	createArenaVisuals(newArena, config, palette, totalWidth, totalDepth)

	for row = 1, config.Rows do
		for column = 1, config.Columns do
			local blockId = string.format("R%02dC%02d", row, column)
			local colorIndex = ((row + column - 2) % #colors) + 1

			local block = Instance.new("Part")
			block.Name = blockId
			block.Anchored = true
			block.CanCollide = true
			block.Size = config.BlockSize
			block.Position = Vector3.new(
				startX + ((column - 1) * stepX),
				config.Position.Y,
				startZ + ((row - 1) * stepZ)
			)
			block.Material = Enum.Material.SmoothPlastic
			block.Color = colors[colorIndex]
			block.TopSurface = Enum.SurfaceType.Smooth
			block.BottomSurface = Enum.SurfaceType.Smooth
			block:SetAttribute(ArenaConstants.GridRowAttribute, row)
			block:SetAttribute(ArenaConstants.GridColumnAttribute, column)
			block:SetAttribute(ArenaConstants.BlockIdAttribute, blockId)
			block:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
			block:SetAttribute(ATTR_IS_DESTROYED, false)
			CollectionService:AddTag(block, BLOCK_TAG)
			block.Parent = blocksFolder

			table.insert(arenaBlocks, block)
			blockRecords[block] = {
				part = block,
				gridRow = row,
				gridColumn = column,
				blockId = blockId,
				originalCFrame = block.CFrame,
				originalSize = block.Size,
				originalColor = block.Color,
				originalMaterial = block.Material,
				originalTransparency = block.Transparency,
				originalCanCollide = block.CanCollide,
				originalCanTouch = block.CanTouch,
				originalCanQuery = block.CanQuery,
				generation = arenaGeneration,
				isDestroyed = false,
			}
		end
	end

	arenaModel = newArena
	currentArenaConfig = config
	effectsFolder = newEffectsFolder
	remainingBlockCount = #arenaBlocks
	publishBlockCounts()

	return newArena
end

function ArenaService.getModel(): Model?
	return arenaModel
end

function ArenaService.getBlocks(): { Part }
	local blocksCopy: { Part } = {}
	for _, block in ipairs(arenaBlocks) do
		table.insert(blocksCopy, block)
	end

	return blocksCopy
end

local function computeSpawnCFrames(config: ArenaConfig, count: number): { CFrame }
	local totalWidth = (config.Columns * config.BlockSize.X) + ((config.Columns - 1) * config.BlockGap)
	local totalDepth = (config.Rows * config.BlockSize.Z) + ((config.Rows - 1) * config.BlockGap)
	local topY = config.Position.Y + (config.BlockSize.Y / 2) + SPAWN_HEIGHT_OFFSET

	local marginX = totalWidth * SPAWN_MARGIN_RATIO
	local marginZ = totalDepth * SPAWN_MARGIN_RATIO
	local usableWidth = totalWidth - (marginX * 2)
	local usableDepth = totalDepth - (marginZ * 2)
	local minX = config.Position.X - (totalWidth / 2) + marginX
	local minZ = config.Position.Z - (totalDepth / 2) + marginZ

	local gridColumns = math.ceil(math.sqrt(count))
	local gridRows = math.ceil(count / gridColumns)

	local spawnCFrames: { CFrame } = {}
	for index = 1, count do
		local zeroBased = index - 1
		local gridRow = math.floor(zeroBased / gridColumns)
		local gridColumn = zeroBased % gridColumns

		local xRatio = if gridColumns > 1 then gridColumn / (gridColumns - 1) else 0.5
		local zRatio = if gridRows > 1 then gridRow / (gridRows - 1) else 0.5

		local x = minX + (xRatio * usableWidth)
		local z = minZ + (zRatio * usableDepth)

		table.insert(spawnCFrames, CFrame.new(x, topY, z))
	end

	return spawnCFrames
end

function ArenaService.getPlayerSpawnCFrames(): { CFrame }
	if currentArenaConfig == nil then
		error(`Cannot compute spawn positions before {SERVICE_NAME}.create has been called`)
	end

	return computeSpawnCFrames(currentArenaConfig, GameConfig.MaximumPlayers)
end

function ArenaService.beginRound(roundId: number)
	activeRoundId = roundId
	destructionEnabled = true
	setArenaEnergy(true)
end

function ArenaService.endRound()
	destructionEnabled = false
	setArenaEnergy(false)
end

function ArenaService.isActiveBlock(instance: Instance): boolean
	if not instance:IsA("Part") then
		return false
	end

	local record = blockRecords[instance]
	if record == nil then
		return false
	end

	return not record.isDestroyed and record.generation == arenaGeneration
end

local function createCollapseEffect(record: BlockRecord, context: BlockDestructionContext)
	local parent = effectsFolder
	if parent == nil or parent.Parent == nil then
		return
	end

	local visual = Instance.new("Part")
	visual.Name = `{record.blockId}Collapse`
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanTouch = false
	visual.CanQuery = false
	visual.CastShadow = false
	visual.CFrame = record.originalCFrame
	visual.Size = record.originalSize
	visual.Color = record.originalColor
	visual.Material = Enum.Material.SmoothPlastic
	visual.TopSurface = Enum.SurfaceType.Smooth
	visual.BottomSurface = Enum.SurfaceType.Smooth
	visual.Parent = parent

	local columnDirection = if record.gridColumn % 2 == 0 then 1 else -1
	local rowDirection = if record.gridRow % 2 == 0 then -1 else 1
	local impactNudge = context.normal * 0.3
	local fallOffset = Vector3.new(columnDirection * 1.35, -4.5, rowDirection * 1.35) + impactNudge
	local tilt = CFrame.Angles(math.rad(rowDirection * 16), 0, math.rad(columnDirection * 18))
	local endCFrame = (record.originalCFrame + fallOffset) * tilt

	local light = Instance.new("PointLight")
	light.Name = "CollapseGlow"
	light.Color = record.originalColor
	light.Brightness = 0.65
	light.Range = 6
	light.Shadows = false
	light.Parent = visual

	TweenService:Create(visual, TweenInfo.new(COLLAPSE_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		CFrame = endCFrame,
		Size = Vector3.new(record.originalSize.X * 0.2, 0.12, record.originalSize.Z * 0.2),
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(COLLAPSE_DURATION, Enum.EasingStyle.Quad), {
		Brightness = 0,
	}):Play()

	Debris:AddItem(visual, COLLAPSE_DURATION + 0.05)
end

function ArenaService.tryDestroyBlock(instance: Instance, context: BlockDestructionContext): boolean
	if not destructionEnabled then
		return false
	end

	if context.roundId ~= activeRoundId then
		return false
	end

	if context.ownerPlayer.Parent == nil then
		return false
	end

	if context.ownerPlayer:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) ~= context.roundId then
		return false
	end

	if context.ownerPlayer:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= false then
		return false
	end

	if not instance:IsA("Part") then
		return false
	end

	local record = blockRecords[instance]
	if record == nil then
		return false
	end

	if record.generation ~= arenaGeneration then
		return false
	end

	if not isOwned(instance) then
		return false
	end

	if not CollectionService:HasTag(instance, BLOCK_TAG) then
		return false
	end

	if record.isDestroyed then
		return false
	end

	record.isDestroyed = true
	remainingBlockCount -= 1

	instance.Transparency = 1
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false
	instance:SetAttribute(ATTR_IS_DESTROYED, true)
	createCollapseEffect(record, context)

	publishBlockCounts()

	return true
end

local function tryReparent(part: Part, parent: Instance): boolean
	local ok = pcall(function()
		part.Parent = parent
	end)
	return ok
end

local function recreateBlockFromRecord(record: BlockRecord): Part?
	if arenaModel == nil then
		return nil
	end

	local blocksFolder = arenaModel:FindFirstChild(BLOCKS_NAME)
	if blocksFolder == nil then
		return nil
	end

	local block = Instance.new("Part")
	block.Name = record.blockId
	block.Anchored = true
	block.CFrame = record.originalCFrame
	block.Size = record.originalSize
	block.Color = record.originalColor
	block.Material = record.originalMaterial
	block.Transparency = record.originalTransparency
	block.CanCollide = record.originalCanCollide
	block.CanTouch = record.originalCanTouch
	block.CanQuery = record.originalCanQuery
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth
	block:SetAttribute(ArenaConstants.GridRowAttribute, record.gridRow)
	block:SetAttribute(ArenaConstants.GridColumnAttribute, record.gridColumn)
	block:SetAttribute(ArenaConstants.BlockIdAttribute, record.blockId)
	block:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	block:SetAttribute(ATTR_IS_DESTROYED, false)
	CollectionService:AddTag(block, BLOCK_TAG)
	block.Parent = blocksFolder

	return block
end

local function restoreBlockAt(index: number)
	local block = arenaBlocks[index]
	local record = blockRecords[block]
	if record == nil then
		return
	end
	local shouldAnimateRestore = record.isDestroyed or block.Transparency ~= record.originalTransparency

	if block.Parent == nil then
		local blocksFolder = if arenaModel ~= nil then arenaModel:FindFirstChild(BLOCKS_NAME) else nil
		local reparented = blocksFolder ~= nil and tryReparent(block, blocksFolder)

		if not reparented then
			local recreated = recreateBlockFromRecord(record)
			if recreated == nil then
				warn(string.format("[BlocoPuff] Could not restore missing block %s", record.blockId))
				return
			end

			blockRecords[block] = nil
			arenaBlocks[index] = recreated
			blockRecords[recreated] = {
				part = recreated,
				gridRow = record.gridRow,
				gridColumn = record.gridColumn,
				blockId = record.blockId,
				originalCFrame = record.originalCFrame,
				originalSize = record.originalSize,
				originalColor = record.originalColor,
				originalMaterial = record.originalMaterial,
				originalTransparency = record.originalTransparency,
				originalCanCollide = record.originalCanCollide,
				originalCanTouch = record.originalCanTouch,
				originalCanQuery = record.originalCanQuery,
				generation = record.generation,
				isDestroyed = false,
			}
			return
		end
	end

	record.isDestroyed = false
	block.CFrame = record.originalCFrame
	block.Size = record.originalSize
	block.Color = record.originalColor
	block.Material = record.originalMaterial
	block.Transparency = record.originalTransparency
	block.CanCollide = record.originalCanCollide
	block.CanTouch = record.originalCanTouch
	block.CanQuery = record.originalCanQuery
	block:SetAttribute(ATTR_IS_DESTROYED, false)

	if shouldAnimateRestore and record.originalTransparency < 1 then
		block.Transparency = math.max(record.originalTransparency, 0.55)
		TweenService:Create(block, TweenInfo.new(RESTORE_FADE_DURATION, Enum.EasingStyle.Quad), {
			Transparency = record.originalTransparency,
		}):Play()
	end
end

function ArenaService.restoreAllBlocks()
	for index = 1, #arenaBlocks do
		local ok = pcall(restoreBlockAt, index)
		if not ok then
			warn(string.format("[BlocoPuff] Error restoring block at index %d", index))
		end
	end

	remainingBlockCount = #arenaBlocks
	publishBlockCounts()
end

function ArenaService.getRemainingBlockCount(): number
	return remainingBlockCount
end

function ArenaService.getDestroyedBlockCount(): number
	return #arenaBlocks - remainingBlockCount
end

function ArenaService.getTotalBlockCount(): number
	return #arenaBlocks
end

function ArenaService.getEliminationY(): number
	if currentArenaConfig == nil then
		error(`Cannot compute elimination height before {SERVICE_NAME}.create has been called`)
	end

	return currentArenaConfig.Position.Y - GameConfig.EliminationZone.DepthBelowArena
end

return table.freeze(ArenaService)
