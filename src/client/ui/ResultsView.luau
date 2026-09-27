--!strict

-- Painel de pós-partida: título (vitória, fim ou empate), sua posição, seus
-- blocos e derrubadas, destaques da rodada, as primeiras posições e um
-- rodapé com o tempo até a próxima rodada. Só visual.

local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResultTypes = require(ReplicatedStorage.Shared.types.ResultTypes)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type RoundResult = ResultTypes.RoundResult
type ResultEntry = ResultTypes.ResultEntry

export type ResultsViewHandle = {
	show: (result: RoundResult, localUserId: number) -> (),
	setFooter: (text: string) -> (),
	hide: () -> (),
	isVisible: () -> boolean,
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffResults"
local PANEL_SIZE = Vector2.new(440, 430)
local MAX_ROWS = 5
local ROW_HEIGHT = 26

local ResultsView = {}

local function label(parent: Instance, name: string, text: string, font: Enum.Font, size: number, color: Color3, position: UDim2, frameSize: UDim2): TextLabel
	local created = UiTheme.createLabel(parent, name, text, font, size, color)
	created.Position = position
	created.Size = frameSize
	created.ZIndex = 3
	return created
end

local function findEntry(result: RoundResult, userId: number): ResultEntry?
	for _, entry in ipairs(result.entries) do
		if entry.userId == userId then
			return entry
		end
	end
	return nil
end

local function plural(count: number, singular: string, pluralForm: string): string
	return string.format("%d %s", count, if count == 1 then singular else pluralForm)
end

local function describe(result: RoundResult, mine: ResultEntry?, localUserId: number): (string, string, Color3)
	if result.winnerUserId ~= 0 and result.winnerUserId == localUserId then
		return "VITÓRIA!", "Você foi o último na arena", UiTheme.Colors.Gold
	elseif result.draw then
		local survivors = 0
		for _, entry in ipairs(result.entries) do
			if entry.survived then
				survivors += 1
			end
		end
		return "EMPATE!", string.format("%d jogadores resistiram até o fim", survivors), UiTheme.Colors.Brand
	elseif result.winnerUserId ~= 0 then
		return "FIM DA RODADA", string.format("%s venceu a rodada", result.winnerName), UiTheme.Colors.Brand
	end
	return "FIM DA RODADA", if mine ~= nil then "Ninguém sobrou na arena" else "Rodada encerrada", UiTheme.Colors.Brand
end

function ResultsView.new(playerGui: PlayerGui, onClose: () -> ()): ResultsViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 28)
	screenGui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.52)
	root.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	local responsive = ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.6, 1.05)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = root

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 20)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 2
	card.Parent = root
	local stroke = UiTheme.stylePanel(card, { accent = UiTheme.Colors.Gold, radius = 20 })

	local title = label(card, "Title", "", UiTheme.Fonts.Display, 36, UiTheme.Colors.Gold, UDim2.fromOffset(20, 14), UDim2.new(1, -40, 0, 42))
	UiTheme.addTextOutline(title, 3)
	local subtitle = label(card, "Subtitle", "", UiTheme.Fonts.BodyBold, 15, UiTheme.Colors.White, UDim2.fromOffset(20, 58), UDim2.new(1, -40, 0, 20))

	-- Cartão pessoal: posição grande e números da rodada.
	local personal = Instance.new("Frame")
	personal.Name = "Personal"
	personal.Position = UDim2.fromOffset(20, 88)
	personal.Size = UDim2.new(1, -40, 0, 66)
	personal.BackgroundColor3 = UiTheme.Colors.Outline
	personal.BackgroundTransparency = 0.35
	personal.ZIndex = 3
	personal.Parent = card
	UiTheme.addCorner(personal, 14)
	local positionLabel = label(personal, "Position", "", UiTheme.Fonts.Display, 34, UiTheme.Colors.Gold, UDim2.fromOffset(12, 6), UDim2.fromOffset(90, 40))
	UiTheme.addTextOutline(positionLabel, 2.5)
	local ofLabel = label(personal, "Of", "", UiTheme.Fonts.BodyBold, 12, UiTheme.Colors.InkSoft, UDim2.fromOffset(12, 44), UDim2.fromOffset(90, 16))
	local statsLabel = label(personal, "Stats", "", UiTheme.Fonts.BodyBold, 15, UiTheme.Colors.White, UDim2.fromOffset(110, 8), UDim2.new(1, -122, 1, -16))
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left

	local highlightsLabel = label(card, "Highlights", "", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.Gold, UDim2.fromOffset(20, 162), UDim2.new(1, -40, 0, 36))
	highlightsLabel.TextXAlignment = Enum.TextXAlignment.Left
	highlightsLabel.TextYAlignment = Enum.TextYAlignment.Top

	local list = Instance.new("Frame")
	list.Name = "Ranking"
	list.Position = UDim2.fromOffset(20, 204)
	list.Size = UDim2.new(1, -40, 0, MAX_ROWS * ROW_HEIGHT)
	list.BackgroundTransparency = 1
	list.ZIndex = 3
	list.Parent = card
	local rows: { { frame: Frame, rank: TextLabel, name: TextLabel, numbers: TextLabel } } = {}
	for index = 1, MAX_ROWS do
		local row = Instance.new("Frame")
		row.Name = string.format("Row%d", index)
		row.Position = UDim2.fromOffset(0, (index - 1) * ROW_HEIGHT)
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 3)
		row.BackgroundColor3 = UiTheme.Colors.Gold
		row.BackgroundTransparency = 1
		row.ZIndex = 3
		row.Parent = list
		UiTheme.addCorner(row, 8)
		local rank = label(row, "Rank", "", UiTheme.Fonts.Display, 15, UiTheme.Colors.Gold, UDim2.fromOffset(8, 0), UDim2.new(0, 34, 1, 0))
		local name = label(row, "Name", "", UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.White, UDim2.fromOffset(44, 0), UDim2.new(0.55, -44, 1, 0))
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local numbers = label(row, "Numbers", "", UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft, UDim2.new(0.55, 0, 0, 0), UDim2.new(0.45, -8, 1, 0))
		numbers.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, { frame = row, rank = rank, name = name, numbers = numbers })
	end

	local footer = label(card, "Footer", "", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.InkSoft, UDim2.new(0, 20, 1, -52), UDim2.new(1, -150, 0, 36))
	footer.TextXAlignment = Enum.TextXAlignment.Left
	local okButton = UiKit.createButton(card, {
		name = "OkButton",
		text = "OK",
		variant = "Gold",
		size = UDim2.fromOffset(110, 40),
		position = UDim2.new(1, -20, 1, -16),
		anchorPoint = Vector2.new(1, 1),
		textSize = 18,
		zIndex = 4,
	})
	okButton.button.Activated:Connect(function()
		UiKit.playClick()
		onClose()
	end)

	local handle = {} :: ResultsViewHandle

	handle.show = function(result: RoundResult, localUserId: number)
		local mine = findEntry(result, localUserId)
		local titleText, subtitleText, accent = describe(result, mine, localUserId)
		title.Text = titleText
		title.TextColor3 = accent
		subtitle.Text = subtitleText
		local strokeGradient = stroke:FindFirstChildOfClass("UIGradient") :: UIGradient?
		if strokeGradient ~= nil then
			strokeGradient.Color = ColorSequence.new(accent, accent:Lerp(UiTheme.Colors.White, 0.3))
		end

		personal.Visible = mine ~= nil
		if mine ~= nil then
			positionLabel.Text = string.format("#%d", mine.position)
			ofLabel.Text = string.format("de %d", result.participantCount)
			statsLabel.Text = string.format(
				"%s\n%s",
				plural(mine.blocks, "bloco destruído", "blocos destruídos"),
				plural(mine.knockouts, "derrubada", "derrubadas")
			)
		end

		local highlightLines: { string } = {}
		for _, highlight in ipairs(result.highlights) do
			table.insert(highlightLines, string.format("★ %s: %s (%d)", highlight.title, highlight.name, highlight.value))
		end
		highlightsLabel.Text = table.concat(highlightLines, "\n")

		for index, row in ipairs(rows) do
			local entry = result.entries[index]
			row.frame.Visible = entry ~= nil
			if entry ~= nil then
				row.rank.Text = string.format("#%d", entry.position)
				row.name.Text = entry.name
				row.numbers.Text = string.format("%d blocos • %d derr.", entry.blocks, entry.knockouts)
				row.frame.BackgroundTransparency = if entry.userId == localUserId then 0.75 else 1
			end
		end

		screenGui.Enabled = true
		pop.Scale = 0.85
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	handle.setFooter = function(text: string)
		footer.Text = text
	end

	handle.hide = function()
		screenGui.Enabled = false
	end

	handle.isVisible = function(): boolean
		return screenGui.Enabled
	end

	handle.destroy = function()
		responsive.destroy()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(ResultsView)
