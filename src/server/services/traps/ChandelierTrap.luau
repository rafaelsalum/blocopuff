--!strict

-- Lustre Despencando (Fase 5, entrega 5.4). Cada lustre fica pendurado
-- embaixo de um bloco do andar de cima (o bloco de apoio), sobre o térreo:
-- florão no teto, corrente e o lustre bem acima da cabeça de quem joga.
-- Cai de dois jeitos, sempre com o mesmo aviso:
--   * um tiro de longe na corrente ou no lustre (quem atirou leva o
--     crédito das derrubadas);
--   * o bloco de apoio caindo (tiro de quem está no andar de cima, que leva
--     o crédito, ou o Caos Final, sem crédito) — TrapService.dependentOn.
-- Na queda, empurra para fora do círculo quem estava embaixo, e os blocos
-- do chão bem embaixo (uma cruz de 5) piscam e caem, abrindo um buraco.
-- Cai uma vez por rodada. O cliente (effects/ChandelierTrapFx) desenha o
-- balanço, as faíscas, a sombra no chão, a queda e os cacos.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local ArenaService = require(script.Parent.Parent.ArenaService)
local BuildingDecor = require(script.Parent.Parent.BuildingDecor)
local CombatantRegistry = require(script.Parent.Parent.CombatantRegistry)
local TrapBlocks = require(script.Parent.TrapBlocks)

type Combatant = CombatantRegistry.Combatant

local CONFIG = TrapConfig.Chandelier
local ROSETTE_SIZE = Vector3.new(0.4, 2.6, 2.6)
-- A caixa de acerto vai do teto até um pouco abaixo do lustre e é um pouco
-- mais larga que ele (mais fácil de acertar no celular).
local HITBOX_MARGIN = 0.6
local HITBOX_BELOW = 0.8
local LIGHT_RANGE = 22
local LIGHT_BRIGHTNESS = 1.4
-- Altura (acima e abaixo do chão) em que o impacto pega alguém.
local IMPACT_BELOW = 1
local IMPACT_ABOVE = 8
local MIN_DROP = 2

type Chandelier = {
	model: Model,
	hitbox: BasePart,
	row: number,
	column: number,
	-- Ponto do chão do térreo onde ele cai.
	impact: Vector3,
}

local ChandelierTrap = {}

ChandelierTrap.rules = CONFIG :: TrapConfig.TrapRules

local chandeliers: { [BasePart]: Chandelier } = {}
-- Pela célula do bloco de apoio (no andar de cima).
local bySupport: { [string]: Chandelier } = {}
local originalTransparency: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any

local function cellKey(row: number, column: number): string
	return `{row}:{column}`
end

local function blockAt(floor: number, row: number, column: number): Part?
	for _, block in ipairs(ArenaService.getBlocks()) do
		if
			block:GetAttribute(ArenaConstants.FloorAttribute) == floor
			and block:GetAttribute(ArenaConstants.GridRowAttribute) == row
			and block:GetAttribute(ArenaConstants.GridColumnAttribute) == column
		then
			return block
		end
	end
	return nil
end

local function isSupportStanding(chandelier: Chandelier): boolean
	local support = blockAt(CONFIG.Floor + 1, chandelier.row, chandelier.column)
	return support ~= nil and support:GetAttribute(ArenaConstants.IsDestroyedAttribute) ~= true
end

