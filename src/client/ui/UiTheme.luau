--!strict

-- Design tokens e construtores visuais compartilhados por todas as telas do
-- cliente. Mantém cor, tipografia, borda e safe area consistentes.

export type ColorPalette = {
	Ink: Color3,
	InkSoft: Color3,
	Panel: Color3,
	White: Color3,
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
	Heading: Enum.Font,
	Body: Enum.Font,
	BodyBold: Enum.Font,
}

local UiTheme = {}

UiTheme.Colors = table.freeze({
	Ink = Color3.fromRGB(58, 43, 69),
	InkSoft = Color3.fromRGB(102, 84, 115),
	Panel = Color3.fromRGB(255, 250, 240),
	White = Color3.fromRGB(255, 255, 255),
	Purple = Color3.fromRGB(180, 139, 255),
	Blue = Color3.fromRGB(105, 194, 255),
	Yellow = Color3.fromRGB(255, 221, 91),
	Orange = Color3.fromRGB(255, 157, 91),
	Pink = Color3.fromRGB(255, 126, 190),
	Green = Color3.fromRGB(94, 214, 154),
	Danger = Color3.fromRGB(241, 88, 115),
	Track = Color3.fromRGB(91, 73, 105),
}) :: ColorPalette

UiTheme.Fonts = table.freeze({
	Heading = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	BodyBold = Enum.Font.GothamBold,
}) :: FontPalette

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
	stroke.Color = color or UiTheme.Colors.Ink
	stroke.Thickness = thickness or 3
	stroke.Transparency = 0.05
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

function UiTheme.createShadow(parent: Instance, position: UDim2, size: UDim2, radius: number?): Frame
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = position + UDim2.fromOffset(4, 5)
	shadow.Size = size
	shadow.BackgroundColor3 = UiTheme.Colors.Ink
	shadow.BackgroundTransparency = 0.25
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = parent
	UiTheme.addCorner(shadow, radius)
	return shadow
end

return table.freeze(UiTheme)
