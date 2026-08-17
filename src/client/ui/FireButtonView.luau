--!strict

-- Botão de disparo dedicado para toque. Exibe texto, estado desabilitado e
-- progresso de recarga para não depender apenas de cor ou de um ícone.

local TweenService = game:GetService("TweenService")

local FIRE_BUTTON_NAME = "BlocoPuffFireButton"
local BUTTON_SIZE = 84
local READY_COLOR = Color3.fromRGB(255, 221, 91)
local DISABLED_COLOR = Color3.fromRGB(157, 146, 166)

export type FireButtonViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
	startCooldown: (duration: number) -> (),
	destroy: () -> (),
}

local FireButtonView = {}

function FireButtonView.new(playerGui: PlayerGui, onFire: () -> ()): FireButtonViewHandle
	local existing = playerGui:FindFirstChild(FIRE_BUTTON_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = FIRE_BUTTON_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 19
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -28, 1, -166)
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.BackgroundColor3 = READY_COLOR
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = true
	button.Text = ""
	button.Active = true
	button.Selectable = true
	button.SelectionOrder = 10
	button.ClipsDescendants = true
	button.Parent = screenGui

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(1, 0)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Color3.fromRGB(73, 52, 89)
	buttonStroke.Thickness = 4
	buttonStroke.Parent = button

	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.AnchorPoint = Vector2.new(0, 1)
	cooldownOverlay.Position = UDim2.fromScale(0, 1)
	cooldownOverlay.Size = UDim2.fromScale(1, 0)
	cooldownOverlay.BackgroundColor3 = Color3.fromRGB(71, 57, 82)
	cooldownOverlay.BackgroundTransparency = 0.28
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.ZIndex = 2
	cooldownOverlay.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "PUFF!"
	label.TextColor3 = Color3.fromRGB(58, 43, 69)
	label.TextSize = 19
	label.ZIndex = 3
	label.Parent = button

	button.Activated:Connect(function()
		if button.Active then
			onFire()
		end
	end)

	screenGui.Parent = playerGui

	local handle = {} :: FireButtonViewHandle
	handle.screenGui = screenGui

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.startCooldown = function(duration: number)
		button.Active = false
		button.Selectable = false
		button.AutoButtonColor = false
		button.BackgroundColor3 = DISABLED_COLOR
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
			button.BackgroundColor3 = READY_COLOR
			label.Text = "PUFF!"
		end)
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(FireButtonView)
