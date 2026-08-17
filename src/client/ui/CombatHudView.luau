--!strict

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

type ResponsiveScaleHandle = ResponsiveScale.ResponsiveScaleHandle

export type CombatHudViewHandle = {
	setVisible: (visible: boolean) -> (),
	setTimer: (text: string) -> (),
	setParticipants: (count: number) -> (),
	setArenaIntegrity: (remaining: number, total: number) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffCombatHud"
local REFERENCE_VIEWPORT = Vector2.new(1280, 720)

local CombatHudView = {}

local function createPanelRoot(
	parent: Instance,
	name: string,
	anchorPoint: Vector2,
	position: UDim2,
	size: UDim2,
	accentColor: Color3,
	scaleHandles: { ResponsiveScaleHandle }
): (Frame, Frame)
	local root = Instance.new("Frame")
	root.Name = name
	root.AnchorPoint = anchorPoint
	root.Position = position
	root.Size = size
	root.BackgroundTransparency = 1
	root.Parent = parent
	table.insert(scaleHandles, ResponsiveScale.attach(root, REFERENCE_VIEWPORT, 0.8, 1.08))

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 16)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = UiTheme.Colors.Panel
	card.BackgroundTransparency = 0.03
	card.BorderSizePixel = 0
	card.ZIndex = 1
	card.Parent = root
	UiTheme.addCorner(card, 16)
	UiTheme.addStroke(card, accentColor, 3)

	return root, card
end

