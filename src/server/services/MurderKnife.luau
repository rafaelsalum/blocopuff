--!strict

-- Faca do Assassino (Fase 5E): a ferramenta (guardada fora da mochila, no
-- servidor, até ele atacar; sacada, todos a veem na mão), o alvo do golpe de perto e a faca
-- arremessada, que voa em linha reta, para na primeira parede ou móvel e
-- atinge o primeiro que encontrar. Tudo simulado no servidor; o modo decide
-- quem pode golpear, as recargas e o que acontece com o alvo.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local MurderRules = require(script.Parent.Parent.data.MurderRules)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

export type Throw = {
	origin: Vector3,
	direction: Vector3,
	-- Peças que param a faca (paredes e móveis da Ala).
	obstacles: Instance,
	targets: () -> { Combatant },
	onHit: (victim: Combatant) -> (),
}

local TOOL_NAME = "Faca"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "MurderKnife"
local HANDLE_COLOR = Color3.fromRGB(70, 44, 30)
local BLADE_COLOR = Color3.fromRGB(150, 160, 176)
local THROWN_SPIN = 18
-- A faca arremessada é maior que a da mão, para dar para ver no ar.
local THROWN_SCALE = 1.8
local TRAIL_COLOR = Color3.fromRGB(255, 90, 90)
local SHEATH_NAME = "MurderKnives"

local MurderKnife = {}

local tools: { [Combatant]: Tool } = {}
local flying: { [Model]: RBXScriptConnection } = {}

-- Faca guardada: fora da mochila, para não aparecer na barra de itens.
local function sheath(): Folder
	local existing = ServerStorage:FindFirstChild(SHEATH_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = SHEATH_NAME
	folder.Parent = ServerStorage
	return folder
end

local function knifeParts(parent: Instance, anchored: boolean, scale: number?): (Part, Part)
	local size = scale or 1
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1) * size
	handle.Color = HANDLE_COLOR
	handle.Material = Enum.Material.Wood
	handle.Anchored = anchored
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = parent
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.1, 0.4, 1.5) * size
	blade.Color = BLADE_COLOR
	blade.Material = Enum.Material.Metal
	blade.Anchored = anchored
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.Massless = true
	-- A lâmina sai da ponta do cabo (−Z).
	blade.CFrame = handle.CFrame * CFrame.new(0, 0.05 * size, -1.25 * size)
	blade.Parent = parent
	if not anchored then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = blade
		weld.Parent = handle
	end
	return handle, blade
end

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	-- Cabo na mão, lâmina para a frente.
	tool.Grip = CFrame.new(0, 0, 0.3)
	tool:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	knifeParts(tool, false)
	return tool
end

-- Entrega a faca guardada (jogador: fora da mochila, o modo saca quando
-- ele ataca; bot: já na mão, só no teste solo do Studio).
function MurderKnife.give(combatant: Combatant)
	MurderKnife.take(combatant)
	local tool = buildTool()
	local player = combatant.player
	if player ~= nil then
		tool.Parent = sheath()
	else
		local humanoid = CombatantRegistry.getHumanoid(combatant)
		if humanoid == nil then
			tool:Destroy()
			return
		end
		tool.Parent = CombatantRegistry.getCharacter(combatant)
		humanoid:EquipTool(tool)
	end
	tools[combatant] = tool
end

function MurderKnife.take(combatant: Combatant)
	local tool = tools[combatant]
	if tool ~= nil then
		tool:Destroy()
		tools[combatant] = nil
	end
end

-- Faca na mão (sacada), visível para todos.
function MurderKnife.isEquipped(combatant: Combatant): boolean
	local tool = tools[combatant]
	local character = CombatantRegistry.getCharacter(combatant)
	return tool ~= nil and character ~= nil and tool.Parent == character
end

-- Saca ou guarda a faca (o modo saca ao atacar e guarda depois de um tempo).
function MurderKnife.setEquipped(combatant: Combatant, equipped: boolean)
	local tool = tools[combatant]
	local humanoid = CombatantRegistry.getHumanoid(combatant)
	-- Faca destruída com o corpo (reset sem eliminação): nada a fazer.
	if tool == nil or tool.Parent == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if equipped then
		humanoid:EquipTool(tool)
	elseif MurderKnife.isEquipped(combatant) then
		tool.Parent = sheath()
	end
