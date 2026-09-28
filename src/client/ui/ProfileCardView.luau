--!strict

-- Cartão de perfil no canto superior esquerdo do lobby: nível (e prestígio),
-- barra de XP, um botão que abre as estatísticas da carreira e, ao lado, os
-- botões 🏆 do ranking global, ✨ do Puffdex e 🎰 da Puff Machine (com o
-- saldo de tickets). Some durante a partida (o HUD de combate usa esse
-- canto). Só visual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LevelCurve = require(ReplicatedStorage.Shared.modules.LevelCurve)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot

export type ProfileCardViewHandle = {
	setProfile: (snapshot: ProfileSnapshot) -> (),
	setVisible: (visible: boolean) -> (),
	celebrateLevel: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffProfileCard"
local CARD_SIZE = Vector2.new(236, 66)
local STATS_SIZE = Vector2.new(236, 212)
local SIDE_BUTTON_WIDTH = 50
local SIDE_BUTTON_GAP = 8

-- Estatísticas mostradas no painel, na ordem.
local STAT_ROWS: { { key: string, label: string } } = {
	{ key = "matches", label = "Partidas" },
	{ key = "wins", label = "Vitórias" },
	{ key = "top3", label = "Top 3" },
	{ key = "knockouts", label = "Derrubadas" },
	{ key = "blocksDestroyed", label = "Blocos destruídos" },
	{ key = "vaultsConquered", label = "Cofres conquistados" },
	{ key = "baraoEscapes", label = "Fugas do Barão" },
	{ key = "secretsFound", label = "Passagens descobertas" },
	{ key = "comebacks", label = "Voltas por Cima" },
}

local ProfileCardView = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

-- `onRanking`: abre o painel RANKING (botão 🏆 ao lado do cartão).
-- `onPuffdex`: abre o PUFFDEX (botão ✨). `onMachine`: abre a PUFF MACHINE (🎰).
function ProfileCardView.new(playerGui: PlayerGui, onRanking: () -> (), onPuffdex: () -> (), onMachine: () -> ()): ProfileCardViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 12)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Position = UDim2.fromOffset(18, 16)
	root.Size = UDim2.fromOffset(CARD_SIZE.X + (SIDE_BUTTON_WIDTH + SIDE_BUTTON_GAP) * 3, CARD_SIZE.Y + STATS_SIZE.Y + 8)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = screenGui
	ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.72, 1.05)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	card.Parent = root
	UiTheme.stylePanel(card, { radius = 14 })
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local badge = Instance.new("Frame")
	badge.Name = "LevelBadge"
	badge.Position = UDim2.fromOffset(10, 9)
	badge.Size = UDim2.fromOffset(48, 48)
	badge.BackgroundColor3 = UiTheme.Colors.White
	badge.ZIndex = 2
	badge.Parent = card
	UiTheme.addCorner(badge, 999)
	UiTheme.addGradient(badge, UiTheme.Colors.Gold, UiTheme.Colors.GoldDeep)
	UiTheme.addStroke(badge, UiTheme.Colors.Outline, 2.5)

	local levelLabel = UiTheme.createLabel(badge, "Level", "1", UiTheme.Fonts.Display, 24, UiTheme.Colors.White)
	levelLabel.Size = UDim2.fromScale(1, 1)
	levelLabel.ZIndex = 3
	UiTheme.addTextOutline(levelLabel, 2)

	local title = UiTheme.createLabel(card, "Title", "NÍVEL 1", UiTheme.Fonts.Display, 18, UiTheme.Colors.Ink)
	title.Position = UDim2.fromOffset(68, 8)
	title.Size = UDim2.new(1, -150, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 2
	UiTheme.addTextOutline(title, 1.5)

	local track = Instance.new("Frame")
	track.Name = "XpTrack"
	track.Position = UDim2.fromOffset(68, 34)
	track.Size = UDim2.new(1, -80, 0, 10)
	track.BackgroundColor3 = UiTheme.Colors.Track
	track.ZIndex = 2
	track.Parent = card
	UiTheme.addCorner(track, 999)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UiTheme.Colors.White
	fill.ZIndex = 3
	fill.Parent = track
	UiTheme.addCorner(fill, 999)
	UiTheme.addGradient(fill, UiTheme.Colors.Gold, UiTheme.Colors.Brand, 0)

	local xpLabel = UiTheme.createLabel(card, "Xp", "0 / 100 XP", UiTheme.Fonts.BodyBold, 11, UiTheme.Colors.InkSoft)
	xpLabel.Position = UDim2.fromOffset(68, 46)
	xpLabel.Size = UDim2.new(1, -80, 0, 14)
	xpLabel.TextXAlignment = Enum.TextXAlignment.Left
	xpLabel.ZIndex = 2

	local statsButton = UiKit.createButton(card, {
		name = "StatsButton",
		text = "PERFIL",
		variant = "Neutral",
		size = UDim2.fromOffset(70, 24),
		position = UDim2.new(1, -10, 0, 8),
		anchorPoint = Vector2.new(1, 0),
		textSize = 12,
		zIndex = 4,
	})

	local rankingButton = UiKit.createButton(root, {
		name = "RankingButton",
		text = "🏆",
		variant = "Gold",
		size = UDim2.fromOffset(SIDE_BUTTON_WIDTH, CARD_SIZE.Y),
		position = UDim2.fromOffset(CARD_SIZE.X + SIDE_BUTTON_GAP, 0),
		textSize = 24,
		zIndex = 4,
	})
	rankingButton.button.Activated:Connect(function()
		UiKit.playClick()
		onRanking()
	end)

	local puffdexButton = UiKit.createButton(root, {
		name = "PuffdexButton",
		text = "✨",
		variant = "Primary",
		size = UDim2.fromOffset(SIDE_BUTTON_WIDTH, CARD_SIZE.Y),
		position = UDim2.fromOffset(CARD_SIZE.X + SIDE_BUTTON_GAP * 2 + SIDE_BUTTON_WIDTH, 0),
		textSize = 24,
		zIndex = 4,
	})
	puffdexButton.button.Activated:Connect(function()
		UiKit.playClick()
		onPuffdex()
	end)

	local machineButton = UiKit.createButton(root, {
		name = "MachineButton",
		text = "🎰",
		variant = "Gold",
		size = UDim2.fromOffset(SIDE_BUTTON_WIDTH, CARD_SIZE.Y),
		position = UDim2.fromOffset(CARD_SIZE.X + SIDE_BUTTON_GAP * 3 + SIDE_BUTTON_WIDTH * 2, 0),
		textSize = 24,
		zIndex = 4,
	})
	machineButton.button.Activated:Connect(function()
		UiKit.playClick()
		onMachine()
	end)
	-- Saldo de tickets num selo embaixo do botão.
	local ticketBadge = UiTheme.createLabel(machineButton.root, "Tickets", "🎟 0", UiTheme.Fonts.Display, 11, UiTheme.Colors.White)
	ticketBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	ticketBadge.Position = UDim2.new(0.5, 0, 1, -2)
	ticketBadge.Size = UDim2.fromOffset(SIDE_BUTTON_WIDTH + 6, 18)
	ticketBadge.BackgroundTransparency = 0
	ticketBadge.BackgroundColor3 = UiTheme.Colors.Outline
	ticketBadge.TextScaled = true
	ticketBadge.ZIndex = 8
	UiTheme.addTextConstraint(ticketBadge, 8, 11)
	UiTheme.addCorner(ticketBadge, 999)

	-- Painel das estatísticas (abre abaixo do cartão).
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Position = UDim2.fromOffset(0, CARD_SIZE.Y + 8)
	stats.Size = UDim2.fromOffset(STATS_SIZE.X, STATS_SIZE.Y)
	stats.Visible = false
	stats.Parent = root
	UiTheme.stylePanel(stats, { radius = 14 })

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 10)
	list.Size = UDim2.new(1, -24, 1, -20)
	list.BackgroundTransparency = 1
	list.ZIndex = 2
	list.Parent = stats
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	local valueLabels: { [string]: TextLabel } = {}
	for index, row in ipairs(STAT_ROWS) do
		local line = Instance.new("Frame")
		line.Name = row.key
		line.LayoutOrder = index
		line.Size = UDim2.new(1, 0, 0, 20)
		line.BackgroundTransparency = 1
		line.ZIndex = 2
		line.Parent = list
		local name = UiTheme.createLabel(line, "Name", row.label, UiTheme.Fonts.Body, 13, UiTheme.Colors.InkSoft)
		name.Size = UDim2.new(0.7, 0, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 3
		local value = UiTheme.createLabel(line, "Value", "0", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.Ink)
		value.Position = UDim2.fromScale(0.7, 0)
		value.Size = UDim2.new(0.3, 0, 1, 0)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.ZIndex = 3
		valueLabels[row.key] = value
	end
	local notice = UiTheme.createLabel(list, "Notice", "", UiTheme.Fonts.BodyBold, 11, UiTheme.Colors.Orange)
	notice.LayoutOrder = #STAT_ROWS + 1
	notice.Size = UDim2.new(1, 0, 0, 28)
	notice.TextXAlignment = Enum.TextXAlignment.Left
	notice.ZIndex = 3
	notice.Visible = false

	statsButton.button.Activated:Connect(function()
		stats.Visible = not stats.Visible
		statsButton.setText(if stats.Visible then "FECHAR" else "PERFIL")
	end)

	local handle = {} :: ProfileCardViewHandle

	handle.setProfile = function(snapshot: ProfileSnapshot)
		local progress = LevelCurve.progress(snapshot.xp)
		levelLabel.Text = tostring(progress.level)
		local prestigeText = if snapshot.prestige > 0 then string.format("  ★%d", snapshot.prestige) else ""
		title.Text = string.format("NÍVEL %d%s", progress.level, prestigeText)
		local ratio = if progress.isMax then 1 else math.clamp(progress.current / math.max(1, progress.needed), 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
		xpLabel.Text = if progress.isMax
			then "NÍVEL MÁXIMO"
			else string.format("%s / %s XP", formatNumber(progress.current), formatNumber(progress.needed))
		local statsTable = snapshot.stats :: any
		for key, value in pairs(valueLabels) do
			value.Text = formatNumber(statsTable[key] or 0)
		end
		ticketBadge.Text = string.format("🎟 %s", formatNumber(snapshot.tickets))
		notice.Visible = not snapshot.saved
		notice.Text = "Progresso desta sessão não está sendo salvo"
	end

	handle.setVisible = function(visible: boolean)
		root.Visible = visible
		if not visible then
			stats.Visible = false
			statsButton.setText("PERFIL")
		end
	end

	handle.celebrateLevel = function()
		cardScale.Scale = 1.15
		TweenService:Create(cardScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(ProfileCardView)
