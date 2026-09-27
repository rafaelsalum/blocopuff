--!strict

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiTheme = require(script.Parent.UiTheme)

type ResponsiveScaleHandle = ResponsiveScale.ResponsiveScaleHandle

-- Situação de vidas do jogador local na rodada.
export type LivesState = "Hidden" | "SecondChance" | "LastLife" | "Chaos"

export type CombatHudViewHandle = {
	setVisible: (visible: boolean) -> (),
	setTimer: (text: string) -> (),
	setParticipants: (count: number) -> (),
	setArenaIntegrity: (remaining: number, total: number) -> (),
	setPersonalScore: (count: number, visible: boolean) -> (),
	setLives: (state: LivesState) -> (),
	setTimerDanger: (danger: boolean) -> (),
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
	table.insert(scaleHandles, ResponsiveScale.attach(root, REFERENCE_VIEWPORT, 0.72, 1))

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 14)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 1
	card.Parent = root
	UiTheme.stylePanel(card, { accent = accentColor, radius = 14, transparency = 0.1 })

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
		UDim2.fromOffset(118, 44),
		UiTheme.Colors.Blue,
		scaleHandles
	)
	local timerLabel = createLabel(
		"TimerLabel",
		timerCard,
		"03:00",
		UiTheme.Fonts.Display,
		24,
		UiTheme.Colors.Ink
	)
	UiTheme.addTextOutline(timerLabel, 2)

	local playersRoot, playersCard = createPanelRoot(
		screenGui,
		"PlayersPanel",
		Vector2.new(1, 0),
		UDim2.new(1, -18, 0, 16),
		UDim2.fromOffset(146, 44),
		UiTheme.Colors.Purple,
		scaleHandles
	)
	local playersCaption = createLabel(
		"PlayersCaption",
		playersCard,
		"JOGADORES",
		UiTheme.Fonts.BodyBold,
		10,
		UiTheme.Colors.InkSoft
	)
	playersCaption.Position = UDim2.new(0, 12, 0, 6)
	playersCaption.Size = UDim2.new(1, -54, 0, 15)
	playersCaption.TextXAlignment = Enum.TextXAlignment.Left

	local playersValue = createLabel(
		"PlayersValue",
		playersCard,
		"0",
		UiTheme.Fonts.Heading,
		21,
		UiTheme.Colors.Ink
	)
	playersValue.AnchorPoint = Vector2.new(1, 0.5)
	playersValue.Position = UDim2.new(1, -11, 0.5, 0)
	playersValue.Size = UDim2.fromOffset(36, 32)
	playersValue.TextXAlignment = Enum.TextXAlignment.Right
	UiTheme.addTextOutline(playersValue, 2)

	local playersSubLabel = createLabel(
		"PlayersSubLabel",
		playersCard,
		"NA RODADA",
		UiTheme.Fonts.Body,
		8,
		UiTheme.Colors.InkSoft
	)
	playersSubLabel.Position = UDim2.new(0, 12, 0, 22)
	playersSubLabel.Size = UDim2.new(1, -54, 0, 13)
	playersSubLabel.TextXAlignment = Enum.TextXAlignment.Left

	local arenaRoot, arenaCard = createPanelRoot(
		screenGui,
		"ArenaPanel",
		Vector2.new(0, 0),
		UDim2.new(0, 18, 0, 16),
		UDim2.fromOffset(220, 58),
		UiTheme.Colors.Green,
		scaleHandles
	)

	local arenaTitle = createLabel(
		"ArenaTitle",
		arenaCard,
		"ARENA 100%",
		UiTheme.Fonts.BodyBold,
		12,
		UiTheme.Colors.Ink
	)
	arenaTitle.Position = UDim2.new(0, 12, 0, 6)
	arenaTitle.Size = UDim2.new(0.65, 0, 0, 20)
	arenaTitle.TextXAlignment = Enum.TextXAlignment.Left

	local arenaExact = createLabel(
		"ArenaExact",
		arenaCard,
		"225 / 225",
		UiTheme.Fonts.Body,
		10,
		UiTheme.Colors.InkSoft
	)
	arenaExact.AnchorPoint = Vector2.new(1, 0)
	arenaExact.Position = UDim2.new(1, -12, 0, 7)
	arenaExact.Size = UDim2.new(0.35, 0, 0, 18)
	arenaExact.TextXAlignment = Enum.TextXAlignment.Right

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "IntegrityTrack"
	progressTrack.Position = UDim2.new(0, 12, 0, 35)
	progressTrack.Size = UDim2.new(1, -24, 0, 9)
	progressTrack.BackgroundColor3 = UiTheme.Colors.Track
	progressTrack.BackgroundTransparency = 0.3
	progressTrack.BorderSizePixel = 0
	progressTrack.ClipsDescendants = true
	progressTrack.ZIndex = 2
	progressTrack.Parent = arenaCard
	UiTheme.addCorner(progressTrack, 5)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "IntegrityFill"
	progressFill.Size = UDim2.fromScale(1, 1)
	progressFill.BackgroundColor3 = UiTheme.Colors.Green
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 3
	progressFill.Parent = progressTrack
	UiTheme.addCorner(progressFill, 5)
	-- Brilho no topo da barra, dando volume ao preenchimento.
	local fillShine = UiTheme.addGradient(progressFill, UiTheme.Colors.White, UiTheme.Colors.White)
	fillShine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0),
	})

	local scoreRoot, scoreCard = createPanelRoot(
		screenGui,
		"PersonalScorePanel",
		Vector2.new(0, 0),
		UDim2.new(0, 18, 0, 82),
		UDim2.fromOffset(146, 38),
		UiTheme.Colors.Yellow,
		scaleHandles
	)
	scoreRoot.Visible = false

	local scoreCaption = createLabel(
		"ScoreCaption",
		scoreCard,
		"SEUS BLOCOS",
		UiTheme.Fonts.BodyBold,
		9,
		UiTheme.Colors.InkSoft
	)
	scoreCaption.Position = UDim2.new(0, 11, 0, 0)
	scoreCaption.Size = UDim2.new(1, -50, 1, 0)
	scoreCaption.TextXAlignment = Enum.TextXAlignment.Left

	local scoreValue = createLabel(
		"ScoreValue",
		scoreCard,
		"0",
		UiTheme.Fonts.Display,
		19,
		UiTheme.Colors.Gold
	)
	scoreValue.AnchorPoint = Vector2.new(1, 0.5)
	scoreValue.Position = UDim2.new(1, -11, 0.5, 0)
	scoreValue.Size = UDim2.fromOffset(34, 28)
	scoreValue.TextXAlignment = Enum.TextXAlignment.Right
	UiTheme.addTextOutline(scoreValue, 2)
	local lastPersonalScore = 0

	local livesRoot, livesCard = createPanelRoot(
		screenGui,
		"LivesPanel",
		Vector2.new(0, 0),
		UDim2.new(0, 18, 0, 128),
		UDim2.fromOffset(146, 34),
		UiTheme.Colors.Green,
		scaleHandles
	)
	livesRoot.Visible = false
	local livesLabel = createLabel("LivesLabel", livesCard, "", UiTheme.Fonts.Display, 14, UiTheme.Colors.Green)
	UiTheme.addTextOutline(livesLabel, 2)
	local livesScale = Instance.new("UIScale")
	livesScale.Name = "Pulse"
	livesScale.Parent = livesCard
	local lastLivesState: LivesState = "Hidden"
	local timerPulse: Tween? = nil

	local cameraConnection: RBXScriptConnection? = nil
	local workspaceConnection: RBXScriptConnection? = nil

	local function updateLayout()
		local camera = Workspace.CurrentCamera
		local compact = camera ~= nil and camera.ViewportSize.X < 700
		arenaRoot.Position = UDim2.new(0, if compact then 12 else 18, 0, 16)
		scoreRoot.Position = UDim2.new(0, if compact then 12 else 18, 0, 82)
		livesRoot.Position = UDim2.new(0, if compact then 12 else 18, 0, 128)
		playersRoot.Position = UDim2.new(1, if compact then -12 else -18, 0, 16)
		timerRoot.Position = UDim2.new(0.5, 0, 0, if compact then 106 else 16)
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

	handle.setPersonalScore = function(count: number, visible: boolean)
		local safeCount = math.max(0, math.floor(count))
		scoreRoot.Visible = visible
		scoreValue.Text = tostring(safeCount)
		if visible and safeCount > lastPersonalScore then
			scoreValue.TextSize = 23
			TweenService:Create(scoreValue, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
				TextSize = 19,
			}):Play()
		end
		lastPersonalScore = safeCount
	end

	handle.setLives = function(state: LivesState)
		livesRoot.Visible = state ~= "Hidden"
		if state == "SecondChance" then
			livesLabel.Text = "♥♥ 2 VIDAS"
			livesLabel.TextColor3 = UiTheme.Colors.Green
		elseif state == "LastLife" then
			livesLabel.Text = "♥ ÚLTIMA VIDA"
			livesLabel.TextColor3 = UiTheme.Colors.Orange
		elseif state == "Chaos" then
			livesLabel.Text = "☠ SEM 2ª CHANCE"
			livesLabel.TextColor3 = UiTheme.Colors.Danger
		end
		if state ~= lastLivesState and state ~= "Hidden" then
			livesScale.Scale = 1.2
			TweenService:Create(livesScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastLivesState = state
	end

	handle.setTimerDanger = function(danger: boolean)
		if danger and timerPulse == nil then
			timerLabel.TextColor3 = UiTheme.Colors.Danger
			local pulse = TweenService:Create(
				timerLabel,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ TextSize = 28 }
			)
			pulse:Play()
			timerPulse = pulse
		elseif not danger and timerPulse ~= nil then
			timerPulse:Cancel()
			timerPulse = nil
			timerLabel.TextSize = 24
			timerLabel.TextColor3 = UiTheme.Colors.Ink
		end
	end

	handle.destroy = function()
		if timerPulse ~= nil then
			timerPulse:Cancel()
		end
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
