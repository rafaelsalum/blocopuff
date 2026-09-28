--!strict

-- Cartão de anúncios na borda esquerda da tela, acima da faixa de avisos
-- (BannerView): entra deslizando pela esquerda e deixa o centro (mira) e o
-- topo (cronômetro) livres.

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
local CARD_SIZE = Vector2.new(330, 80)
local EDGE_X = 18
-- Altura (fração da tela) do centro do cartão: abaixo do cartão de perfil
-- ou do HUD de combate (canto superior esquerdo).
local CENTER_Y = 0.42
local SHOWN_POSITION = UDim2.new(0, EDGE_X, CENTER_Y, 0)
-- Escondido fora da tela, à esquerda (largura máxima já escalada).
local HIDDEN_POSITION = UDim2.new(0, -(CARD_SIZE.X * 1.1) - 30, CENTER_Y, 0)

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
	responsiveRoot.AnchorPoint = Vector2.new(0, 0.5)
	responsiveRoot.Position = HIDDEN_POSITION
	responsiveRoot.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	responsiveRoot.BackgroundTransparency = 1
	responsiveRoot.Visible = false
	responsiveRoot.Parent = screenGui
	local responsiveHandle = ResponsiveScale.attach(responsiveRoot, Vector2.new(1280, 720), 0.66, 1.08)

	local animationGroup = Instance.new("Frame")
	animationGroup.Name = "AnimationGroup"
	animationGroup.Size = UDim2.fromScale(1, 1)
	animationGroup.BackgroundTransparency = 1
	animationGroup.Parent = responsiveRoot

	UiTheme.createShadow(animationGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 16)

	local card = Instance.new("Frame")
	card.Name = "AnnouncementCard"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 1
	card.Parent = animationGroup
	local cardStroke = UiTheme.stylePanel(card, { accent = UiTheme.Colors.Blue, radius = 14 })
	cardStroke.Thickness = 2.5
	local strokeGradient = cardStroke:FindFirstChildOfClass("UIGradient") :: UIGradient?

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	-- Barra vertical colorida na lateral esquerda do cartão.
	accent.AnchorPoint = Vector2.new(0, 0.5)
	accent.Position = UDim2.new(0, 8, 0.5, 0)
	accent.Size = UDim2.new(0, 5, 0.62, 0)
	accent.BackgroundColor3 = UiTheme.Colors.Blue
	accent.BorderSizePixel = 0
	accent.ZIndex = 2
	accent.Parent = card
	UiTheme.addCorner(accent, 4)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Position = UDim2.new(0, 22, 0, 10)
	titleLabel.Size = UDim2.new(1, -34, 0, 32)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = UiTheme.Fonts.Display
	titleLabel.Text = ""
	titleLabel.TextColor3 = UiTheme.Colors.White
	titleLabel.TextScaled = true
	titleLabel.TextWrapped = true
	titleLabel.ZIndex = 2
	titleLabel.Parent = card
	UiTheme.addTextConstraint(titleLabel, 16, 26)
	local titleGradient = UiTheme.addGradient(titleLabel, UiTheme.Colors.White, UiTheme.Colors.Blue)
	local titleOutline = UiTheme.addTextOutline(titleLabel, 3)

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.Position = UDim2.new(0, 22, 0, 45)
	subtitleLabel.Size = UDim2.new(1, -34, 0, 24)
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = UiTheme.Fonts.BodyBold
	subtitleLabel.Text = ""
	subtitleLabel.TextColor3 = UiTheme.Colors.InkSoft
	subtitleLabel.TextScaled = true
	subtitleLabel.TextWrapped = true
	subtitleLabel.ZIndex = 2
	subtitleLabel.Parent = card
	UiTheme.addTextConstraint(subtitleLabel, 10, 14)

	local generation = 0
	local visible = false

	local function setTransparency(value: number)
		card.BackgroundTransparency = value
		titleLabel.TextTransparency = value
		titleOutline.Transparency = value
		subtitleLabel.TextTransparency = value
		accent.BackgroundTransparency = value
		cardStroke.Transparency = value
	end

	-- Animações em andamento: mostrar e esconder cancelam as anteriores, para
	-- uma saída atrasada não apagar o cartão que acabou de entrar.
	local activeTweens: { Tween } = {}
	local function play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
		local tween = TweenService:Create(instance, info, goal)
		table.insert(activeTweens, tween)
		tween:Play()
		return tween
	end
	local function cancelTweens()
		for _, tween in ipairs(activeTweens) do
			tween:Cancel()
		end
		table.clear(activeTweens)
	end

	local handle = {} :: AnnouncementViewHandle

	handle.hide = function()
		if not visible then
			return
		end
		visible = false
		generation += 1
		local hideGeneration = generation

		cancelTweens()
		play(responsiveRoot, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = HIDDEN_POSITION })
		local fadeTween = play(card, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
		play(titleLabel, TweenInfo.new(0.13), { TextTransparency = 1 })
		play(titleOutline, TweenInfo.new(0.13), { Transparency = 1 })
		play(subtitleLabel, TweenInfo.new(0.13), { TextTransparency = 1 })
		play(accent, TweenInfo.new(0.13), { BackgroundTransparency = 1 })
		play(cardStroke, TweenInfo.new(0.13), { Transparency = 1 })
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
		titleGradient.Color = ColorSequence.new(UiTheme.Colors.White, toneColor:Lerp(UiTheme.Colors.White, 0.2))
		if strokeGradient ~= nil then
			strokeGradient.Color = ColorSequence.new(toneColor, toneColor:Lerp(UiTheme.Colors.Gold, 0.55))
		end
		cancelTweens()
		if not responsiveRoot.Visible then
			responsiveRoot.Position = HIDDEN_POSITION
		end
		responsiveRoot.Visible = true
		setTransparency(0.08)

		play(responsiveRoot, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = SHOWN_POSITION,
		})

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
		cancelTweens()
		responsiveHandle.destroy()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(AnnouncementView)
