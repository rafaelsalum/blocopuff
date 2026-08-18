--!strict

-- Aviso administrativo compacto e temporário. Fica separado dos anúncios da
-- rodada para não alterar o estado ou o ciclo visual do HUD principal.

local TweenService = game:GetService("TweenService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

type ResponsiveScaleHandle = ResponsiveScale.ResponsiveScaleHandle

export type AdminBroadcastViewHandle = {
	show: (sender: string, message: string) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffAdminBroadcast"
local DISPLAY_DURATION = 6

local AdminBroadcastView = {}

function AdminBroadcastView.new(playerGui: PlayerGui): AdminBroadcastViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 45)

	local root = Instance.new("Frame")
	root.Name = "ResponsiveRoot"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 128)
	root.Size = UDim2.fromOffset(480, 70)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = screenGui
	local responsiveHandle: ResponsiveScaleHandle = ResponsiveScale.attach(
		root,
		Vector2.new(1280, 720),
		0.58,
		1.05
	)

	local animationGroup = Instance.new("Frame")
	animationGroup.Name = "AnimationGroup"
	animationGroup.Size = UDim2.fromScale(1, 1)
	animationGroup.BackgroundTransparency = 1
	animationGroup.Parent = root

	local scale = Instance.new("UIScale")
	scale.Name = "AnimationScale"
	scale.Parent = animationGroup

	UiTheme.createShadow(animationGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 18)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = UiTheme.Colors.Panel
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.ZIndex = 1
	card.Parent = animationGroup
	UiTheme.addCorner(card, 16)
	local stroke = UiTheme.addStroke(card, UiTheme.Colors.Blue, 1.5)

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Position = UDim2.new(0, 13, 0, 11)
	badge.Size = UDim2.fromOffset(94, 21)
	badge.BackgroundColor3 = UiTheme.Colors.SurfaceSoft
	badge.BorderSizePixel = 0
	badge.Font = UiTheme.Fonts.BodyBold
	badge.Text = "AVISO ADMIN"
	badge.TextColor3 = UiTheme.Colors.Ink
	badge.TextSize = 10
	badge.ZIndex = 2
	badge.Parent = card
	UiTheme.addCorner(badge, 8)

	local senderLabel = Instance.new("TextLabel")
	senderLabel.Name = "SenderLabel"
	senderLabel.Position = UDim2.new(0, 116, 0, 10)
	senderLabel.Size = UDim2.new(1, -130, 0, 22)
	senderLabel.BackgroundTransparency = 1
	senderLabel.Font = UiTheme.Fonts.BodyBold
	senderLabel.Text = ""
	senderLabel.TextColor3 = UiTheme.Colors.InkSoft
	senderLabel.TextSize = 11
	senderLabel.TextTruncate = Enum.TextTruncate.AtEnd
	senderLabel.TextXAlignment = Enum.TextXAlignment.Left
	senderLabel.ZIndex = 2
	senderLabel.Parent = card

	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "MessageLabel"
	messageLabel.Position = UDim2.new(0, 14, 0, 35)
	messageLabel.Size = UDim2.new(1, -28, 0, 24)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Font = UiTheme.Fonts.BodyBold
	messageLabel.Text = ""
	messageLabel.TextColor3 = UiTheme.Colors.Ink
	messageLabel.TextScaled = true
	messageLabel.TextWrapped = true
	messageLabel.ZIndex = 2
	messageLabel.Parent = card
	UiTheme.addTextConstraint(messageLabel, 11, 15)

	local generation = 0

	local handle = {} :: AdminBroadcastViewHandle
	handle.show = function(sender: string, message: string)
		generation += 1
		local currentGeneration = generation
		senderLabel.Text = string.format("enviado por %s", sender)
		messageLabel.Text = message
		root.Visible = true
		scale.Scale = 0.86
		card.BackgroundTransparency = 0.12
		badge.BackgroundTransparency = 0.08
		senderLabel.TextTransparency = 0
		messageLabel.TextTransparency = 0
		stroke.Transparency = 0.22

		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		task.delay(DISPLAY_DURATION, function()
			if generation ~= currentGeneration then
				return
			end

			local tween = TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
			TweenService:Create(badge, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(senderLabel, TweenInfo.new(0.15), { TextTransparency = 1 }):Play()
			TweenService:Create(messageLabel, TweenInfo.new(0.15), { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.18), { Transparency = 1 }):Play()
			tween:Play()
			tween.Completed:Connect(function()
				if generation == currentGeneration then
					root.Visible = false
				end
			end)
		end)
	end

	handle.destroy = function()
		generation += 1
		responsiveHandle.destroy()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(AdminBroadcastView)
