--!strict

-- Desenho do Lustre Despencando num cliente (Fase 5, 5.4). Lê os atributos
-- da caixa de acerto (TrapConstants) e mexe no lustre só neste cliente:
--   * pendurado e pronto: brilho leve;
--   * tiro de perto: balança um pouco e tilinta;
--   * aviso: balança cada vez mais, solta faíscas do florão e uma sombra
--     cresce no chão; no fim do aviso ele cai (o servidor aplica o impacto
--     no instante em que ele chega ao chão, pelo relógio do servidor);
--   * impacto: cacos dourados, poeira e pedaços que afundam no buraco.
-- O lustre some e volta pelo servidor (vale para todos, mesmo quem chega
-- depois).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local TrapFxUtil = require(script.Parent.TrapFxUtil)

local CONFIG = TrapConfig.Chandelier
local GOLD = Color3.fromRGB(255, 214, 120)
local GLASS = Color3.fromRGB(230, 245, 255)
local DUST = Color3.fromRGB(210, 200, 185)
local SHADOW_COLOR = Color3.fromRGB(20, 15, 25)
local ROSETTE_NAME = "Rosette"
local SWING_MAX = math.rad(14)
local SWING_SPEED = 9
local SWING_RAMP = 0.3
local CRACK_SWING = math.rad(4)
local CRACK_TIME = 0.6
local SHADOW_START = 0.75
local SHADOW_END = 0.4
local SHADOW_THICKNESS = 0.05
local SHADOW_LIFT = 0.07
local REPLAY_WINDOW = 1
local DEBRIS_COUNT = 6
local DEBRIS_SINK = 30
local DEBRIS_SINK_TIME = 1.1

export type Handle = {
	update: (dt: number) -> (),
	destroy: () -> (),
}

type Piece = {
	part: BasePart,
	rest: CFrame,
	falls: boolean,
}

local ChandelierTrapFx = {}

local function vectorAttribute(part: BasePart, name: string, fallback: Vector3): Vector3
	local value = part:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else fallback
end

