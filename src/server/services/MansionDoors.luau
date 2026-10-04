--!strict

-- Portas duplas de madeira nos arcos das divisórias do Casarão (Fase 5C.1).
-- O servidor só monta as peças paradas (fechadas, sem colisão nem toque):
-- quem abre, fecha e toca os sons é o MansionDoorController, em cada
-- cliente. Cada porta é um Model com a tag MansionConfig.Door.Tag e a normal
-- da parede; cada folha é um Model com o CFrame da dobradiça.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local BuildingDecor = require(script.Parent.BuildingDecor)

type Mansion = MansionLayout.Mansion

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

-- Porta dupla centrada em `center` (no piso), na parede com normal `normal`.
local function createDoor(parent: Instance, name: string, center: Vector3, along: Vector3, normal: Vector3)
	local door = Instance.new("Model")
	door.Name = name
	door:SetAttribute(CONFIG.NormalAttribute, normal)
	local halfSpan = MansionConfig.ArchWidth / 2 - GAP / 2
	local width = halfSpan - GAP
	local height = MansionConfig.ArchHeight - GAP * 3
	createLeaf(door, "LeftLeaf", center - along * halfSpan, along, normal, width, height)
	createLeaf(door, "RightLeaf", center + along * halfSpan, -along, normal, width, height)
	door.Parent = parent
	CollectionService:AddTag(door, CONFIG.Tag)
end

-- Uma porta em cada arco das divisórias.
function MansionDoors.build(parent: Instance, mansion: Mansion)
	for _, partition in ipairs(mansion.partitions) do
		for index, offset in ipairs(partition.arches) do
			local name = `{partition.name}Door{index}`
			if partition.axis == "X" then
				createDoor(parent, name, Vector3.new(offset, mansion.floorY, partition.fixed), Vector3.xAxis, Vector3.zAxis)
			else
				createDoor(parent, name, Vector3.new(partition.fixed, mansion.floorY, offset), Vector3.zAxis, Vector3.xAxis)
			end
		end
	end
end

return table.freeze(MansionDoors)