local function createLabel(
	name: string,
	parent: Instance,
	text: string,
	font: Enum.Font,
	textSize: number,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextWrapped = true
	label.ZIndex = 2
	label.Parent = parent
	return label
end

function CombatHudView.new(playerGui: PlayerGui): CombatHudViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 11)
	screenGui.Enabled = false
	local scaleHandles: { ResponsiveScaleHandle } = {}

	local timerRoot, timerCard = createPanelRoot(
		screenGui,
		"TimerPanel",
		Vector2.new(0.5, 0),
		UDim2.new(0.5, 0, 0, 16),
		UDim2.fromOffset(144, 54),
		UiTheme.Colors.Blue,
		scaleHandles
	)
	local timerLabel = createLabel(
		"TimerLabel",
		timerCard,
		"03:00",
		UiTheme.Fonts.Heading,
		27,
		UiTheme.Colors.Ink
	)

	local playersRoot, playersCard = createPanelRoot(
		screenGui,
		"PlayersPanel",
		Vector2.new(1, 0),
		UDim2.new(1, -18, 0, 16),
		UDim2.fromOffset(174, 54),
		UiTheme.Colors.Purple,
		scaleHandles
	)
	local playersCaption = createLabel(
		"PlayersCaption",
		playersCard,
		"JOGADORES",
		UiTheme.Fonts.BodyBold,
		12,
		UiTheme.Colors.InkSoft
	)
	playersCaption.Position = UDim2.new(0, 14, 0, 7)
	playersCaption.Size = UDim2.new(1, -66, 0, 18)
	playersCaption.TextXAlignment = Enum.TextXAlignment.Left

	local playersValue = createLabel(
		"PlayersValue",
		playersCard,
		"0",
		UiTheme.Fonts.Heading,
		27,
		UiTheme.Colors.Ink
	)
	playersValue.AnchorPoint = Vector2.new(1, 0.5)
	playersValue.Position = UDim2.new(1, -14, 0.5, 0)
	playersValue.Size = UDim2.fromOffset(44, 40)
	playersValue.TextXAlignment = Enum.TextXAlignment.Right

	local playersSubLabel = createLabel(
		"PlayersSubLabel",
		playersCard,
		"NA RODADA",
		UiTheme.Fonts.Body,
		10,
		UiTheme.Colors.InkSoft
	)
	playersSubLabel.Position = UDim2.new(0, 14, 0, 25)
	playersSubLabel.Size = UDim2.new(1, -66, 0, 16)
	playersSubLabel.TextXAlignment = Enum.TextXAlignment.Left

	local arenaRoot, arenaCard = createPanelRoot(
		screenGui,
		"ArenaPanel",
		Vector2.new(0, 0),
		UDim2.new(0, 18, 0, 16),
		UDim2.fromOffset(270, 70),
		UiTheme.Colors.Green,
		scaleHandles
	)

	local arenaTitle = createLabel(
		"ArenaTitle",
		arenaCard,
		"ARENA 100%",
		UiTheme.Fonts.BodyBold,
		14,
		UiTheme.Colors.Ink
	)
	arenaTitle.Position = UDim2.new(0, 15, 0, 8)
	arenaTitle.Size = UDim2.new(0.65, 0, 0, 20)
	arenaTitle.TextXAlignment = Enum.TextXAlignment.Left

	local arenaExact = createLabel(
		"ArenaExact",
		arenaCard,
		"225 / 225",
		UiTheme.Fonts.Body,
		12,
		UiTheme.Colors.InkSoft
	)
	arenaExact.AnchorPoint = Vector2.new(1, 0)
	arenaExact.Position = UDim2.new(1, -15, 0, 9)
	arenaExact.Size = UDim2.new(0.35, 0, 0, 18)
	arenaExact.TextXAlignment = Enum.TextXAlignment.Right

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "IntegrityTrack"
	progressTrack.Position = UDim2.new(0, 15, 0, 39)
	progressTrack.Size = UDim2.new(1, -30, 0, 14)
	progressTrack.BackgroundColor3 = UiTheme.Colors.Track
	progressTrack.BackgroundTransparency = 0.72
	progressTrack.BorderSizePixel = 0
	progressTrack.ClipsDescendants = true
	progressTrack.ZIndex = 2
	progressTrack.Parent = arenaCard
	UiTheme.addCorner(progressTrack, 7)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "IntegrityFill"
	progressFill.Size = UDim2.fromScale(1, 1)
	progressFill.BackgroundColor3 = UiTheme.Colors.Green
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 3
	progressFill.Parent = progressTrack
	UiTheme.addCorner(progressFill, 7)

	local cameraConnection: RBXScriptConnection? = nil
	local workspaceConnection: RBXScriptConnection? = nil

	local function updateLayout()
		local camera = Workspace.CurrentCamera
		local compact = camera ~= nil and camera.ViewportSize.X < 700
		arenaRoot.Position = UDim2.new(0, if compact then 12 else 18, 0, 16)
		playersRoot.Position = UDim2.new(1, if compact then -12 else -18, 0, 16)
		timerRoot.Position = UDim2.new(0.5, 0, 0, if compact then 84 else 16)
	end

	local function connectCamera()
		if cameraConnection ~= nil then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end

		local camera = Workspace.CurrentCamera
		if camera ~= nil then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
		end
		updateLayout()
	end

	workspaceConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
	connectCamera()

	local handle = {} :: CombatHudViewHandle
	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.setTimer = function(text: string)
		timerLabel.Text = text
	end

	handle.setParticipants = function(count: number)
		playersValue.Text = tostring(math.max(0, math.floor(count)))
	end

	handle.setArenaIntegrity = function(remaining: number, total: number)
		local safeTotal = math.max(0, math.floor(total))
		local safeRemaining = math.clamp(math.floor(remaining), 0, safeTotal)
		local ratio = if safeTotal > 0 then safeRemaining / safeTotal else 0
		local percent = math.floor((ratio * 100) + 0.5)
		local fillColor = if ratio > 0.6
			then UiTheme.Colors.Green
			elseif ratio > 0.3 then UiTheme.Colors.Orange
			else UiTheme.Colors.Danger

		arenaTitle.Text = string.format("ARENA %d%%", percent)
		arenaExact.Text = string.format("%d / %d", safeRemaining, safeTotal)
		TweenService:Create(progressFill, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(ratio, 1),
			BackgroundColor3 = fillColor,
		}):Play()
	end

	handle.destroy = function()
		if cameraConnection ~= nil then
			cameraConnection:Disconnect()
		end
		if workspaceConnection ~= nil then
			workspaceConnection:Disconnect()
		end
		for _, scaleHandle in ipairs(scaleHandles) do
			scaleHandle.destroy()
		end
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(CombatHudView)
