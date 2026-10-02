--!strict

-- Tapete Puxado (Fase 5, entrega 5.3). Dois tapetes no térreo, cada um com
-- uma franja numa ponta (o alvo). Ao fim do aviso, todo mundo em cima do
-- tapete escorrega para o lado da franja: só na horizontal, sem pulo (a
-- gravidade continua valendo, então quem passa por um buraco cai). O
-- perigo depende do caminho, então quem atira precisa ler onde a vítima
-- está. Quem atirou nunca escorrega.
--
-- O tapete é feito de um pedaço por bloco do piso: o pedaço some quando o
-- bloco embaixo cai e volta quando ele é restaurado, para nunca ficar
-- tapete flutuando sobre um buraco. Os blocos são seguidos pela célula da
-- grade (não pela peça), porque a arena pode recriar um bloco perdido. A
-- franja some (e deixa de ser alvo) se todos os blocos debaixo dela
-- caírem. O cliente (effects/RugTrapFx) desenha a onda, o puxão e o tapete
-- embolado.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local ArenaService = require(script.Parent.Parent.ArenaService)
local KnockbackService = require(script.Parent.Parent.KnockbackService)

local CONFIG = TrapConfig.Rug
local TILE_THICKNESS = 0.12
local TILE_LIFT = 0.02
local FRINGE_DEPTH = 0.9
local FRINGE_HEIGHT = 0.4
-- Tom do xadrez discreto do tecido.
local WEAVE_SHADE = 0.12
-- Folga nas bordas ao conferir quem está em cima do tapete.
local EDGE_MARGIN = 0.5

type Cell = {
	row: number,
	column: number,
	tile: BasePart,
	block: BasePart?,
	connection: RBXScriptConnection?,
	-- Célula debaixo da franja.
	underFringe: boolean,
}

type Rug = {
	center: Vector3,
	pull: Vector3,
	across: Vector3,
	halfAlong: number,
	halfAcross: number,
	-- Altura da face de cima do piso.
	topY: number,
	-- Centro do primeiro bloco (linha e coluna iniciais) e passo da grade.
	origin: Vector3,
	row: number,
	column: number,
	stepX: number,
	stepZ: number,
	cells: { [string]: Cell },
	fringe: BasePart,
}

local PULL_VECTORS: { [TrapConfig.RugPull]: Vector3 } = {
	["+Column"] = Vector3.xAxis,
	["-Column"] = -Vector3.xAxis,
	["+Row"] = Vector3.zAxis,
	["-Row"] = -Vector3.zAxis,
}

local RugTrap = {}

RugTrap.rules = CONFIG :: TrapConfig.TrapRules

local rugs: { [BasePart]: Rug } = {}
local connections: { RBXScriptConnection } = {}

local function cellKey(row: number, column: number): string
	return `{row}:{column}`
end

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Fabric
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function isStanding(cell: Cell): boolean
	local block = cell.block
	return block ~= nil and block.Parent ~= nil and block:GetAttribute(ArenaConstants.IsDestroyedAttribute) ~= true
end

-- A franja some (e não é mais alvo) quando todos os blocos debaixo dela
-- caem.
local function syncFringe(rug: Rug)
	local standing = false
	for _, cell in pairs(rug.cells) do
		if cell.underFringe and isStanding(cell) then
			standing = true
			break
		end
	end
	rug.fringe.Transparency = if standing then 0 else 1
	rug.fringe.CanQuery = standing
end

local function syncCell(rug: Rug, cell: Cell)
	cell.tile.Transparency = if isStanding(cell) then 0 else 1
	if cell.underFringe then
		syncFringe(rug)
	end
end

-- Liga o pedaço do tapete ao bloco atual da célula.
local function bindBlock(rug: Rug, cell: Cell, block: BasePart)
	local previous = cell.connection
	if previous ~= nil then
		previous:Disconnect()
	end
	cell.block = block
	cell.connection = block:GetAttributeChangedSignal(ArenaConstants.IsDestroyedAttribute):Connect(function()
		syncCell(rug, cell)
	end)
	syncCell(rug, cell)
