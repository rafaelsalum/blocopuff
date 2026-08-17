--!strict

local TweenService = game:GetService("TweenService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

export type AnnouncementTone = "Info" | "Warning" | "Danger" | "Winner"

export type AnnouncementViewHandle = {
	show: (title: string, subtitle: string, tone: AnnouncementTone, duration: number?) -> (),
	hide: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffAnnouncements"

local AnnouncementView = {}

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
	responsiveRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	responsiveRoot.Position = UDim2.fromScale(0.5, 0.48)
	responsiveRoot.Size = UDim2.fromOffset(540, 116)
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
	card.BackgroundColor3 = UiTheme.Colors.Panel
	card.BorderSizePixel = 0
	card.ZIndex = 1
	card.Parent = animationGroup
	UiTheme.addCorner(card, 22)
	local cardStroke = UiTheme.addStroke(card, UiTheme.Colors.Blue, 5)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.AnchorPoint = Vector2.new(0.5, 0)
	accent.Position = UDim2.new(0.5, 0, 0, 0)
	accent.Size = UDim2.new(0.58, 0, 0, 8)
	accent.BackgroundColor3 = UiTheme.Colors.Blue
	accent.BorderSizePixel = 0
	accent.ZIndex = 2
	accent.Parent = card
	UiTheme.addCorner(accent, 4)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Position = UDim2.new(0, 20, 0, 19)
	titleLabel.Size = UDim2.new(1, -40, 0, 44)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = UiTheme.Fonts.Heading
	titleLabel.Text = ""
	titleLabel.TextColor3 = UiTheme.Colors.Ink
	titleLabel.TextScaled = true
	titleLabel.TextWrapped = true
	titleLabel.ZIndex = 2
	titleLabel.Parent = card
	UiTheme.addTextConstraint(titleLabel, 22, 38)

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.Position = UDim2.new(0, 22, 0, 66)
	subtitleLabel.Size = UDim2.new(1, -44, 0, 32)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = UiTheme.Fonts.BodyBold
	subtitleLabel.Text = ""
	subtitleLabel.TextColor3 = UiTheme.Colors.InkSoft
	subtitleLabel.TextScaled = true
	subtitleLabel.TextWrapped = true
	subtitleLabel.ZIndex = 2
	subtitleLabel.Parent = card
	UiTheme.addTextConstraint(subtitleLabel, 12, 18)

	local generation = 0
	local visible = false

	local function setTransparency(value: number)
		card.BackgroundTransparency = value
		titleLabel.TextTransparency = value
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
		cardStroke.Color = toneColor
		responsiveRoot.Visible = true
		animationScale.Scale = 0.78
		setTransparency(0)

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
