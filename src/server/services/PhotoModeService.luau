--!strict

-- Modo foto para capas e thumbnails da loja. Só existe no Studio: monta
-- cenas de ação repetíveis (bonecos em pose com o Puffador, buracos no piso,
-- projéteis e pedaços congelados no ar) e posiciona a câmera.
--
-- Uso: aperte Run (F8) e, na barra de comandos, rode por exemplo
--   workspace:SetAttribute("PhotoScene", "acao")
-- Cenas: "acao", "queda", "icone", "lobby". Para limpar, use "".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ArenaService = require(script.Parent.ArenaService)

type Pose = "Aim" | "AimUp" | "Fall" | "Cheer" | "Idle"

type ActorSpec = {
	position: Vector3,
	lookAt: Vector3,
	pose: Pose,
	colorIndex: number,
	withPuffador: boolean,
}

type Scene = {
	holes: { Vector3 },
	actors: { ActorSpec },
	shots: { { from: Vector3, to: Vector3 } },
	debris: { Vector3 },
	camera: CFrame,
	fieldOfView: number,
}

local SCENE_ATTRIBUTE = "PhotoScene"
local FOLDER_NAME = "PhotoMode"
local SHIRT_COLORS = {
	Color3.fromRGB(169, 139, 255),
	Color3.fromRGB(255, 209, 102),
	Color3.fromRGB(92, 200, 255),
	Color3.fromRGB(255, 122, 186),
	Color3.fromRGB(79, 214, 160),
	Color3.fromRGB(255, 159, 67),
}
local SKIN_COLORS = {
	Color3.fromRGB(255, 214, 170),
	Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(240, 190, 150),
	Color3.fromRGB(140, 94, 66),
}
local PANTS_COLOR = Color3.fromRGB(44, 40, 66)

local PhotoModeService = {}

local folder: Folder? = nil
local sceneGeneration = 0

-- Centro do bloco (linha, coluna) de um piso; 1 = piso mais baixo.
local function blockCenter(floorIndex: number, row: number, column: number): Vector3
	local arena = GameConfig.Arena
	local width, depth = BuildingLayout.getFloorSize(arena)
	local stepX = arena.BlockSize.X + arena.BlockGap
	local stepZ = arena.BlockSize.Z + arena.BlockGap
	return Vector3.new(
		arena.Position.X - (width / 2) + (arena.BlockSize.X / 2) + ((column - 1) * stepX),
		BuildingLayout.getFloorY(arena, floorIndex),
		arena.Position.Z - (depth / 2) + (arena.BlockSize.Z / 2) + ((row - 1) * stepZ)
	)
end

-- Ponto em pé sobre um bloco (altura da raiz do personagem R15).
local function standingOn(floorIndex: number, row: number, column: number): Vector3
	return blockCenter(floorIndex, row, column) + Vector3.new(0, (GameConfig.Arena.BlockSize.Y / 2) + 3, 0)
end

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

local function openHole(center: Vector3)
	for _, block in ipairs(ArenaService.getBlocks()) do
		if (block.Position - center).Magnitude < 0.5 then
			block.Transparency = 1
			block.CanCollide = false
			block.CanQuery = false
			block:SetAttribute(ArenaConstants.IsDestroyedAttribute, true)
		end
	end
end

local function rotateJoint(model: Model, jointName: string, rotation: CFrame)
	local joint = model:FindFirstChild(jointName, true)
	if joint ~= nil and joint:IsA("Motor6D") then
		joint.C0 = joint.C0 * rotation
	end
end

