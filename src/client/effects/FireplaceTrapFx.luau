--!strict

-- Desenho da Lareira de Fuligem num cliente (Fase 5, 5.5). Lê os atributos
-- da boca da lareira (TrapConstants):
--   * pronta: brasas acesas e brilho leve;
--   * tiro de perto: um soluço de brasas e um pouco de fumaça;
--   * aviso: a lareira tosse brasas e começa a soltar fumaça;
--   * efeito: uma nuvem de fuligem fica em frente a ela por CloudDuration
--     segundos (quem chega depois também vê o que resta da nuvem);
--   * recarregando: brasas apagadas.
-- Os espirros e o rosto sujo de quem estava na nuvem ficam no SootFx.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local TrapFxUtil = require(script.Parent.TrapFxUtil)

local CONFIG = TrapConfig.Fireplace
local EMBERS_NAME = "Embers"
local EMBER_COLOR = Color3.fromRGB(255, 140, 50)
local EMBER_DIM = Color3.fromRGB(70, 40, 30)
local SOOT_COLOR = Color3.fromRGB(45, 40, 40)
local REPLAY_WINDOW = 1
-- A fumaça da nuvem para de sair um pouco antes do fim, para sumir junto
-- com os espirros (ela ainda dura CLOUD_LIFETIME no ar).
local CLOUD_LIFETIME = 1.2

export type Handle = {
	update: (dt: number) -> (),
	destroy: () -> (),
}

local FireplaceTrapFx = {}

local function newSmoke(parent: Instance, rate: number, size: NumberSequence, speed: NumberRange): ParticleEmitter
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = TrapFxUtil.SmokeTexture
	smoke.Color = ColorSequence.new(SOOT_COLOR)
	smoke.LightEmission = 0
	smoke.LightInfluence = 1
	smoke.Enabled = false
	smoke.Rate = rate
	smoke.Size = size
	smoke.Speed = speed
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.25, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Parent = parent
	return smoke
end

