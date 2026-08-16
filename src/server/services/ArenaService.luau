--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
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
local BLOCK_TAG = "ArenaBlock"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "ArenaService"
local ATTR_IS_DESTROYED = "IsDestroyed"

local SPAWN_HEIGHT_OFFSET = 5
local SPAWN_MARGIN_RATIO = 0.15

local ArenaService = {}

local currentWorldRoot: Model? = nil
local arenaModel: Model? = nil
local arenaBlocks: { Part } = {}
local currentArenaConfig: ArenaConfig? = nil

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
	table.clear(arenaBlocks)
	table.clear(blockRecords)
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

	local colors = getArenaColors(palette)
	local stepX = config.BlockSize.X + config.BlockGap
	local stepZ = config.BlockSize.Z + config.BlockGap
	local totalWidth = (config.Columns * config.BlockSize.X) + ((config.Columns - 1) * config.BlockGap)
	local totalDepth = (config.Rows * config.BlockSize.Z) + ((config.Rows - 1) * config.BlockGap)
	local startX = config.Position.X - (totalWidth / 2) + (config.BlockSize.X / 2)
	local startZ = config.Position.Z - (totalDepth / 2) + (config.BlockSize.Z / 2)

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
			block:SetAttribute("GridRow", row)
			block:SetAttribute("GridColumn", column)
			block:SetAttribute("BlockId", blockId)
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
end

function ArenaService.endRound()
	destructionEnabled = false
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
	block:SetAttribute("GridRow", record.gridRow)
	block:SetAttribute("GridColumn", record.gridColumn)
	block:SetAttribute("BlockId", record.blockId)
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

return table.freeze(ArenaService)