local function applyPose(model: Model, pose: Pose)
	if pose == "Aim" then
		rotateJoint(model, "RightShoulder", CFrame.Angles(math.rad(90), 0, 0))
		rotateJoint(model, "LeftShoulder", CFrame.Angles(math.rad(80), math.rad(-35), 0))
	elseif pose == "AimUp" then
		rotateJoint(model, "RightShoulder", CFrame.Angles(math.rad(150), 0, 0))
		rotateJoint(model, "LeftShoulder", CFrame.Angles(math.rad(140), math.rad(-30), 0))
		rotateJoint(model, "Neck", CFrame.Angles(math.rad(30), 0, 0))
	elseif pose == "Fall" then
		rotateJoint(model, "RightShoulder", CFrame.Angles(math.rad(160), 0, math.rad(25)))
		rotateJoint(model, "LeftShoulder", CFrame.Angles(math.rad(160), 0, math.rad(-25)))
		rotateJoint(model, "RightHip", CFrame.Angles(math.rad(-20), 0, math.rad(20)))
		rotateJoint(model, "LeftHip", CFrame.Angles(math.rad(25), 0, math.rad(-20)))
		rotateJoint(model, "Neck", CFrame.Angles(math.rad(25), 0, 0))
	elseif pose == "Cheer" then
		rotateJoint(model, "RightShoulder", CFrame.Angles(math.rad(165), 0, math.rad(20)))
		rotateJoint(model, "LeftShoulder", CFrame.Angles(math.rad(165), 0, math.rad(-20)))
	end
end

local function attachPuffador(model: Model)
	local hand = model:FindFirstChild("RightHand")
	if hand == nil or not hand:IsA("BasePart") then
		return
	end
	-- Mesma silhueta do Puffador real: cabo dourado, cano lilás e boca dourada,
	-- apontando para onde a mão aponta.
	local base = hand.CFrame * CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	local parts = {
		createPart(model, "PuffadorHandle", Vector3.new(0.6, 0.6, 2), base, PuffadorConstants.PuffadorAccentColor, Enum.Material.SmoothPlastic),
		createPart(model, "PuffadorBarrel", Vector3.new(1.6, 0.9, 0.9), base * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(90), 0), PuffadorConstants.PuffadorPrimaryColor, Enum.Material.SmoothPlastic),
		createPart(model, "PuffadorBell", Vector3.new(1, 1, 1), base * CFrame.new(0, 0, -2.1), PuffadorConstants.PuffadorAccentColor, Enum.Material.SmoothPlastic),
	}
	parts[2].Shape = Enum.PartType.Cylinder
	parts[3].Shape = Enum.PartType.Ball
end

