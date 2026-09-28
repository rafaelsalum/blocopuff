--!strict

-- Painel RANKING: top 10 global por categoria (abas), com foto, posição,
-- nome e valor. A linha do próprio jogador fica em dourado. Aba de
-- temporada reservada (desativada). Só visual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LeaderboardTypes = require(ReplicatedStorage.Shared.types.LeaderboardTypes)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type LeaderboardData = LeaderboardTypes.LeaderboardData
type Leaderboard = LeaderboardTypes.Leaderboard

export type LeaderboardViewHandle = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setData: (data: LeaderboardData) -> (),
	destroy: () -> (),
}

type Row = {
	frame: Frame,
	avatar: ImageLabel,
	rank: TextLabel,
	name: TextLabel,
	value: TextLabel,
}

local GUI_NAME = "BlocoPuffLeaderboard"
local PANEL_SIZE = Vector2.new(440, 470)
local ROW_HEIGHT = 30
local MEDALS = { "🥇", "🥈", "🥉" }

local LeaderboardView = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

local function describeAge(updatedAt: number): string
	if updatedAt <= 0 then
		return "Carregando ranking…"
	end
	local minutes = math.floor(math.max(0, os.time() - updatedAt) / 60)
	return if minutes < 1 then "Atualizado agora" else string.format("Atualizado há %d min", minutes)
end

