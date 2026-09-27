--!strict

-- Faixa de aviso no topo da tela (ícone, título e subtítulo). Só visual:
-- quem decide o que aparece, em que ordem e por quanto tempo é o
-- NotificationManager.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

export type BannerTone = "Gold" | "Danger" | "Info"

export type BannerViewHandle = {
	show: (icon: string, title: string, subtitle: string, tone: BannerTone, duration: number?) -> (),
	hide: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffBanner"
local BANNER_SIZE = Vector2.new(520, 84)
local HIDDEN_Y = -120
local SHOWN_Y = 96
-- Em telas estreitas o cronômetro da partida desce para y≈106; a faixa
-- fica abaixo dele para não se sobrepor.
local SHOWN_Y_COMPACT = 162
local COMPACT_WIDTH = 700

local function getShownY(): number
	local camera = Workspace.CurrentCamera
	if camera ~= nil and camera.ViewportSize.X < COMPACT_WIDTH then
		return SHOWN_Y_COMPACT
	end
	return SHOWN_Y
end

local BannerView = {}

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

function BannerView.new(playerGui: PlayerGui): BannerViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 31)
	local banner, stroke, badge, icon, title, subtitle = createBanner(screenGui)
	local generation = 0

	local handle = {} :: BannerViewHandle

	handle.show = function(iconText: string, titleText: string, subtitleText: string, tone: BannerTone, duration: number?)
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
			Position = UDim2.new(0.5, 0, 0, getShownY()),
		}):Play()

		if duration ~= nil and duration > 0 then
			task.delay(duration, function()
				if current == generation then
					handle.hide()
				end
			end)
		end
	end

	handle.hide = function()
		generation += 1
		local current = generation
		if not banner.Visible then
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
	end

	handle.destroy = function()
		generation += 1
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(BannerView)
