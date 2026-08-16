--!strict

-- Constrói e mantém a interface visual do HUD. Não conhece regras de rodada,
-- não escreve estado replicado e não contém loops: apenas cria instâncias
-- nativas e expõe setters simples para o HudController preencher.

local HUD_NAME = "BlocoPuffHud"

local COLOR_PANEL_BACKGROUND = Color3.fromRGB(255, 250, 240)
local COLOR_PANEL_STROKE = Color3.fromRGB(194, 168, 255)
local COLOR_TEXT_PRIMARY = Color3.fromRGB(64, 48, 76)
local COLOR_TEXT_SECONDARY = Color3.fromRGB(104, 88, 116)
local COLOR_TIMER_BACKGROUND = Color3.fromRGB(151, 211, 255)
local COLOR_SUBMESSAGE_BACKGROUND = Color3.fromRGB(255, 230, 148)
local COLOR_WINNER_ACCENT = Color3.fromRGB(255, 196, 92)

local FONT_HEADING = Enum.Font.FredokaOne
local FONT_BODY = Enum.Font.GothamMedium

export type HudViewHandle = {
	screenGui: ScreenGui,
	setStatusText: (text: string) -> (),
	setStatusVisible: (visible: boolean) -> (),
	setTimerText: (text: string) -> (),
	setTimerVisible: (visible: boolean) -> (),
	setParticipantsText: (text: string) -> (),
	setParticipantsVisible: (visible: boolean) -> (),
	setBlockCountText: (text: string) -> (),
	setBlockCountVisible: (visible: boolean) -> (),
	setSubMessageText: (text: string) -> (),
	setSubMessageVisible: (visible: boolean) -> (),
	setStatusHighlighted: (highlighted: boolean) -> (),
	destroy: () -> (),
}

local HudView = {}

local function applyCorner(instance: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = instance
end

local function applyStroke(instance: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0.1
	stroke.Parent = instance
	return stroke
end

local function createLabel(name: string, parent: Instance, minTextSize: number, maxTextSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.TextColor3 = COLOR_TEXT_PRIMARY
	label.Font = FONT_BODY
	label.TextWrapped = true
	label.RichText = false
	label.Text = ""
	label.Parent = parent

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MinTextSize = minTextSize
	sizeConstraint.MaxTextSize = maxTextSize
	sizeConstraint.Parent = label

	return label
end

local function createBadge(name: string, parent: Instance, backgroundColor: Color3, layoutOrder: number): Frame
	local badge = Instance.new("Frame")
	badge.Name = name
	badge.BackgroundColor3 = backgroundColor
	badge.BorderSizePixel = 0
	badge.AutomaticSize = Enum.AutomaticSize.XY
	badge.Size = UDim2.new(0, 0, 0, 0)
	badge.LayoutOrder = layoutOrder
	badge.Visible = false
	badge.Parent = parent

	applyCorner(badge, UDim.new(0, 12))

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = badge

	return badge
end

function HudView.new(playerGui: PlayerGui): HudViewHandle
	local existing = playerGui:FindFirstChild(HUD_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = HUD_NAME
	screenGui.ResetOnSpawn = false
	-- Mantém o inset padrão (false) para não sobrepor a barra superior do Roblox.
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local panel = Instance.new("Frame")
	panel.Name = "RoundPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0.02, 0)
	panel.Size = UDim2.new(0.4, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = COLOR_PANEL_BACKGROUND
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local panelSizeConstraint = Instance.new("UISizeConstraint")
	panelSizeConstraint.MinSize = Vector2.new(200, 0)
	panelSizeConstraint.MaxSize = Vector2.new(360, 10000)
	panelSizeConstraint.Parent = panel

	applyCorner(panel, UDim.new(0, 14))
	local panelStroke = applyStroke(panel, COLOR_PANEL_STROKE, 2)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = panel

	local statusLabel = createLabel("StatusLabel", panel, 14, 22)
	statusLabel.Font = FONT_HEADING
	statusLabel.TextSize = 20
	statusLabel.LayoutOrder = 1

	local timerBadge = createBadge("TimerBadge", panel, COLOR_TIMER_BACKGROUND, 2)
	local timerLabel = createLabel("TimerLabel", timerBadge, 18, 24)
	timerLabel.Font = FONT_HEADING
	timerLabel.TextSize = 22
	timerLabel.Size = UDim2.new(0, 0, 0, 0)
	timerLabel.AutomaticSize = Enum.AutomaticSize.XY

	local participantsLabel = createLabel("ParticipantsLabel", panel, 13, 18)
	participantsLabel.TextColor3 = COLOR_TEXT_SECONDARY
	participantsLabel.TextSize = 17
	participantsLabel.LayoutOrder = 3

	local blockCountLabel = createLabel("BlockCountLabel", panel, 12, 16)
	blockCountLabel.TextColor3 = COLOR_TEXT_SECONDARY
	blockCountLabel.TextSize = 15
	blockCountLabel.LayoutOrder = 4
	blockCountLabel.Visible = false

	local subMessageBadge = createBadge("SubMessageBadge", panel, COLOR_SUBMESSAGE_BACKGROUND, 5)
	local subMessageLabel = createLabel("SubMessageLabel", subMessageBadge, 13, 16)
	subMessageLabel.TextSize = 15
	subMessageLabel.Size = UDim2.new(0, 0, 0, 0)
	subMessageLabel.AutomaticSize = Enum.AutomaticSize.XY

	screenGui.Parent = playerGui

	local handle = {} :: HudViewHandle
	handle.screenGui = screenGui

	handle.setStatusText = function(text: string)
		statusLabel.Text = text
	end

	handle.setStatusVisible = function(visible: boolean)
		statusLabel.Visible = visible
	end

	handle.setTimerText = function(text: string)
		timerLabel.Text = text
	end

	handle.setTimerVisible = function(visible: boolean)
		timerBadge.Visible = visible
	end

	handle.setParticipantsText = function(text: string)
		participantsLabel.Text = text
	end

	handle.setParticipantsVisible = function(visible: boolean)
		participantsLabel.Visible = visible
	end

	handle.setBlockCountText = function(text: string)
		blockCountLabel.Text = text
	end

	handle.setBlockCountVisible = function(visible: boolean)
		blockCountLabel.Visible = visible
	end

	handle.setSubMessageText = function(text: string)
		subMessageLabel.Text = text
	end

	handle.setSubMessageVisible = function(visible: boolean)
		subMessageBadge.Visible = visible
	end

	handle.setStatusHighlighted = function(highlighted: boolean)
		panelStroke.Color = if highlighted then COLOR_WINNER_ACCENT else COLOR_PANEL_STROKE
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(HudView)