local function buildDescription(colorIndex: number): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local shirt = SHIRT_COLORS[((colorIndex - 1) % #SHIRT_COLORS) + 1]
	local skin = SKIN_COLORS[((colorIndex - 1) % #SKIN_COLORS) + 1]
	description.HeadColor = skin
	description.TorsoColor = shirt
	description.LeftArmColor = shirt
	description.RightArmColor = shirt
	description.LeftLegColor = PANTS_COLOR
	description.RightLegColor = PANTS_COLOR
	return description
end

local function spawnActor(parent: Instance, spec: ActorSpec, index: number)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(buildDescription(spec.colorIndex), Enum.HumanoidRigType.R15)
	end)
	if not ok or result == nil then
		warn(string.format("[BlocoPuff][PhotoMode] Could not create actor %d: %s", index, tostring(result)))
		return
	end

	local model = result :: Model
	model.Name = string.format("Actor%02d", index)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end

	local flatTarget = Vector3.new(spec.lookAt.X, spec.position.Y, spec.lookAt.Z)
	model:PivotTo(CFrame.lookAt(spec.position, flatTarget))
	model.Parent = parent
	applyPose(model, spec.pose)
	if spec.withPuffador then
		-- A pose é aplicada pelas juntas; espera um quadro para a mão chegar
		-- à posição final antes de encaixar a arma.
		RunService.Heartbeat:Wait()
		attachPuffador(model)
	end
end

-- Projétil "congelado" com rastro alongado, simulando o movimento.
local function createShot(parent: Instance, from: Vector3, to: Vector3)
	local direction = to - from
	local length = direction.Magnitude
	if length < 0.1 then
		return
	end
	local midpoint = from + (direction / 2)
	local streak = createPart(parent, "ShotStreak", Vector3.new(length, 0.5, 0.5), CFrame.lookAt(midpoint, to) * CFrame.Angles(0, math.rad(90), 0), PuffadorConstants.PuffadorAccentColor, Enum.Material.Neon)
	streak.Shape = Enum.PartType.Cylinder
	streak.Transparency = 0.45
	local head = createPart(parent, "ShotHead", Vector3.new(1.6, 1.6, 1.6), CFrame.new(to), PuffadorConstants.ProjectileColor, Enum.Material.Neon)
	head.Shape = Enum.PartType.Ball
	local glow = Instance.new("PointLight")
	glow.Color = PuffadorConstants.PuffadorAccentColor
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Parent = head
end

-- Pedaços de um bloco caindo logo abaixo de um buraco.
local function createDebris(parent: Instance, holeCenter: Vector3, random: Random)
	local arena = GameConfig.Arena
	for index = 1, 4 do
		local offset = Vector3.new(random:NextNumber(-2.5, 2.5), -random:NextNumber(1.5, 6), random:NextNumber(-2.5, 2.5))
		local tilt = CFrame.Angles(math.rad(random:NextNumber(-50, 50)), math.rad(random:NextNumber(-50, 50)), math.rad(random:NextNumber(-50, 50)))
		local style = arena.FloorStyles[math.min(arena.FloorCount, #arena.FloorStyles)]
		createPart(
			parent,
			string.format("Debris%02d", index),
			Vector3.new(arena.BlockSize.X / 2.2, arena.BlockSize.Y, arena.BlockSize.Z / 2.2),
			CFrame.new(holeCenter + offset) * tilt,
			style.Colors[((index - 1) % #style.Colors) + 1],
			style.Material
		)
	end
end

local function getScene(name: string): Scene?
	local top = GameConfig.Arena.FloorCount
	local lowerFloor = math.max(1, top - 1)
	local gallery = BuildingLayout.getGallery(GameConfig.Arena, GameConfig.Building)
	local muzzleHeight = Vector3.new(0, 1.2, 0)

	if name == "acao" then
		local shooterA = standingOn(top, 5, 5)
		local shooterB = standingOn(top, 11, 11)
		return {
			holes = { blockCenter(top, 8, 8), blockCenter(top, 8, 9), blockCenter(top, 9, 8), blockCenter(top, 7, 10), blockCenter(top, 10, 6) },
			actors = {
				{ position = shooterA, lookAt = blockCenter(top, 9, 9), pose = "Aim", colorIndex = 1, withPuffador = true },
				{ position = shooterB, lookAt = blockCenter(top, 8, 8), pose = "Aim", colorIndex = 2, withPuffador = true },
				{ position = blockCenter(top, 8, 8) + Vector3.new(0, -2, 0), lookAt = shooterA, pose = "Fall", colorIndex = 3, withPuffador = false },
				{ position = standingOn(top, 12, 5), lookAt = blockCenter(top, 10, 6), pose = "Cheer", colorIndex = 4, withPuffador = true },
			},
			shots = {
				{ from = shooterA + muzzleHeight + Vector3.new(1.5, 0, 1.5), to = blockCenter(top, 9, 10) + Vector3.new(0, 1, 0) },
				{ from = shooterB + muzzleHeight - Vector3.new(1.5, 0, 1.5), to = blockCenter(top, 9, 8) + Vector3.new(0, 1.5, 0) },
			},
			debris = { blockCenter(top, 9, 8), blockCenter(top, 7, 10) },
			camera = CFrame.lookAt(blockCenter(top, 1, 2) + Vector3.new(0, 20, 2), blockCenter(top, 9, 9)),
			fieldOfView = 55,
		}
	elseif name == "queda" then
		local hole = blockCenter(top, 8, 8)
		local shooterBelow = standingOn(lowerFloor, 11, 6)
		return {
			holes = { hole, blockCenter(top, 8, 9), blockCenter(top, 7, 8), blockCenter(top, 5, 11) },
			actors = {
				{ position = hole + Vector3.new(0, -6, 0), lookAt = shooterBelow, pose = "Fall", colorIndex = 2, withPuffador = false },
				{ position = shooterBelow, lookAt = blockCenter(top, 7, 7), pose = "AimUp", colorIndex = 5, withPuffador = true },
			},
			shots = {
				{ from = shooterBelow + Vector3.new(0, 3, -1), to = blockCenter(top, 7, 7) + Vector3.new(0, -1, 0) },
			},
			debris = { hole, blockCenter(top, 7, 8) },
			camera = CFrame.lookAt(standingOn(lowerFloor, 12, 10) + Vector3.new(0, 1, 0), hole + Vector3.new(0, -4, 0)),
			fieldOfView = 62,
		}
	elseif name == "icone" then
		local hero = standingOn(top, 8, 8)
		local cameraPosition = hero + Vector3.new(4, 1.5, -10)
		return {
			holes = { blockCenter(top, 8, 9), blockCenter(top, 9, 9), blockCenter(top, 7, 7) },
			actors = {
				{ position = hero, lookAt = cameraPosition, pose = "Aim", colorIndex = 1, withPuffador = true },
			},
			shots = {
				{ from = hero + muzzleHeight + Vector3.new(0.8, 0, -2.5), to = hero + muzzleHeight + Vector3.new(2.4, 0.3, -7) },
			},
			debris = { blockCenter(top, 8, 9) },
			camera = CFrame.lookAt(cameraPosition, hero + Vector3.new(0, 1.2, 0)),
			fieldOfView = 40,
		}
	elseif name == "lobby" then
		local glassX = gallery.innerX + 2.5
		local y = gallery.floorY + 3
		local actors: { ActorSpec } = {}
		for index = 1, 4 do
			local position = Vector3.new(glassX + ((index % 2) * 2), y, gallery.center.Z + ((index - 2.5) * 5))
			table.insert(actors, {
				position = position,
				lookAt = position + Vector3.new(-10, 0, 0),
				pose = if index == 2 then "Cheer" else "Idle",
				colorIndex = index + 1,
				withPuffador = false,
			})
		end
		return {
			holes = { blockCenter(top, 8, 5), blockCenter(top, 9, 6) },
			actors = actors,
			shots = {},
			debris = {},
			camera = CFrame.lookAt(
				Vector3.new(gallery.innerX + GameConfig.Building.GalleryDepth - 3, y + 4, gallery.center.Z + 16),
				Vector3.new(GameConfig.Arena.Position.X, BuildingLayout.getTopFloorY(GameConfig.Arena), GameConfig.Arena.Position.Z)
			),
			fieldOfView = 60,
		}
	end
	return nil
end

function PhotoModeService.clear()
	sceneGeneration += 1
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
	ArenaService.restoreAllBlocks()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
end

function PhotoModeService.show(name: string)
	PhotoModeService.clear()
	local scene = getScene(name)
	if scene == nil then
		warn(`[BlocoPuff][PhotoMode] Unknown scene "{name}". Use: acao, queda, icone, lobby`)
		return
	end
	local generation = sceneGeneration

	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	newFolder.Parent = Workspace
	folder = newFolder

	for _, hole in ipairs(scene.holes) do
		openHole(hole)
	end
	local random = Random.new(7)
	for _, center in ipairs(scene.debris) do
		createDebris(newFolder, center, random)
	end
	for _, shot in ipairs(scene.shots) do
		createShot(newFolder, shot.from, shot.to)
	end

	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = scene.fieldOfView
		camera.CFrame = scene.camera
	end

	for index, actor in ipairs(scene.actors) do
		if generation ~= sceneGeneration then
			return
		end
		spawnActor(newFolder, actor, index)
	end
	print(`[BlocoPuff][PhotoMode] Scene "{name}" ready. Clear with workspace:SetAttribute("{SCENE_ATTRIBUTE}", "")`)
end

function PhotoModeService.start()
	if not RunService:IsStudio() then
		return
	end
	Workspace:GetAttributeChangedSignal(SCENE_ATTRIBUTE):Connect(function()
		local value = Workspace:GetAttribute(SCENE_ATTRIBUTE)
		task.spawn(function()
			if type(value) == "string" and value ~= "" then
				PhotoModeService.show(value)
			else
				PhotoModeService.clear()
			end
		end)
	end)
end

return table.freeze(PhotoModeService)