end

local function blockCell(block: Instance): (number?, number?)
	if block:GetAttribute(ArenaConstants.FloorAttribute) ~= CONFIG.Floor then
		return nil, nil
	end
	local row = block:GetAttribute(ArenaConstants.GridRowAttribute)
	local column = block:GetAttribute(ArenaConstants.GridColumnAttribute)
	if typeof(row) ~= "number" or typeof(column) ~= "number" then
		return nil, nil
	end
	return row, column
end

local function buildRug(parent: Instance, index: number, layout: TrapConfig.RugLayout, blocks: { [string]: BasePart })
	local arena = GameConfig.Arena
	local pull = PULL_VECTORS[layout.pull]
	local first = blocks[cellKey(layout.row, layout.column)]
	local last = blocks[cellKey(layout.row + layout.rows - 1, layout.column + layout.columns - 1)]
	if pull == nil or first == nil or last == nil then
		warn(`[BlocoPuff] Rug {index} does not fit the arena grid; skipped`)
		return
	end
	local stepX = arena.BlockSize.X + arena.BlockGap
	local stepZ = arena.BlockSize.Z + arena.BlockGap
	local topY = first.Position.Y + (arena.BlockSize.Y / 2)
	local center = Vector3.new((first.Position.X + last.Position.X) / 2, topY, (first.Position.Z + last.Position.Z) / 2)
	local halfX = (layout.columns * stepX) / 2
	local halfZ = (layout.rows * stepZ) / 2
	local alongX = math.abs(pull.X) > 0.5
	local halfAlong = if alongX then halfX else halfZ
	local halfAcross = if alongX then halfZ else halfX
	local fringeEdge = center + (pull * halfAlong)

	local model = Instance.new("Model")
	model.Name = `Rug{index}`
	model.Parent = parent

	local fringePosition = fringeEdge - (pull * (FRINGE_DEPTH / 2)) + Vector3.new(0, (FRINGE_HEIGHT / 2) + TILE_LIFT, 0)
	local fringe = newPart(
		model,
		"Fringe",
		Vector3.new(halfAcross * 2, FRINGE_HEIGHT, FRINGE_DEPTH),
		CFrame.lookAt(fringePosition, fringePosition + pull),
		CONFIG.FringeColor
	)

	local rug: Rug = {
		center = center,
		pull = pull,
		across = pull:Cross(Vector3.yAxis),
		halfAlong = halfAlong,
		halfAcross = halfAcross,
		topY = topY,
		origin = first.Position,
		row = layout.row,
		column = layout.column,
		stepX = stepX,
		stepZ = stepZ,
		cells = {},
		fringe = fringe,
	}

	for row = layout.row, layout.row + layout.rows - 1 do
		for column = layout.column, layout.column + layout.columns - 1 do
			local center3 = first.Position + Vector3.new((column - layout.column) * stepX, 0, (row - layout.row) * stepZ)
			local position = Vector3.new(center3.X, topY + (TILE_THICKNESS / 2) + TILE_LIFT, center3.Z)
			local shade = if (row + column) % 2 == 0 then layout.color else layout.color:Lerp(Color3.new(0, 0, 0), WEAVE_SHADE)
			local tile = newPart(model, `Tile{row}_{column}`, Vector3.new(stepX, TILE_THICKNESS, stepZ), CFrame.new(position), shade)
			tile:SetAttribute(TrapConstants.RugAlongAttribute, (fringeEdge - position):Dot(pull))
			rug.cells[cellKey(row, column)] = {
				row = row,
				column = column,
				tile = tile,
				block = nil,
				connection = nil,
				underFringe = (fringeEdge - center3):Dot(pull) < (if alongX then stepX else stepZ),
			}
		end
	end
	for key, cell in pairs(rug.cells) do
		local block = blocks[key]
		if block ~= nil then
			bindBlock(rug, cell, block)
		else
			syncCell(rug, cell)
		end
	end

	-- Por último: o cliente começa a desenhar quando a franja ganha a tag,
	-- com os pedaços já no lugar.
	fringe:SetAttribute(TrapConstants.KindAttribute, TrapConstants.Rug)
	fringe:SetAttribute(TrapConstants.IdAttribute, model.Name)
	fringe:SetAttribute(TrapConstants.FloorAttribute, CONFIG.Floor)
	fringe:SetAttribute(TrapConstants.RugPullAttribute, pull)
	rugs[fringe] = rug
	CollectionService:AddTag(fringe, TrapConstants.Tag)
