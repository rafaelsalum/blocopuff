--!strict

-- Botão de disparo dedicado para toque. Exibe texto, estado desabilitado e
-- progresso de recarga para não depender apenas de cor ou de um ícone.

local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent.UiTheme)

local FIRE_BUTTON_NAME = "BlocoPuffFireButton"
local BUTTON_SIZE = 92

export type FireButtonViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
	startCooldown: (duration: number) -> (),
	destroy: () -> (),
}

local FireButtonView = {}

function FireButtonView.new(playerGui: PlayerGui, onFire: () -> ()): FireButtonViewHandle
	local screenGui = UiTheme.createScreenGui(FIRE_BUTTON_NAME, playerGui, 19)
	screenGui.Enabled = false

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -28, 1, -166)
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.BackgroundColor3 = UiTheme.Colors.Yellow
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = true
	-- O texto transparente mantém uma descrição semântica no próprio botão;
	-- o Label filho controla a apresentação acima do overlay de recarga.
	button.Text = "ATIRAR"
	button.TextTransparency = 1
	button.Active = true
	button.Selectable = true
	button.SelectionOrder = 10
	button.ClipsDescendants = true
	button.Parent = screenGui

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	UiTheme.addCorner(button, BUTTON_SIZE / 2)
	UiTheme.addStroke(button, UiTheme.Colors.Ink, 4)

	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.AnchorPoint = Vector2.new(0, 1)
	cooldownOverlay.Position = UDim2.fromScale(0, 1)
	cooldownOverlay.Size = UDim2.fromScale(1, 0)
	cooldownOverlay.BackgroundColor3 = UiTheme.Colors.Ink
	cooldownOverlay.BackgroundTransparency = 0.28
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.ZIndex = 2
	cooldownOverlay.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.76, 0.44)
	label.BackgroundTransparency = 1
	label.Font = UiTheme.Fonts.Heading
	label.Text = "ATIRAR"
	label.TextColor3 = UiTheme.Colors.Ink
	label.TextScaled = true
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.None
	label.ZIndex = 3
	label.Parent = button
	UiTheme.addTextConstraint(label, 12, 20)

	button.Activated:Connect(function()
		if button.Active then
			onFire()
		end
	end)

	local handle = {} :: FireButtonViewHandle
	handle.screenGui = screenGui

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.startCooldown = function(duration: number)
		button.Active = false
		button.Selectable = false
		button.AutoButtonColor = false
		button.BackgroundColor3 = UiTheme.Colors.InkSoft
		button.Text = "RECARREGANDO"
		label.Text = "..."
		cooldownOverlay.Size = UDim2.fromScale(1, 1)
		scale.Scale = 0.9

		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		local cooldownTween = TweenService:Create(
			cooldownOverlay,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(1, 0) }
		)
		cooldownTween:Play()
		cooldownTween.Completed:Connect(function()
			if button.Parent == nil then
				return
			end
			button.Active = true
			button.Selectable = true
			button.AutoButtonColor = true
			button.BackgroundColor3 = UiTheme.Colors.Yellow
			button.Text = "ATIRAR"
			label.Text = "ATIRAR"
		end)
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(FireButtonView)
