--!strict

-- Janela Ventania (Fase 5, entrega 5.2). Ao fim do aviso, o vidro estoura,
-- uma rajada entra num cone para dentro da arena (forte perto da janela,
-- fraca no fim do cone) e os blocos encostados na parede, debaixo da
-- janela, piscam e caem. Depois a janela fica aberta e, no fim da recarga,
-- é pregada com tábuas. Quem atirou nunca é empurrado; quedas contam como
-- derrubada dele (KnockbackService).
--
-- O servidor só muda o que importa para todos (vidro, tábuas, blocos e
-- empurrões); o TrapVisualController desenha trincas, cortinas, confete de
-- vidro e vento a partir dos atributos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local ArenaService = require(script.Parent.Parent.ArenaService)
local KnockbackService = require(script.Parent.Parent.KnockbackService)
local CombatantRegistry = require(script.Parent.Parent.CombatantRegistry)
local TrapBlocks = require(script.Parent.TrapBlocks)

type Combatant = CombatantRegistry.Combatant

local CONFIG = TrapConfig.Window
local MULLION_NAMES = { "MullionV", "MullionH" }

type Frame = {
	-- Ponto no piso, junto da parede, bem embaixo da janela.
	base: Vector3,
	inward: Vector3,
	along: Vector3,
	floor: number,
}

local WindowTrap = {}

WindowTrap.rules = CONFIG :: TrapConfig.TrapRules

-- Transparência original de cada peça que some quando a janela quebra.
local originalTransparency: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any

local function setHidden(part: BasePart, hidden: boolean)
	local original = originalTransparency[part]
	if original == nil then
		original = part.Transparency
		originalTransparency[part] = original
	end
	part.Transparency = if hidden then 1 else original
end

local function windowParts(glass: BasePart, names: { string }): { BasePart }
	local parts: { BasePart } = {}
	local model = glass.Parent
	if model == nil then
		return parts
	end
	for _, name in ipairs(names) do
		local part = model:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	return parts
end

local function boards(glass: BasePart): { BasePart }
	local parts: { BasePart } = {}
	local model = glass.Parent
	if model == nil then
		return parts
	end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #TrapConstants.WindowBoardPrefix) == TrapConstants.WindowBoardPrefix then
			table.insert(parts, child)
		end
	end
	return parts
end

-- Vidro (e travessas) visível e acertável, ou quebrado e vazado.
local function setBroken(glass: BasePart, broken: boolean)
	setHidden(glass, broken)
	glass.CanQuery = not broken
	for _, part in ipairs(windowParts(glass, MULLION_NAMES)) do
		setHidden(part, broken)
	end
end

local function setBoarded(glass: BasePart, boarded: boolean)
	for _, board in ipairs(boards(glass)) do
		board.Transparency = if boarded then 0 else 1
	end
end

local function frameOf(glass: BasePart): Frame?
	local floor = glass:GetAttribute(TrapConstants.FloorAttribute)
	local inwardValue = glass:GetAttribute(TrapConstants.InwardAttribute)
	if typeof(floor) ~= "number" or typeof(inwardValue) ~= "Vector3" then
		return nil
	end
	local flat = Vector3.new(inwardValue.X, 0, inwardValue.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	local inward = flat.Unit
	local floorY = BuildingLayout.getFloorSurfaceY(GameConfig.Arena, floor)
	return {
		base = Vector3.new(glass.Position.X, floorY, glass.Position.Z),
		inward = inward,
		along = inward:Cross(Vector3.yAxis),
		floor = floor,
	}
end

-- Força da rajada em `position` (múltiplo do empurrão do disparo; 0 = fora
-- do cone) e o lado em que a pessoa está (-1 a 1, para abrir o vento).
local function gustAt(frame: Frame, position: Vector3): (number, number)
	local offset = position - frame.base
	if offset.Y < -1 or offset.Y > CONFIG.ConeHeight then
		return 0, 0
	end
	local depth = offset:Dot(frame.inward)
	if depth < 0 or depth > CONFIG.ConeLength then
		return 0, 0
	end
	local halfWidth = CONFIG.ConeBaseHalfWidth + (depth * math.tan(math.rad(CONFIG.ConeHalfAngle)))
	local lateral = offset:Dot(frame.along)
	if math.abs(lateral) > halfWidth then
		return 0, 0
	end
	local progress = depth / CONFIG.ConeLength
	local strength = CONFIG.NearMultiplier + ((CONFIG.FarMultiplier - CONFIG.NearMultiplier) * progress)
	return strength, lateral / halfWidth
end

local function pushPlayers(frame: Frame, shooter: Combatant?): number
	local knockback = GameConfig.Knockback
	local affected = 0
	for _, combatant in ipairs(CombatantRegistry.all()) do
		local root = TrapBlocks.targetRoot(combatant, shooter)
		if root ~= nil then
			local strength, side = gustAt(frame, root.Position)
			if strength > 0 then
				local direction = (frame.inward + (frame.along * side * CONFIG.Spread)).Unit
				local velocity = (direction * knockback.HorizontalSpeed * strength)
					+ Vector3.new(0, knockback.VerticalSpeed * strength * CONFIG.LiftFactor, 0)
				if KnockbackService.push(shooter, combatant, velocity) then
					affected += 1
				end
			end
		end
	end
	return affected
end

-- Blocos inteiros da fileira encostada na parede, debaixo da janela.
local function looseBlocks(frame: Frame): { Part }
	local rowDepth = GameConfig.Arena.BlockSize.X
	local blocks: { Part } = {}
	for _, block in ipairs(ArenaService.getIntactBlocks()) do
		if block:GetAttribute(ArenaConstants.FloorAttribute) == frame.floor then
			local offset = block.Position - frame.base
			local depth = offset:Dot(frame.inward)
			if depth >= 0 and depth <= rowDepth and math.abs(offset:Dot(frame.along)) <= CONFIG.LooseBlocksAlong then
				table.insert(blocks, block)
			end
		end
	end
	return blocks
end

-- Efeito ao fim do aviso. Devolve quantos jogadores a rajada empurrou.
function WindowTrap.trigger(glass: BasePart, shooter: Combatant?, isCurrent: () -> boolean): number
	setBroken(glass, true)
	task.delay(CONFIG.RechargeTime * (1 - CONFIG.BoardedFraction), function()
		if isCurrent() then
			setBoarded(glass, true)
		end
	end)
	local frame = frameOf(glass)
	if frame == nil then
		warn(`[BlocoPuff] Window trap {glass:GetFullName()} has no floor/inward attributes`)
		return 0
	end
	local affected = pushPlayers(frame, shooter)
	TrapBlocks.drop(looseBlocks(frame), shooter, CONFIG.LooseBlockDelay, isCurrent)
	return affected
end

-- Vidro inteiro, sem tábuas.
function WindowTrap.restore(glass: BasePart)
	setBoarded(glass, false)
	setBroken(glass, false)
end

return table.freeze(WindowTrap)
