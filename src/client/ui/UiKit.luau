--!strict

-- Componentes interativos da identidade BlocoPuff. O botão "gordinho" tem
-- uma base mais escura que dá profundidade: ao passar o mouse ele cresce um
-- pouco, ao pressionar afunda sobre a base e toca um clique. Todos os
-- botões continuam selecionáveis por gamepad e acessíveis por toque.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent.UiTheme)

export type ButtonVariant = "Primary" | "Gold" | "Success" | "Danger" | "Warning" | "Neutral"

export type ButtonOptions = {
	name: string,
	text: string,
	variant: ButtonVariant?,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	textSize: number?,
	round: boolean?,
	layoutOrder: number?,
	selectionOrder: number?,
	zIndex: number?,
}

export type ButtonHandle = {
	root: Frame,
	button: TextButton,
	setEnabled: (enabled: boolean) -> (),
	setText: (text: string) -> (),
	setVariant: (variant: ButtonVariant) -> (),
	setSelected: (selected: boolean) -> (),
}

type VariantColors = {
	top: Color3,
	bottom: Color3,
	edge: Color3,
	text: Color3,
}

local DEPTH = 4
local HOVER_SCALE = 1.04
local PRESS_SCALE = 0.97
local TWEEN_FAST = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_BOUNCE = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLICK_SOUND_ID = "rbxassetid://88442833509532"
local DISABLED_COLORS: VariantColors = {
	top = Color3.fromRGB(92, 86, 112),
	bottom = Color3.fromRGB(70, 64, 90),
	edge = Color3.fromRGB(40, 36, 56),
	text = Color3.fromRGB(180, 174, 200),
}

local UiKit = {}

local clickSound: Sound? = nil

local function getVariantColors(variant: ButtonVariant): VariantColors
	local colors = UiTheme.Colors
	local base = if variant == "Gold"
		then colors.Gold
		elseif variant == "Success" then colors.Green
		elseif variant == "Danger" then colors.Danger
		elseif variant == "Warning" then colors.Orange
		elseif variant == "Neutral" then colors.SurfaceSoft
		else colors.Brand
	local darkText = variant == "Gold" or variant == "Success" or variant == "Warning"
	return {
		top = base:Lerp(colors.White, 0.22),
		bottom = base,
		edge = base:Lerp(colors.Outline, 0.55),
		text = if darkText then colors.Outline else colors.Ink,
	}
end

function UiKit.playClick(pitch: number?)
	local sound = clickSound
	if sound == nil then
		local newSound = Instance.new("Sound")
		newSound.Name = "BlocoPuffUiClick"
		newSound.SoundId = CLICK_SOUND_ID
		newSound.Volume = 0.35
		newSound.Parent = SoundService
		clickSound = newSound
		sound = newSound
	end
	if sound ~= nil then
		sound.PlaybackSpeed = pitch or 1.15
		SoundService:PlayLocalSound(sound)
	end
end

-- Pequeno "salto" de escala usado para chamar atenção a uma mudança.
function UiKit.pop(target: GuiObject, strength: number?)
	local scale = target:FindFirstChild("PopScale")
	if scale == nil or not scale:IsA("UIScale") then
		local newScale = Instance.new("UIScale")
		newScale.Name = "PopScale"
		newScale.Parent = target
		scale = newScale
	end
	local uiScale = scale :: UIScale
	uiScale.Scale = 1 + (strength or 0.14)
	TweenService:Create(uiScale, TWEEN_BOUNCE, { Scale = 1 }):Play()
end