end

-- Um bloco recriado pela arena: religa o pedaço de tapete da célula dele.
local function onBlockAdded(block: Instance)
	if not block:IsA("BasePart") then
		return
	end
	local row, column = blockCell(block)
	if row == nil or column == nil then
		return
	end
	local key = cellKey(row, column)
	for _, rug in pairs(rugs) do
		local cell = rug.cells[key]
		if cell ~= nil and cell.block ~= block then
			bindBlock(rug, cell, block)
		end
	end
end

-- Monta os tapetes do térreo sobre os blocos da arena (depois do
-- ArenaService.create).
function RugTrap.build(parent: Instance)
	local blocks: { [string]: BasePart } = {}
	for _, block in ipairs(ArenaService.getBlocks()) do
		local row, column = blockCell(block)
		if row ~= nil and column ~= nil then
			blocks[cellKey(row, column)] = block
		end
	end
	for index, layout in ipairs(CONFIG.Rugs) do
		buildRug(parent, index, layout, blocks)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(ArenaConstants.BlockTag):Connect(onBlockAdded))
end

-- Desfaz o que `build` ligou (as peças somem com a pasta do TrapService).
function RugTrap.clear()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, rug in pairs(rugs) do
		for _, cell in pairs(rug.cells) do
			local connection = cell.connection
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end
	table.clear(rugs)
end

-- Em cima do tapete, num pedaço com chão embaixo.
local function isOnRug(rug: Rug, position: Vector3): boolean
	local height = position.Y - rug.topY
	if height < 0 or height > CONFIG.StandHeight then
		return false
	end
	local offset = position - rug.center
	if math.abs(offset:Dot(rug.pull)) > rug.halfAlong + EDGE_MARGIN or math.abs(offset:Dot(rug.across)) > rug.halfAcross + EDGE_MARGIN then
		return false
	end
	local fromOrigin = position - rug.origin
	local row = rug.row + math.floor((fromOrigin.Z / rug.stepZ) + 0.5)
	local column = rug.column + math.floor((fromOrigin.X / rug.stepX) + 0.5)
	local cell = rug.cells[cellKey(row, column)]
	return cell ~= nil and isStanding(cell)
end

-- Efeito ao fim do aviso: quem está em cima escorrega para o lado da
-- franja. Devolve quantos escorregaram.
function RugTrap.trigger(fringe: BasePart, shooter: Player, _isCurrent: () -> boolean): number
	local rug = rugs[fringe]
	if rug == nil then
		return 0
	end
	local velocity = rug.pull * GameConfig.Knockback.HorizontalSpeed * CONFIG.SlideMultiplier
	local affected = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= shooter and KnockbackService.isActiveParticipant(player) then
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if root ~= nil and root:IsA("BasePart") and isOnRug(rug, root.Position) and KnockbackService.slide(shooter, player, velocity, CONFIG.SlideDuration) then
				affected += 1
			end
		end
	end
	return affected
end

-- O tapete embolado e esticado é só desenho no cliente (pelo estado): no
-- servidor não há nada a desfazer.
function RugTrap.restore(_fringe: BasePart) end

return table.freeze(RugTrap)
