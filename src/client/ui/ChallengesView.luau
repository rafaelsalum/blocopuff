--!strict

-- Painel DESAFIOS (Fase 4.3): os 3 desafios do dia com progresso, o ciclo
-- de 7 dias do retorno diário com a sequência, e as conquistas secretas
-- ("???" com uma pista até conseguir). Só visual: tudo vem do perfil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DailyConfig = require(ReplicatedStorage.Shared.config.DailyConfig)
local SecretCatalog = require(ReplicatedStorage.Shared.config.SecretCatalog)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type ChallengeDefinition = DailyConfig.ChallengeDefinition

export type ChallengesViewHandle = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setProfile: (snapshot: ProfileSnapshot) -> (),
	destroy: () -> (),
}

type ChallengeRow = {
	frame: Frame,
	title: TextLabel,
	fill: Frame,
	count: TextLabel,
	reward: TextLabel,
}

type DayBox = {
	frame: Frame,
	stroke: UIStroke,
	label: TextLabel,
	check: TextLabel,
}

type SecretBadge = {
	frame: Frame,
	name: TextLabel,
	hint: TextLabel,
	stroke: UIStroke,
}

local GUI_NAME = "BlocoPuffChallenges"
local PANEL_SIZE = Vector2.new(580, 470)
local ROW_HEIGHT = 46

local ChallengesView = {}

local function findChallenge(id: string): ChallengeDefinition?
	for _, definition in ipairs(DailyConfig.Challenges) do
		if definition.id == id then
			return definition
		end
	end
	return nil
end

local function formatCountdown(seconds: number): string
	if seconds <= 0 then
		return "Novos desafios chegando…"
	end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("Novos desafios em %dh %02dmin", hours, minutes)
	end
	return string.format("Novos desafios em %d min", math.max(1, minutes))
end

local function sectionTitle(parent: Instance, name: string, text: string, y: number): TextLabel
	local label = UiTheme.createLabel(parent, name, text, UiTheme.Fonts.Display, 16, UiTheme.Colors.Gold)
	label.Position = UDim2.fromOffset(20, y)
	label.Size = UDim2.new(1, -40, 0, 20)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 3
	UiTheme.addTextOutline(label, 1.5)
	return label
end

