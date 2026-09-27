--!strict

-- Identidade visual do BlocoPuff: design tokens e construtores compartilhados
-- por todas as telas do cliente.
--
-- Conceito: "noite na mansão" (fundos roxo-escuros) com as duas cores do
-- Puffador como marca — lilás Puff e dourado Puff. Títulos usam uma fonte
-- arredondada e encorpada com contorno escuro; painéis têm gradiente suave,
-- borda em gradiente lilás→dourado e sombra sólida deslocada.

export type ColorPalette = {
	Ink: Color3,
	InkSoft: Color3,
	Panel: Color3,
	Surface: Color3,
	SurfaceSoft: Color3,
	Border: Color3,
	Shadow: Color3,
	Outline: Color3,
	White: Color3,
	Brand: Color3,
	BrandDeep: Color3,
	Gold: Color3,
	GoldDeep: Color3,
	Purple: Color3,
	Blue: Color3,
	Yellow: Color3,
	Orange: Color3,
	Pink: Color3,
	Green: Color3,
	Danger: Color3,
	Track: Color3,
}

export type FontPalette = {
	Display: Enum.Font,
	Heading: Enum.Font,
	Body: Enum.Font,
	BodyBold: Enum.Font,
}

export type PanelOptions = {
	accent: Color3?,
	radius: number?,
	transparency: number?,
	shadow: boolean?,
}

local UiTheme = {}

UiTheme.Colors = table.freeze({
	Ink = Color3.fromRGB(255, 248, 238),
	InkSoft = Color3.fromRGB(190, 180, 220),
	Panel = Color3.fromRGB(26, 21, 48),
	Surface = Color3.fromRGB(42, 34, 71),
	SurfaceSoft = Color3.fromRGB(58, 47, 96),
	Border = Color3.fromRGB(124, 108, 178),
	Shadow = Color3.fromRGB(8, 5, 18),
	Outline = Color3.fromRGB(14, 10, 28),
	White = Color3.fromRGB(255, 255, 255),
	Brand = Color3.fromRGB(169, 139, 255),
	BrandDeep = Color3.fromRGB(104, 76, 204),
	Gold = Color3.fromRGB(255, 209, 102),
	GoldDeep = Color3.fromRGB(214, 150, 40),
	Purple = Color3.fromRGB(169, 139, 255),
	Blue = Color3.fromRGB(92, 200, 255),
	Yellow = Color3.fromRGB(255, 209, 102),
	Orange = Color3.fromRGB(255, 159, 67),
	Pink = Color3.fromRGB(255, 122, 186),
	Green = Color3.fromRGB(79, 214, 160),
	Danger = Color3.fromRGB(255, 93, 115),
	Track = Color3.fromRGB(14, 10, 28),
}) :: ColorPalette

UiTheme.Fonts = table.freeze({
	Display = Enum.Font.FredokaOne,
	Heading = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	BodyBold = Enum.Font.GothamBold,
}) :: FontPalette

-- Deslocamento da sombra sólida, característico da identidade.
UiTheme.ShadowOffset = Vector2.new(0, 4)

function UiTheme.createScreenGui(name: string, playerGui: PlayerGui, displayOrder: number): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screenGui.ClipToDeviceSafeArea = true
	screenGui.DisplayOrder = displayOrder
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	return screenGui
end

function UiTheme.addCorner(instance: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 16)
	corner.Parent = instance
	return corner
end

function UiTheme.addStroke(instance: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or UiTheme.Colors.Border
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = 0.2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

function UiTheme.addPadding(instance: Instance, horizontal: number, vertical: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, horizontal)
	padding.PaddingRight = UDim.new(0, horizontal)
	padding.PaddingTop = UDim.new(0, vertical)
	padding.PaddingBottom = UDim.new(0, vertical)
	padding.Parent = instance
	return padding
end

function UiTheme.addTextConstraint(label: TextLabel, minimum: number, maximum: number): UITextSizeConstraint
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minimum
	constraint.MaxTextSize = maximum
	constraint.Parent = label
	return constraint
end

-- Gradiente vertical (topo → base). Em UIStroke vira borda em gradiente.
function UiTheme.addGradient(instance: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

-- Contorno escuro nos textos de destaque: leitura garantida sobre qualquer
-- fundo e o visual "de jogo" da identidade.
function UiTheme.addTextOutline(label: TextLabel | TextButton, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = UiTheme.Colors.Outline
	stroke.Thickness = thickness or 2
	stroke.Transparency = 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

-- Sombra sólida deslocada para baixo (sem desfoque), assinatura da identidade.
function UiTheme.createShadow(parent: Instance, position: UDim2, size: UDim2, radius: number?): Frame
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = position + UDim2.fromOffset(UiTheme.ShadowOffset.X, UiTheme.ShadowOffset.Y)
	shadow.Size = size
	shadow.BackgroundColor3 = UiTheme.Colors.Shadow
	shadow.BackgroundTransparency = 0.35
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = parent
	UiTheme.addCorner(shadow, radius)
	return shadow
end

-- Aplica o visual padrão de painel da marca a um Frame existente: fundo
-- noturno com gradiente, borda em gradiente e cantos arredondados.
-- Retorna a borda para que a tela possa animar sua cor/transparência.
function UiTheme.stylePanel(frame: GuiObject, options: PanelOptions?): UIStroke
	local accent = if options ~= nil and options.accent ~= nil then options.accent else UiTheme.Colors.Brand
	local radius = if options ~= nil and options.radius ~= nil then options.radius else 16
	local transparency = if options ~= nil and options.transparency ~= nil then options.transparency else 0.08

	frame.BackgroundColor3 = UiTheme.Colors.White
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	UiTheme.addCorner(frame, radius)
	UiTheme.addGradient(frame, UiTheme.Colors.Surface, UiTheme.Colors.Panel)

	local stroke = UiTheme.addStroke(frame, UiTheme.Colors.White, 2)
	stroke.Transparency = 0
	UiTheme.addGradient(stroke, accent, accent:Lerp(UiTheme.Colors.Gold, 0.55), 45)
	return stroke
end

-- Rótulo padrão: evita repetir as mesmas oito propriedades em cada tela.
function UiTheme.createLabel(
	parent: Instance,
	name: string,
	text: string,
	font: Enum.Font,
	textSize: number,
	color: Color3?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color or UiTheme.Colors.Ink
	label.TextWrapped = true
	label.Parent = parent
	return label
end

return table.freeze(UiTheme)
