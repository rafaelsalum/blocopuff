--!strict

-- Peças dinâmicas do Cofre do Barão: a folha da porta (que colide enquanto
-- fechada e abre girando na dobradiça), o brilho dourado que escapa por baixo
-- da porta certa, a luz de alarme e o Puffador do Cofre girando no pedestal.
-- Só cuida da aparência; as regras ficam no VaultService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)
local PuffadorModel = require(script.Parent.PuffadorModel)
local SecretRoomBuilder = require(script.Parent.SecretRoomBuilder)

type BuildingConfig = GameConfig.BuildingConfig
type SecretDoor = BuildingLayout.SecretDoor

export type DoorProps = {
	door: SecretDoor,
	model: Model,
	panel: Part,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	prompt: ProximityPrompt,
	glow: Part,
	alarm: PointLight,
	soundAnchor: Part,
}

local DOOR_THICKNESS = 0.4
local DOOR_COLOR = Color3.fromRGB(96, 62, 40)
local BRASS_COLOR = Color3.fromRGB(214, 170, 84)
local GLOW_COLOR = Color3.fromRGB(255, 206, 90)
local ALARM_COLOR = Color3.fromRGB(255, 70, 60)
local OPEN_ANGLE = math.rad(105)
local OPEN_TIME = 0.9

local VaultProps = {}

-- Peça decorativa presa à folha da porta para acompanhar a abertura.
local function attachToPanel(panel: Part, part: Part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = panel
	weld.Part1 = part
	weld.Parent = part
	part.Anchored = false
	part.Massless = true
end

local function createPanel(model: Model, door: SecretDoor, building: BuildingConfig): (Part, CFrame, CFrame)
	local size = BuildingLayout.SecretDoorSize
	local frame = SecretRoomBuilder.getFrame(door)
	-- Folha no meio da espessura da parede; a dobradiça fica no lado -X.
	local closed = frame * CFrame.new(0, size.Y / 2, building.WallThickness / 2)
	local hinge = frame * CFrame.new(-size.X / 2, size.Y / 2, building.WallThickness / 2)
	local open = hinge * CFrame.Angles(0, -OPEN_ANGLE, 0) * CFrame.new(size.X / 2, 0, 0)

	local panel = BuildingDecor.createPart(model, "DoorPanel", Vector3.new(size.X - 0.1, size.Y - 0.05, DOOR_THICKNESS), closed, DOOR_COLOR, {
		material = Enum.Material.WoodPlanks,
		collide = true,
	})

	-- Almofadas, placa de latão, fechadura e maçaneta nas duas faces.
	for _, face in ipairs({ -1, 1 }) do
		local z = face * ((DOOR_THICKNESS / 2) + 0.05)
		for index, y in ipairs({ 1.9, -1.6 }) do
			local inset = BuildingDecor.createPart(model, `DoorInset{index}`, Vector3.new(size.X - 1.4, 2.8, 0.1), closed * CFrame.new(0, y, z), DOOR_COLOR:Lerp(Color3.new(0, 0, 0), 0.25), {
				material = Enum.Material.Wood,
			})
			attachToPanel(panel, inset)
		end
		local plate = BuildingDecor.createPart(model, "LockPlate", Vector3.new(0.5, 1.2, 0.1), closed * CFrame.new((size.X / 2) - 0.7, -0.4, z), BRASS_COLOR, {
			material = Enum.Material.Metal,
		})
		attachToPanel(panel, plate)
		local knob = BuildingDecor.createPart(model, "Knob", Vector3.new(0.45, 0.45, 0.45), closed * CFrame.new((size.X / 2) - 0.7, -0.1, z + (face * 0.2)), BRASS_COLOR, {
			material = Enum.Material.Metal,
			shape = Enum.PartType.Ball,
		})
		attachToPanel(panel, knob)
	end

	return panel, closed, open
end

local function createPrompt(panel: Part): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Abrir"
	prompt.ObjectText = "Porta misteriosa"
	prompt.HoldDuration = GameConfig.SecretRoom.OpenHoldDuration
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = panel
	return prompt
end

-- Faixa de luz dourada no chão, do lado de dentro do prédio, como se o
-- brilho do cofre vazasse por baixo da porta. Começa apagada.
local function createGlow(model: Model, door: SecretDoor): Part
	local frame = SecretRoomBuilder.getFrame(door)
	local glow = BuildingDecor.createPart(model, "UnderDoorGlow", Vector3.new(4.4, 0.06, 1.2), frame * CFrame.new(0, 0.04, -0.6), GLOW_COLOR, {
		material = Enum.Material.Neon,
		transparency = 1,
	})
	local light = Instance.new("PointLight")
	light.Name = "GlowLight"
	light.Color = GLOW_COLOR
	light.Range = 9
	light.Brightness = 0
	light.Shadows = false
	light.Parent = glow

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "GlowSparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(GLOW_COLOR)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Speed = NumberRange.new(0.6, 1.4)
	sparkles.SpreadAngle = Vector2.new(30, 30)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Rate = 6
	sparkles.Enabled = false
	sparkles.Parent = glow
	return glow
end

local function createAlarm(model: Model, door: SecretDoor): (PointLight, Part)
	local frame = SecretRoomBuilder.getFrame(door)
	local size = BuildingLayout.SecretDoorSize
	local lamp = BuildingDecor.createPart(model, "AlarmLamp", Vector3.new(0.9, 0.5, 0.5), frame * CFrame.new(0, size.Y + 2, 0.4), ALARM_COLOR, {
		material = Enum.Material.Glass,
		transparency = 0.2,
	})
	local alarm = Instance.new("PointLight")
	alarm.Name = "Alarm"
	alarm.Color = ALARM_COLOR
	alarm.Range = 18
	alarm.Brightness = 0
	alarm.Shadows = false
	alarm.Parent = lamp
	return alarm, lamp
end

function VaultProps.create(parent: Instance, door: SecretDoor, building: BuildingConfig): DoorProps
	local model = Instance.new("Model")
	model.Name = `Vault{door.name}`
	local panel, closed, open = createPanel(model, door, building)
	local prompt = createPrompt(panel)
	local glow = createGlow(model, door)
	local alarm, lamp = createAlarm(model, door)
	model.Parent = parent

	return {
		door = door,
		model = model,
		panel = panel,
		closedCFrame = closed,
		openCFrame = open,
		prompt = prompt,
		glow = glow,
		alarm = alarm,
		soundAnchor = lamp,
	}
end

function VaultProps.setGlow(props: DoorProps, enabled: boolean)
	local target = if enabled then 0.35 else 1
	TweenService:Create(props.glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Transparency = target }):Play()
	local light = props.glow:FindFirstChild("GlowLight")
	if light ~= nil and light:IsA("PointLight") then
		TweenService:Create(light, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Brightness = if enabled then 0.9 else 0 }):Play()
	end
	local sparkles = props.glow:FindFirstChild("GlowSparkles")
	if sparkles ~= nil and sparkles:IsA("ParticleEmitter") then
		sparkles.Enabled = enabled
	end
