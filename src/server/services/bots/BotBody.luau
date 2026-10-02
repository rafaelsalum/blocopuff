--!strict

-- Corpo de um bot RoboPuff (Fase 5B): um personagem R15 do servidor com as
-- cores de Puff, uma antena (para ninguém confundir com um jogador), o nome
-- com a etiqueta 🤖 e o Puffador na mão. A física é do servidor (sem dono
-- na rede) e as animações padrão tocam pelo Animator do servidor, porque o
-- script Animate do avatar só roda no personagem de um jogador.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PuffadorModel = require(script.Parent.Parent.PuffadorModel)

local SERVICE_NAME = "BotFillService"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"

-- Animações padrão do avatar R15 do Roblox.
local ANIMATIONS = table.freeze({
	Idle = "rbxassetid://507766666",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
	Hold = "rbxassetid://507768375",
})
local RUN_SPEED_THRESHOLD = 0.75

local BotBody = {}

local function describe(color: Color3): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = color
	description.TorsoColor = color
	description.LeftArmColor = color
	description.RightArmColor = color
	description.LeftLegColor = color:Lerp(Color3.new(0, 0, 0), 0.15)
	description.RightLegColor = color:Lerp(Color3.new(0, 0, 0), 0.15)
	return description
end

local function addAntenna(model: Model)
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local stick = Instance.new("Part")
	stick.Name = "AntennaStick"
	stick.Size = Vector3.new(0.12, 0.7, 0.12)
	stick.Color = Color3.fromRGB(70, 70, 80)
	stick.Material = Enum.Material.Metal
	stick.CanCollide = false
	stick.CanQuery = false
	stick.CanTouch = false
	stick.Massless = true
	stick.CFrame = head.CFrame * CFrame.new(0, (head.Size.Y / 2) + 0.35, 0)
	stick.Parent = model
	local ball = Instance.new("Part")
	ball.Name = "AntennaBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.35, 0.35, 0.35)
	ball.Color = BotConfig.Body.AntennaColor
	ball.Material = Enum.Material.Neon
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Massless = true
	ball.CFrame = stick.CFrame * CFrame.new(0, 0.4, 0)
	ball.Parent = model
	for _, part in ipairs({ stick, ball }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end
end

-- Toca idle/correr/pular/cair conforme o Humanoid. As conexões morrem com o
-- corpo.
local function animate(humanoid: Humanoid)
	local animator: Animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks: { [string]: AnimationTrack } = {}
	for key, id in pairs(ANIMATIONS) do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok then
			tracks[key] = track
		end
	end
	local currentKey = ""
	local function play(key: string)
		local track = tracks[key]
		if key == currentKey or not track then
			return
		end
		local previous = tracks[currentKey]
		if previous then
			previous:Stop(0.15)
		end
		currentKey = key
		track:Play(0.15)
	end
	local hold = tracks.Hold
	if hold then
		hold.Priority = Enum.AnimationPriority.Action
		hold:Play()
	end
	play("Idle")
	humanoid.Running:Connect(function(speed: number)
		play(if speed > RUN_SPEED_THRESHOLD then "Run" else "Idle")
	end)
	humanoid.Jumping:Connect(function(active: boolean)
		if active then
			play("Jump")
		end
	end)
	humanoid.FreeFalling:Connect(function(active: boolean)
		if active then
			play("Fall")
		end
	end)
end

local function giveServerPhysics(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(nil)
			end)
		end
	end
end

-- Nome, etiqueta, antena, Puffador, física e animações.
local function dress(model: Model, id: number, name: string, parent: Instance, cframe: CFrame)
	model.Name = `RoboPuff_{name}`
	model:SetAttribute(StateAttributeNames.BotId, id)
	CollectionService:AddTag(model, StateAttributeNames.BotTag)
	model:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	local animateScript = model:FindFirstChild("Animate")
	if animateScript ~= nil then
		animateScript:Destroy()
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		error("avatar without Humanoid")
	end
	humanoid.DisplayName = `{BotConfig.Body.Tag} {name}`
	humanoid.WalkSpeed = BotConfig.Body.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	addAntenna(model)

	local tool = PuffadorModel.build("Standard", SERVICE_NAME)
	tool.Parent = model
	model:PivotTo(cframe)
	model.Parent = parent
	humanoid:EquipTool(tool)
	giveServerPhysics(model)
	animate(humanoid)
end

-- Monta o corpo em `cframe`, dentro de `parent`. nil se o Roblox não
-- conseguir criar o avatar (o bot simplesmente não vem).
function BotBody.build(id: number, name: string, colorIndex: number, parent: Instance, cframe: CFrame): Model?
	local colors = BotConfig.Body.Colors
	local color = colors[((colorIndex - 1) % #colors) + 1]
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(color), Enum.HumanoidRigType.R15)
	end)
	if not ok or result == nil then
		warn(`[BlocoPuff] Could not build RoboPuff {name}: {result}`)
		return nil
	end
	local model: Model = result
	local built, failure = pcall(function()
		dress(model, id, name, parent, cframe)
	end)
	if not built then
		model:Destroy()
		warn(`[BlocoPuff] Could not dress RoboPuff {name}: {failure}`)
		return nil
	end
	return model
end

return table.freeze(BotBody)
