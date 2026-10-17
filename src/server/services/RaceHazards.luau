--!strict

-- Obstáculos da Corrida da Torre do Relógio (Fase 5D.2): o Barão joga do
-- topo barris que rolam rampa abaixo e objetos que caem do alto (caixotes,
-- baús e quadros), sempre com aviso: o barril se vê descendo, e o que cai
-- tem uma sombra no chão antes. Quem é atingido é empurrado rampa abaixo e
-- às vezes cai para a volta de baixo; ninguém é eliminado. O ritmo acelera
-- conforme a corrida passa.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local RaceRules = require(script.Parent.Parent.data.RaceRules)
local TowerBuilder = require(script.Parent.TowerBuilder)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local KnockbackService = require(script.Parent.KnockbackService)

type Combatant = CombatantRegistry.Combatant
type TowerLayout = TowerBuilder.TowerLayout

type Barrel = {
	part: Part,
	t: number,
	roll: number,
}

type DropStyle = {
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
}

local DROP_STYLES: { DropStyle } = {
	{ name = "Crate", size = Vector3.new(5, 5, 5), color = Color3.fromRGB(150, 110, 70), material = Enum.Material.WoodPlanks },
	{ name = "Chest", size = Vector3.new(6, 4, 4), color = Color3.fromRGB(120, 80, 40), material = Enum.Material.Wood },
	{ name = "Portrait", size = Vector3.new(7, 6, 1), color = Color3.fromRGB(200, 160, 70), material = Enum.Material.Wood },
}
local SHADOW_COLOR = Color3.fromRGB(40, 20, 20)
local SHADOW_TRANSPARENCY = 0.35
-- Diferença de altura máxima para o objeto que caiu acertar alguém.
local DROP_HIT_HEIGHT = 6
-- Quanto à frente do corredor (em voltas) o objeto cai.
local DROP_AHEAD_MIN = 0.12
local DROP_AHEAD_MAX = 0.35
local DROP_LINGER = 1.2

local RaceHazards = {}

local random = Random.new()
local running = false
local generation = 0
local layout: TowerLayout? = nil
local getRacers: (() -> { Combatant })? = nil
local barrels: { Barrel } = {}
local heartbeat: RBXScriptConnection? = nil
local spawned: { Instance } = {}

local function hazardsFolder(): Instance?
	local current = layout
	return if current ~= nil then current.folder else nil
end

