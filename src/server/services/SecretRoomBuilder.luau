--!strict

-- Arquitetura estática de cada sala secreta ("Cofre do Barão Puff"), do lado
-- de fora das portas do andar de baixo: piso firme, paredes com lambri
-- escuro, cofres de parede, o grande disco de cofre ao fundo e o pedestal
-- onde o VaultService expõe o Puffador do Cofre. Nada aqui muda durante a
-- partida; portas, alarmes e prêmio são do VaultService.
--
-- Espaço local da sala: X ao longo da parede, Y para cima e Z para fora do
-- prédio. A origem é o centro da porta, na face interna da parede e no nível
-- do piso; o interior vai de Z = espessura da parede até espessura + fundo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)

type BuildingConfig = GameConfig.BuildingConfig
type SecretDoor = BuildingLayout.SecretDoor

local SHELL_THICKNESS = 1
local PANEL_COLOR = Color3.fromRGB(70, 44, 32)
local FLOOR_COLOR = Color3.fromRGB(58, 50, 54)
local RUG_COLOR = Color3.fromRGB(120, 28, 40)
local STEEL_COLOR = Color3.fromRGB(96, 100, 110)
local GOLD_COLOR = Color3.fromRGB(230, 180, 70)
local ROOM_LIGHT_COLOR = Color3.fromRGB(255, 214, 150)
local LOCKER_SIZE = 1.4
local LOCKER_GAP = 0.2

local SecretRoomBuilder = {}

-- Referencial da sala: fromMatrix(along, up) deixa +Z apontando para fora.
function SecretRoomBuilder.getFrame(door: SecretDoor): CFrame
	return CFrame.fromMatrix(door.center, door.along, Vector3.yAxis)
end

-- Posição (no mundo) do topo do pedestal, onde o prêmio fica flutuando.
function SecretRoomBuilder.getPedestalTop(door: SecretDoor, building: BuildingConfig): Vector3
	local room = BuildingLayout.SecretRoomSize
	local z = building.WallThickness + room.Z - 3
	return (SecretRoomBuilder.getFrame(door) * CFrame.new(0, 3.2, z)).Position
end

