--!strict

-- Partes comuns às armadilhas que mexem com os blocos e com quem está
-- perto (Fase 5): quem pode ser atingido e os blocos que piscam e caem,
-- com a queda de quem estava em cima creditada a quem acionou.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local ArenaService = require(script.Parent.Parent.ArenaService)
local KnockbackService = require(script.Parent.Parent.KnockbackService)
local CombatantRegistry = require(script.Parent.Parent.CombatantRegistry)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)

type Combatant = CombatantRegistry.Combatant

-- Folga ao conferir quem está em cima de um bloco que vai cair.
local STANDING_MARGIN = 0.5
local STANDING_HEIGHT = 6

local TrapBlocks = {}

-- Corpo de quem pode ser atingido (participante vivo que não é quem
-- acionou).
function TrapBlocks.targetRoot(combatant: Combatant, shooter: Combatant?): BasePart?
	if combatant == shooter or not KnockbackService.isActiveParticipant(combatant) then
		return nil
	end
	return CombatantRegistry.getRoot(combatant)
end

function TrapBlocks.isStandingOn(block: Part, position: Vector3): boolean
	local half = block.Size / 2
	local offset = position - block.Position
	return math.abs(offset.X) <= half.X + STANDING_MARGIN
		and math.abs(offset.Z) <= half.Z + STANDING_MARGIN
		and offset.Y > 0
		and offset.Y < half.Y + STANDING_HEIGHT
end

-- Blocos inteiros do andar `floor` com o centro a até `radius` studs (na
-- horizontal) de `center`.
function TrapBlocks.intactNear(floor: number, center: Vector3, radius: number): { Part }
	local blocks: { Part } = {}
	for _, block in ipairs(ArenaService.getIntactBlocks()) do
		if block:GetAttribute(ArenaConstants.FloorAttribute) == floor then
			local offset = block.Position - center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
				table.insert(blocks, block)
			end
		end
	end
	return blocks
end

-- Os blocos piscam por `delay` segundos e caem; quem estiver em cima na
-- hora cai por causa de `shooter` (nil: ninguém leva o crédito).
function TrapBlocks.drop(blocks: { Part }, shooter: Combatant?, delay: number, isCurrent: () -> boolean)
	if #blocks == 0 then
		return
	end
	for _, block in ipairs(blocks) do
		ArenaService.setCollapseWarning(block, true)
	end
	task.delay(delay, function()
		if not isCurrent() then
			for _, block in ipairs(blocks) do
				ArenaService.setCollapseWarning(block, false)
			end
			return
		end
		-- Quem está em cima de cada bloco, antes de ele cair.
		local standing: { [Part]: { Combatant } } = {}
		for _, combatant in ipairs(CombatantRegistry.all()) do
			local root = TrapBlocks.targetRoot(combatant, shooter)
			if root ~= nil then
				for _, block in ipairs(blocks) do
					if TrapBlocks.isStandingOn(block, root.Position) then
						local list = standing[block] or {}
						table.insert(list, combatant)
						standing[block] = list
						break
					end
				end
			end
		end
		for _, block in ipairs(blocks) do
			-- Só leva o crédito quem estava em cima de um bloco que caiu mesmo.
			if ArenaService.collapseBlock(block, shooter) and shooter ~= nil then
				for _, victim in ipairs(standing[block] or {}) do
					KnockbackService.markAttacker(victim, shooter)
				end
			end
		end
	end)
end

-- Empurrão de impacto para longe de `center` (na horizontal), para quem
-- estiver a até `radius` studs e entre `below` e `above` studs de altura em
-- relação a `center`. Devolve quantos foram empurrados.
function TrapBlocks.pushAway(center: Vector3, radius: number, below: number, above: number, multiplier: number, lift: number, shooter: Combatant?): number
	local knockback = GameConfig.Knockback
	local random = Random.new()
	local affected = 0
	for _, combatant in ipairs(CombatantRegistry.all()) do
		local root = TrapBlocks.targetRoot(combatant, shooter)
		if root ~= nil then
			local offset = root.Position - center
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if offset.Y >= -below and offset.Y <= above and flat.Magnitude <= radius then
				local angle = random:NextNumber(0, math.pi * 2)
				local direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(math.cos(angle), 0, math.sin(angle))
				local velocity = (direction * knockback.HorizontalSpeed * multiplier) + Vector3.new(0, knockback.VerticalSpeed * lift, 0)
				if KnockbackService.push(shooter, combatant, velocity) then
					affected += 1
				end
			end
		end
	end
	return affected
end

return table.freeze(TrapBlocks)