end

function VaultProps.setOpen(props: DoorProps, open: boolean, animate: boolean)
	local target = if open then props.openCFrame else props.closedCFrame
	props.panel.CanCollide = not open
	if animate then
		TweenService:Create(props.panel, TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = target }):Play()
	else
		props.panel.CFrame = target
	end
end

-- Luz vermelha piscando sobre a porta enquanto `isActive()` for verdadeiro.
function VaultProps.startAlarm(props: DoorProps, isActive: () -> boolean)
	task.spawn(function()
		local on = false
		while isActive() and props.alarm.Parent ~= nil do
			on = not on
			props.alarm.Brightness = if on then 2.2 else 0.2
			task.wait(0.35)
		end
		if props.alarm.Parent ~= nil then
			props.alarm.Brightness = 0
		end
	end)
end

function VaultProps.playSound(props: DoorProps, soundId: string, speed: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.RollOffMaxDistance = 60
	sound.Parent = props.soundAnchor
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(5, function()
		if sound.Parent ~= nil then
			sound:Destroy()
		end
	end)
end

-- Puffador do Cofre girando sobre o pedestal, com o prompt para pegá-lo.
function VaultProps.createPrize(parent: Instance, door: SecretDoor, building: BuildingConfig): (Model, ProximityPrompt, Part)
	local tool = PuffadorModel.build("Super", "VaultService", PuffadorModel.DisplayScale)
	local prize = Instance.new("Model")
	prize.Name = "SuperPuffadorPrize"
	local handle = tool:FindFirstChild("Handle") :: Part
	for _, child in ipairs(tool:GetChildren()) do
		child.Parent = prize
	end
	tool:Destroy()
	handle.Anchored = true
	prize.PrimaryPart = handle

	local top = SecretRoomBuilder.getPedestalTop(door, building)
	prize:PivotTo(CFrame.new(top + Vector3.new(0, 1.4, 0)))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Pegar"
	prompt.ObjectText = "Puffador do Cofre"
	prompt.HoldDuration = GameConfig.SecretRoom.GrabHoldDuration
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = handle

	prize.Parent = parent
	return prize, prompt, handle
end

return table.freeze(VaultProps)