function FireplaceTrapFx.new(mouth: BasePart, effectsFolder: Folder): Handle
	local model = mouth.Parent
	local embersPart = if model ~= nil then model:FindFirstChild(EMBERS_NAME) else nil
	local embers: BasePart? = if embersPart ~= nil and embersPart:IsA("BasePart") then embersPart else nil
	local emberLight = if embers ~= nil then embers:FindFirstChildOfClass("PointLight") else nil
	local inwardValue = mouth:GetAttribute(TrapConstants.InwardAttribute)
	local inward = if typeof(inwardValue) == "Vector3" then inwardValue else Vector3.zAxis
	local cloudValue = mouth:GetAttribute(TrapConstants.FireplaceCloudAttribute)
	local cloudCenter = if typeof(cloudValue) == "Vector3" then cloudValue else mouth.Position + (inward * CONFIG.CloudOffset)

	-- Boca da lareira, virada para dentro da sala (a fumaça sai para a frente).
	local mouthFront = mouth.Position + (inward * 0.8)
	local holder = TrapFxUtil.newAnchor(effectsFolder, "FireplaceTrapFx", CFrame.lookAt(mouthFront, mouthFront + inward))
	local mouthPoint = Instance.new("Attachment")
	mouthPoint.Parent = holder
	local sparkle = TrapFxUtil.newReadySparkle(mouthPoint, EMBER_COLOR)
	local sparks = TrapFxUtil.newEmitter(mouthPoint, TrapFxUtil.SparkleTexture, EMBER_COLOR)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Speed = NumberRange.new(8, 16)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Acceleration = Vector3.new(0, -25, 0)
	sparks.EmissionDirection = Enum.NormalId.Front
	local puff = newSmoke(mouthPoint, 18, NumberSequence.new(1.2, 3.5), NumberRange.new(3, 6))
	puff.Lifetime = NumberRange.new(0.8, 1.4)
	puff.SpreadAngle = Vector2.new(25, 25)
	puff.EmissionDirection = Enum.NormalId.Front

	-- Volume da nuvem: um elipsoide no chão, da parede para dentro da sala
	-- (nada de fumaça atravessando a parede).
	local wallPoint = cloudCenter - (inward * CONFIG.CloudOffset)
	local depth = CONFIG.CloudOffset + (CONFIG.CloudRadius * 0.9)
	local cloudMiddle = wallPoint + (inward * (depth / 2)) + Vector3.new(0, CONFIG.CloudHeight / 2, 0)
	local cloudPart = TrapFxUtil.newAnchor(effectsFolder, "FireplaceCloud", CFrame.lookAt(cloudMiddle, cloudMiddle + inward))
	cloudPart.Size = Vector3.new(CONFIG.CloudRadius * 1.8, CONFIG.CloudHeight, depth)
	local cloud = newSmoke(cloudPart, 40, NumberSequence.new(3, 6), NumberRange.new(0.5, 1.5))
	cloud.Shape = Enum.ParticleEmitterShape.Sphere
	cloud.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	cloud.Lifetime = NumberRange.new(CLOUD_LIFETIME * 0.8, CLOUD_LIFETIME)
	cloud.Drag = 1

	local coughSound = TrapFxUtil.newSound(holder, CONFIG.CoughSoundId, 1.2, 0.8)
	local puffSound = TrapFxUtil.newSound(holder, CONFIG.PuffSoundId, 0.9, 1)

	local state = mouth:GetAttribute(TrapConstants.StateAttribute)
	local cracks = mouth:GetAttribute(TrapConstants.CracksAttribute)
	local connections: { RBXScriptConnection } = {}

	local function stateAge(): number
		local at = mouth:GetAttribute(TrapConstants.StateAtAttribute)
		return if typeof(at) == "number" then Workspace:GetServerTimeNow() - at else math.huge
	end

	-- Brasas acesas (pronta ou avisando) ou apagadas (recarregando, gasta).
	local function setEmbers(lit: boolean)
		if embers ~= nil then
			embers.Color = if lit then EMBER_COLOR else EMBER_DIM
		end
		if emberLight ~= nil then
			emberLight.Enabled = lit
		end
	end

	-- `silent`: estado de quem acabou de chegar (mostra, sem som nem rajada).
	local function applyState(previous: unknown, silent: boolean)
		local ready = state == TrapConstants.Ready
		local warning = state == TrapConstants.Warning
		sparkle.Enabled = ready
		puff.Enabled = warning
		setEmbers(ready or warning)
		if warning and not silent then
			sparks:Emit(25)
			coughSound:Play()
		elseif
			state == TrapConstants.Recharging
			and not silent
			and previous == TrapConstants.Warning
			and stateAge() < REPLAY_WINDOW
		then
			puff:Emit(30)
			cloud:Emit(25)
			puffSound:Play()
		end
	end

	local function onState()
		local previous = state
		state = mouth:GetAttribute(TrapConstants.StateAttribute)
		applyState(previous, false)
	end

	local function onCracks()
		local current = mouth:GetAttribute(TrapConstants.CracksAttribute)
		if typeof(current) == "number" and (typeof(cracks) ~= "number" or current > cracks) and state == TrapConstants.Ready then
			sparks:Emit(6)
			puff:Emit(3)
		end
		cracks = current
	end

	table.insert(connections, mouth:GetAttributeChangedSignal(TrapConstants.StateAttribute):Connect(onState))
	table.insert(connections, mouth:GetAttributeChangedSignal(TrapConstants.CracksAttribute):Connect(onCracks))
	applyState(nil, true)

	local handle = {} :: Handle

	handle.update = function(_dt: number)
		-- A nuvem segue o relógio do servidor: some sozinha no fim.
		cloud.Enabled = state == TrapConstants.Recharging and stateAge() < CONFIG.CloudDuration - (CLOUD_LIFETIME * 0.8)
	end

	handle.destroy = function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		setEmbers(true)
		cloudPart:Destroy()
		holder:Destroy()
	end

	return handle
end

return table.freeze(FireplaceTrapFx)
