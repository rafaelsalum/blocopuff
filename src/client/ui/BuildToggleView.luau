--!strict

-- Botão redondo menor, acima do botão PUFF, para alternar entre Puff e
-- Construir com o Puffador do Cofre (toque). No teclado e no controle a
-- troca é pela tecla Q / botão Y; a dica fica no próprio botão.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local UiTheme = require(script.Parent.UiTheme)

local T = Lang.t

export type BuildToggleViewHandle = {
	setVisible: (visible: boolean) -> (),
	setMode: (building: boolean, charges: number) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffBuildToggle"
local BUTTON_SIZE = 66

local BuildToggleView = {}

-- `anchor`: ScreenGui do botão PUFF, para acompanhar a posição dele.
function BuildToggleView.new(playerGui: PlayerGui, anchor: ScreenGui, onToggle: () -> ()): BuildToggleViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 20)
	screenGui.Enabled = false

	local button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.BackgroundColor3 = UiTheme.Colors.White
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = screenGui
	UiTheme.addCorner(button, 999)
	local gradient = UiTheme.addGradient(button, UiTheme.Colors.Gold, UiTheme.Colors.GoldDeep)
	UiTheme.addStroke(button, UiTheme.Colors.Outline, 3)

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local icon = UiTheme.createLabel(button, "Icon", "🧱", UiTheme.Fonts.Display, 24, UiTheme.Colors.White)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.38)
	icon.Size = UDim2.new(1, 0, 0, 26)

	local caption = UiTheme.createLabel(button, "Caption", T("CONSTRUIR"), UiTheme.Fonts.BodyBold, 10, UiTheme.Colors.Ink)
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.Position = UDim2.fromScale(0.5, 0.74)
	caption.Size = UDim2.new(1, -6, 0, 12)
	UiTheme.addTextOutline(caption, 1.5)

	button.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onToggle()
	end)

	-- Fica logo acima do botão PUFF (que se reposiciona com o botão de pulo).
	local function follow()
		local fire = anchor:FindFirstChild("Root")
		if fire == nil or not fire:IsA("GuiObject") then
			button.Position = UDim2.new(1, -76, 1, -250)
			return
		end
		local center = fire.AbsolutePosition + Vector2.new(fire.AbsoluteSize.X / 2, 0) - screenGui.AbsolutePosition
		button.Position = UDim2.fromOffset(center.X, center.Y - 10)
	end

	local followConnection: RBXScriptConnection? = nil

	local handle = {} :: BuildToggleViewHandle

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
		if visible then
			follow()
			if followConnection == nil then
				local fire = anchor:FindFirstChild("Root")
				if fire ~= nil and fire:IsA("GuiObject") then
					followConnection = fire:GetPropertyChangedSignal("AbsolutePosition"):Connect(follow)
				end
			end
		end
	end

	handle.setMode = function(building: boolean, charges: number)
		if building then
			icon.Text = "💨"
			caption.Text = T("PUFF")
			gradient.Color = ColorSequence.new(UiTheme.Colors.Brand, UiTheme.Colors.BrandDeep)
		else
			icon.Text = "🧱"
			caption.Text = T("CONSTRUIR %d", charges)
			gradient.Color = ColorSequence.new(UiTheme.Colors.Gold, UiTheme.Colors.GoldDeep)
		end
	end

	handle.destroy = function()
		if followConnection ~= nil then
			followConnection:Disconnect()
			followConnection = nil
		end
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(BuildToggleView)
