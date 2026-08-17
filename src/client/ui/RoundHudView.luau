--!strict

local TweenService = game:GetService("TweenService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

type ResponsiveScaleHandle = ResponsiveScale.ResponsiveScaleHandle

export type RoundHudMode = "Hidden" | "Waiting" | "Countdown"

export type RoundHudViewHandle = {
	setMode: (mode: RoundHudMode) -> (),
	setStatus: (text: string) -> (),
	setParticipants: (text: string) -> (),
	setCountdown: (text: string) -> (),
	setQueueText: (text: string) -> (),
	setQueueVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffRoundHud"
local REFERENCE_VIEWPORT = Vector2.new(1280, 720)

local RoundHudView = {}

local function createTextLabel(
	name: string,
	parent: Instance,
	font: Enum.Font,
	textSize: number,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function createAnimationGroup(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2
): (Frame, Frame, UIScale, ResponsiveScaleHandle)
	local responsiveRoot = Instance.new("Frame")
	responsiveRoot.Name = `{name}ResponsiveRoot`
	responsiveRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	responsiveRoot.Position = position
	responsiveRoot.Size = size
	responsiveRoot.BackgroundTransparency = 1
	responsiveRoot.Parent = parent
	local responsiveHandle = ResponsiveScale.attach(responsiveRoot, REFERENCE_VIEWPORT, 0.78, 1.08)

	local animationGroup = Instance.new("Frame")
	animationGroup.Name = name
	animationGroup.Size = UDim2.fromScale(1, 1)
	animationGroup.BackgroundTransparency = 1
	animationGroup.Parent = responsiveRoot

	local animationScale = Instance.new("UIScale")
	animationScale.Name = "AnimationScale"
	animationScale.Parent = animationGroup

	return responsiveRoot, animationGroup, animationScale, responsiveHandle
end

function RoundHudView.new(playerGui: PlayerGui): RoundHudViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 10)

	local waitingRoot, waitingGroup, waitingScale, waitingResponsive = createAnimationGroup(
		screenGui,
		"WaitingGroup",
		UDim2.new(0.5, 0, 0, 74),
		UDim2.fromOffset(430, 96)
	)
	waitingRoot.Visible = false

	UiTheme.createShadow(waitingGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 20)

	local waitingCard = Instance.new("Frame")
	waitingCard.Name = "WaitingCard"
	waitingCard.Size = UDim2.fromScale(1, 1)
	waitingCard.BackgroundColor3 = UiTheme.Colors.Panel
	waitingCard.BorderSizePixel = 0
	waitingCard.ZIndex = 1
	waitingCard.Parent = waitingGroup
	UiTheme.addCorner(waitingCard, 20)
	UiTheme.addStroke(waitingCard, UiTheme.Colors.Purple, 4)
	UiTheme.addPadding(waitingCard, 22, 12)

	local waitingLayout = Instance.new("UIListLayout")
	waitingLayout.FillDirection = Enum.FillDirection.Vertical
	waitingLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	waitingLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	waitingLayout.SortOrder = Enum.SortOrder.LayoutOrder
	waitingLayout.Padding = UDim.new(0, 3)
	waitingLayout.Parent = waitingCard

	local statusLabel = createTextLabel(
		"StatusLabel",
		waitingCard,
		UiTheme.Fonts.Heading,
		25,
		UiTheme.Colors.Ink
	)
	statusLabel.Size = UDim2.new(1, 0, 0, 34)
	statusLabel.LayoutOrder = 1

	local participantsLabel = createTextLabel(
		"ParticipantsLabel",
		waitingCard,
		UiTheme.Fonts.BodyBold,
		15,
		UiTheme.Colors.InkSoft
	)
	participantsLabel.Size = UDim2.new(1, 0, 0, 22)
	participantsLabel.LayoutOrder = 2

	local queueBadge = Instance.new("Frame")
	queueBadge.Name = "QueueBadge"
	queueBadge.AnchorPoint = Vector2.new(0.5, 0)
	queueBadge.Position = UDim2.new(0.5, 0, 1, 12)
	queueBadge.Size = UDim2.fromOffset(350, 38)
	queueBadge.BackgroundColor3 = UiTheme.Colors.Yellow
	queueBadge.BorderSizePixel = 0
	queueBadge.Visible = false
	queueBadge.ZIndex = 2
	queueBadge.Parent = waitingGroup
	UiTheme.addCorner(queueBadge, 12)
	UiTheme.addStroke(queueBadge, UiTheme.Colors.Ink, 2)

	local queueLabel = createTextLabel(
		"QueueLabel",
		queueBadge,
		UiTheme.Fonts.BodyBold,
		14,
		UiTheme.Colors.Ink
	)

	local countdownRoot, countdownGroup, countdownScale, countdownResponsive = createAnimationGroup(
		screenGui,
		"CountdownGroup",
		UDim2.fromScale(0.5, 0.43),
		UDim2.fromOffset(184, 184)
	)
	countdownRoot.Visible = false

	UiTheme.createShadow(countdownGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 28)

	local countdownCard = Instance.new("Frame")
	countdownCard.Name = "CountdownCard"
	countdownCard.Size = UDim2.fromScale(1, 1)
	countdownCard.BackgroundColor3 = UiTheme.Colors.Yellow
	countdownCard.BorderSizePixel = 0
	countdownCard.ZIndex = 1
	countdownCard.Parent = countdownGroup
	UiTheme.addCorner(countdownCard, 28)
	UiTheme.addStroke(countdownCard, UiTheme.Colors.Ink, 5)

	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = 1
	aspectRatio.AspectType = Enum.AspectType.ScaleWithParentSize
	aspectRatio.Parent = countdownCard

	local prepareLabel = createTextLabel(
		"PrepareLabel",
		countdownCard,
		UiTheme.Fonts.BodyBold,
		15,
		UiTheme.Colors.Ink
	)
	prepareLabel.Position = UDim2.new(0, 0, 0, 22)
	prepareLabel.Size = UDim2.new(1, 0, 0, 22)
	prepareLabel.Text = "PREPARE-SE"

	local countdownLabel = createTextLabel(
		"CountdownLabel",
		countdownCard,
		UiTheme.Fonts.Heading,
		82,
		UiTheme.Colors.Ink
	)
	countdownLabel.Position = UDim2.new(0, 0, 0, 38)
	countdownLabel.Size = UDim2.new(1, 0, 1, -48)
	countdownLabel.Text = "3"

	local currentMode: RoundHudMode = "Hidden"

	local function popIn(root: Frame, scale: UIScale)
		root.Visible = true
		scale.Scale = 0.78
		TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end

	local handle = {} :: RoundHudViewHandle
	handle.setMode = function(mode: RoundHudMode)
		if mode == currentMode then
			return
		end
		currentMode = mode
		waitingRoot.Visible = false
		countdownRoot.Visible = false

		if mode == "Waiting" then
			popIn(waitingRoot, waitingScale)
		elseif mode == "Countdown" then
			popIn(countdownRoot, countdownScale)
		end
	end

	handle.setStatus = function(text: string)
		statusLabel.Text = text
	end

	handle.setParticipants = function(text: string)
		participantsLabel.Text = text
	end

	handle.setCountdown = function(text: string)
		if countdownLabel.Text == text then
			return
		end
		countdownLabel.Text = text
		countdownScale.Scale = 1.16
		TweenService:Create(countdownScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	handle.setQueueText = function(text: string)
		queueLabel.Text = text
	end

	handle.setQueueVisible = function(visible: boolean)
		queueBadge.Visible = visible
	end

	handle.destroy = function()
		waitingResponsive.destroy()
		countdownResponsive.destroy()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(RoundHudView)
