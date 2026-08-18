--!strict

local TweenService = game:GetService("TweenService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

export type SpectatorViewHandle = {
	setVisible: (visible: boolean) -> (),
	setTargetInfo: (name: string, activeCount: number) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffSpectatorHud"

local SpectatorView = {}

local function createButton(
	name: string,
	text: string,
	parent: Instance,
	layoutOrder: number,
	selectionOrder: number
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = UiTheme.Fonts.BodyBold
	button.TextSize = 22
	button.TextColor3 = UiTheme.Colors.Ink
	button.BackgroundColor3 = UiTheme.Colors.SurfaceSoft
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = true
	button.Size = UDim2.fromOffset(48, 48)
	button.LayoutOrder = layoutOrder
	button.Selectable = true
	button.SelectionOrder = selectionOrder
	button.Parent = parent
	UiTheme.addCorner(button, 14)
	UiTheme.addStroke(button, UiTheme.Colors.Border, 1.5)
	return button
end

function SpectatorView.new(playerGui: PlayerGui, onPrevious: () -> (), onNext: () -> ()): SpectatorViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 20)
	screenGui.Enabled = false

	local responsiveRoot = Instance.new("Frame")
	responsiveRoot.Name = "ResponsiveRoot"
	responsiveRoot.AnchorPoint = Vector2.new(0.5, 1)
	responsiveRoot.Position = UDim2.new(0.5, 0, 1, -22)
	responsiveRoot.Size = UDim2.fromOffset(360, 66)
	responsiveRoot.BackgroundTransparency = 1
	responsiveRoot.Parent = screenGui
	local responsiveHandle = ResponsiveScale.attach(responsiveRoot, Vector2.new(1280, 720), 0.76, 1.08)

	local animationScale = Instance.new("UIScale")
	animationScale.Name = "AnimationScale"

	local animationGroup = Instance.new("Frame")
	animationGroup.Name = "AnimationGroup"
	animationGroup.Size = UDim2.fromScale(1, 1)
	animationGroup.BackgroundTransparency = 1
	animationGroup.Parent = responsiveRoot
	animationScale.Parent = animationGroup

	UiTheme.createShadow(animationGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 20)

	local panel = Instance.new("Frame")
	panel.Name = "SpectatorPanel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = UiTheme.Colors.Panel
	panel.BackgroundTransparency = 0.16
	panel.BorderSizePixel = 0
	panel.ZIndex = 1
	panel.Parent = animationGroup
	UiTheme.addCorner(panel, 17)
	UiTheme.addStroke(panel, UiTheme.Colors.Border, 1.5)
	UiTheme.addPadding(panel, 8, 8)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 9)
	layout.Parent = panel

	local previousButton = createButton("PreviousButton", "<", panel, 1, 20)

	local information = Instance.new("Frame")
	information.Name = "Information"
	information.Size = UDim2.fromOffset(226, 48)
	information.BackgroundTransparency = 1
	information.LayoutOrder = 2
	information.Parent = panel

	local captionLabel = Instance.new("TextLabel")
	captionLabel.Name = "CaptionLabel"
	captionLabel.Size = UDim2.new(1, 0, 0, 17)
	captionLabel.BackgroundTransparency = 1
	captionLabel.Font = UiTheme.Fonts.BodyBold
	captionLabel.Text = "ASSISTINDO"
	captionLabel.TextSize = 10
	captionLabel.TextColor3 = UiTheme.Colors.InkSoft
	captionLabel.Parent = information

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "TargetNameLabel"
	nameLabel.Position = UDim2.new(0, 0, 0, 14)
	nameLabel.Size = UDim2.new(1, 0, 0, 24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = UiTheme.Fonts.Heading
	nameLabel.Text = ""
	nameLabel.TextSize = 17
	nameLabel.TextColor3 = UiTheme.Colors.Ink
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = information

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "ActiveCountLabel"
	countLabel.Position = UDim2.new(0, 0, 0, 37)
	countLabel.Size = UDim2.new(1, 0, 0, 16)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = UiTheme.Fonts.Body
	countLabel.Text = ""
	countLabel.TextSize = 11
	countLabel.TextColor3 = UiTheme.Colors.InkSoft
	countLabel.Parent = information

	local nextButton = createButton("NextButton", ">", panel, 3, 21)

	previousButton.Activated:Connect(onPrevious)
	nextButton.Activated:Connect(onNext)

	local currentlyVisible = false
	local handle = {} :: SpectatorViewHandle

	handle.setVisible = function(visible: boolean)
		if visible == currentlyVisible then
			return
		end
		currentlyVisible = visible
		screenGui.Enabled = visible
		if visible then
			animationScale.Scale = 0.84
			TweenService:Create(animationScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end

	handle.setTargetInfo = function(name: string, activeCount: number)
		nameLabel.Text = name
		countLabel.Text = if activeCount == 1 then "1 jogador restante" else string.format("%d jogadores restantes", activeCount)
	end

	handle.destroy = function()
		responsiveHandle.destroy()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(SpectatorView)
