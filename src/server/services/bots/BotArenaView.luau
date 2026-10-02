--!strict

-- O que os bots RoboPuff enxergam da arena a cada decisão (Fase 5B): a
-- grade (BotGrid), os blocos inteiros, os que estão piscando antes de cair
-- e a área das armadilhas em aviso. Só lê o que qualquer jogador vê.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local BotGrid = require(script.Parent.Parent.Parent.data.BotGrid)
local ArenaService = require(script.Parent.Parent.ArenaService)

export type View = {
	grid: BotGrid.Grid,
	intact: { [number]: boolean },
	-- Células perigosas: piscando antes de cair ou perto de armadilha em aviso.
	danger: { [number]: boolean },
	-- Altura do topo dos blocos de cada andar.
	floorTops: { [number]: number },
}

-- Quão perto (studs, na horizontal) de uma armadilha em aviso é perigoso.
local TRAP_DANGER_RADIUS = 12

local BotArenaView = {}

local cachedGrid: BotGrid.Grid? = nil
local cachedTops: { [number]: number } = {}

local function readNumber(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

-- A grade não muda durante o jogo: calcula uma vez a partir dos blocos.
local function buildGrid(): BotGrid.Grid?
	local arena = GameConfig.Arena
	local step = arena.BlockSize.X + arena.BlockGap
	local grid: BotGrid.Grid? = nil
	for _, block in ipairs(ArenaService.getBlocks()) do
		local row = readNumber(block, ArenaConstants.GridRowAttribute)
		local column = readNumber(block, ArenaConstants.GridColumnAttribute)
		local floor = readNumber(block, ArenaConstants.FloorAttribute)
		if row ~= nil and column ~= nil and floor ~= nil then
			cachedTops[floor] = block.Position.Y + (block.Size.Y / 2)
			if grid == nil then
				grid = {
					originX = block.Position.X - ((column - 1) * step),
					originZ = block.Position.Z - ((row - 1) * step),
					step = step,
					rows = arena.Rows,
					columns = arena.Columns,
				}
			end
		end
	end
	return grid
end

local function markTrapDanger(view: View)
	for _, part in ipairs(CollectionService:GetTagged(TrapConstants.Tag)) do
		if part:IsA("BasePart") and part:GetAttribute(TrapConstants.StateAttribute) == TrapConstants.Warning then
			local trapFloor = readNumber(part, TrapConstants.FloorAttribute)
			for floor in pairs(view.floorTops) do
				if trapFloor ~= nil and trapFloor ~= floor then
					continue
				end
				local row, column = BotGrid.cellOf(view.grid, part.Position.X, part.Position.Z)
				local reach = math.ceil(TRAP_DANGER_RADIUS / view.grid.step)
				for dr = -reach, reach do
					for dc = -reach, reach do
						view.danger[BotGrid.key(floor, row + dr, column + dc)] = true
					end
				end
			end
		end
	end
end

-- Fotografia da arena agora. nil antes de a arena existir.
function BotArenaView.capture(): View?
	local grid = cachedGrid
	if grid == nil then
		grid = buildGrid()
		cachedGrid = grid
	end
	if grid == nil then
		return nil
	end
	local view: View = { grid = grid, intact = {}, danger = {}, floorTops = cachedTops }
	for _, block in ipairs(ArenaService.getIntactBlocks()) do
		local row = readNumber(block, ArenaConstants.GridRowAttribute)
		local column = readNumber(block, ArenaConstants.GridColumnAttribute)
		local floor = readNumber(block, ArenaConstants.FloorAttribute)
		if row ~= nil and column ~= nil and floor ~= nil then
			local cellKey = BotGrid.key(floor, row, column)
			view.intact[cellKey] = true
			if block:GetAttribute(ArenaConstants.CollapseWarningAttribute) == true then
				view.danger[cellKey] = true
			end
		end
	end
	markTrapDanger(view)
	return view
end

-- Andar em que está quem tem o centro do corpo em `y` (o topo mais alto
-- abaixo dele). nil se estiver abaixo de todos (caindo para fora).
function BotArenaView.floorAt(view: View, y: number): number?
	local best: number? = nil
	local bestTop = -math.huge
	for floor, top in pairs(view.floorTops) do
		if top <= y + 0.5 and top > bestTop then
			best = floor
			bestTop = top
		end
	end
	return best
end

return table.freeze(BotArenaView)
