--!strict

-- Fuligem nos personagens (Fase 5, 5.5), só no cliente. O servidor marca o
-- corpo de quem espirrou na nuvem da Lareira de Fuligem com a tag
-- TrapSooty (até o fim da rodada) e o atributo TrapSneezeAt (cada espirro):
--   * rosto sujo: a cabeça fica escurecida e solta um pouco de pó;
--   * cada espirro: "ATCHIM!" sobre a cabeça, um sopro de fuligem e som;
--   * no próprio personagem: a tela fica levemente embaçada por BlurTime,
--     sumindo devagar (sem piscar).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local TrapFxUtil = require(script.Parent.TrapFxUtil)

local CONFIG = TrapConfig.Fireplace
local SOOT_COLOR = Color3.fromRGB(35, 30, 30)
local SOOT_FILL = 0.5
local BLUR_NAME = "SootBlur"
local BLUR_SIZE = 8
local BLUR_IN = 0.12
local TEXT_TIME = 1.2
local TEXT_RISE = 2
-- Só desenha espirros recentes (quem chega depois não vê os antigos).
local REPLAY_WINDOW = 1

type Tracked = {
	highlight: Highlight?,
	dust: ParticleEmitter?,
	puff: ParticleEmitter?,
	sound: Sound?,
	connections: { RBXScriptConnection },
}

local SootFx = {}

local started = false
local tracked: { [Model]: Tracked } = {}
local blur: BlurEffect? = nil
local blurTween: Tween? = nil

local function getBlur(): BlurEffect
	local existing = blur
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local effect = Instance.new("BlurEffect")
	effect.Name = BLUR_NAME
	effect.Size = 0
	effect.Parent = Lighting
	blur = effect
	return effect
end

local function blurScreen()
	local effect = getBlur()
	if blurTween ~= nil then
		blurTween:Cancel()
	end
	-- Embaça rápido (sem salto), fica embaçado quase todo o tempo e clareia
	-- no fim.
	local fadeIn = TweenService:Create(effect, TweenInfo.new(BLUR_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = BLUR_SIZE })
	local fadeOut = TweenService:Create(
		effect,
		TweenInfo.new(math.max(0, CONFIG.BlurTime - BLUR_IN), Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{ Size = 0 }
	)
	fadeIn.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and blurTween == fadeIn then
			blurTween = fadeOut
			fadeOut:Play()
		end
	end)
	blurTween = fadeIn
	fadeIn:Play()
end

local function showText(head: BasePart, effectsFolder: Folder)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SneezeText"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Size = UDim2.fromScale(5, 1.6)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = Lang.t("ATCHIM!")
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = SOOT_COLOR
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = effectsFolder
	local info = TweenInfo.new(TEXT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, TEXT_RISE, 0) }):Play()
	local fade = TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
	fade.Completed:Once(function()
		gui:Destroy()
	end)
	fade:Play()
end

local function untrack(model: Model)
	local entry = tracked[model]
	if entry == nil then
		return
	end
	tracked[model] = nil
	for _, connection in ipairs(entry.connections) do
		connection:Disconnect()
	end
	local highlight = entry.highlight
	if highlight ~= nil then
		highlight:Destroy()
	end
	local dust = entry.dust
	if dust ~= nil then
		local attachment = dust.Parent
		if attachment ~= nil then
			attachment:Destroy()
		end
	end
end

local function track(instance: Instance, effectsFolder: Folder)
	if not instance:IsA("Model") or tracked[instance] ~= nil then
		return
	end
	local model = instance
	local headInstance = model:FindFirstChild("Head")
	local head: BasePart? = if headInstance ~= nil and headInstance:IsA("BasePart") then headInstance else nil

	local entry: Tracked = { highlight = nil, connections = {} }
	if head ~= nil then
		-- Só a cabeça (rosto sujo), nunca o corpo inteiro.
		local highlight = Instance.new("Highlight")
		highlight.Name = "Soot"
		highlight.Adornee = head
		highlight.FillColor = SOOT_COLOR
		highlight.FillTransparency = SOOT_FILL
		highlight.OutlineTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = effectsFolder
		entry.highlight = highlight
		-- Fica no corpo (que é do servidor), mas só neste cliente.
		local point = Instance.new("Attachment")
		point.Name = "SootFx"
		point.Parent = head
		local dust = TrapFxUtil.newEmitter(point, TrapFxUtil.SmokeTexture, SOOT_COLOR)
		dust.LightEmission = 0
		dust.Rate = 1.5
		dust.Enabled = true
		dust.Lifetime = NumberRange.new(0.6, 1)
		dust.Size = NumberSequence.new(0.4, 1.2)
		dust.Transparency = NumberSequence.new(0.5, 1)
		dust.Speed = NumberRange.new(0.5, 1)
		dust.Acceleration = Vector3.new(0, -2, 0)
		local puff = TrapFxUtil.newEmitter(point, TrapFxUtil.SmokeTexture, SOOT_COLOR)
		puff.LightEmission = 0
		puff.Lifetime = NumberRange.new(0.5, 0.9)
		puff.Size = NumberSequence.new(0.8, 2.6)
		puff.Transparency = NumberSequence.new(0.3, 1)
		puff.Speed = NumberRange.new(4, 8)
		puff.SpreadAngle = Vector2.new(40, 40)
		puff.EmissionDirection = Enum.NormalId.Front
		entry.dust = dust
		entry.puff = puff
		entry.sound = TrapFxUtil.newSound(point, CONFIG.SneezeSoundId, 1.6, 0.9)
	end
	tracked[model] = entry

	local lastAt = 0
	local function onSneeze()
		local at = model:GetAttribute(TrapConstants.SneezeAtAttribute)
		if typeof(at) ~= "number" or at == lastAt or Workspace:GetServerTimeNow() - at > REPLAY_WINDOW then
			return
		end
		lastAt = at
		if head ~= nil then
			showText(head, effectsFolder)
		end
		local puff = entry.puff
		if puff ~= nil then
			puff:Emit(12)
		end
		local sound = entry.sound
		if sound ~= nil then
			sound:Play()
		end
		local localPlayer = Players.LocalPlayer
		if localPlayer ~= nil and localPlayer.Character == model then
			blurScreen()
		end
	end

	table.insert(entry.connections, model:GetAttributeChangedSignal(TrapConstants.SneezeAtAttribute):Connect(onSneeze))
	table.insert(entry.connections, model.Destroying:Connect(function()
		untrack(model)
	end))
	-- A tag chega junto com o primeiro espirro.
	onSneeze()
end

function SootFx.start(effectsFolder: Folder)
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(TrapConstants.SootTag):Connect(function(instance)
		track(instance, effectsFolder)
	end)
	CollectionService:GetInstanceRemovedSignal(TrapConstants.SootTag):Connect(function(instance)
		if instance:IsA("Model") then
			untrack(instance)
		end
	end)
	for _, instance in ipairs(CollectionService:GetTagged(TrapConstants.SootTag)) do
		track(instance, effectsFolder)
	end
end

return table.freeze(SootFx)
