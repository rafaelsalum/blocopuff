--!strict

-- Arma do Xerife caída no Assassinato no Casarão (Fase 5E.4): o próprio
-- Puffador (PuffadorModel), um pouco maior que o da mão, girando devagar
-- acima do chão, com brilho e um feixe de luz azul visíveis de longe.
-- Qualquer Inocente humano vivo que chegar perto pega e vira o Herói (quem
-- decide é o modo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local PuffadorModel = require(script.Parent.PuffadorModel)

local SERVICE_NAME = "MurderGunDrop"
local GLOW_COLOR = Color3.fromRGB(110, 170, 255)
local SCALE = 1.3
local HOVER_HEIGHT = 1.6
local BOB_HEIGHT = 0.25
local BOB_SPEED = 2
local SPIN_SPEED = 1.2
local BEAM_HEIGHT = 13

local MurderGunDrop = {}

local function anchorAll(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		elseif descendant:IsA("Sound") or descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

-- O Puffador como modelo (sem ser ferramenta), com a pega como peça
-- principal.
local function puffadorModel(): Model
	local tool = PuffadorModel.build("Standard", SERVICE_NAME, SCALE)
	local model = Instance.new("Model")
	model.Name = "DroppedSheriffGun"
	local handle: BasePart? = nil
	for _, child in ipairs(tool:GetChildren()) do
		child.Parent = model
		if child:IsA("BasePart") and handle == nil and child.Name == PuffadorConstants.HandleName then
			handle = child
		end
	end
	tool:Destroy()
	model.PrimaryPart = handle
	anchorAll(model)
	return model
end

local function beam(model: Model, floor: Vector3)
	local part = Instance.new("Part")
	part.Name = "Beam"
	part.Color = GLOW_COLOR
	part.Material = Enum.Material.Neon
	part.Transparency = 0.6
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(0.5, BEAM_HEIGHT, 0.5)
	part.CFrame = CFrame.new(floor + Vector3.new(0, BEAM_HEIGHT / 2, 0))
	part.Parent = model
	local light = Instance.new("PointLight")
	light.Color = GLOW_COLOR
	light.Range = 14
	light.Brightness = 3
	light.Parent = part
end

-- Puffador caído em `floor` (ponto no chão). O modelo para de girar quando
-- é destruído.
function MurderGunDrop.build(floor: Vector3, parent: Instance): Model
	local model = puffadorModel()
	beam(model, floor)
	local gun = model.PrimaryPart
	local beamPart = model:FindFirstChild("Beam")
	-- Só o Puffador gira; o feixe fica parado. Peças do Puffador presas à
	-- pega por posição relativa.
	local offsets: { [BasePart]: CFrame } = {}
	if gun ~= nil then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= beamPart then
				offsets[descendant] = gun.CFrame:ToObjectSpace(descendant.CFrame)
			end
		end
	end
	local phase = math.random() * math.pi * 2
	local function place()
		local t = os.clock() + phase
		local lift = HOVER_HEIGHT + math.sin(t * BOB_SPEED) * BOB_HEIGHT
		local at = CFrame.new(floor + Vector3.new(0, lift, 0)) * CFrame.Angles(0, t * SPIN_SPEED, 0)
		for part, offset in pairs(offsets) do
			part.CFrame = at * offset
		end
	end
	place()
	model.Parent = parent
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if model.Parent == nil then
			connection:Disconnect()
			return
		end
		place()
	end)
	return model
end

return table.freeze(MurderGunDrop)
