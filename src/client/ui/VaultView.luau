--!strict

-- Telas do Cofre do Barão: faixa de aviso no topo (destravou, alguém
-- invadiu, Super pego, eliminado no cofre) e a pílula dourada "SUPER" com
-- os tiros restantes do Super Puffador. Só visual.

local TweenService = game:GetService("TweenService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

export type BannerTone = "Gold" | "Danger" | "Info"

export type VaultViewHandle = {
	showBanner: (icon: string, title: string, subtitle: string, tone: BannerTone, duration: number?) -> (),
	setSuperCharges: (charges: number) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffVault"
local BANNER_SIZE = Vector2.new(520, 84)
local BANNER_DURATION = 4
local HIDDEN_Y = -120
local SHOWN_Y = 96

local VaultView = {}

local function getToneColor(tone: BannerTone): Color3
	if tone == "Danger" then
		return UiTheme.Colors.Danger
	elseif tone == "Info" then
		return UiTheme.Colors.Brand
	end
	return UiTheme.Colors.Gold
end

local function createBanner(screenGui: ScreenGui)
	local root = Instance.new("Frame")
	root.Name = "Banner"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	root.Size = UDim2.fromOffset(BANNER_SIZE.X, BANNER_SIZE.Y)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = screenGui
	ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.62, 1.05)

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 18)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 1
	card.Parent = root
	local stroke = UiTheme.stylePanel(card, { accent = UiTheme.Colors.Gold, radius = 18 })

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 14, 0.5, 0)
	badge.Size = UDim2.fromOffset(58, 58)
	badge.BackgroundColor3 = UiTheme.Colors.Gold
	badge.BorderSizePixel = 0
	badge.ZIndex = 2
	badge.Parent = card
	UiTheme.addCorner(badge, 999)
	UiTheme.addStroke(badge, UiTheme.Colors.Outline, 3)

	local icon = UiTheme.createLabel(badge, "Icon", "", UiTheme.Fonts.Display, 30, UiTheme.Colors.White)
	icon.Size = UDim2.fromScale(1, 1)
	icon.ZIndex = 3

	local title = UiTheme.createLabel(card, "Title", "", UiTheme.Fonts.Display, 26, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(86, 10)
	title.Size = UDim2.new(1, -100, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	title.ZIndex = 2
	UiTheme.addTextOutline(title, 2.5)
	UiTheme.addTextConstraint(title, 14, 26)

	local subtitle = UiTheme.createLabel(card, "Subtitle", "", UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.White)
	subtitle.Position = UDim2.fromOffset(86, 46)
	subtitle.Size = UDim2.new(1, -100, 0, 28)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextScaled = true
	subtitle.ZIndex = 2
	UiTheme.addTextConstraint(subtitle, 11, 16)

	return root, stroke, badge, icon, title, subtitle
end

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

function VaultView.new(playerGui: PlayerGui): VaultViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 31)
	local banner, stroke, badge, icon, title, subtitle = createBanner(screenGui)
	local pill, pillLabel, pillScale = createSuperPill(screenGui)
	local generation = 0

	local handle = {} :: VaultViewHandle

	handle.showBanner = function(iconText: string, titleText: string, subtitleText: string, tone: BannerTone, duration: number?)
		generation += 1
		local current = generation
		local color = getToneColor(tone)
		icon.Text = iconText
		title.Text = titleText
		title.TextColor3 = color
		subtitle.Text = subtitleText
		badge.BackgroundColor3 = color
		local strokeGradient = stroke:FindFirstChildOfClass("UIGradient") :: UIGradient?
		if strokeGradient ~= nil then
			strokeGradient.Color = ColorSequence.new(color, color:Lerp(UiTheme.Colors.White, 0.3))
		end

		banner.Visible = true
		banner.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
		TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, SHOWN_Y),
		}):Play()

		task.delay(duration or BANNER_DURATION, function()
			if current ~= generation or screenGui.Parent == nil then
				return
			end
			local hide = TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, HIDDEN_Y),
			})
			hide:Play()
			hide.Completed:Connect(function()
				if current == generation then
					banner.Visible = false
				end
			end)
		end)
	end

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

return table.freeze(VaultView)
