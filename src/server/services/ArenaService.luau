--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ReplicatedState = require(script.Parent.ReplicatedStateService)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

type ArenaConfig = GameConfig.ArenaConfig
type WorldPalette = GameConfig.WorldPalette

-- Dados mínimos para restaurar um bloco à sua aparência e comportamento
-- originais depois de uma destruição temporária.
export type BlockDestructionContext = {
	position: Vector3,
	normal: Vector3,
	-- Quem atirou (jogador ou bot).
	owner: Combatant,
	roundId: number,
	projectileId: number,
}

type BlockRecord = {
	part: Part,
	floorIndex: number,
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

local ENERGY_NODE_SIZE = 1.35
local ENERGY_HEIGHT_OFFSET = 1.15
local ENERGY_BEAM_WIDTH = 0.34
local ENERGY_WALL_INSET = 1
local RESTORE_FADE_DURATION = 0.22
local REBUILD_FLASH_COLOR = Color3.fromRGB(255, 214, 90)
local REBUILD_FLASH_DURATION = 0.9

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
local spawnRandom = Random.new()
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

local function getFloorStyle(config: ArenaConfig, floorIndex: number): GameConfig.FloorStyle
	local styles = config.FloorStyles
	return styles[math.min(floorIndex, #styles)]
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
	visuals: Model,
	config: ArenaConfig,
	palette: WorldPalette,
	floorIndex: number,
	totalWidth: number,
	totalDepth: number
)
	local firstNodeIndex = #energyNodes + 1
	local energyY = BuildingLayout.getFloorY(config, floorIndex) - (config.BlockSize.Y / 2) - ENERGY_HEIGHT_OFFSET
	-- Recuado para dentro, pois as paredes do prédio encostam na borda do piso.
	local halfWidth = (totalWidth / 2) - ENERGY_WALL_INSET
	local halfDepth = (totalDepth / 2) - ENERGY_WALL_INSET
	local cornerOffsets = {
		Vector3.new(-halfWidth, 0, -halfDepth),
		Vector3.new(halfWidth, 0, -halfDepth),
		Vector3.new(halfWidth, 0, halfDepth),
		Vector3.new(-halfWidth, 0, halfDepth),
	}

	for index, offset in ipairs(cornerOffsets) do
		local node = Instance.new("Part")
		node.Name = string.format("EnergyNodeF%d_%02d", floorIndex, index)
		node.Shape = Enum.PartType.Ball
		node.Size = Vector3.new(ENERGY_NODE_SIZE, ENERGY_NODE_SIZE, ENERGY_NODE_SIZE)
		node.Position = Vector3.new(config.Position.X, energyY, config.Position.Z) + offset
		node.Anchored = true
		node.CanCollide = false
		node.CanTouch = false
		node.CanQuery = false
		node.CastShadow = false
		node.Material = Enum.Material.Neon
		node.Color = palette.Yellow:Lerp(palette.Orange, 0.4)
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

	local lastNodeIndex = #energyNodes
	for index = firstNodeIndex, lastNodeIndex do
		local nextIndex = if index == lastNodeIndex then firstNodeIndex else index + 1
		local attachment0 = energyNodes[index]:FindFirstChild("EnergyAttachment")
		local attachment1 = energyNodes[nextIndex]:FindFirstChild("EnergyAttachment")
		if attachment0 ~= nil and attachment0:IsA("Attachment") and attachment1 ~= nil and attachment1:IsA("Attachment") then
			local beam = Instance.new("Beam")
			beam.Name = string.format("EnergyEdgeF%d_%02d", floorIndex, index - firstNodeIndex + 1)
			beam.Attachment0 = attachment0
			beam.Attachment1 = attachment1
			beam.Width0 = ENERGY_BEAM_WIDTH
			beam.Width1 = ENERGY_BEAM_WIDTH
			beam.FaceCamera = true
			beam.LightEmission = 0.45
			beam.Color = ColorSequence.new(palette.Yellow, palette.Orange)
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

	local stepX = config.BlockSize.X + config.BlockGap
	local stepZ = config.BlockSize.Z + config.BlockGap
	local totalWidth, totalDepth = BuildingLayout.getFloorSize(config)
	local startX = config.Position.X - (totalWidth / 2) + (config.BlockSize.X / 2)
	local startZ = config.Position.Z - (totalDepth / 2) + (config.BlockSize.Z / 2)

	local visuals = Instance.new("Model")
	visuals.Name = VISUALS_NAME
	visuals.Parent = newArena

	for floorIndex = 1, config.FloorCount do
		local style = getFloorStyle(config, floorIndex)
		local colors = style.Colors
		local floorY = BuildingLayout.getFloorY(config, floorIndex)
		createArenaVisuals(visuals, config, palette, floorIndex, totalWidth, totalDepth)

		for row = 1, config.Rows do
			for column = 1, config.Columns do
				local blockId = string.format("F%dR%02dC%02d", floorIndex, row, column)
				local colorIndex = ((row + column) % #colors) + 1

				local block = Instance.new("Part")
				block.Name = blockId
				block.Anchored = true
				block.CanCollide = true
				block.Size = config.BlockSize
				block.Position = Vector3.new(startX + ((column - 1) * stepX), floorY, startZ + ((row - 1) * stepZ))
				block.Material = style.Material
				block.Color = colors[colorIndex]
				block.TopSurface = Enum.SurfaceType.Smooth
				block.BottomSurface = Enum.SurfaceType.Smooth
				block:SetAttribute(ArenaConstants.FloorAttribute, floorIndex)
				block:SetAttribute(ArenaConstants.GridRowAttribute, row)
				block:SetAttribute(ArenaConstants.GridColumnAttribute, column)
				block:SetAttribute(ArenaConstants.BlockIdAttribute, blockId)
				block:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
				block:SetAttribute(ATTR_IS_DESTROYED, false)
				block:SetAttribute(ArenaConstants.CollapseWarningAttribute, false)
				CollectionService:AddTag(block, BLOCK_TAG)
				block.Parent = blocksFolder

				table.insert(arenaBlocks, block)
				blockRecords[block] = {
					part = block,
					floorIndex = floorIndex,
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

function ArenaService.getPlayerSpawnCFrames(count: number): { CFrame }
	if currentArenaConfig == nil then
		error(`Cannot compute spawn positions before {SERVICE_NAME}.create has been called`)
	end

	-- A partida sempre começa no piso de cima, com os jogadores sorteados em
	-- posições o mais afastadas possível umas das outras.
	return BuildingLayout.getSpreadSpawnCFrames(currentArenaConfig, currentArenaConfig.FloorCount, count, spawnRandom)
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

local function findActiveBlockAt(floorIndex: number, row: number, column: number): Part?
	for part, record in pairs(blockRecords) do
		if
			record.floorIndex == floorIndex
			and record.gridRow == row
			and record.gridColumn == column
			and not record.isDestroyed
			and record.generation == arenaGeneration
		then
			return part
		end
	end
	return nil
end

-- Avisados quando um bloco cai. `by` é quem derrubou (nil: o próprio jogo,
-- como o Caos Final). Usado pelas armadilhas presas a um bloco (lustre).
export type DestroyedListener = (block: Part, by: Combatant?) -> ()
local destroyedListeners: { DestroyedListener } = {}

local function notifyDestroyed(block: Part, by: Combatant?)
	for _, listener in ipairs(destroyedListeners) do
		task.spawn(listener, block, by)
	end
end

function ArenaService.addDestroyedListener(listener: DestroyedListener)
	table.insert(destroyedListeners, listener)
end

local function markDestroyed(instance: Part, record: BlockRecord)
	record.isDestroyed = true
	remainingBlockCount -= 1

	instance.Transparency = 1
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false
	instance:SetAttribute(ATTR_IS_DESTROYED, true)
	instance:SetAttribute(ArenaConstants.CollapseWarningAttribute, false)
	-- A animação de quebra roda no cliente (BlockCollapseController), a partir
	-- do atributo IsDestroyed, para ficar fluida.

	publishBlockCounts()
end

function ArenaService.tryDestroyBlock(instance: Instance, context: BlockDestructionContext): boolean
	if not destructionEnabled then
		return false
	end

	if context.roundId ~= activeRoundId then
		return false
	end

	local owner = context.owner
	if not CombatantRegistry.isPresent(owner) then
		return false
	end

	if CombatantRegistry.getAttribute(owner, StateAttributeNames.PlayerParticipatingRoundId) ~= context.roundId then
		return false
	end

	if CombatantRegistry.getAttribute(owner, StateAttributeNames.PlayerIsEliminated) ~= false then
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

	markDestroyed(instance, record)
	notifyDestroyed(instance, owner)
	return true
end

-- Bloco derrubado sem tiro direto: pelo próprio jogo (Caos Final) ou por
-- uma armadilha, que informa quem a acionou em `by`.
function ArenaService.collapseBlock(instance: Instance, by: Combatant?): boolean
	if not destructionEnabled or not instance:IsA("Part") then
		return false
	end
	local record = blockRecords[instance]
	if record == nil or record.isDestroyed or record.generation ~= arenaGeneration then
		return false
	end
	markDestroyed(instance, record)
	notifyDestroyed(instance, by)
	return true
end

function ArenaService.getIntactBlocks(): { Part }
	local intact: { Part } = {}
	for _, block in ipairs(arenaBlocks) do
		local record = blockRecords[block]
		if record ~= nil and not record.isDestroyed and record.generation == arenaGeneration then
			table.insert(intact, block)
		end
	end
	return intact
end

-- Ponto seguro para a Segunda Chance: um bloco inteiro do andar pedido,
-- preferindo os que ainda têm mais vizinhos inteiros (menos chance de cair
-- de novo logo em seguida). Nil se o andar não tiver mais blocos.
function ArenaService.getSafeRespawnCFrame(floorIndex: number): CFrame?
	local config = currentArenaConfig
	if config == nil then
		return nil
	end
	local candidates: { Part } = {}
	local intactCells: { [number]: boolean } = {}
	local function cellKey(row: number, column: number): number
		return (row * 1000) + column
	end
	for _, block in ipairs(arenaBlocks) do
		local record = blockRecords[block]
		if record ~= nil and record.floorIndex == floorIndex and not record.isDestroyed and record.generation == arenaGeneration then
			table.insert(candidates, block)
			intactCells[cellKey(record.gridRow, record.gridColumn)] = true
		end
	end

	local best: { Part } = {}
	local bestScore = -1
	for _, block in ipairs(candidates) do
		local record = blockRecords[block]
		if record ~= nil then
			local score = 0
			for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				if intactCells[cellKey(record.gridRow + offset[1], record.gridColumn + offset[2])] then
					score += 1
				end
			end
			if score > bestScore then
				bestScore = score
				best = { block }
			elseif score == bestScore then
				table.insert(best, block)
			end
		end
	end
	if #best == 0 then
		return nil
	end
	local chosen = best[spawnRandom:NextInteger(1, #best)]
	local position = chosen.Position + Vector3.new(0, (config.BlockSize.Y / 2) + 3, 0)
	local center = Vector3.new(config.Position.X, position.Y, config.Position.Z)
	if (center - position).Magnitude < 0.1 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, center)
end

-- Marca (ou desmarca) um bloco piscando antes de cair no Caos Final.
function ArenaService.setCollapseWarning(instance: Instance, warning: boolean)
	if not instance:IsA("Part") then
		return
	end
	local record = blockRecords[instance]
	if record == nil or record.isDestroyed then
		return
	end
	instance:SetAttribute(ArenaConstants.CollapseWarningAttribute, warning)
end

-- Vizinho do bloco atingido para o Puffador do Cofre: segue o eixo em que o
-- impacto ficou mais afastado do centro (coluna = X, linha = Z). Na borda
-- da grade, ou se esse vizinho já caiu, tenta o lado oposto.
function ArenaService.getNeighborBlock(instance: Instance, impactPosition: Vector3): Part?
	local config = currentArenaConfig
	if config == nil or not instance:IsA("Part") then
		return nil
	end
	local record = blockRecords[instance]
	if record == nil then
		return nil
	end

	local offset = impactPosition - record.originalCFrame.Position
	local alongColumns = math.abs(offset.X) >= math.abs(offset.Z)
	local sign = if alongColumns then (if offset.X >= 0 then 1 else -1) else (if offset.Z >= 0 then 1 else -1)
	for _, direction in ipairs({ sign, -sign }) do
		local row = record.gridRow + (if alongColumns then 0 else direction)
		local column = record.gridColumn + (if alongColumns then direction else 0)
		if row >= 1 and row <= config.Rows and column >= 1 and column <= config.Columns then
			local neighbor = findActiveBlockAt(record.floorIndex, row, column)
			if neighbor ~= nil then
				return neighbor
			end
		end
	end
	return nil
end

local function findBlockAt(floorIndex: number, row: number, column: number): (Part?, BlockRecord?)
	for part, record in pairs(blockRecords) do
		if record.floorIndex == floorIndex and record.gridRow == row and record.gridColumn == column and record.generation == arenaGeneration then
			return part, record
		end
	end
	return nil, nil
end

-- Estado de uma célula da grade (para o modo Construir), ou nil se não existir.
function ArenaService.getCellState(floorIndex: number, row: number, column: number): ("Destroyed" | "Intact")?
	local _, record = findBlockAt(floorIndex, row, column)
	if record == nil then
		return nil
	end
	return if record.isDestroyed then "Destroyed" else "Intact"
end

-- Reconstrói um bloco derrubado no seu lugar original (modo Construir do
-- Puffador do Cofre). Pisca dourado ao voltar. Falso se não der.
function ArenaService.rebuildBlock(floorIndex: number, row: number, column: number): boolean
	if not destructionEnabled then
		return false
	end
	local block, record = findBlockAt(floorIndex, row, column)
	if block == nil or record == nil or not record.isDestroyed or block.Parent == nil then
		return false
	end

	record.isDestroyed = false
	remainingBlockCount += 1
	block.CFrame = record.originalCFrame
	block.Size = record.originalSize
	block.Material = record.originalMaterial
	block.Transparency = record.originalTransparency
	block.CanCollide = record.originalCanCollide
	block.CanTouch = record.originalCanTouch
	block.CanQuery = record.originalCanQuery
	block:SetAttribute(ATTR_IS_DESTROYED, false)
	block:SetAttribute(ArenaConstants.CollapseWarningAttribute, false)
	block.Color = REBUILD_FLASH_COLOR
	TweenService:Create(block, TweenInfo.new(REBUILD_FLASH_DURATION, Enum.EasingStyle.Quad), {
		Color = record.originalColor,
	}):Play()

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
	block:SetAttribute(ArenaConstants.FloorAttribute, record.floorIndex)
	block:SetAttribute(ArenaConstants.GridRowAttribute, record.gridRow)
	block:SetAttribute(ArenaConstants.GridColumnAttribute, record.gridColumn)
	block:SetAttribute(ArenaConstants.BlockIdAttribute, record.blockId)
	block:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	block:SetAttribute(ATTR_IS_DESTROYED, false)
	block:SetAttribute(ArenaConstants.CollapseWarningAttribute, false)
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
				floorIndex = record.floorIndex,
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
	block:SetAttribute(ArenaConstants.CollapseWarningAttribute, false)

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

	-- Só cair abaixo do piso mais baixo elimina: quem cai do piso de cima
	-- apenas desce de andar e continua na partida.
	return BuildingLayout.getEliminationY(currentArenaConfig, GameConfig.EliminationZone.DepthBelowArena)
end

return table.freeze(ArenaService)
