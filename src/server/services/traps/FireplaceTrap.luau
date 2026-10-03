--!strict

-- Lareira de Fuligem (Fase 5, entrega 5.5). Fica numa parede externa do
-- térreo (TrapConfig.Fireplace), no trecho que a decoração deixa livre. A
-- boca da lareira é o alvo. Ao fim do aviso, uma nuvem de fuligem fica em
-- frente a ela por alguns segundos: quem estiver dentro espirra ("ATCHIM!"),
-- com um pulinho para longe do centro da nuvem (no máximo um espirro a cada
-- SneezeCooldown por pessoa), e fica com o rosto sujo até o fim da rodada.
-- É a armadilha mais leve: só desequilibra uma briga perto da parede.
--
-- O servidor monta a lareira, aplica os espirros e marca o corpo de quem
-- espirrou (tag TrapSooty e atributo TrapSneezeAt); os clientes desenham
-- brasas, fumaça, a nuvem, o "ATCHIM!", a tela embaçada e o rosto sujo
-- (effects/FireplaceTrapFx e effects/SootFx).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local BuildingDecor = require(script.Parent.Parent.BuildingDecor)
local CombatantRegistry = require(script.Parent.Parent.CombatantRegistry)
local KnockbackService = require(script.Parent.Parent.KnockbackService)
local TrapBlocks = require(script.Parent.TrapBlocks)

type Combatant = CombatantRegistry.Combatant

local CONFIG = TrapConfig.Fireplace
local MOUTH_NAME = "Mouth"
local EMBERS_NAME = "Embers"
-- Medidas da lareira (largura total em CONFIG.Width).
local PILLAR_WIDTH = 1.4
local BODY_DEPTH = 1.6
local OPENING_HEIGHT = 4.8
local LINTEL_HEIGHT = 1
local MANTEL_SIZE = Vector3.new(0, 0.4, 2)
local HEARTH_SIZE = Vector3.new(0, 0.3, 2.4)
local BREAST_DEPTH = 1.1
local MOUTH_DEPTH = 0.6
local SOOT_COLOR = Color3.fromRGB(28, 24, 24)
local EMBER_COLOR = Color3.fromRGB(255, 120, 40)
local LOG_COLOR = Color3.fromRGB(92, 60, 38)
-- Intervalo entre as conferências de quem está na nuvem.
local SWEEP_INTERVAL = 0.1
-- Altura (abaixo e acima do chão) em que a nuvem pega alguém.
local CLOUD_BELOW = 1

local FireplaceTrap = {}

FireplaceTrap.rules = CONFIG :: TrapConfig.TrapRules

local mouths: { [BasePart]: Vector3 } = {}
-- Último espirro de cada um (id do combatente -> os.clock()).
local lastSneeze: { [number]: number } = {}
-- Corpos marcados com fuligem nesta rodada.
local sootyModels: { [Model]: boolean } = {}

local function wallSegment(): BuildingDecor.WallSegment
	local bounds = BuildingLayout.getRoomBounds(GameConfig.Arena, GameConfig.Building)
	local center = Vector3.new(bounds.center.X, 0, bounds.center.Z)
	local origin: Vector3
	local inward: Vector3
	if CONFIG.Wall == "West" then
		origin, inward = center + Vector3.new(-bounds.halfWidth, 0, 0), Vector3.new(1, 0, 0)
	elseif CONFIG.Wall == "North" then
		origin, inward = center + Vector3.new(0, 0, -bounds.halfDepth), Vector3.new(0, 0, 1)
	else
		origin, inward = center + Vector3.new(0, 0, bounds.halfDepth), Vector3.new(0, 0, -1)
	end
	return {
		name = "Fireplace",
		origin = origin,
		inward = inward,
		length = CONFIG.Width,
		bottomY = bounds.bottomY,
		topY = bounds.ceilingY,
	}
end