-- Volta (t) do ponto do caminho mais perto de `position`.
function RaceHazards.turnsAt(tower: TowerLayout, position: Vector3): number
	local bestIndex = 1
	local bestDistance = math.huge
	for index, point in ipairs(tower.path) do
		local distance = (point - position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestIndex = index
		end
	end
	return tower.pathTurns[bestIndex]
end

local function push(tower: TowerLayout, combatant: Combatant, t: number)
	local root = CombatantRegistry.getRoot(combatant)
	if root == nil then
		return
	end
	local hazards = RaceConfig.Hazards
	local tangent = tower.tangentAt(t)
	local downhill = -Vector3.new(tangent.X, 0, tangent.Z).Unit
	local away = Vector3.new(root.Position.X - tower.center.X, 0, root.Position.Z - tower.center.Z)
	local outward = if away.Magnitude > 1e-3 then away.Unit else Vector3.zero
	local velocity = downhill * hazards.PushDownhill + outward * hazards.PushOutward + Vector3.new(0, hazards.PushVertical, 0)
	if KnockbackService.push(nil, combatant, velocity) then
		KnockbackService.protect(combatant, hazards.HitProtection)
	end
end

local function racers(): { Combatant }
	local provider = getRacers
	return if provider ~= nil then provider() else {}
end

local function barrelCFrame(tower: TowerLayout, barrel: Barrel): CFrame
	local position = tower.pointAt(barrel.t) + Vector3.new(0, RaceConfig.Hazards.BarrelRadius, 0)
	local tangent = tower.tangentAt(barrel.t)
	-- O eixo do cilindro (X) fica atravessado na rampa; o barril gira nele.
	return CFrame.lookAt(position, position - tangent) * CFrame.Angles(barrel.roll, 0, 0)
end

local function spawnBarrel(tower: TowerLayout)
	local hazards = RaceConfig.Hazards
	local folder = hazardsFolder()
	if folder == nil then
		return
	end
	local barrelPart = Instance.new("Part")
	barrelPart.Name = "Barrel"
	barrelPart.Shape = Enum.PartType.Cylinder
	barrelPart.Size = Vector3.new(4, hazards.BarrelRadius * 2, hazards.BarrelRadius * 2)
	barrelPart.Color = Color3.fromRGB(122, 78, 44)
	barrelPart.Material = Enum.Material.Wood
	barrelPart.Anchored = true
	barrelPart.CanCollide = false
	barrelPart.CastShadow = false
	local barrel: Barrel = { part = barrelPart, t = tower.spiral.turns, roll = 0 }
	barrelPart.CFrame = barrelCFrame(tower, barrel)
	barrelPart.Parent = folder
	table.insert(barrels, barrel)
	table.insert(spawned, barrelPart)
end

local function stepBarrels(dt: number)
	local tower = layout
	if tower == nil then
		return
	end
	local hazards = RaceConfig.Hazards
	local current = racers()
	for index = #barrels, 1, -1 do
		local barrel = barrels[index]
		barrel.t -= dt / hazards.BarrelSecondsPerTurn
		barrel.roll += dt * 6
		if barrel.t <= 0 then
			barrel.part:Destroy()
			table.remove(barrels, index)
			continue
		end
		local cframe = barrelCFrame(tower, barrel)
		barrel.part.CFrame = cframe
		for _, combatant in ipairs(current) do
			local root = CombatantRegistry.getRoot(combatant)
			if root ~= nil then
				local offset = root.Position - cframe.Position
				local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if RaceRules.barrelHits(horizontal, offset.Y, hazards.BarrelHitRadius, hazards.BarrelRadius, hazards.BarrelClearHeight) then
					push(tower, combatant, barrel.t)
				end
			end
		end
	end
end

local function fadeAndDestroy(instance: BasePart, delay: number)
	task.delay(delay, function()
		if instance.Parent == nil then
			return
		end
		local tween = TweenService:Create(instance, TweenInfo.new(0.4), { Transparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		instance:Destroy()
	end)
end

local function dropObject(tower: TowerLayout, current: number)
	local hazards = RaceConfig.Hazards
	local folder = hazardsFolder()
	local candidates = racers()
	if folder == nil or #candidates == 0 then
		return
	end
	local target = candidates[random:NextInteger(1, #candidates)]
	local root = CombatantRegistry.getRoot(target)
	if root == nil then
		return
	end
	local t = math.min(RaceHazards.turnsAt(tower, root.Position) + random:NextNumber(DROP_AHEAD_MIN, DROP_AHEAD_MAX), tower.spiral.turns - 0.05)
	local spot = tower.pointAt(t)

	local shadow = Instance.new("Part")
	shadow.Name = "DropShadow"
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Size = Vector3.new(0.2, hazards.DropHitRadius * 2, hazards.DropHitRadius * 2)
	shadow.CFrame = CFrame.new(spot + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	shadow.Color = SHADOW_COLOR
	shadow.Material = Enum.Material.Neon
	shadow.Transparency = SHADOW_TRANSPARENCY
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanQuery = false
	shadow.CastShadow = false
	shadow.Parent = folder
	table.insert(spawned, shadow)

	task.delay(hazards.DropWarning, function()
		if not running or generation ~= current then
			return
		end
		local style = DROP_STYLES[random:NextInteger(1, #DROP_STYLES)]
		local object = Instance.new("Part")
		object.Name = style.name
		object.Size = style.size
		object.Color = style.color
		object.Material = style.material
		object.Anchored = true
		object.CanCollide = false
		object.CastShadow = false
		local landing = CFrame.new(spot + Vector3.new(0, style.size.Y / 2, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
		object.CFrame = landing + Vector3.new(0, hazards.DropHeight, 0)
		object.Parent = folder
		table.insert(spawned, object)
		local fall = TweenService:Create(object, TweenInfo.new(hazards.DropFallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = landing })
		fall:Play()
		fall.Completed:Wait()
		shadow:Destroy()
		if not running or generation ~= current then
			return
		end
		for _, combatant in ipairs(racers()) do
			local victimRoot = CombatantRegistry.getRoot(combatant)
			if victimRoot ~= nil then
				local offset = victimRoot.Position - spot
				local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if horizontal <= hazards.DropHitRadius and math.abs(offset.Y) <= DROP_HIT_HEIGHT then
					push(tower, combatant, t)
				end
			end
		end
		fadeAndDestroy(object, DROP_LINGER)
	end)
end

-- Liga os obstáculos. `provider` devolve quem ainda está correndo (sem quem
-- já chegou ao topo).
function RaceHazards.start(tower: TowerLayout, provider: () -> { Combatant }, duration: number)
	RaceHazards.stop()
	running = true
	generation += 1
	local current = generation
	layout = tower
	getRacers = provider
	heartbeat = RunService.Heartbeat:Connect(stepBarrels)
	local hazards = RaceConfig.Hazards
	task.spawn(function()
		local startedAt = os.clock()
		-- Um respiro na largada antes do primeiro obstáculo.
		task.wait(hazards.SlowInterval)
		while running and generation == current do
			if random:NextNumber() < hazards.BarrelChance then
				spawnBarrel(tower)
			else
				dropObject(tower, current)
			end
			local progress = if duration > 0 then (os.clock() - startedAt) / duration else 1
			task.wait(RaceRules.hazardInterval(progress, hazards.SlowInterval, hazards.FastInterval))
		end
	end)
end

-- Posições dos barris descendo (os bots pulam quando um chega perto).
function RaceHazards.barrelPositions(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, barrel in ipairs(barrels) do
		table.insert(positions, barrel.part.Position)
	end
	return positions
end

function RaceHazards.stop()
	running = false
	generation += 1
	if heartbeat ~= nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for _, instance in ipairs(spawned) do
		instance:Destroy()
	end
	table.clear(spawned)
	table.clear(barrels)
	layout = nil
	getRacers = nil
end

return table.freeze(RaceHazards)
