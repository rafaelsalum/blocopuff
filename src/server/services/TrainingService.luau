--!strict

-- Área de treino do lobby, na sala de Treino do Casarão (ala sul): quem
-- passa da faixa verde (e não está competindo) recebe um Puffador de treino
-- e pratica a mira em alvos (fixos e dois que deslizam). Os disparos de
-- treino só acertam os alvos: não quebram bloco, não empurram ninguém e não
-- contam estatística (ver ProjectileService/PuffadorService). Sair do
-- tapete, entrar na partida ou sair do jogo tira o Puffador de treino.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ProjectileService = require(script.Parent.ProjectileService)
local PuffadorService = require(script.Parent.PuffadorService)
local TelemetryService = require(script.Parent.TelemetryService)

local FOLDER_NAME = "TrainingRange"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "TrainingService"
local TARGET_ATTRIBUTE = "TrainingTarget"
local HANDLER_KEY = "Training"
-- Profundidade da área (a partir da parede sul) e folga das paredes laterais.
local ZONE_LENGTH = 20
local ZONE_SIDE_INSET = 1.5
local FIXED_TARGETS = 6
local CHECK_INTERVAL = 0.25
local TARGET_COLOR = Color3.fromRGB(255, 93, 115)
local TARGET_HIT_COLOR = Color3.fromRGB(255, 209, 102)
local HIT_SOUND = "rbxasset://sounds/electronicpingshort.wav"

type Session = {
	startedAt: number,
	hits: number,
}

local TrainingService = {}

local started = false
local zoneMin = Vector3.zero
local zoneMax = Vector3.zero
local sessions: { [Player]: Session } = {}
local accumulator = 0

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Anchored = true
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = color
	instance.Material = material or Enum.Material.SmoothPlastic
	if shape ~= nil then
		instance.Shape = shape
	end
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Parent = parent
	return instance
end