local function solid(parent: Instance, name: string, frame: CFrame, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
	return BuildingDecor.createPart(parent, name, size, frame * CFrame.new(offset), color, { material = material, collide = true })
end

local function decor(parent: Instance, name: string, frame: CFrame, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	return BuildingDecor.createPart(parent, name, size, frame * CFrame.new(offset), color, { material = material, shape = shape })
end

local function buildShell(parent: Instance, frame: CFrame, wall: number, building: BuildingConfig)
	local room = BuildingLayout.SecretRoomSize
	local t = SHELL_THICKNESS
	local outerWidth = room.X + (t * 2)
	local depthCenter = wall + (room.Z / 2)
	local fullDepth = room.Z + t

	solid(parent, "Floor", frame, Vector3.new(outerWidth, t, fullDepth), Vector3.new(0, -t / 2, depthCenter + (t / 2)), FLOOR_COLOR, Enum.Material.Marble)
	solid(parent, "Ceiling", frame, Vector3.new(outerWidth, t, fullDepth), Vector3.new(0, room.Y + (t / 2), depthCenter + (t / 2)), building.CeilingColor, Enum.Material.Plaster)
	for _, side in ipairs({ -1, 1 }) do
		solid(parent, "SideWall", frame, Vector3.new(t, room.Y, fullDepth), Vector3.new(side * ((room.X + t) / 2), room.Y / 2, depthCenter + (t / 2)), PANEL_COLOR, Enum.Material.Wood)
	end
	solid(parent, "BackWall", frame, Vector3.new(room.X, room.Y, t), Vector3.new(0, room.Y / 2, wall + room.Z + (t / 2)), PANEL_COLOR, Enum.Material.Wood)
end

-- Lambri escuro com friso dourado nas duas laterais e no fundo.
local function buildPaneling(parent: Instance, frame: CFrame, wall: number)
	local room = BuildingLayout.SecretRoomSize
	local back = wall + room.Z
	for _, side in ipairs({ -1, 1 }) do
		local x = side * ((room.X / 2) - 0.1)
		decor(parent, "Wainscot", frame, Vector3.new(0.2, 3.6, room.Z), Vector3.new(x, 1.8, wall + (room.Z / 2)), PANEL_COLOR:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.WoodPlanks)
		decor(parent, "GoldRail", frame, Vector3.new(0.3, 0.25, room.Z), Vector3.new(x, 3.7, wall + (room.Z / 2)), GOLD_COLOR, Enum.Material.Metal)
		decor(parent, "Crown", frame, Vector3.new(0.4, 0.4, room.Z), Vector3.new(x, room.Y - 0.2, wall + (room.Z / 2)), GOLD_COLOR, Enum.Material.Metal)
	end
	decor(parent, "BackWainscot", frame, Vector3.new(room.X, 3.6, 0.2), Vector3.new(0, 1.8, back - 0.1), PANEL_COLOR:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.WoodPlanks)
	decor(parent, "BackGoldRail", frame, Vector3.new(room.X, 0.25, 0.3), Vector3.new(0, 3.7, back - 0.15), GOLD_COLOR, Enum.Material.Metal)
	decor(parent, "Rug", frame, Vector3.new(room.X - 4, 0.08, room.Z - 3), Vector3.new(0, 0.04, wall + (room.Z / 2)), RUG_COLOR, Enum.Material.Fabric)
	decor(parent, "RugTrim", frame, Vector3.new(room.X - 3.4, 0.06, room.Z - 2.4), Vector3.new(0, 0.03, wall + (room.Z / 2)), GOLD_COLOR, Enum.Material.Fabric)
end

-- Grade de cofres de parede (aço com puxador dourado) nas laterais.
local function buildLockers(parent: Instance, frame: CFrame, wall: number)
	local room = BuildingLayout.SecretRoomSize
	local columns = math.floor((room.Z - 4) / (LOCKER_SIZE + LOCKER_GAP))
	local step = LOCKER_SIZE + LOCKER_GAP
	local firstZ = wall + 2 + (LOCKER_SIZE / 2)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * ((room.X / 2) - 0.25)
		for row = 0, 3 do
			for column = 0, columns - 1 do
				local offset = Vector3.new(x, 4.6 + (row * step), firstZ + (column * step))
				decor(parent, "Locker", frame, Vector3.new(0.3, LOCKER_SIZE, LOCKER_SIZE), offset, STEEL_COLOR, Enum.Material.DiamondPlate)
				decor(parent, "LockerKnob", frame, Vector3.new(0.25, 0.25, 0.25), offset - Vector3.new(side * 0.25, 0, 0), GOLD_COLOR, Enum.Material.Metal, Enum.PartType.Ball)
			end
		end
	end
end

-- Porta redonda de cofre ao fundo, atrás do pedestal: pura decoração.
local function buildVaultDisk(parent: Instance, frame: CFrame, wall: number)
	local room = BuildingLayout.SecretRoomSize
	local back = wall + room.Z
	local axis = CFrame.Angles(0, math.rad(90), 0)
	local diskCenter = Vector3.new(0, 6.2, back - 0.3)
	local function disk(name: string, diameter: number, depth: number, z: number, color: Color3, material: Enum.Material)
		BuildingDecor.createPart(
			parent,
			name,
			Vector3.new(depth, diameter, diameter),
			frame * CFrame.new(diskCenter - Vector3.new(0, 0, z)) * axis,
			color,
			{ material = material, shape = Enum.PartType.Cylinder }
		)
	end
	disk("VaultRing", 8, 0.4, 0, GOLD_COLOR, Enum.Material.Metal)
	disk("VaultDoor", 7, 0.5, 0.2, STEEL_COLOR, Enum.Material.DiamondPlate)
	disk("VaultHub", 1.6, 0.4, 0.55, GOLD_COLOR, Enum.Material.Metal)
	for index = 0, 2 do
		BuildingDecor.createPart(
			parent,
			"VaultSpoke",
			Vector3.new(4.2, 0.3, 0.3),
			frame * CFrame.new(diskCenter - Vector3.new(0, 0, 0.7)) * CFrame.Angles(0, 0, math.rad(index * 60)),
			GOLD_COLOR,
			{ material = Enum.Material.Metal }
		)
	end
end

local function buildPedestal(parent: Instance, frame: CFrame, wall: number)
	local room = BuildingLayout.SecretRoomSize
	local z = wall + room.Z - 3
	solid(parent, "PedestalBase", frame, Vector3.new(2.8, 0.5, 2.8), Vector3.new(0, 0.25, z), GOLD_COLOR, Enum.Material.Metal)
	solid(parent, "PedestalColumn", frame, Vector3.new(2, 2.2, 2), Vector3.new(0, 1.6, z), Color3.fromRGB(236, 230, 222), Enum.Material.Marble)
	solid(parent, "PedestalTop", frame, Vector3.new(2.6, 0.3, 2.6), Vector3.new(0, 2.85, z), GOLD_COLOR, Enum.Material.Metal)
	decor(parent, "Plaque", frame, Vector3.new(1.4, 0.5, 0.1), Vector3.new(0, 1.6, z - 1.02), GOLD_COLOR, Enum.Material.Metal)
end

local function buildLights(parent: Instance, frame: CFrame, wall: number)
	local room = BuildingLayout.SecretRoomSize
	local lamp = decor(parent, "CeilingLamp", frame, Vector3.new(1.4, 0.3, 1.4), Vector3.new(0, room.Y - 0.15, wall + (room.Z / 2)), ROOM_LIGHT_COLOR, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = ROOM_LIGHT_COLOR
	light.Range = 16
	light.Brightness = 0.6
	light.Shadows = true
	light.Parent = lamp

	-- Foco dourado sobre o pedestal, que destaca o prêmio.
	local spotHolder = decor(parent, "PedestalSpot", frame, Vector3.new(0.8, 0.2, 0.8), Vector3.new(0, room.Y - 0.1, wall + room.Z - 3), GOLD_COLOR, Enum.Material.Metal)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Color = GOLD_COLOR
	spot.Range = 12
	spot.Angle = 40
	spot.Brightness = 1.2
	spot.Parent = spotHolder
end

function SecretRoomBuilder.build(parent: Instance, door: SecretDoor, building: BuildingConfig): Model
	local model = Instance.new("Model")
	model.Name = `SecretRoom{door.name}`
	local frame = SecretRoomBuilder.getFrame(door)
	local wall = building.WallThickness

	buildShell(model, frame, wall, building)
	buildPaneling(model, frame, wall)
	buildLockers(model, frame, wall)
	buildVaultDisk(model, frame, wall)
	buildPedestal(model, frame, wall)
	buildLights(model, frame, wall)

	model.Parent = parent
	return model
end

return table.freeze(SecretRoomBuilder)