-- Lustre pendurado (visível, aceso e acertável) ou caído (sumido).
local function setFallen(chandelier: Chandelier, fallen: boolean)
	for _, descendant in ipairs(chandelier.model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= chandelier.hitbox then
			local original = originalTransparency[descendant]
			if original == nil then
				original = descendant.Transparency
				originalTransparency[descendant] = original
			end
			descendant.Transparency = if fallen then 1 else original
		elseif descendant:IsA("Light") then
			descendant.Enabled = not fallen
		end
	end
	chandelier.hitbox.CanQuery = not fallen
end

local function buildChandelier(parent: Instance, index: number, spot: TrapConfig.ChandelierSpot)
	local arena = GameConfig.Arena
	local style = GameConfig.Building
	local floorBlock = blockAt(CONFIG.Floor, spot.row, spot.column)
	local support = blockAt(CONFIG.Floor + 1, spot.row, spot.column)
	if floorBlock == nil or support == nil then
		warn(`[BlocoPuff] Chandelier {index} does not fit the arena grid; skipped`)
		return
	end
	local floorTopY = floorBlock.Position.Y + (arena.BlockSize.Y / 2)
	local ceilingY = support.Position.Y - (arena.BlockSize.Y / 2)
	local bodyY = floorTopY + CONFIG.HangHeight
	local drop = ceilingY - bodyY
	if drop < MIN_DROP then
		warn(`[BlocoPuff] Chandelier {index} has no room below the ceiling; skipped`)
		return
	end
	local anchor = Vector3.new(floorBlock.Position.X, ceilingY, floorBlock.Position.Z)

	local model = Instance.new("Model")
	model.Name = `Chandelier{index}`
	model.Parent = parent
	BuildingDecor.createPart(
		model,
		"Rosette",
		ROSETTE_SIZE,
		CFrame.new(anchor - Vector3.new(0, ROSETTE_SIZE.X / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		style.BrassColor,
		{ material = Enum.Material.Metal, shape = Enum.PartType.Cylinder }
	)
	BuildingDecor.createChandelier(model, "Lustre", anchor, drop, CONFIG.Radius, style, LIGHT_RANGE, LIGHT_BRIGHTNESS, false)

	local hitboxBottom = bodyY - HITBOX_BELOW
	local width = (CONFIG.Radius * 2) + HITBOX_MARGIN
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.CastShadow = false
	hitbox.Transparency = 1
	hitbox.Size = Vector3.new(width, ceilingY - hitboxBottom, width)
	hitbox.CFrame = CFrame.new(anchor.X, (ceilingY + hitboxBottom) / 2, anchor.Z)
	hitbox.Parent = model

	local chandelier: Chandelier = {
		model = model,
		hitbox = hitbox,
		row = spot.row,
		column = spot.column,
		impact = Vector3.new(anchor.X, floorTopY, anchor.Z),
	}
	chandeliers[hitbox] = chandelier
	bySupport[cellKey(spot.row, spot.column)] = chandelier

	-- Por último: o cliente começa a desenhar quando a caixa ganha a tag.
	hitbox:SetAttribute(TrapConstants.KindAttribute, TrapConstants.Chandelier)
	hitbox:SetAttribute(TrapConstants.IdAttribute, model.Name)
	hitbox:SetAttribute(TrapConstants.FloorAttribute, CONFIG.Floor)
	hitbox:SetAttribute(TrapConstants.ChandelierAnchorAttribute, anchor)
	hitbox:SetAttribute(TrapConstants.ChandelierImpactAttribute, chandelier.impact)
	CollectionService:AddTag(hitbox, TrapConstants.Tag)
end

-- Pendura os lustres do térreo embaixo dos blocos de apoio (depois do
-- ArenaService.create).
function ChandelierTrap.build(parent: Instance)
	for index, spot in ipairs(CONFIG.Spots) do
		buildChandelier(parent, index, spot)
	end
end

function ChandelierTrap.clear()
	table.clear(chandeliers)
	table.clear(bySupport)
end

-- A armadilha que depende de `block` (o lustre pendurado nele), se houver.
function ChandelierTrap.dependentOn(block: Part): BasePart?
	if block:GetAttribute(ArenaConstants.FloorAttribute) ~= CONFIG.Floor + 1 then
		return nil
	end
	local row = block:GetAttribute(ArenaConstants.GridRowAttribute)
	local column = block:GetAttribute(ArenaConstants.GridColumnAttribute)
	if typeof(row) ~= "number" or typeof(column) ~= "number" then
		return nil
	end
	local chandelier = bySupport[cellKey(row, column)]
	return if chandelier ~= nil then chandelier.hitbox else nil
end

-- Efeito ao fim do aviso (o lustre acabou de chegar ao chão). Devolve
-- quantos foram empurrados.
function ChandelierTrap.trigger(hitbox: BasePart, shooter: Combatant?, isCurrent: () -> boolean): number
	local chandelier = chandeliers[hitbox]
	if chandelier == nil then
		return 0
	end
	setFallen(chandelier, true)
	local affected = TrapBlocks.pushAway(
		chandelier.impact,
		CONFIG.ImpactRadius,
		IMPACT_BELOW,
		IMPACT_ABOVE,
		CONFIG.ImpactMultiplier,
		CONFIG.ImpactLift,
		shooter
	)
	TrapBlocks.drop(TrapBlocks.intactNear(CONFIG.Floor, chandelier.impact, CONFIG.HoleRadius), shooter, CONFIG.HoleDelay, isCurrent)
	return affected
end

-- Pendurado de novo, se o bloco de apoio estiver de pé (entre rodadas ele
-- pode continuar caído até a arena ser restaurada no começo da próxima).
function ChandelierTrap.restore(hitbox: BasePart)
	local chandelier = chandeliers[hitbox]
	if chandelier ~= nil then
		setFallen(chandelier, not isSupportStanding(chandelier))
	end
end

return table.freeze(ChandelierTrap)
