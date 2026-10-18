--!strict

-- Primeira pessoa do Assassinato no Casarão (Fase 5E.4): durante a partida a
-- câmera fica travada nos olhos (sem afastar com a rolagem, para ninguém
-- espiar por cima das paredes) e na tela aparecem só a mão e o item do
-- papel: a faca 3D do Assassino (KnifeMesh; abaixada enquanto guardada,
-- erguida quando à vista) ou o próprio Puffador do Xerife e do Herói (cópia
-- das peças da ferramenta que ele segura). A câmera não balança ao andar
-- (enjoa, principalmente as crianças). O modelo das mãos é só do cliente,
-- preso à câmera e invisível para raios.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local KnifeMesh = require(ReplicatedStorage.Shared.modules.KnifeMesh)
local CombatCameraController = require(script.Parent.CombatCameraController)

export type Item = "Knife" | "Gun"
export type Pulse = "Stab" | "Throw" | "Shot"

local RENDER_STEP_NAME = "BlocoPuffMurderViewmodel"
-- Depois da câmera padrão (o modelo segue a câmera já atualizada).
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
-- Distância mínima da câmera ao sair (volta à terceira pessoa).
local EXIT_ZOOM = 10

-- Mão direita na frente da câmera, um pouco abaixo e à direita, apontando
-- de leve para cima.
local BASE = CFrame.new(1.05, -1.05, -1.9) * CFrame.Angles(math.rad(12), math.rad(-8), 0)
local LOWERED = CFrame.new(0.1, -0.7, 0.4) * CFrame.Angles(math.rad(-30), math.rad(10), 0)
local CHARGED = CFrame.new(0.25, 0.35, 0.7) * CFrame.Angles(math.rad(40), 0, math.rad(-12))
local RAISE_RATE = 10
local TREMBLE = 0.035
local PULSE_SECONDS: { [Pulse]: number } = { Stab = 0.25, Throw = 0.45, Shot = 0.18 }
-- Depois do arremesso, a faca some da mão por esse tempo.
local THROW_EMPTY_SECONDS = 0.6

local ARM_SIZE = Vector3.new(0.42, 0.42, 2.3)
-- O braço sai um pouco mais escuro que a pele (com o brilho da luz, a cor
-- cheia vira um bloco claro demais).
local ARM_SHADE = 0.15
-- Faca na tela (1 = a malha original): na mão, girada para mostrar a
-- lateral da lâmina (de frente só se veria o fio).
local KNIFE_SCALE = 0.6
local KNIFE_GRIP = CFrame.new(0, 0.1, -0.1) * CFrame.Angles(math.rad(18), math.rad(12), math.rad(-60))
-- Puffador na tela: um pouco à frente e virado de lado (de trás só se veria
-- a tampa) e menor que o da mão do personagem (inteiro ele tapa a tela).
local GUN_GRIP = CFrame.new(0.15, -0.1, -0.9) * CFrame.Angles(math.rad(-10), math.rad(14), math.rad(-8))
local GUN_SCALE = 0.75
-- Peças que vão junto na cópia do Puffador (som, luz, efeitos e juntas não).
local GUN_KEEP_CLASSES = { "DataModelMesh", "Decal", "Texture", "SurfaceAppearance" }
local DEFAULT_SKIN = Color3.fromRGB(245, 205, 150)

type Piece = {
	part: BasePart,
	offset: CFrame,
	-- Parte do item (some depois do arremesso).
	isItem: boolean,
}

local MurderFirstPerson = {}

local enabled = false
local pieces: { Piece } = {}
local model: Model? = nil
local currentItem: Item? = nil
-- Ferramenta de onde sai a cópia do Puffador.
local currentSource: Tool? = nil
local raised = true
local raiseAlpha = 1
local charge = 0
local pulseKind: Pulse? = nil
local pulseAt = 0
local previousCameraMode = Enum.CameraMode.Classic
local previousFov = 70
local previousMouseIcon = true
local random = Random.new()

