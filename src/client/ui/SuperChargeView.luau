--!strict

-- Pílula dourada "⚡ SUPER × n" com os tiros restantes do Super Puffador.
-- Só visual.

local TweenService = game:GetService("TweenService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

export type SuperChargeViewHandle = {
	setSuperCharges: (charges: number) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffSuperCharges"

local SuperChargeView = {}

local function createSuperPill(screenGui: ScreenGui)
	local pill = Instance.new("Frame")
	pill.Name = "SuperPill"
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.new(0.5, 0, 1, -150)
	pill.Size = UDim2.fromOffset(210, 46)
	pill.BackgroundColor3 = UiTheme.Colors.White
	pill.BorderSizePixel = 0
	pill.Visible = false
	pill.Parent = screenGui
	UiTheme.addCorner(pill, 999)
	UiTheme.addGradient(pill, UiTheme.Colors.Gold, UiTheme.Colors.GoldDeep)
	UiTheme.addStroke(pill, UiTheme.Colors.Outline, 3)
	ResponsiveScale.attach(pill, Vector2.new(1280, 720), 0.7, 1.05)

	local scale = Instance.new("UIScale")
	scale.Name = "Pulse"
	scale.Parent = pill

	local label = UiTheme.createLabel(pill, "Label", "", UiTheme.Fonts.Display, 22, UiTheme.Colors.White)
	label.Size = UDim2.fromScale(1, 1)
	UiTheme.addTextOutline(label, 2.5)
	return pill, label, scale
end

function SuperChargeView.new(playerGui: PlayerGui): SuperChargeViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 31)
	local pill, pillLabel, pillScale = createSuperPill(screenGui)

	local handle = {} :: SuperChargeViewHandle

	handle.setSuperCharges = function(charges: number)
		if charges <= 0 then
			pill.Visible = false
			return
		end
		pillLabel.Text = string.format("⚡ SUPER × %d", charges)
		pill.Visible = true
		pillScale.Scale = 1.15
		TweenService:Create(pillScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(SuperChargeView)
