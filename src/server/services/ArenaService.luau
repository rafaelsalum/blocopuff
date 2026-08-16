--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

type ArenaConfig = GameConfig.ArenaConfig
type WorldPalette = GameConfig.WorldPalette

local ARENA_NAME = "Arena"
local BLOCKS_NAME = "Blocks"
local BLOCK_TAG = "ArenaBlock"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "ArenaService"

local SPAWN_HEIGHT_OFFSET = 5
local SPAWN_MARGIN_RATIO = 0.15

local ArenaService = {}

local currentWorldRoot: Model? = nil
local arenaModel: Model? = nil
local arenaBlocks: { Part } = {}
local currentArenaConfig: ArenaConfig? = nil

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
end

function ArenaService.create(worldRoot: Model, config: ArenaConfig, palette: WorldPalette): Model
	ArenaService.destroy()
	destroyOwnedChild(worldRoot)

	currentWorldRoot = worldRoot

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
			CollectionService:AddTag(block, BLOCK_TAG)
			block.Parent = blocksFolder

			table.insert(arenaBlocks, block)
		end
	end

	arenaModel = newArena
	currentArenaConfig = config
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

return table.freeze(ArenaService)