local function skinColor(): Color3
	local character = Players.LocalPlayer.Character
	if character == nil then
		return DEFAULT_SKIN
	end
	for _, name in ipairs({ "RightHand", "RightLowerArm", "Right Arm" }) do
		local part = character:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			return part.Color
		end
	end
	return DEFAULT_SKIN
end

local function addPart(parent: Model, part: BasePart, offset: CFrame, isItem: boolean)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	table.insert(pieces, { part = part, offset = offset, isItem = isItem })
end

local function addPiece(parent: Model, name: string, size: Vector3, color: Color3, material: Enum.Material, offset: CFrame, isItem: boolean)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	addPart(parent, part, offset, isItem)
end

local function keepInGunCopy(instance: Instance): boolean
	for _, className in ipairs(GUN_KEEP_CLASSES) do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

-- Cópia das peças do Puffador, cada uma na posição em relação à pega.
local function addGunCopy(parent: Model, tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return
	end
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			local copy = descendant:Clone()
			for _, child in ipairs(copy:GetChildren()) do
				if not keepInGunCopy(child) then
					child:Destroy()
				elseif child:IsA("SpecialMesh") then
					child.Scale *= GUN_SCALE
				end
			end
			copy.Size *= GUN_SCALE
			local relative = handle.CFrame:ToObjectSpace(descendant.CFrame)
			addPart(parent, copy, GUN_GRIP * CFrame.new(relative.Position * GUN_SCALE) * relative.Rotation, true)
		end
	end
end

local function destroyModel()
	local current = model
	if current ~= nil then
		current:Destroy()
	end
	model = nil
	table.clear(pieces)
end

-- Monta a mão com o item (o ponto de origem é a mão).
local function buildModel(item: Item, source: Tool?)
	destroyModel()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local newModel = Instance.new("Model")
	newModel.Name = "MurderViewmodel"
	addPiece(newModel, "Arm", ARM_SIZE, skinColor():Lerp(Color3.new(0, 0, 0), ARM_SHADE), Enum.Material.SmoothPlastic, CFrame.new(0, 0, ARM_SIZE.Z / 2), false)
	if item == "Knife" then
		addPart(newModel, KnifeMesh.part("Knife", KNIFE_SCALE), KNIFE_GRIP * KnifeMesh.inHand(KNIFE_SCALE), true)
	elseif source ~= nil then
		addGunCopy(newModel, source)
	end
	newModel.Parent = camera
	model = newModel
end

-- Animação curta do golpe, do arremesso ou do tiro (0 a 1 e de volta).
local function pulseOffset(now: number): (CFrame, boolean)
	local kind = pulseKind
	if kind == nil then
		return CFrame.identity, false
	end
	local elapsed = now - pulseAt
	local duration = PULSE_SECONDS[kind]
	local emptyHand = kind == "Throw" and elapsed < THROW_EMPTY_SECONDS
	if elapsed >= duration then
		if not emptyHand then
			pulseKind = nil
		end
		return CFrame.identity, emptyHand
	end
	local wave = math.sin(math.pi * elapsed / duration)
	if kind == "Stab" then
		return CFrame.new(-0.35 * wave, 0.15 * wave, -1.0 * wave) * CFrame.Angles(math.rad(-10) * wave, math.rad(20) * wave, 0), false
	elseif kind == "Throw" then
		return CFrame.new(-0.2 * wave, 0.2 * wave, -1.2 * wave) * CFrame.Angles(math.rad(-35) * wave, 0, 0), emptyHand
	end
	return CFrame.new(0, 0.05 * wave, 0.35 * wave) * CFrame.Angles(math.rad(14) * wave, 0, 0), false
end

-- O item de verdade (a ferramenta no corpo) não aparece em primeira pessoa:
-- ficaria solto perto da cintura.
local function hideRealTools()
	local character = Players.LocalPlayer.Character
	if character == nil then
		return
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			for _, part in ipairs(child:GetDescendants()) do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

local function onRender(deltaTime: number)
	local camera = Workspace.CurrentCamera
	hideRealTools()
	if camera == nil or model == nil then
		return
	end
	local now = os.clock()
	local target = if raised then 1 else 0
	raiseAlpha += (target - raiseAlpha) * math.clamp(deltaTime * RAISE_RATE, 0, 1)
	local pose = LOWERED:Lerp(CFrame.identity, raiseAlpha)
	if charge > 0 then
		pose = pose * CFrame.identity:Lerp(CHARGED, charge)
		if charge >= 1 then
			pose = pose * CFrame.new(random:NextNumber(-TREMBLE, TREMBLE), random:NextNumber(-TREMBLE, TREMBLE), 0)
		end
	end
	local pulse, emptyHand = pulseOffset(now)
	local root = camera.CFrame * BASE * pose * pulse
	for _, piece in ipairs(pieces) do
		piece.part.CFrame = root * piece.offset
		-- (o tanque de vidro do Puffador tem transparência própria)
		piece.part.LocalTransparencyModifier = if piece.isItem and emptyHand then 1 else 0
	end
end

function MurderFirstPerson.enable()
	if enabled then
		return
	end
	enabled = true
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	-- A câmera de combate (sobre o ombro) brigaria com a primeira pessoa.
	-- Desliga antes de guardar o estado, para guardar o de fora do combate.
	CombatCameraController.setSuppressed(true)
	previousCameraMode = player.CameraMode
	previousMouseIcon = UserInputService.MouseIconEnabled
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	if camera ~= nil then
		previousFov = camera.FieldOfView
		camera.FieldOfView = MysteryModeConfig.FirstPersonFov
	end
	-- A mira do modo fica no centro; o cursor do mouse some.
	UserInputService.MouseIconEnabled = false
	local item = currentItem
	if item ~= nil then
		buildModel(item, currentSource)
	end
	RunService:BindToRenderStep(RENDER_STEP_NAME, RENDER_PRIORITY, onRender)
end

function MurderFirstPerson.disable()
	if not enabled then
		return
	end
	enabled = false
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	destroyModel()
	charge = 0
	pulseKind = nil
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	player.CameraMode = previousCameraMode
	if camera ~= nil then
		camera.FieldOfView = previousFov
	end
	UserInputService.MouseIconEnabled = previousMouseIcon
	-- Afasta a câmera de volta para a terceira pessoa.
	local minZoom = player.CameraMinZoomDistance
	player.CameraMinZoomDistance = math.min(EXIT_ZOOM, player.CameraMaxZoomDistance)
	task.defer(function()
		player.CameraMinZoomDistance = minZoom
	end)
	CombatCameraController.setSuppressed(false)
end

function MurderFirstPerson.isEnabled(): boolean
	return enabled
end

-- Item na mão (nil: mãos vazias, nada na tela). Para a arma, `source` é o
-- Puffador que o personagem segura (a tela mostra uma cópia dele).
function MurderFirstPerson.setItem(item: Item?, source: Tool?)
	if item == currentItem and source == currentSource then
		return
	end
	currentItem = item
	currentSource = source
	charge = 0
	pulseKind = nil
	if not enabled then
		return
	end
	if item == nil then
		destroyModel()
	else
		buildModel(item, source)
	end
end

-- Faca à vista (erguida) ou guardada (abaixada).
function MurderFirstPerson.setRaised(value: boolean)
	raised = value
end

-- Carga do arremesso (0 a 1; cheia, a mão treme).
function MurderFirstPerson.setCharge(value: number)
	charge = math.clamp(value, 0, 1)
end

function MurderFirstPerson.pulse(kind: Pulse)
	pulseKind = kind
	pulseAt = os.clock()
	charge = 0
end

return table.freeze(MurderFirstPerson)
