--!strict

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

export type AnnouncementTone = "Info" | "Warning" | "Danger" | "Winner"

export type AnnouncementViewHandle = {
	show: (title: string, subtitle: string, tone: AnnouncementTone, duration: number?) -> (),
	hide: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffAnnouncements"
-- Topo do cartão: logo abaixo da faixa de avisos (BannerView mostra em
-- y 96, ou 162 em telas estreitas), deixando o centro (mira) livre.
local TOP_Y = 196
local TOP_Y_COMPACT = 256
local COMPACT_WIDTH = 700

local AnnouncementView = {}

local function getTopY(): number
	local camera = Workspace.CurrentCamera
	if camera ~= nil and camera.ViewportSize.X < COMPACT_WIDTH then
		return TOP_Y_COMPACT
	end
	return TOP_Y
end

local function getToneColor(tone: AnnouncementTone): Color3
	if tone == "Warning" then
		return UiTheme.Colors.Orange
	elseif tone == "Danger" then
		return UiTheme.Colors.Danger
	elseif tone == "Winner" then
		return UiTheme.Colors.Yellow
	end

	return UiTheme.Colors.Blue
end

function AnnouncementView.new(playerGui: PlayerGui): AnnouncementViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 30)

	local responsiveRoot = Instance.new("Frame")
	responsiveRoot.Name = "ResponsiveRoot"
	-- No topo, abaixo da faixa de avisos (BannerView), longe da mira.
	responsiveRoot.AnchorPoint = Vector2.new(0.5, 0)
	responsiveRoot.Position = UDim2.new(0.5, 0, 0, getTopY())
	responsiveRoot.Size = UDim2.fromOffset(460, 92)
	responsiveRoot.BackgroundTransparency = 1
	responsiveRoot.Visible = false
	responsiveRoot.Parent = screenGui
	local responsiveHandle = ResponsiveScale.attach(responsiveRoot, Vector2.new(1280, 720), 0.66, 1.08)

	local animationGroup = Instance.new("Frame")
	animationGroup.Name = "AnimationGroup"
	animationGroup.Size = UDim2.fromScale(1, 1)
	animationGroup.BackgroundTransparency = 1
	animationGroup.Parent = responsiveRoot

	local animationScale = Instance.new("UIScale")
	animationScale.Name = "AnimationScale"
	animationScale.Parent = animationGroup

	UiTheme.createShadow(animationGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 22)

	local card = Instance.new("Frame")
	card.Name = "AnnouncementCard"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 1
	card.Parent = animationGroup
	local cardStroke = UiTheme.stylePanel(card, { accent = UiTheme.Colors.Blue, radius = 18 })
	cardStroke.Thickness = 3
	local strokeGradient = cardStroke:FindFirstChildOfClass("UIGradient") :: UIGradient?

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.AnchorPoint = Vector2.new(0.5, 0)
	accent.Position = UDim2.new(0.5, 0, 0, 0)
	accent.Size = UDim2.new(0.46, 0, 0, 5)
	accent.BackgroundColor3 = UiTheme.Colors.Blue
	accent.BorderSizePixel = 0
	accent.ZIndex = 2
	accent.Parent = card
	UiTheme.addCorner(accent, 4)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Position = UDim2.new(0, 18, 0, 14)
	titleLabel.Size = UDim2.new(1, -36, 0, 34)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = UiTheme.Fonts.Display
	titleLabel.Text = ""
	titleLabel.TextColor3 = UiTheme.Colors.White
	titleLabel.TextScaled = true
	titleLabel.TextWrapped = true
	titleLabel.ZIndex = 2
	titleLabel.Parent = card
	UiTheme.addTextConstraint(titleLabel, 18, 32)
	local titleGradient = UiTheme.addGradient(titleLabel, UiTheme.Colors.White, UiTheme.Colors.Blue)
	local titleOutline = UiTheme.addTextOutline(titleLabel, 3)

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.Position = UDim2.new(0, 20, 0, 51)
	subtitleLabel.Size = UDim2.new(1, -40, 0, 25)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = UiTheme.Fonts.BodyBold
	subtitleLabel.Text = ""
	subtitleLabel.TextColor3 = UiTheme.Colors.InkSoft
	subtitleLabel.TextScaled = true
	subtitleLabel.TextWrapped = true
	subtitleLabel.ZIndex = 2
	subtitleLabel.Parent = card
	UiTheme.addTextConstraint(subtitleLabel, 11, 15)

	local generation = 0
	local visible = false

	local function setTransparency(value: number)
		card.BackgroundTransparency = value
		titleLabel.TextTransparency = value
		titleOutline.Transparency = value
		subtitleLabel.TextTransparency = value
		accent.BackgroundTransparency = value
		cardStroke.Transparency = value
	end

	local handle = {} :: AnnouncementViewHandle

	handle.hide = function()
		if not visible then
			return
		end
		visible = false
		generation += 1
		local hideGeneration = generation

		TweenService:Create(animationScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 0.9 }):Play()
		local fadeTween = TweenService:Create(card, TweenInfo.new(0.16), { BackgroundTransparency = 1 })
		TweenService:Create(titleLabel, TweenInfo.new(0.13), { TextTransparency = 1 }):Play()
		TweenService:Create(titleOutline, TweenInfo.new(0.13), { Transparency = 1 }):Play()
		TweenService:Create(subtitleLabel, TweenInfo.new(0.13), { TextTransparency = 1 }):Play()
		TweenService:Create(accent, TweenInfo.new(0.13), { BackgroundTransparency = 1 }):Play()
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			if generation == hideGeneration and not visible then
				responsiveRoot.Visible = false
			end
		end)
	end

	handle.show = function(title: string, subtitle: string, tone: AnnouncementTone, duration: number?)
		generation += 1
		local showGeneration = generation
		visible = true

		local toneColor = getToneColor(tone)
		titleLabel.Text = title
		subtitleLabel.Text = subtitle
		accent.BackgroundColor3 = toneColor
		titleGradient.Color = ColorSequence.new(UiTheme.Colors.White, toneColor:Lerp(UiTheme.Colors.White, 0.2))
		if strokeGradient ~= nil then
			strokeGradient.Color = ColorSequence.new(toneColor, toneColor:Lerp(UiTheme.Colors.Gold, 0.55))
		end
		responsiveRoot.Position = UDim2.new(0.5, 0, 0, getTopY())
		responsiveRoot.Visible = true
		animationScale.Scale = 0.78
		setTransparency(0.08)

		TweenService:Create(animationScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		if duration ~= nil and duration > 0 then
			task.delay(duration, function()
				if generation == showGeneration then
					handle.hide()
				end
			end)
		end
	end

	handle.destroy = function()
		generation += 1
		responsiveHandle.destroy()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(AnnouncementView)