end

-- Primeiro alvo ao alcance do golpe: à frente, perto e sem parede no meio.
function MurderKnife.stabTarget(attacker: Combatant, targets: { Combatant }, obstacles: Instance): Combatant?
	local root = CombatantRegistry.getRoot(attacker)
	if root == nil then
		return nil
	end
	local look = root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { obstacles }
	local best: Combatant? = nil
	local bestDistance = math.huge
	for _, target in ipairs(targets) do
		local targetRoot = CombatantRegistry.getRoot(target)
		if target ~= attacker and targetRoot ~= nil then
			local offset = targetRoot.Position - root.Position
			local inReach = math.abs(offset.Y) <= MysteryModeConfig.StabMaxHeight
				and MurderRules.inStabReach(offset.X, offset.Z, look.X, look.Z, MysteryModeConfig.StabRange, MysteryModeConfig.StabConeDegrees)
			if inReach and offset.Magnitude < bestDistance and workspace:Raycast(root.Position, offset, params) == nil then
				best = target
				bestDistance = offset.Magnitude
			end
		end
	end
	return best
end

local function finish(model: Model)
	local connection = flying[model]
	if connection ~= nil then
		connection:Disconnect()
		flying[model] = nil
	end
	model:Destroy()
end

-- Faca arremessada (a direção do cliente vale só no plano; a origem é a
-- posição do corpo no servidor).
function MurderKnife.throw(throw: Throw)
	local direction = Vector3.new(throw.direction.X, 0, throw.direction.Z)
	local length = direction.Magnitude
	if length ~= length or length < 1e-3 or length == math.huge or throw.origin ~= throw.origin then
		return
	end
	direction = direction.Unit
	local model = Instance.new("Model")
	model.Name = "ThrownKnife"
	local handle, blade = knifeParts(model, true, THROWN_SCALE)
	blade.Material = Enum.Material.Neon
	model.PrimaryPart = handle
	-- Rastro vermelho atrás da faca, para quem está perto ver de onde veio.
	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(0, 0.3, 0)
	tail.Parent = handle
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, -0.3, 0)
	tip.Parent = handle
	local trail = Instance.new("Trail")
	trail.Attachment0 = tail
	trail.Attachment1 = tip
	trail.Color = ColorSequence.new(TRAIL_COLOR)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = handle
	model:PivotTo(CFrame.lookAt(throw.origin, throw.origin + direction))
	model.Parent = throw.obstacles

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { throw.obstacles }

	local travelled = 0
	local position = throw.origin
	flying[model] = RunService.Heartbeat:Connect(function(dt: number)
		local step = math.min(MysteryModeConfig.ThrowSpeed * dt, MysteryModeConfig.ThrowRange - travelled)
		local wallHit = workspace:Raycast(position, direction * step, params)
		-- A própria faca está na pasta dos obstáculos: ignora o acerto nela.
		if wallHit ~= nil and wallHit.Instance:IsDescendantOf(model) then
			wallHit = nil
		end
		local reach = if wallHit ~= nil then (wallHit.Position - position).Magnitude else step
		-- Quem estiver no trecho percorrido neste quadro é atingido.
		for _, target in ipairs(throw.targets()) do
			local root = CombatantRegistry.getRoot(target)
			if root ~= nil then
				local offset = root.Position - position
				local along = math.clamp(offset:Dot(direction), 0, reach)
				local gap = root.Position - (position + direction * along)
				if Vector3.new(gap.X, 0, gap.Z).Magnitude <= MysteryModeConfig.ThrowHitRadius and math.abs(gap.Y) <= 4 then
					throw.onHit(target)
					finish(model)
					return
				end
			end
		end
		travelled += step
		position += direction * reach
		if wallHit ~= nil or travelled >= MysteryModeConfig.ThrowRange then
			finish(model)
			return
		end
		model:PivotTo(CFrame.lookAt(position, position + direction) * CFrame.Angles(-travelled * THROWN_SPIN / 10, 0, 0))
	end)
end

-- Fim da partida: some com as facas (na mão, na mochila e no ar).
function MurderKnife.clear()
	for combatant in pairs(tools) do
		MurderKnife.take(combatant)
	end
	for model in pairs(flying) do
		finish(model)
	end
end

return table.freeze(MurderKnife)
