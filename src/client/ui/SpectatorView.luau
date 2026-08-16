--!strict

-- Constrói os controles visuais do modo espectador (nome do alvo observado e
-- botões de alternância). Não decide quem observar: apenas expõe callbacks
-- para o SpectatorController reagir a cliques/toques nos botões.

local GUI_NAME = "BlocoPuffSpectatorHud"

local COLOR_PANEL_BACKGROUND = Color3.fromRGB(255, 250, 240)
local COLOR_PANEL_STROKE = Color3.fromRGB(194, 168, 255)
local COLOR_TEXT_PRIMARY = Color3.fromRGB(64, 48, 76)
local COLOR_BUTTON_BACKGROUND = Color3.fromRGB(151, 211, 255)

local FONT_HEADING = Enum.Font.FredokaOne
local FONT_BODY = Enum.Font.GothamMedium

export type SpectatorViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
	setTargetName: (name: string) -> (),
	destroy: () -> (),
}

local SpectatorView = {}

local function applyCorner(instance: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = instance
end

local function createButton(name: string, text: string, parent: Instance, layoutOrder: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = FONT_HEADING
	button.TextSize = 22
	button.TextColor3 = COLOR_TEXT_PRIMARY
	button.BackgroundColor3 = COLOR_BUTTON_BACKGROUND
	button.AutoButtonColor = true
	button.Size = UDim2.new(0, 44, 0, 44)
	button.LayoutOrder = layoutOrder
	button.Parent = parent

	applyCorner(button, UDim.new(1, 0))

	return button
end

function SpectatorView.new(playerGui: PlayerGui, onPrevious: () -> (), onNext: () -> ()): SpectatorViewHandle
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "SpectatorPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 0.97, 0)
	panel.Size = UDim2.new(0, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.BackgroundColor3 = COLOR_PANEL_BACKGROUND
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	applyCorner(panel, UDim.new(0, 16))

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_PANEL_STROKE
	stroke.Thickness = 3
	stroke.Transparency = 0.1
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = panel

	local previousButton = createButton("PreviousButton", "<", panel, 1)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "TargetNameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.Size = UDim2.new(0, 0, 0, 44)
	nameLabel.TextColor3 = COLOR_TEXT_PRIMARY
	nameLabel.Font = FONT_BODY
	nameLabel.TextSize = 17
	nameLabel.Text = ""
	nameLabel.LayoutOrder = 2
	nameLabel.Parent = panel

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(80, 0)
	sizeConstraint.MaxSize = Vector2.new(240, 10000)
	sizeConstraint.Parent = nameLabel

	local nextButton = createButton("NextButton", ">", panel, 3)

	screenGui.Parent = playerGui

	previousButton.Activated:Connect(onPrevious)
	nextButton.Activated:Connect(onNext)

	local handle = {} :: SpectatorViewHandle
	handle.screenGui = screenGui

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.setTargetName = function(name: string)
		nameLabel.Text = string.format("Assistindo: %s", name)
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(SpectatorView)
