--!strict

-- Design tokens e construtores visuais compartilhados por todas as telas do
-- cliente. Mantém cor, tipografia, borda e safe area consistentes.

export type ColorPalette = {
	Ink: Color3,
	InkSoft: Color3,
	Panel: Color3,
	Surface: Color3,
	SurfaceSoft: Color3,
	Border: Color3,
	Shadow: Color3,
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
	Ink = Color3.fromRGB(241, 245, 249),
	InkSoft = Color3.fromRGB(169, 182, 197),
	Panel = Color3.fromRGB(24, 30, 41),
	Surface = Color3.fromRGB(34, 42, 55),
	SurfaceSoft = Color3.fromRGB(44, 54, 69),
	Border = Color3.fromRGB(122, 139, 158),
	Shadow = Color3.fromRGB(5, 9, 15),
	White = Color3.fromRGB(248, 250, 252),
	Purple = Color3.fromRGB(132, 112, 181),
	Blue = Color3.fromRGB(80, 145, 178),
	Yellow = Color3.fromRGB(199, 164, 82),
	Orange = Color3.fromRGB(190, 122, 77),
	Pink = Color3.fromRGB(177, 99, 137),
	Green = Color3.fromRGB(70, 165, 126),
	Danger = Color3.fromRGB(198, 78, 91),
	Track = Color3.fromRGB(13, 19, 28),
}) :: ColorPalette

UiTheme.Fonts = table.freeze({
	Heading = Enum.Font.GothamBold,
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
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or UiTheme.Colors.Border
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = 0.35
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
	shadow.Position = position + UDim2.fromOffset(2, 3)
	shadow.Size = size
	shadow.BackgroundColor3 = UiTheme.Colors.Shadow
	shadow.BackgroundTransparency = 0.58
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = parent
	UiTheme.addCorner(shadow, radius)
	return shadow
end

return table.freeze(UiTheme)
