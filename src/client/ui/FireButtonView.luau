--!strict

-- Botão de disparo para toque no estilo dos jogos de tiro mobile: grande,
-- redondo, com volume (base mais escura), afunda ao tocar e mostra a recarga
-- enchendo o círculo de baixo para cima. O texto continua visível para não
-- depender apenas de cor ou de ícone.

local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent.UiTheme)

local FIRE_BUTTON_NAME = "BlocoPuffFireButton"
local BUTTON_SIZE = 96
local DEPTH = 6

export type FireButtonViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
	startCooldown: (duration: number) -> (),
	destroy: () -> (),
}

local FireButtonView = {}

local function circle(instance: Instance)
	UiTheme.addCorner(instance, 999)
end

function FireButtonView.new(playerGui: PlayerGui, onFire: () -> ()): FireButtonViewHandle
	local screenGui = UiTheme.createScreenGui(FIRE_BUTTON_NAME, playerGui, 19)
	screenGui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -28, 1, -118)
	root.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE + DEPTH)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	local rootScale = Instance.new("UIScale")
	rootScale.Parent = root

	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.Position = UDim2.fromOffset(0, DEPTH)
	edge.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	edge.BackgroundColor3 = UiTheme.Colors.BrandDeep:Lerp(UiTheme.Colors.Outline, 0.35)
	edge.BorderSizePixel = 0
	edge.Parent = root
	circle(edge)

	-- CanvasGroup recorta o preenchimento da recarga no formato do círculo.
	local face = Instance.new("CanvasGroup")
	face.Name = "Face"
	face.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	face.BackgroundColor3 = UiTheme.Colors.White
	face.BorderSizePixel = 0
	face.ZIndex = 2
	face.Parent = root
	circle(face)

	-- O gradiente fica num fundo próprio: num CanvasGroup ele tingiria
	-- também o texto e os demais elementos do botão.
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = UiTheme.Colors.White
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = face
	UiTheme.addGradient(fill, UiTheme.Colors.Brand:Lerp(UiTheme.Colors.White, 0.25), UiTheme.Colors.BrandDeep)

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, -12, 1, -12)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 3
	ring.Parent = face
	circle(ring)
	local ringStroke = UiTheme.addStroke(ring, UiTheme.Colors.Gold, 3)
	ringStroke.Transparency = 0.1

	local cooldownFill = Instance.new("Frame")
	cooldownFill.Name = "CooldownFill"
	cooldownFill.AnchorPoint = Vector2.new(0, 1)
	cooldownFill.Position = UDim2.fromScale(0, 1)
	cooldownFill.Size = UDim2.fromScale(1, 0)
	cooldownFill.BackgroundColor3 = UiTheme.Colors.Outline
	cooldownFill.BackgroundTransparency = 0.35
	cooldownFill.BorderSizePixel = 0
	cooldownFill.ZIndex = 4
	cooldownFill.Parent = face

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.new(0.5, 0, 0, 8)
	shine.Size = UDim2.new(0.62, 0, 0.3, 0)
	shine.BackgroundColor3 = UiTheme.Colors.White
	shine.BackgroundTransparency = 0.8
	shine.BorderSizePixel = 0
	shine.ZIndex = 3
	shine.Parent = face
	circle(shine)

	local label = UiTheme.createLabel(face, "Label", "PUFF!", UiTheme.Fonts.Display, 24, UiTheme.Colors.Ink)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.44)
	label.Size = UDim2.new(1, -16, 0, 28)
	label.ZIndex = 5
	UiTheme.addTextOutline(label, 2.5)

	local caption = UiTheme.createLabel(face, "Caption", "ATIRAR", UiTheme.Fonts.BodyBold, 11, UiTheme.Colors.Ink)
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.Position = UDim2.fromScale(0.5, 0.68)
	caption.Size = UDim2.new(1, -20, 0, 14)
	caption.ZIndex = 5
	UiTheme.addTextOutline(caption, 1.5)

	-- Área de toque invisível por cima de tudo; mantém o nome acessível.
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.BackgroundTransparency = 1
	button.Text = "ATIRAR"
	button.TextTransparency = 1
	button.AutoButtonColor = false
	button.Active = true
	button.Selectable = true
	button.SelectionOrder = 10
	button.ZIndex = 10
	button.Parent = root
	circle(button)

	local ready = true

	local function press(down: boolean)
		local offset = if down then DEPTH - 1 else 0
		TweenService:Create(face, TweenInfo.new(0.07, Enum.EasingStyle.Quad), {
			Position = UDim2.fromOffset(0, offset),
		}):Play()
		TweenService:Create(rootScale, TweenInfo.new(if down then 0.07 else 0.2, if down then Enum.EasingStyle.Quad else Enum.EasingStyle.Back), {
			Scale = if down then 0.94 else 1,
		}):Play()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			press(true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			press(false)
		end
	end)
	button.Activated:Connect(function()
		if ready then
			onFire()
		end
	end)

	local handle = {} :: FireButtonViewHandle
	handle.screenGui = screenGui

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.startCooldown = function(duration: number)
		ready = false
		button.Text = "RECARREGANDO"
		caption.Text = "RECARGA"
		ringStroke.Color = UiTheme.Colors.InkSoft
		cooldownFill.Size = UDim2.fromScale(1, 1)

		local cooldownTween = TweenService:Create(
			cooldownFill,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(1, 0) }
		)
		cooldownTween:Play()
		cooldownTween.Completed:Connect(function()
			if screenGui.Parent == nil then
				return
			end
			ready = true
			button.Text = "ATIRAR"
			caption.Text = "ATIRAR"
			ringStroke.Color = UiTheme.Colors.Gold
			-- Pulso curto avisando que já pode atirar de novo.
			rootScale.Scale = 1.08
			TweenService:Create(rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(FireButtonView)