function ChallengesView.new(playerGui: PlayerGui, onOpened: () -> ()): ChallengesViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 27)
	screenGui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	local responsive = ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.55, 1.0)
	local pop = Instance.new("UIScale")
	pop.Parent = root

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 20)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 2
	card.Parent = root
	UiTheme.stylePanel(card, { accent = UiTheme.Colors.Green, radius = 20 })

	local title = UiTheme.createLabel(card, "Title", "📋 DESAFIOS", UiTheme.Fonts.Display, 28, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(0, 240, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	UiTheme.addTextOutline(title, 2.5)

	local timer = UiTheme.createLabel(card, "Timer", "", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.InkSoft)
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.new(1, -68, 0, 20)
	timer.Size = UDim2.fromOffset(240, 20)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.ZIndex = 3

	local closeButton = UiKit.createButton(card, {
		name = "Close",
		text = "✕",
		variant = "Neutral",
		size = UDim2.fromOffset(40, 36),
		position = UDim2.new(1, -16, 0, 12),
		anchorPoint = Vector2.new(1, 0),
		textSize = 18,
		zIndex = 4,
	})

	-- Desafios do dia.
	sectionTitle(card, "TodayTitle", "HOJE", 56)
	local rows: { ChallengeRow } = {}
	for index = 1, #DailyConfig.Tiers do
		local frame = Instance.new("Frame")
		frame.Name = `Challenge{index}`
		frame.Position = UDim2.fromOffset(16, 80 + (index - 1) * (ROW_HEIGHT + 6))
		frame.Size = UDim2.new(1, -32, 0, ROW_HEIGHT)
		frame.BackgroundColor3 = UiTheme.Colors.Outline
		frame.BackgroundTransparency = 0.35
		frame.ZIndex = 3
		frame.Parent = card
		UiTheme.addCorner(frame, 12)
		local rowTitle = UiTheme.createLabel(frame, "Title", "", UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.Ink)
		rowTitle.Position = UDim2.fromOffset(12, 5)
		rowTitle.Size = UDim2.new(1, -110, 0, 20)
		rowTitle.TextXAlignment = Enum.TextXAlignment.Left
		rowTitle.ZIndex = 4
		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(12, 29)
		track.Size = UDim2.new(1, -170, 0, 9)
		track.BackgroundColor3 = UiTheme.Colors.Track
		track.ZIndex = 4
		track.Parent = frame
		UiTheme.addCorner(track, 999)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = UiTheme.Colors.White
		fill.ZIndex = 5
		fill.Parent = track
		UiTheme.addCorner(fill, 999)
		UiTheme.addGradient(fill, UiTheme.Colors.Green, UiTheme.Colors.Blue, 0)
		local count = UiTheme.createLabel(frame, "Count", "", UiTheme.Fonts.Display, 14, UiTheme.Colors.Ink)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -92, 0, 22)
		count.Size = UDim2.fromOffset(62, 22)
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.ZIndex = 4
		local reward = UiTheme.createLabel(frame, "Reward", "", UiTheme.Fonts.Display, 16, UiTheme.Colors.Gold)
		reward.AnchorPoint = Vector2.new(1, 0.5)
		reward.Position = UDim2.new(1, -12, 0.5, 0)
		reward.Size = UDim2.fromOffset(76, 28)
		reward.TextXAlignment = Enum.TextXAlignment.Right
		reward.ZIndex = 4
		UiTheme.addTextOutline(reward, 1.5)
		table.insert(rows, { frame = frame, title = rowTitle, fill = fill, count = count, reward = reward })
	end

	-- Retorno diário.
	local dailyTop = 80 + #DailyConfig.Tiers * (ROW_HEIGHT + 6) + 8
	sectionTitle(card, "DailyTitle", "RETORNO DIÁRIO", dailyTop)
	local streakLabel = UiTheme.createLabel(card, "Streak", "", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.Ink)
	streakLabel.AnchorPoint = Vector2.new(1, 0)
	streakLabel.Position = UDim2.new(1, -20, 0, dailyTop + 2)
	streakLabel.Size = UDim2.fromOffset(300, 18)
	streakLabel.TextXAlignment = Enum.TextXAlignment.Right
	streakLabel.ZIndex = 3
	local days = Instance.new("Frame")
	days.Name = "Days"
	days.Position = UDim2.fromOffset(16, dailyTop + 24)
	days.Size = UDim2.new(1, -32, 0, 50)
	days.BackgroundTransparency = 1
	days.ZIndex = 3
	days.Parent = card
	local dayLayout = Instance.new("UIListLayout")
	dayLayout.FillDirection = Enum.FillDirection.Horizontal
	dayLayout.Padding = UDim.new(0, 6)
	dayLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dayLayout.Parent = days
	local rewards = DailyConfig.DailyRewards
	local dayBoxes: { DayBox } = {}
	for index, tickets in ipairs(rewards) do
		local frame = Instance.new("Frame")
		frame.Name = `Day{index}`
		frame.LayoutOrder = index
		frame.Size = UDim2.new(1 / #rewards, -6, 1, 0)
		frame.BackgroundColor3 = UiTheme.Colors.Surface
		frame.ZIndex = 4
		frame.Parent = days
		UiTheme.addCorner(frame, 10)
		local stroke = UiTheme.addStroke(frame, UiTheme.Colors.Border, 1.5)
		local label = UiTheme.createLabel(frame, "Label", string.format("Dia %d\n🎟 %d", index, tickets), UiTheme.Fonts.BodyBold, 12, UiTheme.Colors.Ink)
		label.Size = UDim2.fromScale(1, 1)
		label.ZIndex = 5
		local check = UiTheme.createLabel(frame, "Check", "✓", UiTheme.Fonts.Display, 14, UiTheme.Colors.Outline)
		check.AnchorPoint = Vector2.new(1, 0)
		check.Position = UDim2.new(1, 2, 0, -4)
		check.Size = UDim2.fromOffset(18, 18)
		check.BackgroundTransparency = 0
		check.BackgroundColor3 = UiTheme.Colors.Green
		check.ZIndex = 6
		check.Visible = false
		UiTheme.addCorner(check, 999)
		table.insert(dayBoxes, { frame = frame, stroke = stroke, label = label, check = check })
	end
	local graceNote = UiTheme.createLabel(card, "Grace", "Perdeu um dia? Tudo bem: a sequência continua.", UiTheme.Fonts.Body, 11, UiTheme.Colors.InkSoft)
	graceNote.Position = UDim2.fromOffset(20, dailyTop + 78)
	graceNote.Size = UDim2.new(1, -40, 0, 16)
	graceNote.TextXAlignment = Enum.TextXAlignment.Left
	graceNote.ZIndex = 3

	-- Conquistas secretas.
	local secretTop = dailyTop + 102
	local secretTitle = sectionTitle(card, "SecretTitle", "CONQUISTAS SECRETAS", secretTop)
	local secretRow = Instance.new("Frame")
	secretRow.Name = "Secrets"
	secretRow.Position = UDim2.fromOffset(16, secretTop + 24)
	secretRow.Size = UDim2.new(1, -32, 0, 56)
	secretRow.BackgroundTransparency = 1
	secretRow.ZIndex = 3
	secretRow.Parent = card
	local secretLayout = Instance.new("UIListLayout")
	secretLayout.FillDirection = Enum.FillDirection.Horizontal
	secretLayout.Padding = UDim.new(0, 6)
	secretLayout.SortOrder = Enum.SortOrder.LayoutOrder
	secretLayout.Parent = secretRow
	local secrets = SecretCatalog.all()
	local badges: { [string]: SecretBadge } = {}
	for index, definition in ipairs(secrets) do
		local frame = Instance.new("Frame")
		frame.Name = definition.id
		frame.LayoutOrder = index
		frame.Size = UDim2.new(1 / #secrets, -6, 1, 0)
		frame.BackgroundColor3 = UiTheme.Colors.Surface
		frame.ZIndex = 4
		frame.Parent = secretRow
		UiTheme.addCorner(frame, 10)
		local stroke = UiTheme.addStroke(frame, UiTheme.Colors.Border, 1.5)
		local name = UiTheme.createLabel(frame, "Name", "???", UiTheme.Fonts.Display, 13, UiTheme.Colors.InkSoft)
		name.Position = UDim2.fromOffset(4, 4)
		name.Size = UDim2.new(1, -8, 0, 18)
		name.TextScaled = true
		name.ZIndex = 5
		UiTheme.addTextConstraint(name, 9, 13)
		local hint = UiTheme.createLabel(frame, "Hint", definition.hint, UiTheme.Fonts.Body, 10, UiTheme.Colors.InkSoft)
		hint.Position = UDim2.fromOffset(4, 22)
		hint.Size = UDim2.new(1, -8, 1, -26)
		hint.TextScaled = true
		hint.ZIndex = 5
		UiTheme.addTextConstraint(hint, 7, 10)
		badges[definition.id] = { frame = frame, name = name, hint = hint, stroke = stroke }
	end

	local nextResetAt = 0
	local generation = 0

	local function refreshTimer()
		timer.Text = if nextResetAt > 0 then formatCountdown(nextResetAt - os.time()) else ""
	end

	local handle = {} :: ChallengesViewHandle

	handle.setProfile = function(snapshot: ProfileSnapshot)
		nextResetAt = snapshot.nextResetAt
		refreshTimer()
		for index, row in ipairs(rows) do
			local state = snapshot.challenges[index]
			local definition = if state ~= nil then findChallenge(state.id) else nil
			row.frame.Visible = definition ~= nil
			if state ~= nil and definition ~= nil then
				row.title.Text = definition.title
				local ratio = math.clamp(state.progress / math.max(1, definition.target), 0, 1)
				TweenService:Create(row.fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(if state.done then 1 else ratio, 1) }):Play()
				row.count.Text = string.format("%d/%d", math.min(state.progress, definition.target), definition.target)
				row.reward.Text = if state.done then "✓ FEITO" else string.format("+%d 🎟", definition.tickets)
				row.reward.TextColor3 = if state.done then UiTheme.Colors.Green else UiTheme.Colors.Gold
			end
		end

		local daily = snapshot.daily
		local cycleDay = if daily.streak > 0 then ((daily.streak - 1) % #rewards) + 1 else 0
		for index, box in ipairs(dayBoxes) do
			local claimed = index <= cycleDay
			local isToday = index == cycleDay
			box.check.Visible = claimed
			box.frame.BackgroundColor3 = if isToday then UiTheme.Colors.SurfaceSoft else UiTheme.Colors.Surface
			box.stroke.Color = if isToday then UiTheme.Colors.Gold else UiTheme.Colors.Border
			box.stroke.Thickness = if isToday then 2.5 else 1.5
			box.label.TextTransparency = if claimed and not isToday then 0.4 else 0
		end
		streakLabel.Text = if daily.streak > 0
			then string.format("Sequência: %d %s  ·  recorde %d", daily.streak, if daily.streak == 1 then "dia" else "dias", daily.best)
			else ""

		local owned: { [string]: boolean } = {}
		for _, item in ipairs(snapshot.secrets) do
			owned[item.id] = true
		end
		local count = 0
		for _, definition in ipairs(secrets) do
			local badge = badges[definition.id]
			local has = owned[definition.id] == true
			if has then
				count += 1
			end
			badge.name.Text = if has then definition.name else "???"
			badge.name.TextColor3 = if has then UiTheme.Colors.Gold else UiTheme.Colors.InkSoft
			badge.hint.Text = if has then definition.description else definition.hint
			badge.stroke.Color = if has then UiTheme.Colors.Gold else UiTheme.Colors.Border
		end
		secretTitle.Text = string.format("CONQUISTAS SECRETAS  %d/%d", count, #secrets)
	end

	handle.open = function()
		screenGui.Enabled = true
		pop.Scale = 0.9
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		generation += 1
		local current = generation
		task.spawn(function()
			while screenGui.Enabled and generation == current do
				refreshTimer()
				task.wait(1)
			end
		end)
		onOpened()
	end

	handle.close = function()
		screenGui.Enabled = false
		generation += 1
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.destroy = function()
		generation += 1
		responsive.destroy()
		screenGui:Destroy()
	end

	closeButton.button.Activated:Connect(function()
		UiKit.playClick()
		handle.close()
	end)

	return handle
end

return table.freeze(ChallengesView)