function ChandelierTrapFx.new(hitbox: BasePart, effectsFolder: Folder): Handle
	local model = hitbox.Parent
	local anchorPoint = vectorAttribute(hitbox, TrapConstants.ChandelierAnchorAttribute, hitbox.Position)
	local impact = vectorAttribute(hitbox, TrapConstants.ChandelierImpactAttribute, hitbox.Position)

	local pieces: { Piece } = {}
	local lowest = math.huge
	if model ~= nil then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= hitbox then
				local falls = descendant.Name ~= ROSETTE_NAME
				table.insert(pieces, { part = descendant, rest = descendant.CFrame, falls = falls })
				if falls then
					lowest = math.min(lowest, descendant.Position.Y)
				end
			end
		end
	end
	local bodyY = if lowest < math.huge then lowest else impact.Y + CONFIG.HangHeight
	local fallDistance = math.max(0, bodyY - impact.Y - 0.3)
	local swingEnd = math.max(0, CONFIG.WarningTime - CONFIG.FallTime)

	local holder = TrapFxUtil.newAnchor(effectsFolder, "ChandelierTrapFx", CFrame.new(anchorPoint))
	local ceilingPoint = Instance.new("Attachment")
	ceilingPoint.Parent = holder
	local bodyPoint = Instance.new("Attachment")
	bodyPoint.Parent = holder
	bodyPoint.WorldPosition = Vector3.new(anchorPoint.X, bodyY, anchorPoint.Z)
	local floorPoint = Instance.new("Attachment")
	floorPoint.Parent = holder
	floorPoint.WorldPosition = impact + Vector3.new(0, 0.5, 0)

	local sparkle = TrapFxUtil.newReadySparkle(bodyPoint, GOLD)
	local sparks = TrapFxUtil.newEmitter(ceilingPoint, TrapFxUtil.SparkleTexture, Color3.fromRGB(255, 190, 90))
	sparks.Rate = 30
	sparks.Lifetime = NumberRange.new(0.4, 0.7)
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.EmissionDirection = Enum.NormalId.Bottom
	local shards = TrapFxUtil.newEmitter(floorPoint, TrapFxUtil.SparkleTexture, GLASS)
	shards.Lifetime = NumberRange.new(0.5, 0.9)
	shards.Size = NumberSequence.new(0.45, 0.1)
	shards.Speed = NumberRange.new(14, 26)
	shards.SpreadAngle = Vector2.new(70, 70)
	shards.Acceleration = Vector3.new(0, -45, 0)
	shards.RotSpeed = NumberRange.new(-360, 360)
	shards.EmissionDirection = Enum.NormalId.Top
	local gold = TrapFxUtil.newEmitter(floorPoint, TrapFxUtil.SparkleTexture, GOLD)
	gold.Lifetime = NumberRange.new(0.5, 1)
	gold.Size = NumberSequence.new(0.6, 0)
	gold.Speed = NumberRange.new(10, 20)
	gold.SpreadAngle = Vector2.new(80, 80)
	gold.Acceleration = Vector3.new(0, -30, 0)
	gold.EmissionDirection = Enum.NormalId.Top
	local dust = TrapFxUtil.newEmitter(floorPoint, TrapFxUtil.SmokeTexture, DUST)
	dust.Lifetime = NumberRange.new(0.8, 1.2)
	dust.Size = NumberSequence.new(2, 5)
	dust.Transparency = NumberSequence.new(0.5, 1)
	dust.Speed = NumberRange.new(5, 10)
	dust.SpreadAngle = Vector2.new(85, 85)
	dust.EmissionDirection = Enum.NormalId.Top

	local creakSound = TrapFxUtil.newSound(holder, CONFIG.CreakSoundId, 0.6, 0.8)
	local crashSound = TrapFxUtil.newSound(holder, CONFIG.CrashSoundId, 0.7, 1)
	crashSound.RollOffMaxDistance = 220

	local shadow = Instance.new("Part")
	shadow.Name = "ChandelierShadow"
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanQuery = false
	shadow.CanTouch = false
	shadow.CastShadow = false
	shadow.Material = Enum.Material.SmoothPlastic
	shadow.Color = SHADOW_COLOR
	shadow.Transparency = 1
	shadow.Size = Vector3.new(SHADOW_THICKNESS, CONFIG.Radius * 2, CONFIG.Radius * 2)
	shadow.CFrame = CFrame.new(impact + Vector3.new(0, SHADOW_LIFT, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	shadow.Parent = effectsFolder

	local random = Random.new()
	local clock = 0
	local state = hitbox:GetAttribute(TrapConstants.StateAttribute)
	local cracks = hitbox:GetAttribute(TrapConstants.CracksAttribute)
	local crackUntil = 0
	-- Falso enquanto o lustre está fora do lugar (precisa voltar ao repouso).
	local atRest = true
	local connections: { RBXScriptConnection } = {}

	local function stateAge(): number
		local at = hitbox:GetAttribute(TrapConstants.StateAtAttribute)
		return if typeof(at) == "number" then Workspace:GetServerTimeNow() - at else math.huge
	end

	local function pose(angle: number, drop: number)
		local pivot = CFrame.new(anchorPoint) * CFrame.Angles(angle, 0, angle * 0.6) * CFrame.new(-anchorPoint)
		for _, piece in ipairs(pieces) do
			if piece.falls then
				piece.part.CFrame = (pivot * piece.rest) - Vector3.new(0, drop, 0)
			end
		end
		atRest = false
	end

	local function rest()
		if atRest then
			return
		end
		for _, piece in ipairs(pieces) do
			piece.part.CFrame = piece.rest
		end
		atRest = true
	end

	-- Pedaços do lustre no chão, que afundam junto com os blocos.
	local function spawnDebris()
		for index = 1, DEBRIS_COUNT do
			local angle = (index / DEBRIS_COUNT) * math.pi * 2
			local distance = random:NextNumber(0.5, CONFIG.Radius + 1)
			local size = random:NextNumber(0.5, 1.1)
			local piece = Instance.new("Part")
			piece.Name = "ChandelierDebris"
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			piece.Material = if index % 2 == 0 then Enum.Material.Neon else Enum.Material.Metal
			piece.Color = if index % 2 == 0 then GLASS else GOLD
			piece.Size = Vector3.new(size, size * 0.5, size)
			piece.CFrame = CFrame.new(impact + Vector3.new(math.cos(angle) * distance, size * 0.25, math.sin(angle) * distance))
				* CFrame.Angles(random:NextNumber(0, math.pi), random:NextNumber(0, math.pi), 0)
			piece.Parent = effectsFolder
			local sink = TweenService:Create(
				piece,
				TweenInfo.new(DEBRIS_SINK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, CONFIG.HoleDelay),
				{ CFrame = piece.CFrame - Vector3.new(0, DEBRIS_SINK, 0), Transparency = 1 }
			)
			sink.Completed:Once(function()
				piece:Destroy()
			end)
			sink:Play()
		end
	end

	-- `silent`: estado de quem acabou de chegar (mostra, sem som nem queda).
	local function applyState(previous: unknown, silent: boolean)
		sparkle.Enabled = state == TrapConstants.Ready and hitbox.CanQuery
		sparks.Enabled = state == TrapConstants.Warning
		if state == TrapConstants.Warning then
			if not silent then
				creakSound:Play()
			end
			return
		end
		shadow.Transparency = 1
		rest()
		if
			(state == TrapConstants.Recharging or state == TrapConstants.Spent)
			and not silent
			and previous == TrapConstants.Warning
			and stateAge() < REPLAY_WINDOW
		then
			shards:Emit(35)
			gold:Emit(45)
			dust:Emit(30)
			crashSound:Play()
			spawnDebris()
		end
	end

	local function onState()
		local previous = state
		state = hitbox:GetAttribute(TrapConstants.StateAttribute)
		applyState(previous, false)
	end

	local function onCracks()
		local current = hitbox:GetAttribute(TrapConstants.CracksAttribute)
		if typeof(current) == "number" and (typeof(cracks) ~= "number" or current > cracks) and state == TrapConstants.Ready then
			crackUntil = clock + CRACK_TIME
			creakSound:Play()
		end
		cracks = current
	end

	table.insert(connections, hitbox:GetAttributeChangedSignal(TrapConstants.StateAttribute):Connect(onState))
	table.insert(connections, hitbox:GetAttributeChangedSignal(TrapConstants.CracksAttribute):Connect(onCracks))
	table.insert(connections, hitbox:GetPropertyChangedSignal("CanQuery"):Connect(function()
		sparkle.Enabled = state == TrapConstants.Ready and hitbox.CanQuery
	end))
	applyState(nil, true)

	local handle = {} :: Handle

	handle.update = function(dt: number)
		clock += dt
		if state == TrapConstants.Warning then
			local elapsed = math.max(0, stateAge())
			local progress = math.clamp(elapsed / CONFIG.WarningTime, 0, 1)
			shadow.Transparency = SHADOW_START + ((SHADOW_END - SHADOW_START) * progress)
			local diameter = (CONFIG.Radius * 2) + (((CONFIG.ImpactRadius - CONFIG.Radius) * 2) * progress)
			shadow.Size = Vector3.new(SHADOW_THICKNESS, diameter, diameter)
			local ramp = math.min(1, elapsed / SWING_RAMP)
			local swing = SWING_MAX * ramp * math.sin(elapsed * SWING_SPEED)
			if elapsed < swingEnd then
				pose(swing, 0)
			else
				-- Queda acelerada: chega ao chão quando o aviso acaba, com o
				-- balanço sumindo aos poucos (sem pulo para a vertical).
				local fall = math.clamp((elapsed - swingEnd) / math.max(CONFIG.FallTime, 0.05), 0, 1)
				pose(swing * (1 - fall), fallDistance * fall * fall)
			end
		elseif clock < crackUntil then
			local left = (crackUntil - clock) / CRACK_TIME
			pose(CRACK_SWING * left * math.sin(clock * SWING_SPEED * 1.5), 0)
		else
			rest()
		end
	end

	handle.destroy = function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		atRest = false
		rest()
		shadow:Destroy()
		holder:Destroy()
	end

	return handle
end

return table.freeze(ChandelierTrapFx)
