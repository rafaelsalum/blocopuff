--!strict

-- Cartão de aviso na borda esquerda da tela (ícone, título e subtítulo),
-- abaixo do cartão de anúncios (AnnouncementView): o centro e o topo (mira
-- e cronômetro) ficam livres. Só visual: quem decide o que aparece, em que
-- ordem e por quanto tempo é o NotificationManager.

local TweenService = game:GetService("TweenService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

export type BannerTone = "Gold" | "Danger" | "Info"

export type BannerViewHandle = {
	show: (icon: string, title: string, subtitle: string, tone: BannerTone, duration: number?) -> (),
	hide: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffBanner"
local BANNER_SIZE = Vector2.new(340, 62)
local EDGE_X = 18
-- Altura (fração da tela) do centro do cartão: abaixo do cartão de perfil
-- ou do HUD de combate e acima do convite de Party.
local CENTER_Y = 0.56
local SHOWN_POSITION = UDim2.new(0, EDGE_X, CENTER_Y, 0)
-- Escondido fora da tela, à esquerda (largura máxima já escalada).
local HIDDEN_POSITION = UDim2.new(0, -(BANNER_SIZE.X * 1.1) - 30, CENTER_Y, 0)

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
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = HIDDEN_POSITION
	root.Size = UDim2.fromOffset(BANNER_SIZE.X, BANNER_SIZE.Y)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = screenGui
	ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.66, 1.05)

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 14)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 1
	card.Parent = root
	local stroke = UiTheme.stylePanel(card, { accent = UiTheme.Colors.Gold, radius = 14 })

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 10, 0.5, 0)
	badge.Size = UDim2.fromOffset(42, 42)
	badge.BackgroundColor3 = UiTheme.Colors.Gold
	badge.BorderSizePixel = 0
	badge.ZIndex = 2
	badge.Parent = card
	UiTheme.addCorner(badge, 999)
	UiTheme.addStroke(badge, UiTheme.Colors.Outline, 2.5)

	local icon = UiTheme.createLabel(badge, "Icon", "", UiTheme.Fonts.Display, 22, UiTheme.Colors.White)
	icon.Size = UDim2.fromScale(1, 1)
	icon.ZIndex = 3

	local title = UiTheme.createLabel(card, "Title", "", UiTheme.Fonts.Display, 20, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(62, 7)
	title.Size = UDim2.new(1, -72, 0, 26)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	title.ZIndex = 2
	UiTheme.addTextOutline(title, 2)
	UiTheme.addTextConstraint(title, 13, 20)

	local subtitle = UiTheme.createLabel(card, "Subtitle", "", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.White)
	subtitle.Position = UDim2.fromOffset(62, 34)
	subtitle.Size = UDim2.new(1, -72, 0, 20)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextScaled = true
	subtitle.ZIndex = 2
	UiTheme.addTextConstraint(subtitle, 10, 13)

	return root, stroke, badge, icon, title, subtitle
end

function BannerView.new(playerGui: PlayerGui): BannerViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 31)
	local banner, stroke, badge, icon, title, subtitle = createBanner(screenGui)
	local generation = 0
	-- Só uma animação de posição por vez: entrar cancela a saída e vice-versa.
	local activeTween: Tween? = nil
	local function slideTo(info: TweenInfo, position: UDim2): Tween
		local previous = activeTween
		if previous ~= nil then
			previous:Cancel()
		end
		local tween = TweenService:Create(banner, info, { Position = position })
		activeTween = tween
		tween:Play()
		return tween
	end

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

		if not banner.Visible then
			banner.Position = HIDDEN_POSITION
		end
		banner.Visible = true
		slideTo(TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), SHOWN_POSITION)

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
		local hide = slideTo(TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), HIDDEN_POSITION)
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
