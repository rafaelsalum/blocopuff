--!strict

-- HUD da espera no lobby, no canto superior direito (o centro da tela fica
-- livre para o Casarão): a etiqueta da fila da partida ("🏟 FILA 1/2"), o
-- botão JOGAR (leva ao mirante) para quem está fora da fila e, na contagem,
-- o cronômetro logo acima da etiqueta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

local T = Lang.t

type ResponsiveScaleHandle = ResponsiveScale.ResponsiveScaleHandle

export type RoundHudMode = "Hidden" | "Waiting" | "Countdown"

export type RoundHudViewHandle = {
	setMode: (mode: RoundHudMode) -> (),
	setCountdown: (text: string) -> (),
	-- `inQueue` pinta a etiqueta de verde e esconde o botão JOGAR.
	setQueue: (title: string, subtitle: string, inQueue: boolean) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffRoundHud"
local REFERENCE_VIEWPORT = Vector2.new(1280, 720)
local EDGE = 18
local QUEUE_SIZE = Vector2.new(236, 56)
local JOIN_HEIGHT = 40
local JOIN_GAP = 6
-- A etiqueta fica no topo na espera e desce para baixo do cronômetro
-- (58 de altura) na contagem.
local QUEUE_Y_WAITING = 16
local QUEUE_Y_COUNTDOWN = 82

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
	responsiveRoot.AnchorPoint = Vector2.new(1, 0)
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

function RoundHudView.new(playerGui: PlayerGui, onJoin: () -> ()): RoundHudViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 10)

	local queueRoot, queueGroup, queueScale, queueResponsive = createAnimationGroup(
		screenGui,
		"QueueGroup",
		UDim2.new(1, -EDGE, 0, QUEUE_Y_WAITING),
		UDim2.fromOffset(QUEUE_SIZE.X, QUEUE_SIZE.Y + JOIN_GAP + JOIN_HEIGHT)
	)
	queueRoot.Visible = false

	local queueCard = Instance.new("Frame")
	queueCard.Name = "QueueCard"
	queueCard.Size = UDim2.fromOffset(QUEUE_SIZE.X, QUEUE_SIZE.Y)
	queueCard.ZIndex = 1
	queueCard.Parent = queueGroup
	local queueStroke = UiTheme.stylePanel(queueCard, { accent = UiTheme.Colors.Brand, radius = 14 })
	local queueGradient = queueStroke:FindFirstChildOfClass("UIGradient") :: UIGradient?

	local queueTitle = createTextLabel("QueueTitle", queueCard, UiTheme.Fonts.Display, 17, UiTheme.Colors.Gold)
	queueTitle.Position = UDim2.fromOffset(14, 6)
	queueTitle.Size = UDim2.new(1, -28, 0, 24)
	queueTitle.TextXAlignment = Enum.TextXAlignment.Left
	queueTitle.TextScaled = true
	UiTheme.addTextConstraint(queueTitle, 12, 17)
	UiTheme.addTextOutline(queueTitle, 2)

	local queueSubtitle = createTextLabel("QueueSubtitle", queueCard, UiTheme.Fonts.BodyBold, 12, UiTheme.Colors.Ink)
	queueSubtitle.Position = UDim2.fromOffset(14, 31)
	queueSubtitle.Size = UDim2.new(1, -28, 0, 18)
	queueSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	queueSubtitle.TextScaled = true
	UiTheme.addTextConstraint(queueSubtitle, 10, 12)

	local joinButton = UiKit.createButton(queueGroup, {
		name = "JoinButton",
		text = T("🏟 JOGAR"),
		variant = "Success",
		size = UDim2.fromOffset(QUEUE_SIZE.X, JOIN_HEIGHT),
		position = UDim2.fromOffset(0, QUEUE_SIZE.Y + JOIN_GAP),
		textSize = 16,
		zIndex = 2,
	})
	joinButton.button.Activated:Connect(onJoin)

	local countdownRoot, countdownGroup, countdownScale, countdownResponsive = createAnimationGroup(
		screenGui,
		"CountdownGroup",
		UDim2.new(1, -EDGE, 0, 16),
		UDim2.fromOffset(184, 58)
	)
	countdownRoot.Visible = false

	UiTheme.createShadow(countdownGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 18)

	local countdownCard = Instance.new("Frame")
	countdownCard.Name = "CountdownCard"
	countdownCard.Size = UDim2.fromScale(1, 1)
	countdownCard.ZIndex = 1
	countdownCard.Parent = countdownGroup
	UiTheme.stylePanel(countdownCard, { accent = UiTheme.Colors.Gold, radius = 15 })

	local numberBadge = Instance.new("Frame")
	numberBadge.Name = "NumberBadge"
	numberBadge.AnchorPoint = Vector2.new(1, 0.5)
	numberBadge.Position = UDim2.new(1, -8, 0.5, 0)
	numberBadge.Size = UDim2.fromOffset(42, 42)
	numberBadge.BackgroundColor3 = UiTheme.Colors.White
	numberBadge.BorderSizePixel = 0
	numberBadge.ZIndex = 2
	numberBadge.Parent = countdownCard
	UiTheme.addCorner(numberBadge, 12)
	UiTheme.addGradient(numberBadge, UiTheme.Colors.Gold:Lerp(UiTheme.Colors.White, 0.3), UiTheme.Colors.GoldDeep)
	local badgeStroke = UiTheme.addStroke(numberBadge, UiTheme.Colors.Outline, 2)
	badgeStroke.Transparency = 0.2

	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = 1
	aspectRatio.AspectType = Enum.AspectType.ScaleWithParentSize
	aspectRatio.Parent = numberBadge

	local prepareLabel = createTextLabel(
		"PrepareLabel",
		countdownCard,
		UiTheme.Fonts.BodyBold,
		12,
		UiTheme.Colors.Ink
	)
	prepareLabel.Position = UDim2.new(0, 13, 0, 0)
	prepareLabel.Size = UDim2.new(1, -68, 1, 0)
	prepareLabel.TextXAlignment = Enum.TextXAlignment.Left
	prepareLabel.Text = T("PREPARE-SE")
	prepareLabel.Font = UiTheme.Fonts.Display
	prepareLabel.TextSize = 17
	UiTheme.addTextOutline(prepareLabel, 2)

	local countdownLabel = createTextLabel(
		"CountdownLabel",
		numberBadge,
		UiTheme.Fonts.Heading,
		24,
		UiTheme.Colors.Ink
	)
	countdownLabel.Text = "3"
	countdownLabel.TextSize = 28
	UiTheme.addTextOutline(countdownLabel, 2.5)

	local currentMode: RoundHudMode = "Hidden"
	local currentInQueue: boolean? = nil

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
		local wasShowingQueue = currentMode ~= "Hidden"
		currentMode = mode
		countdownRoot.Visible = false
		queueRoot.Position = UDim2.new(1, -EDGE, 0, if mode == "Countdown" then QUEUE_Y_COUNTDOWN else QUEUE_Y_WAITING)

		if mode == "Hidden" then
			queueRoot.Visible = false
			return
		end
		if not wasShowingQueue then
			popIn(queueRoot, queueScale)
		end
		if mode == "Countdown" then
			popIn(countdownRoot, countdownScale)
		end
	end

	handle.setQueue = function(title: string, subtitle: string, inQueue: boolean)
		queueTitle.Text = title
		queueSubtitle.Text = subtitle
		if inQueue == currentInQueue then
			return
		end
		currentInQueue = inQueue
		joinButton.root.Visible = not inQueue
		local color = if inQueue then UiTheme.Colors.Green else UiTheme.Colors.Brand
		queueTitle.TextColor3 = if inQueue then UiTheme.Colors.Green else UiTheme.Colors.Gold
		if queueGradient ~= nil then
			queueGradient.Color = ColorSequence.new(color, color:Lerp(UiTheme.Colors.White, 0.3))
		end
		UiKit.pop(queueCard)
	end

	handle.setCountdown = function(text: string)
		if countdownLabel.Text == text then
			return
		end
		countdownLabel.Text = text
		countdownScale.Scale = 1.16
		TweenService:Create(countdownScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	handle.destroy = function()
		queueResponsive.destroy()
		countdownResponsive.destroy()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(RoundHudView)
