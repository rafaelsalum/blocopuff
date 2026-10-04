--!strict

-- Desenho do Tapete Puxado num cliente (Fase 5, 5.3). Lê os atributos da
-- franja (TrapConstants) e mexe nos pedaços do tapete só neste cliente:
--   * pronta: brilho leve na franja (dá para atirar);
--   * tiro de perto: a franja e o tapete tremem;
--   * aviso: uma onda corre pelo tapete, da franja para a outra ponta (a
--     franja treme só com tiro de perto);
--   * puxão: o tapete encolhe para o lado da franja e fica embolado, com
--     dobras e poeira, até o fim da recarga;
--   * pronta de novo: o tapete se estica sozinho.
-- Quem chega depois vê o tapete já embolado (pelo estado), sem o puxão.
-- Os pedaços sobre blocos caídos somem pelo servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local TrapFxUtil = require(script.Parent.TrapFxUtil)

local CONFIG = TrapConfig.Rug
local SPARKLE_COLOR = Color3.fromRGB(255, 240, 200)
local DUST_COLOR = Color3.fromRGB(225, 210, 180)
local RIPPLE_HEIGHT = 0.35
-- Velocidade da frente da onda (studs/s) e comprimento de cada ondulação.
local RIPPLE_SPEED = 26
local RIPPLE_WAVELENGTH = 9
local RIPPLE_FADE = 20
-- Quanto o tapete encolhe ao ser puxado (0,55 = fica com 45% do tamanho).
local BUNCH = 0.55
local FOLD_HEIGHT = 0.5
local FOLD_FREQUENCY = 1.3
local FOLD_TILT = math.rad(10)
local PULL_TIME = 0.3
local STRETCH_TIME = 0.6
local SHAKE_TIME = 0.3
local SHAKE_AMPLITUDE = 0.08
local REPLAY_WINDOW = 1

export type Handle = {
	update: (dt: number) -> (),
	destroy: () -> (),
}

type Tile = {
	part: BasePart,
	rest: CFrame,
	size: Vector3,
	along: number,
}

local RugTrapFx = {}