local function buildModel(parent: Instance, segment: BuildingDecor.WallSegment, floorY: number, storyTop: number): (Model, Part)
	local style = GameConfig.Building
	local brick = { material = Enum.Material.Brick }
	local width = CONFIG.Width
	local offset = CONFIG.Offset
	local model = Instance.new("Model")
	model.Name = "Fireplace"
	model.Parent = parent

	local function at(dx: number, y: number, depth: number): CFrame
		return BuildingDecor.wallCFrame(segment, offset + dx, y, depth)
	end

	BuildingDecor.createPart(model, "Hearth", Vector3.new(width, HEARTH_SIZE.Y, HEARTH_SIZE.Z), at(0, floorY + (HEARTH_SIZE.Y / 2), HEARTH_SIZE.Z / 2), style.BasementBrickColor:Lerp(Color3.new(0, 0, 0), 0.35), {
		material = Enum.Material.Slate,
	})
	local pillarHeight = OPENING_HEIGHT
	for _, side in ipairs({ -1, 1 }) do
		BuildingDecor.createPart(
			model,
			"Pillar",
			Vector3.new(PILLAR_WIDTH, pillarHeight, BODY_DEPTH),
			at(side * ((width - PILLAR_WIDTH) / 2), floorY + (pillarHeight / 2), BODY_DEPTH / 2),
			style.BasementBrickColor,
			brick
		)
	end
	local lintelY = floorY + pillarHeight + (LINTEL_HEIGHT / 2)
	BuildingDecor.createPart(model, "Lintel", Vector3.new(width, LINTEL_HEIGHT, BODY_DEPTH), at(0, lintelY, BODY_DEPTH / 2), style.BasementBrickColor, brick)
	local mantelY = lintelY + (LINTEL_HEIGHT / 2) + (MANTEL_SIZE.Y / 2)
	BuildingDecor.createPart(model, "Mantel", Vector3.new(width + 0.4, MANTEL_SIZE.Y, MANTEL_SIZE.Z), at(0, mantelY, MANTEL_SIZE.Z / 2), style.TrimColor, {
		material = Enum.Material.Wood,
	})
	local breastBottom = mantelY + (MANTEL_SIZE.Y / 2)
	if storyTop - breastBottom > 0.5 then
		BuildingDecor.createPart(
			model,
			"ChimneyBreast",
			Vector3.new(width - (PILLAR_WIDTH * 1.2), storyTop - breastBottom, BREAST_DEPTH),
			at(0, (storyTop + breastBottom) / 2, BREAST_DEPTH / 2),
			style.BasementBrickColor,
			brick
		)
	end

	-- Fundo escuro da boca: o alvo dos tiros (as outras peças não entram em
	-- raycast, então um tiro na frente da lareira chega nele).
	local openingWidth = width - (PILLAR_WIDTH * 2)
	local mouth = BuildingDecor.createPart(
		model,
		MOUTH_NAME,
		Vector3.new(openingWidth, OPENING_HEIGHT, 0.2),
		at(0, floorY + (OPENING_HEIGHT / 2), MOUTH_DEPTH),
		SOOT_COLOR,
		{ material = Enum.Material.Slate }
	)
	mouth.CanQuery = true

	for index, dx in ipairs({ -0.7, 0.7 }) do
		BuildingDecor.createPart(
			model,
			`Log{index}`,
			Vector3.new(openingWidth * 0.55, 0.6, 0.6),
			at(dx * 0.4, floorY + HEARTH_SIZE.Y + 0.35, 1.05) * CFrame.Angles(0, math.rad(dx * 12), 0),
			LOG_COLOR,
			{ material = Enum.Material.Wood, shape = Enum.PartType.Cylinder }
		)
	end
	local embers = BuildingDecor.createPart(
		model,
		EMBERS_NAME,
		Vector3.new(openingWidth * 0.6, 0.35, 0.8),
		at(0, floorY + HEARTH_SIZE.Y + 0.2, 1.05),
		EMBER_COLOR,
		{ material = Enum.Material.Neon }
	)
	local light = Instance.new("PointLight")
	light.Color = EMBER_COLOR
	light.Range = 12
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = embers

	return model, mouth
end

-- Monta a lareira (depois do BuildingService.create).
function FireplaceTrap.build(parent: Instance)
	local arena = GameConfig.Arena
	if CONFIG.Floor >= arena.FloorCount then
		warn("[BlocoPuff] Fireplace must sit below the top floor; skipped")
		return
	end
	local segment = wallSegment()
	local floorY = BuildingLayout.getFloorSurfaceY(arena, CONFIG.Floor)
	local storyTop = BuildingLayout.getFloorY(arena, CONFIG.Floor + 1) - (arena.BlockSize.Y / 2)
	local _, mouth = buildModel(parent, segment, floorY, storyTop)
	local cloud = BuildingDecor.wallCFrame(segment, CONFIG.Offset, floorY, CONFIG.CloudOffset).Position
	mouths[mouth] = cloud

	-- Por último: o cliente começa a desenhar quando a boca ganha a tag.
	mouth:SetAttribute(TrapConstants.KindAttribute, TrapConstants.Fireplace)
	mouth:SetAttribute(TrapConstants.IdAttribute, `Fireplace{CONFIG.Wall}`)
	mouth:SetAttribute(TrapConstants.FloorAttribute, CONFIG.Floor)
	mouth:SetAttribute(TrapConstants.InwardAttribute, segment.inward)
	mouth:SetAttribute(TrapConstants.FireplaceCloudAttribute, cloud)
	CollectionService:AddTag(mouth, TrapConstants.Tag)