-- Alvo redondo virado para o norte (−Z), de onde vêm os disparos.
local function createTarget(parent: Instance, name: string, center: Vector3): Part
	local target = part(parent, name, Vector3.new(0.4, 2.6, 2.6), CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0), TARGET_COLOR, Enum.Material.Neon, Enum.PartType.Cylinder)
	target:SetAttribute(TARGET_ATTRIBUTE, true)
	local bullseye = part(parent, `{name}Center`, Vector3.new(0.5, 0.9, 0.9), target.CFrame, Color3.fromRGB(255, 255, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	bullseye.CanCollide = false
	bullseye:SetAttribute(TARGET_ATTRIBUTE, true)
	return target
end

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function inZone(position: Vector3): boolean
	return position.X >= zoneMin.X
		and position.X <= zoneMax.X
		and position.Y >= zoneMin.Y
		and position.Y <= zoneMax.Y
		and position.Z >= zoneMin.Z
		and position.Z <= zoneMax.Z
end

local function endSession(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	PuffadorService.setTraining(player, false)
	TelemetryService.lobbyEvent(player, "TrainingSession", session.hits, `Seconds{math.floor(os.clock() - session.startedAt)}`)
end

local function check()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local inside = root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0 and inZone(root.Position)
		if inside and not isCompeting(player) then
			-- Também devolve o Puffador de treino depois do fim de uma
			-- partida (o PuffadorService recolhe todos).
			if sessions[player] == nil then
				sessions[player] = { startedAt = os.clock(), hits = 0 }
			end
			if not PuffadorService.isTraining(player) then
				PuffadorService.setTraining(player, true)
			end
		elseif sessions[player] ~= nil then
			endSession(player)
		end
	end
end

local function onSurfaceHit(shooter: Player, instance: Instance, _position: Vector3)
	if instance:GetAttribute(TARGET_ATTRIBUTE) ~= true or not instance:IsA("BasePart") then
		return
	end
	local session = sessions[shooter]
	if session == nil then
		return
	end
	session.hits += 1
	PuffadorService.sendFeedback(shooter, "Hit", nil)
	local target = instance
	target.Color = TARGET_HIT_COLOR
	TweenService:Create(target, TweenInfo.new(0.35), { Color = if target.Name:find("Center") then Color3.fromRGB(255, 255, 255) else TARGET_COLOR }):Play()
	local sound = Instance.new("Sound")
	sound.SoundId = HIT_SOUND
	sound.Volume = 0.4
	sound.PlaybackSpeed = 1.3
	sound.Parent = target
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

function TrainingService.start(worldRoot: Model)
	if started then
		return
	end
	started = true
	local existing = worldRoot:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	folder.Parent = worldRoot

	local room = MansionLayout.room("Training")
	local floorY = MansionLayout.get().floorY
	local zMax = room.maxZ
	local xMin = room.minX + ZONE_SIDE_INSET
	local xMax = room.maxX - ZONE_SIDE_INSET
	local zoneStart = zMax - ZONE_LENGTH
	zoneMin = Vector3.new(xMin, floorY - 2, zoneStart)
	zoneMax = Vector3.new(xMax, floorY + 14, zMax)

	-- Faixa que marca a área.
	local matCenter = Vector3.new((xMin + xMax) / 2, floorY + 0.06, zoneStart + 1.5)
	local mat = part(folder, "TrainingMat", Vector3.new(xMax - xMin, 0.12, 3), CFrame.new(matCenter), Color3.fromRGB(79, 214, 160), Enum.Material.Fabric)
	mat.CanCollide = false
	local signGui = Instance.new("BillboardGui")
	signGui.Size = UDim2.new(9, 0, 2.2, 0)
	signGui.StudsOffset = Vector3.new(0, 5, 0)
	signGui.MaxDistance = 60
	signGui.LightInfluence = 0
	signGui.Parent = mat
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = "🎯 TREINO"
	title.TextColor3 = Color3.fromRGB(255, 209, 102)
	title.TextScaled = true
	title.TextStrokeTransparency = 0.2
	title.Parent = signGui
	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromScale(0, 0.6)
	subtitle.Size = UDim2.fromScale(1, 0.4)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = "Passe da faixa verde e pratique a mira"
	subtitle.TextColor3 = Color3.fromRGB(255, 248, 238)
	subtitle.TextScaled = true
	subtitle.TextStrokeTransparency = 0.3
	subtitle.Parent = signGui

	-- Alvos perto da parede sul, em alturas variadas.
	local targetZ = zMax - 1.4
	local left = xMin + 4
	local right = xMax - 4
	local heights = { 3, 5.5, 3.5, 7, 4, 6 }
	for index = 1, FIXED_TARGETS do
		local x = left + ((index - 1) / (FIXED_TARGETS - 1)) * (right - left)
		createTarget(folder, `Target{index}`, Vector3.new(x, floorY + heights[((index - 1) % #heights) + 1], targetZ))
	end
	-- Dois alvos que deslizam, em sentidos opostos.
	for index, height in ipairs({ 9.5, 12 }) do
		local name = `TargetMoving{index}`
		local startX = if index == 1 then left else right
		local mover = createTarget(folder, name, Vector3.new(startX, floorY + height, targetZ))
		local moverCenter = folder:FindFirstChild(`{name}Center`)
		local delta = Vector3.new(if index == 1 then right - left else left - right, 0, 0)
		local slide = TweenInfo.new(3 + index, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(mover, slide, { CFrame = mover.CFrame + delta }):Play()
		if moverCenter ~= nil and moverCenter:IsA("BasePart") then
			TweenService:Create(moverCenter, slide, { CFrame = moverCenter.CFrame + delta }):Play()
		end
	end

	ProjectileService.setSurfaceHitHandler(HANDLER_KEY, onSurfaceHit)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0
		check()
	end)
	Players.PlayerRemoving:Connect(endSession)
end

return table.freeze(TrainingService)
