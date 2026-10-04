--!strict

-- Placa de madeira com o nome da sala, presa à parede acima de um vão
-- (Casarão e ala leste).

local BuildingDecor = require(script.Parent.BuildingDecor)
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.config.GameConfig)

type BuildingConfig = GameConfig.BuildingConfig

local SIZE = Vector2.new(11, 1.8)
local MAX_DISTANCE = 70
local TEXT_COLOR = Color3.fromRGB(255, 209, 102)

local MansionPlaque = {}

MansionPlaque.MaxDistance = MAX_DISTANCE
-- Altura do centro da placa acima do topo do vão.
MansionPlaque.Lift = 2.6

function MansionPlaque.create(parent: Instance, name: string, cframe: CFrame, text: string, style: BuildingConfig)
	local plaque = BuildingDecor.createPart(parent, name, Vector3.new(SIZE.X, SIZE.Y, 0.3), cframe, style.FrameColor, { material = Enum.Material.Wood })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = plaque
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = TEXT_COLOR
	label.TextScaled = true
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = label
end

return table.freeze(MansionPlaque)
