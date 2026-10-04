--!strict

-- Portas duplas de madeira nos vãos do Casarão (Fase 5C.1): os arcos das
-- divisórias dos salões e as portas da ala leste (MansionWingLayout).
-- O servidor só monta as peças paradas (fechadas, sem colisão nem toque):
-- quem abre, fecha e toca os sons é o MansionDoorController, em cada
-- cliente. Cada porta é um Model com a tag MansionConfig.Door.Tag e a normal
-- da parede; cada folha é um Model com o CFrame da dobradiça.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)

type Mansion = MansionLayout.Mansion
type Doorway = MansionWingLayout.Doorway

local CONFIG = MansionConfig.Door
-- Folga entre as folhas e o batente, e acima do piso.
local GAP = 0.1
local KNOB_SIZE = 0.55
local KNOB_HEIGHT = 4.5
local KNOB_INSET = 0.7
local INSET_MARGIN = 0.8
local INSET_DEPTH = 0.06

local MansionDoors = {}

-- Um retângulo em baixo-relevo em cada face da folha (de cima e de baixo).
local function addInsets(leaf: Model, center: Vector3, along: Vector3, normal: Vector3, width: number, height: number)
	local insetWidth = width - INSET_MARGIN * 2
	local insetHeight = (height - INSET_MARGIN * 3) / 2
	if insetWidth <= 0 or insetHeight <= 0 then
		return
	end
	for _, side in ipairs({ -1, 1 }) do
		local face = normal * side * (CONFIG.Thickness / 2 + INSET_DEPTH / 2)
		for _, row in ipairs({ -1, 1 }) do
			local offset = Vector3.yAxis * row * (insetHeight / 2 + INSET_MARGIN / 2)
			local cframe = CFrame.fromMatrix(center + face + offset, along, Vector3.yAxis)
			BuildingDecor.createPart(leaf, "Inset", Vector3.new(insetWidth, insetHeight, INSET_DEPTH), cframe, CONFIG.PanelColor, { material = Enum.Material.Wood })
		end
	end
end

-- Folha que gira em `hinge`; `outward` aponta da dobradiça para o meio do
-- vão.
local function createLeaf(door: Model, name: string, hinge: Vector3, outward: Vector3, normal: Vector3, width: number, height: number)
	local leaf = Instance.new("Model")
	leaf.Name = name
	leaf:SetAttribute(CONFIG.HingeAttribute, CFrame.new(hinge))
	local center = hinge + outward * (width / 2) + Vector3.yAxis * (height / 2 + GAP)
	BuildingDecor.createPart(leaf, "Panel", Vector3.new(width, height, CONFIG.Thickness), CFrame.fromMatrix(center, outward, Vector3.yAxis), CONFIG.Color, { material = Enum.Material.Wood })
	addInsets(leaf, center, outward, normal, width, height)
	local knobBase = hinge + outward * (width - KNOB_INSET) + Vector3.yAxis * KNOB_HEIGHT
	for _, side in ipairs({ -1, 1 }) do
		local position = knobBase + normal * side * (CONFIG.Thickness / 2 + KNOB_SIZE / 2)
		BuildingDecor.createPart(leaf, "Knob", Vector3.one * KNOB_SIZE, CFrame.new(position), CONFIG.KnobColor, { shape = Enum.PartType.Ball, material = Enum.Material.Metal })
	end
	leaf:SetAttribute(CONFIG.PartCountAttribute, #leaf:GetChildren())
	leaf.Parent = door
end

-- Porta dupla no vão `doorway` (centro no piso, no meio da parede).
local function createDoor(parent: Instance, doorway: Doorway)
	local door = Instance.new("Model")
	door.Name = doorway.name
	door:SetAttribute(CONFIG.NormalAttribute, doorway.normal)
	local halfSpan = doorway.size.X / 2 - GAP / 2
	local width = halfSpan - GAP
	local height = doorway.size.Y - GAP * 3
	local along = doorway.along
	createLeaf(door, "LeftLeaf", doorway.center - along * halfSpan, along, doorway.normal, width, height)
	createLeaf(door, "RightLeaf", doorway.center + along * halfSpan, -along, doorway.normal, width, height)
	door.Parent = parent
	CollectionService:AddTag(door, CONFIG.Tag)
end

-- Os arcos das divisórias dos salões, como vãos de porta.
function MansionDoors.partitionDoorways(mansion: Mansion): { Doorway }
	local size = Vector2.new(MansionConfig.ArchWidth, MansionConfig.ArchHeight)
	local doorways: { Doorway } = {}
	for _, partition in ipairs(mansion.partitions) do
		for index, offset in ipairs(partition.arches) do
			local alongX = partition.axis == "X"
			table.insert(doorways, {
				name = `{partition.name}Door{index}`,
				center = if alongX then Vector3.new(offset, mansion.floorY, partition.fixed) else Vector3.new(partition.fixed, mansion.floorY, offset),
				along = if alongX then Vector3.xAxis else Vector3.zAxis,
				normal = if alongX then Vector3.zAxis else Vector3.xAxis,
				size = size,
			})
		end
	end
	return doorways
end

-- Uma porta dupla em cada vão.
function MansionDoors.build(parent: Instance, doorways: { Doorway })
	for _, doorway in ipairs(doorways) do
		createDoor(parent, doorway)
	end
end

return table.freeze(MansionDoors)