end

-- Rosto sujo e espirro (desenhados pelos clientes a partir do corpo).
local function markSneeze(combatant: Combatant)
	local character = CombatantRegistry.getCharacter(combatant)
	if character == nil then
		return
	end
	character:SetAttribute(TrapConstants.SneezeAtAttribute, Workspace:GetServerTimeNow())
	if not sootyModels[character] then
		sootyModels[character] = true
		CollectionService:AddTag(character, TrapConstants.SootTag)
	end
end

local function sneeze(combatant: Combatant, flat: Vector3, inward: Vector3, shooter: Combatant?): boolean
	local knockback = GameConfig.Knockback
	local direction = if flat.Magnitude > 0.1 then flat.Unit else inward
	local velocity = (direction * knockback.HorizontalSpeed * CONFIG.SneezeMultiplier) + Vector3.new(0, knockback.VerticalSpeed * CONFIG.SneezeLift, 0)
	if not KnockbackService.push(shooter, combatant, velocity) then
		return false
	end
	markSneeze(combatant)
	return true
end

-- Quem está na nuvem e pode espirrar agora espirra. Devolve quantos. Quem
-- atirou nunca espirra (como nas outras armadilhas), mesmo se entrar nela.
local function sweep(center: Vector3, inward: Vector3, shooter: Combatant?): number
	local now = os.clock()
	local count = 0
	for _, combatant in ipairs(CombatantRegistry.all()) do
		local root = TrapBlocks.targetRoot(combatant, shooter)
		local last = lastSneeze[combatant.id]
		if root ~= nil and (last == nil or now - last >= CONFIG.SneezeCooldown) then
			local offset = root.Position - center
			local flat = Vector3.new(offset.X, 0, offset.Z)
			-- Só do lado de dentro da parede (atrás dela passa o corredor secreto).
			local inside = offset:Dot(inward) >= -CONFIG.CloudOffset
			if inside and offset.Y >= -CLOUD_BELOW and offset.Y <= CONFIG.CloudHeight and flat.Magnitude <= CONFIG.CloudRadius then
				if sneeze(combatant, flat, inward, shooter) then
					lastSneeze[combatant.id] = now
					count += 1
				end
			end
		end
	end
	return count
end

-- Efeito ao fim do aviso: a nuvem fica CloudDuration segundos. Devolve
-- quantos espirraram logo no começo (telemetria).
function FireplaceTrap.trigger(mouth: BasePart, shooter: Combatant?, isCurrent: () -> boolean): number
	local center = mouths[mouth]
	if center == nil then
		return 0
	end
	local inwardValue = mouth:GetAttribute(TrapConstants.InwardAttribute)
	local inward = if typeof(inwardValue) == "Vector3" then inwardValue else Vector3.zAxis
	local endsAt = os.clock() + CONFIG.CloudDuration
	local first = sweep(center, inward, shooter)
	task.spawn(function()
		while true do
			task.wait(SWEEP_INTERVAL)
			if os.clock() >= endsAt or not isCurrent() then
				return
			end
			-- Quem atirou e saiu do jogo não leva crédito pelos espirros.
			local credit = if shooter ~= nil and CombatantRegistry.isPresent(shooter) then shooter else nil
			local ok, failure = pcall(sweep, center, inward, credit)
			if not ok then
				warn(`[BlocoPuff] Fireplace sneeze failed: {failure}`)
			end
		end
	end)
	return first
end

-- A lareira não muda no servidor entre um uso e outro (brasas e fumaça são
-- do cliente).
function FireplaceTrap.restore(_mouth: BasePart) end

-- Começo e fim de rodada: rostos limpos e espirros liberados.
function FireplaceTrap.roundReset()
	for model in pairs(sootyModels) do
		if model.Parent ~= nil then
			CollectionService:RemoveTag(model, TrapConstants.SootTag)
			model:SetAttribute(TrapConstants.SneezeAtAttribute, nil)
		end
	end
	table.clear(sootyModels)
	table.clear(lastSneeze)
end

function FireplaceTrap.clear()
	FireplaceTrap.roundReset()
	table.clear(mouths)
end

return table.freeze(FireplaceTrap)
