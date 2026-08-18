--!strict

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

export type ControlHintViewHandle = {
	show: (text: string, duration: number?) -> (),
	hide: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffControlHint"

local ControlHintView = {}

function ControlHintView.new(playerGui: PlayerGui): ControlHintViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 19)

	local responsiveRoot = Instance.new("Frame")
	responsiveRoot.Name = "ResponsiveRoot"
	responsiveRoot.AnchorPoint = Vector2.new(0.5, 1)
	responsiveRoot.Position = UDim2.new(0.5, 0, 1, if UserInputService.TouchEnabled then -112 else -22)
	responsiveRoot.Size = UDim2.fromOffset(292, 42)
	responsiveRoot.BackgroundTransparency = 1
	responsiveRoot.Visible = false
	responsiveRoot.Parent = screenGui
	local responsiveHandle = ResponsiveScale.attach(responsiveRoot, Vector2.new(1280, 720), 0.72, 1)

	local animationGroup = Instance.new("Frame")
	animationGroup.Name = "AnimationGroup"
	animationGroup.Size = UDim2.fromScale(1, 1)
	animationGroup.BackgroundTransparency = 1
	animationGroup.Parent = responsiveRoot

	local animationScale = Instance.new("UIScale")
	animationScale.Name = "AnimationScale"
	animationScale.Parent = animationGroup

	UiTheme.createShadow(animationGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 15)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = UiTheme.Colors.Panel
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.ZIndex = 1
	card.Parent = animationGroup
	UiTheme.addCorner(card, 13)
	UiTheme.addStroke(card, UiTheme.Colors.Blue, 1.25)

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Position = UDim2.new(0, 12, 0, 5)
	label.Size = UDim2.new(1, -24, 1, -10)
	label.BackgroundTransparency = 1
	label.Font = UiTheme.Fonts.BodyBold
	label.Text = ""
	label.TextColor3 = UiTheme.Colors.Ink
	label.TextScaled = true
	label.TextWrapped = true
	label.ZIndex = 2
	label.Parent = card
	UiTheme.addTextConstraint(label, 10, 13)

	local generation = 0
	local visible = false
	local handle = {} :: ControlHintViewHandle

	handle.hide = function()
		if not visible then
			return
		end

		visible = false
		generation += 1
		local hideGeneration = generation
		TweenService:Create(animationScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Scale = 0.88 }):Play()
		local fade = TweenService:Create(card, TweenInfo.new(0.14), { BackgroundTransparency = 1 })
		TweenService:Create(label, TweenInfo.new(0.12), { TextTransparency = 1 }):Play()
		fade:Play()
		fade.Completed:Connect(function()
			if generation == hideGeneration and not visible then
				responsiveRoot.Visible = false
			end
		end)
	end

	handle.show = function(text: string, duration: number?)
		generation += 1
		local showGeneration = generation
		visible = true
		label.Text = text
		label.TextTransparency = 0
		card.BackgroundTransparency = 0.18
		animationScale.Scale = 0.82
		responsiveRoot.Visible = true
		TweenService:Create(animationScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
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

return table.freeze(ControlHintView)
