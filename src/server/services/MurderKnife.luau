--!strict

-- Faca do Assassino (Fase 5E): a ferramenta (guardada fora da mochila, no
-- servidor, até ele atacar; sacada, todos a veem na mão), o alvo do golpe de perto e a faca
-- arremessada, que voa em linha reta, para na primeira parede ou móvel e
-- atinge o primeiro que encontrar. Tudo simulado no servidor; o modo decide
-- quem pode golpear, as recargas e o que acontece com o alvo.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local KnifeMesh = require(ReplicatedStorage.Shared.modules.KnifeMesh)
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
-- Tamanho da faca na mão (1 = a malha original, 3 studs).
local HELD_SCALE = 0.55
local THROWN_SPIN = 18
-- A faca arremessada é maior que a da mão, para dar para ver no ar.
local THROWN_SCALE = 0.8
local TRAIL_COLOR = Color3.fromRGB(255, 90, 90)
local SHEATH_NAME = "MurderKnives"
-- Corpo acertável pela faca arremessada: dos pés (3 abaixo da raiz) até o
-- alto da cabeça (2 acima).
local BODY_BELOW_ROOT = 3
local BODY_ABOVE_ROOT = 2
-- A mira do golpe pode se afastar até 110° da frente do corpo.
local AIM_MIN_COSINE = math.cos(math.rad(110))
-- Até onde se ouve a faca (studs) e quanto tempo o som fica no corpo (s).
local SOUND_RANGE = 60
local SOUND_LIFETIME = 3

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

-- Faca 3D (KnifeMesh): uma pega invisível "Handle" (a ferramenta segura
-- por ela; frente -Z) com a malha da faca presa à frente.
local function knifeParts(parent: Instance, anchored: boolean, scale: number): (Part, Part)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.6) * scale
	handle.Transparency = 1
	handle.Anchored = anchored
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = parent
	local knife = KnifeMesh.part("Knife", scale)
	knife.Anchored = anchored
	knife.CFrame = handle.CFrame * KnifeMesh.inHand(scale)
	knife.Parent = parent
	if not anchored then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = knife
		weld.Parent = handle
	end
	return handle, knife
end

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	-- O meio do cabo fica na mão (a pega "Handle" já está nele) e a lâmina
	-- para a frente.
	tool.Grip = CFrame.new()
	tool:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	knifeParts(tool, false, HELD_SCALE)
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
-- `aim` é para onde a mira do jogador aponta (sem ela, a frente do corpo);
-- entre vários ao alcance, vale o mais perto da linha da mira.
function MurderKnife.stabTarget(attacker: Combatant, targets: { Combatant }, obstacles: Instance, aim: Vector3?): Combatant?
	local root = CombatantRegistry.getRoot(attacker)
	if root == nil then
		return nil
	end
	local bodyFront = root.CFrame.LookVector
	local flatAim = if aim ~= nil then Vector3.new(aim.X, 0, aim.Z) else Vector3.zero
	-- A mira vale perto da frente do corpo (em primeira pessoa o corpo gira
	-- com a câmera); fora disso, um cliente alterado golpearia pelas costas.
	local aimUsable = flatAim.Magnitude > 1e-3 and MurderRules.aimCosine(flatAim.X, flatAim.Z, bodyFront.X, bodyFront.Z) >= AIM_MIN_COSINE
	local look = if aimUsable then flatAim.Unit else bodyFront
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { obstacles }
	local best: Combatant? = nil
	local bestCosine = -math.huge
	for _, target in ipairs(targets) do
		local targetRoot = CombatantRegistry.getRoot(target)
		if target ~= attacker and targetRoot ~= nil then
			local offset = targetRoot.Position - root.Position
			local inReach = math.abs(offset.Y) <= MysteryModeConfig.StabMaxHeight
				and MurderRules.inStabReach(offset.X, offset.Z, look.X, look.Z, MysteryModeConfig.StabRange, MysteryModeConfig.StabConeDegrees)
			local cosine = MurderRules.aimCosine(offset.X, offset.Z, look.X, look.Z)
			if inReach and cosine > bestCosine and workspace:Raycast(root.Position, offset, params) == nil then
				best = target
				bestCosine = cosine
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

-- Para onde a faca aponta (de pé ou deitada, para cima ou para baixo).
local function facing(position: Vector3, direction: Vector3): CFrame
	local up = if math.abs(direction.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + direction, up)
end

-- Faca arremessada: segue a mira do cliente em 3D (para cima e para baixo
-- também); a origem é a altura dos olhos do corpo no servidor.
function MurderKnife.throw(throw: Throw)
	local direction = throw.direction
	local length = direction.Magnitude
	if length ~= length or length < 1e-3 or length == math.huge or throw.origin ~= throw.origin then
		return
	end
	direction = direction.Unit
	local model = Instance.new("Model")
	model.Name = "ThrownKnife"
	local handle = knifeParts(model, true, THROWN_SCALE)
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
	model:PivotTo(facing(throw.origin, direction))
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
				local t = root.Position
				if MurderRules.knifeHitsBody(position.X, position.Y, position.Z, direction.X, direction.Y, direction.Z, reach, t.X, t.Y, t.Z, MysteryModeConfig.ThrowHitRadius, BODY_BELOW_ROOT, BODY_ABOVE_ROOT) then
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
		model:PivotTo(facing(position, direction) * CFrame.Angles(-travelled * THROWN_SPIN / 10, 0, 0))
	end)
end

-- Fim da partida: some com as facas (na mão, na mochila e no ar).
-- Som da faca saindo do corpo de `combatant` (quem está por perto ouve).
function MurderKnife.playSound(combatant: Combatant, sound: MysteryModeConfig.KnifeSound)
	local root = CombatantRegistry.getRoot(combatant)
	if root == nil then
		return
	end
	local instance = Instance.new("Sound")
	instance.Name = "KnifeSound"
	instance.SoundId = sound.Id
	instance.Volume = sound.Volume
	instance.PlaybackSpeed = sound.Speed
	instance.RollOffMaxDistance = SOUND_RANGE
	instance.Parent = root
	instance:Play()
	Debris:AddItem(instance, SOUND_LIFETIME)
end

function MurderKnife.clear()
	for combatant in pairs(tools) do
		MurderKnife.take(combatant)
	end
	for model in pairs(flying) do
		finish(model)
	end
end

return table.freeze(MurderKnife)