function LeaderboardView.new(playerGui: PlayerGui, onTab: (categoryId: string) -> ()): LeaderboardViewHandle
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
	UiTheme.stylePanel(card, { accent = UiTheme.Colors.Gold, radius = 20 })

	local title = UiTheme.createLabel(card, "Title", "🏆 RANKING GLOBAL", UiTheme.Fonts.Display, 28, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -90, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	UiTheme.addTextOutline(title, 2.5)

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

	-- Abas: as categorias e a temporada (reservada).
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.fromOffset(16, 56)
	tabs.Size = UDim2.new(1, -32, 0, 34)
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = 3
	tabs.Parent = card
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	local categories = LeaderboardTypes.Categories
	local tabCount = #categories + 1
	local tabWidth = UDim2.new(1 / tabCount, -4, 1, 0)
	local selectedId = categories[1].id
	local tabButtons: { [string]: UiKit.ButtonHandle } = {}
	local render: () -> () = function() end
	for index, category in ipairs(categories) do
		local button = UiKit.createButton(tabs, {
			name = `Tab_{category.id}`,
			text = category.icon,
			variant = "Neutral",
			size = tabWidth,
			textSize = 18,
			layoutOrder = index,
			zIndex = 4,
		})
		button.button.Activated:Connect(function()
			UiKit.playClick()
			selectedId = category.id
			onTab(category.id)
			render()
		end)
		tabButtons[category.id] = button
	end
	local seasonTab = UiKit.createButton(tabs, {
		name = "Tab_season",
		text = "📅",
		variant = "Neutral",
		size = tabWidth,
		textSize = 18,
		layoutOrder = tabCount,
		zIndex = 4,
	})
	seasonTab.setEnabled(false)

	local categoryLabel = UiTheme.createLabel(card, "Category", "", UiTheme.Fonts.Display, 16, UiTheme.Colors.White)
	categoryLabel.Position = UDim2.fromOffset(20, 96)
	categoryLabel.Size = UDim2.new(1, -40, 0, 22)
	categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
	categoryLabel.ZIndex = 3
	UiTheme.addTextOutline(categoryLabel, 1.5)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(16, 122)
	list.Size = UDim2.new(1, -32, 0, ROW_HEIGHT * LeaderboardTypes.TopCount)
	list.BackgroundTransparency = 1
	list.ZIndex = 3
	list.Parent = card
	local rows: { Row } = {}
	for index = 1, LeaderboardTypes.TopCount do
		local frame = Instance.new("Frame")
		frame.Name = string.format("Row%02d", index)
		frame.Position = UDim2.fromOffset(0, (index - 1) * ROW_HEIGHT)
		frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 3)
		frame.BackgroundColor3 = UiTheme.Colors.Outline
		frame.BackgroundTransparency = 0.5
		frame.ZIndex = 3
		frame.Parent = list
		UiTheme.addCorner(frame, 8)
		local rank = UiTheme.createLabel(frame, "Rank", "", UiTheme.Fonts.Display, 15, UiTheme.Colors.Gold)
		rank.Position = UDim2.fromOffset(6, 0)
		rank.Size = UDim2.new(0, 34, 1, 0)
		rank.ZIndex = 4
		local avatar = Instance.new("ImageLabel")
		avatar.Position = UDim2.fromOffset(42, 2)
		avatar.Size = UDim2.fromOffset(ROW_HEIGHT - 7, ROW_HEIGHT - 7)
		avatar.BackgroundColor3 = UiTheme.Colors.SurfaceSoft
		avatar.ZIndex = 4
		avatar.Parent = frame
		UiTheme.addCorner(avatar, 999)
		local name = UiTheme.createLabel(frame, "Name", "", UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.White)
		name.Position = UDim2.fromOffset(74, 0)
		name.Size = UDim2.new(0.62, -74, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextWrapped = false
		name.ZIndex = 4
		local value = UiTheme.createLabel(frame, "Value", "", UiTheme.Fonts.Display, 15, UiTheme.Colors.Ink)
		value.Position = UDim2.fromScale(0.62, 0)
		value.Size = UDim2.new(0.38, -10, 1, 0)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.ZIndex = 4
		table.insert(rows, { frame = frame, avatar = avatar, rank = rank, name = name, value = value })
	end
	local empty = UiTheme.createLabel(list, "Empty", "", UiTheme.Fonts.BodyBold, 15, UiTheme.Colors.InkSoft)
	empty.Position = UDim2.fromScale(0, 0.3)
	empty.Size = UDim2.new(1, 0, 0, 40)
	empty.ZIndex = 4

	local footer = UiTheme.createLabel(card, "Footer", "", UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft)
	footer.Position = UDim2.new(0, 20, 1, -34)
	footer.Size = UDim2.new(1, -40, 0, 20)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.ZIndex = 3

	local data: LeaderboardData = { boards = {}, updatedAt = 0, available = true }

	render = function()
		local board: Leaderboard? = nil
		for _, candidate in ipairs(data.boards) do
			if candidate.id == selectedId then
				board = candidate
			end
		end
		for id, button in pairs(tabButtons) do
			button.setSelected(id == selectedId)
		end
		for _, category in ipairs(categories) do
			if category.id == selectedId then
				categoryLabel.Text = `{category.icon} {category.title}`
			end
		end
		local localPlayer = Players.LocalPlayer
		local localUserId = if localPlayer ~= nil then localPlayer.UserId else 0
		local entries = if board ~= nil then board.entries else {}
		for index, row in ipairs(rows) do
			local entry = entries[index]
			row.frame.Visible = entry ~= nil
			if entry ~= nil then
				row.rank.Text = MEDALS[entry.rank] or `{entry.rank}º`
				row.name.Text = entry.name
				row.value.Text = formatNumber(entry.value)
				row.avatar.Image = `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=48&h=48`
				row.frame.BackgroundColor3 = if entry.userId == localUserId then UiTheme.Colors.GoldDeep else UiTheme.Colors.Outline
			end
		end
		empty.Visible = #entries == 0
		empty.Text = if not data.available
			then "Ranking indisponível no momento"
			elseif data.updatedAt <= 0 then "Carregando…"
			else "Ninguém aqui ainda. Seja o primeiro!"
		footer.Text = describeAge(data.updatedAt) .. "  ·  Temporadas: em breve"
	end

	local handle = {} :: LeaderboardViewHandle

	handle.open = function()
		render()
		screenGui.Enabled = true
		pop.Scale = 0.9
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onTab(selectedId)
	end

	handle.close = function()
		screenGui.Enabled = false
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.setData = function(newData: LeaderboardData)
		data = newData
		if screenGui.Enabled then
			render()
		end
	end

	handle.destroy = function()
		responsive.destroy()
		screenGui:Destroy()
	end

	closeButton.button.Activated:Connect(function()
		UiKit.playClick()
		handle.close()
	end)

	return handle
end

return table.freeze(LeaderboardView)