function UiKit.createButton(parent: Instance, options: ButtonOptions): ButtonHandle
	local variant: ButtonVariant = options.variant or "Primary"
	local radius = if options.round == true then 999 else 12
	local zIndex = options.zIndex or 1

	local root = Instance.new("Frame")
	root.Name = options.name
	root.Size = options.size
	root.Position = options.position or UDim2.new()
	root.AnchorPoint = options.anchorPoint or Vector2.zero
	root.BackgroundTransparency = 1
	root.LayoutOrder = options.layoutOrder or 0
	root.ZIndex = zIndex
	root.Parent = parent

	local rootScale = Instance.new("UIScale")
	rootScale.Name = "InteractionScale"
	rootScale.Parent = root

	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.Position = UDim2.fromOffset(0, DEPTH)
	edge.Size = UDim2.new(1, 0, 1, -DEPTH)
	edge.BorderSizePixel = 0
	edge.ZIndex = zIndex
	edge.Parent = root
	UiTheme.addCorner(edge, radius)

	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -DEPTH)
	face.BackgroundColor3 = UiTheme.Colors.White
	face.BorderSizePixel = 0
	face.AutoButtonColor = false
	-- O texto do próprio botão fica invisível (mantido só como nome
	-- acessível): um UIGradient tinge também o texto do objeto em que está,
	-- o que deixava o rótulo da mesma cor do fundo. O rótulo visível é um
	-- TextLabel filho, que o gradiente não afeta.
	face.Text = options.text
	face.TextTransparency = 1
	face.Active = true
	face.Selectable = true
	face.SelectionOrder = options.selectionOrder or 0
	face.ZIndex = zIndex + 1
	face.Parent = root
	UiTheme.addCorner(face, radius)
	local faceGradient = UiTheme.addGradient(face, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local faceStroke = UiTheme.addStroke(face, UiTheme.Colors.Outline, 2)
	faceStroke.Transparency = 0.25
	UiTheme.addPadding(face, 8, 2)

	-- Brilho sutil na metade de cima, dando volume ao botão.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromOffset(4, 3)
	shine.Size = UDim2.new(1, -8, 0.42, 0)
	shine.BackgroundColor3 = UiTheme.Colors.White
	shine.BackgroundTransparency = 0.82
	shine.BorderSizePixel = 0
	shine.ZIndex = zIndex + 1
	shine.Parent = face
	UiTheme.addCorner(shine, if options.round == true then 999 else 9)

	local label = UiTheme.createLabel(face, "Label", options.text, UiTheme.Fonts.Heading, options.textSize or 16)
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = zIndex + 2

	local enabled = true
	local hovered = false
	local selected = false

	local function applyColors()
		local colors = if enabled then getVariantColors(variant) else DISABLED_COLORS
		faceGradient.Color = ColorSequence.new(colors.top, colors.bottom)
		edge.BackgroundColor3 = colors.edge
		label.TextColor3 = colors.text
		faceStroke.Color = if selected then UiTheme.Colors.Gold else UiTheme.Colors.Outline
		faceStroke.Thickness = if selected then 3 else 2
		faceStroke.Transparency = if selected then 0 else 0.25
	end

	local function setFaceOffset(offset: number)
		TweenService:Create(face, TWEEN_FAST, { Position = UDim2.fromOffset(0, offset) }):Play()
	end

	face.MouseEnter:Connect(function()
		hovered = true
		if enabled then
			TweenService:Create(rootScale, TWEEN_FAST, { Scale = HOVER_SCALE }):Play()
		end
	end)
	face.MouseLeave:Connect(function()
		hovered = false
		TweenService:Create(rootScale, TWEEN_FAST, { Scale = 1 }):Play()
		setFaceOffset(0)
	end)
	face.SelectionGained:Connect(function()
		if enabled then
			TweenService:Create(rootScale, TWEEN_FAST, { Scale = HOVER_SCALE }):Play()
		end
	end)
	face.SelectionLost:Connect(function()
		TweenService:Create(rootScale, TWEEN_FAST, { Scale = 1 }):Play()
	end)
	face.InputBegan:Connect(function(input)
		if not enabled then
			return
		end
		local inputType = input.UserInputType
		if
			inputType == Enum.UserInputType.MouseButton1
			or inputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			setFaceOffset(DEPTH - 1)
			TweenService:Create(rootScale, TWEEN_FAST, { Scale = PRESS_SCALE }):Play()
		end
	end)
	face.InputEnded:Connect(function(input)
		local inputType = input.UserInputType
		if
			inputType == Enum.UserInputType.MouseButton1
			or inputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			setFaceOffset(0)
			TweenService:Create(rootScale, TWEEN_BOUNCE, { Scale = if hovered and enabled then HOVER_SCALE else 1 }):Play()
		end
	end)
	face.Activated:Connect(function()
		if enabled then
			UiKit.playClick()
		end
	end)

	applyColors()

	local handle = {} :: ButtonHandle
	handle.root = root
	handle.button = face
	handle.setEnabled = function(newEnabled: boolean)
		enabled = newEnabled
		face.Active = newEnabled
		face.AutoButtonColor = false
		label.TextTransparency = if newEnabled then 0 else 0.25
		if not newEnabled then
			setFaceOffset(0)
			rootScale.Scale = 1
		end
		applyColors()
	end
	handle.setText = function(text: string)
		face.Text = text
		label.Text = text
	end
	handle.setVariant = function(newVariant: ButtonVariant)
		variant = newVariant
		applyColors()
	end
	handle.setSelected = function(newSelected: boolean)
		selected = newSelected
		applyColors()
	end

	return handle
end

-- Logotipo "BLOCO PUFF": duas linhas com gradientes da marca, contorno
-- escuro e leve inclinação. Usado no lobby e no painel admin.
function UiKit.createWordmark(parent: Instance, height: number, zIndex: number?): Frame
	local layer = zIndex or 1
	local mark = Instance.new("Frame")
	mark.Name = "Wordmark"
	mark.Size = UDim2.fromOffset(math.floor(height * 2.6), height)
	mark.BackgroundTransparency = 1
	mark.Rotation = -3
	mark.ZIndex = layer
	mark.Parent = parent

	local function createLine(name: string, text: string, top: Color3, bottom: Color3, y: number, heightRatio: number)
		local label = UiTheme.createLabel(mark, name, text, UiTheme.Fonts.Display, math.floor(height * heightRatio), UiTheme.Colors.White)
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, heightRatio)
		label.TextScaled = true
		label.ZIndex = layer
		UiTheme.addGradient(label, top, bottom)
		UiTheme.addTextOutline(label, math.max(2, math.floor(height / 18)))
	end

	createLine("Bloco", "BLOCO", UiTheme.Colors.White, UiTheme.Colors.Brand, 0, 0.5)
	createLine("Puff", "PUFF", UiTheme.Colors.Gold:Lerp(UiTheme.Colors.White, 0.35), UiTheme.Colors.GoldDeep, 0.44, 0.56)
	return mark
end

return table.freeze(UiKit)