function RugTrapFx.new(fringe: BasePart, effectsFolder: Folder): Handle
	local model = fringe.Parent
	local pullValue = fringe:GetAttribute(TrapConstants.RugPullAttribute)
	local pull = if typeof(pullValue) == "Vector3" and pullValue.Magnitude > 1e-3 then pullValue.Unit else fringe.CFrame.LookVector
	local alongX = math.abs(pull.X) > 0.5
	local fringeRest = fringe.CFrame

	local tiles: { Tile } = {}
	if model ~= nil then
		for _, child in ipairs(model:GetChildren()) do
			local along = child:GetAttribute(TrapConstants.RugAlongAttribute)
			if child:IsA("BasePart") and typeof(along) == "number" then
				table.insert(tiles, { part = child, rest = child.CFrame, size = child.Size, along = along })
			end
		end
	end

	local anchor = TrapFxUtil.newAnchor(effectsFolder, "RugTrapFx", fringe.CFrame)
	local point = Instance.new("Attachment")
	point.Parent = anchor
	local sparkle = TrapFxUtil.newReadySparkle(point, SPARKLE_COLOR)
	local dust = TrapFxUtil.newEmitter(point, TrapFxUtil.SmokeTexture, DUST_COLOR)
	dust.Lifetime = NumberRange.new(0.6, 0.9)
	dust.Size = NumberSequence.new(1.5, 3)
	dust.Transparency = NumberSequence.new(0.5, 1)
	dust.Speed = NumberRange.new(4, 8)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.EmissionDirection = Enum.NormalId.Top
	local stretchSound = TrapFxUtil.newSound(anchor, CONFIG.StretchSoundId, 1, 0.6)
	local pullSound = TrapFxUtil.newSound(anchor, CONFIG.PullSoundId, 1, 1)

	local random = Random.new()
	local clock = 0
	local state = fringe:GetAttribute(TrapConstants.StateAttribute)
	local cracks = fringe:GetAttribute(TrapConstants.CracksAttribute)
	-- 0 = esticado, 1 = embolado.
	local bunch = 0
	local bunchFrom = 0
	local bunchTo = 0
	local bunchStart = 0
	local bunchDuration: number? = nil
	local warningSince: number? = nil
	local shakeUntil = 0
	-- Falso enquanto o tapete precisa ser redesenhado.
	local settled = true
	local connections: { RBXScriptConnection } = {}

	local function animateBunch(target: number, duration: number)
		bunchFrom = bunch
		bunchTo = target
		bunchStart = clock
		bunchDuration = duration
		settled = false
	end

	local function setBunch(value: number)
		bunch = value
		bunchDuration = nil
		settled = false
	end

	local function rippleAt(along: number): number
		local since = warningSince
		if since == nil then
			return 0
		end
		-- A onda sai da franja e corre para a outra ponta.
		local behindFront = ((clock - since) * RIPPLE_SPEED) - along
		if behindFront <= 0 then
			return 0
		end
		return RIPPLE_HEIGHT * math.sin((behindFront / RIPPLE_WAVELENGTH) * math.pi * 2) * math.exp(-behindFront / RIPPLE_FADE)
	end

	local function pose(shaking: boolean)
		local squeeze = 1 - (BUNCH * bunch)
		for index, tile in ipairs(tiles) do
			local shift = pull * tile.along * BUNCH * bunch
			local fold = FOLD_HEIGHT * bunch * (0.5 + (0.5 * math.sin(tile.along * FOLD_FREQUENCY)))
			local lift = fold + rippleAt(tile.along)
			if shaking then
				lift += random:NextNumber(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE)
			end
			local tilt = FOLD_TILT * bunch * (if index % 2 == 0 then 1 else -1)
			local rotation = if alongX then CFrame.Angles(0, 0, tilt) else CFrame.Angles(tilt, 0, 0)
			tile.part.CFrame = (tile.rest + shift + Vector3.new(0, lift, 0)) * rotation
			tile.part.Size = if alongX
				then Vector3.new(tile.size.X * squeeze, tile.size.Y, tile.size.Z)
				else Vector3.new(tile.size.X, tile.size.Y, tile.size.Z * squeeze)
		end
		fringe.CFrame = if shaking
			then fringeRest + Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * SHAKE_AMPLITUDE
			else fringeRest
	end

	local function stateAge(): number
		local at = fringe:GetAttribute(TrapConstants.StateAtAttribute)
		return if typeof(at) == "number" then Workspace:GetServerTimeNow() - at else math.huge
	end

	-- `silent`: estado de quem acabou de chegar (mostra, sem som nem puxão).
	-- Brilho só com a franja pronta e visível (some se o chão dela caiu).
	local function syncSparkle()
		sparkle.Enabled = state == TrapConstants.Ready and fringe.Transparency < 1
	end

	local function applyState(previous: unknown, silent: boolean)
		syncSparkle()
		if state == TrapConstants.Warning then
			warningSince = clock
			settled = false
			if not silent then
				stretchSound:Play()
			end
		elseif state == TrapConstants.Recharging or state == TrapConstants.Spent then
			warningSince = nil
			if not silent and previous == TrapConstants.Warning and stateAge() < REPLAY_WINDOW then
				animateBunch(1, PULL_TIME)
				pullSound:Play()
				dust:Emit(25)
			else
				setBunch(1)
			end
		else
			warningSince = nil
			if bunch > 0 and not silent then
				animateBunch(0, STRETCH_TIME)
				stretchSound:Play()
			else
				setBunch(0)
			end
		end
	end

	local function onState()
		local previous = state
		state = fringe:GetAttribute(TrapConstants.StateAttribute)
		applyState(previous, false)
	end

	local function onCracks()
		local current = fringe:GetAttribute(TrapConstants.CracksAttribute)
		if typeof(current) == "number" and (typeof(cracks) ~= "number" or current > cracks) then
			shakeUntil = clock + SHAKE_TIME
			settled = false
		end
		cracks = current
	end

	table.insert(connections, fringe:GetAttributeChangedSignal(TrapConstants.StateAttribute):Connect(onState))
	table.insert(connections, fringe:GetAttributeChangedSignal(TrapConstants.CracksAttribute):Connect(onCracks))
	table.insert(connections, fringe:GetPropertyChangedSignal("Transparency"):Connect(syncSparkle))
	applyState(nil, true)

	local handle = {} :: Handle

	handle.update = function(dt: number)
		clock += dt
		local duration = bunchDuration
		if duration ~= nil then
			local progress = math.clamp((clock - bunchStart) / duration, 0, 1)
			local eased = 1 - ((1 - progress) ^ 3)
			bunch = bunchFrom + ((bunchTo - bunchFrom) * eased)
			if progress >= 1 then
				bunchDuration = nil
			end
		end
		local shaking = clock < shakeUntil
		local animating = bunchDuration ~= nil or shaking or warningSince ~= nil
		if animating or not settled then
			pose(shaking)
			-- Depois do último quadro animado, fica parado sem redesenhar.
			settled = not animating
		end
	end

	handle.destroy = function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, tile in ipairs(tiles) do
			tile.part.CFrame = tile.rest
			tile.part.Size = tile.size
		end
		fringe.CFrame = fringeRest
		anchor:Destroy()
	end

	return handle
end

return table.freeze(RugTrapFx)
