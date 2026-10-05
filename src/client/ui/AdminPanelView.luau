--!strict

-- Painel administrativo com a identidade visual do BlocoPuff: cabeçalho com
-- logotipo, seções em cartões, lista de jogadores selecionável, botões 3D e
-- uma pílula de status para o retorno do servidor. Toda ação continua sendo
-- validada no servidor (AdminService); esta tela só coleta a intenção.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ButtonHandle = UiKit.ButtonHandle

export type PlayerEntry = {
	userId: number,
	displayName: string,
	username: string,
}

export type AdminPanelCallbacks = {
	onAnnounce: (message: string) -> (),
	onModerate: (action: string, targetUserIdText: string, reason: string) -> (),
	-- Comandos de teste da partida (MatchTestControls no servidor).
	onTest: (action: string, option: string?) -> (),
}

-- Botões da seção de testes, em fileiras.
type TestButton = { name: string, text: string, variant: UiKit.ButtonVariant, action: string, option: string? }
local TEST_ROWS: { { TestButton } } = {
	{
		{ name = "ForceStartButton", text = "▶ COMEÇAR JÁ", variant = "Success", action = "ForceStart" },
		{ name = "ChaosButton", text = "🌪 CAOS FINAL", variant = "Warning", action = "SkipToChaos" },
		{ name = "EndRoundButton", text = "⏹ ENCERRAR", variant = "Danger", action = "EndRound" },
	},
	{
		{ name = "BotsOnButton", text = "🤖 BOTS LIGADOS", variant = "Primary", action = "BotsOn" },
		{ name = "BotsOffButton", text = "🚫 BOTS DESLIGADOS", variant = "Warning", action = "BotsOff" },
	},
	{
		{ name = "LevelAutoButton", text = "AUTO", variant = "Gold", action = "BotLevel", option = "Auto" },
		{ name = "LevelEasyButton", text = "FÁCIL", variant = "Success", action = "BotLevel", option = "Easy" },
		{ name = "LevelNormalButton", text = "NORMAL", variant = "Primary", action = "BotLevel", option = "Normal" },
		{ name = "LevelHardButton", text = "ESPERTO", variant = "Danger", action = "BotLevel", option = "Hard" },
	},
}
local TEST_ROW_HEIGHT = 48
local TEST_ROW_GAP = 8

export type AdminPanelViewHandle = {
	setPlayers: (players: { PlayerEntry }) -> (),
	setBusy: (busy: boolean) -> (),
	setFeedback: (message: string, ok: boolean) -> (),
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffAdminPanel"
local TOPBAR_GUI_NAME = "BlocoPuffAdminTopbar"
-- Tamanho de desenho do painel. Em telas maiores ele cresce inteiro
-- (texto e botões juntos) até MAX_FIT_SCALE; em telas menores encolhe a
-- área e o conteúdo rola.
local PANEL_WIDTH = 720
local PANEL_HEIGHT = 620
local PANEL_MIN_SIZE = 300
local MAX_FIT_SCALE = 1.6
local SCREEN_MARGIN = Vector2.new(16, 20)
local HEADER_HEIGHT = 76
local ANNOUNCEMENT_LIMIT = 180
local REASON_LIMIT = 120
local TARGET_LIMIT = 20
local ENTRY_HEIGHT = 44

local AdminPanelView = {}

local function createTextBox(parent: Instance, name: string, placeholder: string, multiline: boolean): TextBox
	local textBox = Instance.new("TextBox")
	textBox.Name = name
	textBox.BackgroundColor3 = UiTheme.Colors.Track
	textBox.BackgroundTransparency = 0.15
	textBox.BorderSizePixel = 0
	textBox.ClearTextOnFocus = false
	textBox.Font = UiTheme.Fonts.Body
	textBox.MultiLine = multiline
	textBox.PlaceholderColor3 = UiTheme.Colors.InkSoft
	textBox.PlaceholderText = placeholder
	textBox.Text = ""
	textBox.TextColor3 = UiTheme.Colors.Ink
	textBox.TextSize = 15
	textBox.TextWrapped = multiline
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = if multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center
	textBox.Parent = parent
	UiTheme.addCorner(textBox, 12)
	UiTheme.addPadding(textBox, 13, if multiline then 10 else 4)

	-- A borda acende em dourado enquanto o campo está em foco.
	local stroke = UiTheme.addStroke(textBox, UiTheme.Colors.Border, 1.5)
	textBox.Focused:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.12), { Color = UiTheme.Colors.Gold, Transparency = 0 }):Play()
	end)
	textBox.FocusLost:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.12), { Color = UiTheme.Colors.Border, Transparency = 0.2 }):Play()
	end)
	return textBox
end

local function constrainText(textBox: TextBox, maximumLength: number, counter: TextLabel?): RBXScriptConnection
	local function update()
		if #textBox.Text > maximumLength then
			textBox.Text = string.sub(textBox.Text, 1, maximumLength)
			textBox.CursorPosition = #textBox.Text + 1
		end
		if counter ~= nil then
			counter.Text = string.format("%d/%d", #textBox.Text, maximumLength)
			counter.TextColor3 = if #textBox.Text >= maximumLength then UiTheme.Colors.Orange else UiTheme.Colors.InkSoft
		end
	end
	update()
	return textBox:GetPropertyChangedSignal("Text"):Connect(update)
end

local function createSection(parent: Instance, name: string, title: string, icon: string, accent: Color3, height: number, order: number): Frame
	local section = Instance.new("Frame")
	section.Name = name
	section.Size = UDim2.new(1, -8, 0, height)
	section.LayoutOrder = order
	section.ZIndex = 12
	section.Parent = parent
	UiTheme.stylePanel(section, { accent = accent, radius = 16, transparency = 0.04 })

	local iconBadge = UiTheme.createLabel(section, "Icon", icon, UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.Outline)
	iconBadge.Position = UDim2.fromOffset(14, 12)
	iconBadge.Size = UDim2.fromOffset(30, 30)
	iconBadge.BackgroundColor3 = accent
	iconBadge.BackgroundTransparency = 0
	iconBadge.ZIndex = 13
	UiTheme.addCorner(iconBadge, 9)

	local titleLabel = UiTheme.createLabel(section, "Title", title, UiTheme.Fonts.Display, 19, UiTheme.Colors.Ink)
	titleLabel.Position = UDim2.fromOffset(52, 12)
	titleLabel.Size = UDim2.new(1, -66, 0, 30)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 13
	UiTheme.addTextOutline(titleLabel, 2)
	return section
end

function AdminPanelView.new(playerGui: PlayerGui, callbacks: AdminPanelCallbacks): AdminPanelViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 60)

	-- Botão de abrir na barra do topo, logo depois dos botões do Roblox
	-- (área TopbarSafeInsets): fora do controle de movimento do celular e
	-- dos botões de tiro e pulo.
	local topbarGui = UiTheme.createScreenGui(TOPBAR_GUI_NAME, playerGui, 60)
	topbarGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	local openButton = UiKit.createButton(topbarGui, {
		name = "OpenButton",
		text = "🛡️",
		-- Discreto: neutro e menor que os botões do Roblox ao lado.
		variant = "Neutral",
		size = UDim2.fromScale(0.6, 0.6),
		position = UDim2.new(0, 6, 0.5, 0),
		anchorPoint = Vector2.new(0, 0.5),
		textSize = 13,
		round = true,
		selectionOrder = 100,
	})
	-- Quadrado do tamanho da barra (a altura muda entre aparelhos).
	openButton.root.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shadow
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Active = true
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	panel.ZIndex = 11
	panel.Parent = overlay
	UiTheme.stylePanel(panel, { accent = UiTheme.Colors.Brand, radius = 22, transparency = 0 })
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	-- Ocupa a tela quase toda: escala para cima em telas grandes, área
	-- menor (com rolagem) em telas pequenas.
	local fitScale = 1
	local function fitToScreen()
		local area = screenGui.AbsoluteSize
		if area.X <= 0 or area.Y <= 0 then
			return
		end
		local room = area - (SCREEN_MARGIN * 2)
		fitScale = math.clamp(math.min(room.X / PANEL_WIDTH, room.Y / PANEL_HEIGHT), 1, MAX_FIT_SCALE)
		local width = math.clamp(room.X / fitScale, PANEL_MIN_SIZE, PANEL_WIDTH)
		local height = math.clamp(room.Y / fitScale, PANEL_MIN_SIZE, PANEL_HEIGHT)
		panel.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
		panelScale.Scale = fitScale
	end
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	fitToScreen()

	-- Cabeçalho com faixa em gradiente da marca e logotipo.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.BackgroundColor3 = UiTheme.Colors.White
	header.BorderSizePixel = 0
	header.ZIndex = 12
	header.Parent = panel
	UiTheme.addCorner(header, 22)
	UiTheme.addGradient(header, UiTheme.Colors.Brand, UiTheme.Colors.BrandDeep, 0)

	local headerCover = Instance.new("Frame")
	headerCover.Name = "SquareBottom"
	headerCover.Position = UDim2.new(0, 0, 1, -22)
	headerCover.Size = UDim2.new(1, 0, 0, 22)
	headerCover.BackgroundColor3 = UiTheme.Colors.White
	headerCover.BorderSizePixel = 0
	headerCover.ZIndex = 12
	headerCover.Parent = header
	UiTheme.addGradient(headerCover, UiTheme.Colors.Brand, UiTheme.Colors.BrandDeep, 0)

	local wordmark = UiKit.createWordmark(header, 50, 13)
	wordmark.AnchorPoint = Vector2.new(0, 0.5)
	wordmark.Position = UDim2.new(0, 16, 0.5, 0)

	local title = UiTheme.createLabel(header, "Title", "PAINEL ADMIN", UiTheme.Fonts.Display, 22, UiTheme.Colors.Ink)
	title.Position = UDim2.fromOffset(160, 12)
	title.Size = UDim2.new(1, -240, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 13
	UiTheme.addTextOutline(title, 2.5)

	local subtitle = UiTheme.createLabel(header, "Subtitle", "🔒 Acesso protegido pelo servidor", UiTheme.Fonts.BodyBold, 12, UiTheme.Colors.Ink)
	subtitle.Position = UDim2.fromOffset(161, 42)
	subtitle.Size = UDim2.new(1, -240, 0, 18)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextTransparency = 0.15
	subtitle.ZIndex = 13

	local closeButton = UiKit.createButton(header, {
		name = "CloseButton",
		text = "X",
		variant = "Danger",
		size = UDim2.fromOffset(46, 50),
		position = UDim2.new(1, -14, 0.5, 0),
		anchorPoint = Vector2.new(1, 0.5),
		textSize = 18,
		round = true,
		selectionOrder = 101,
		zIndex = 14,
	})

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Position = UDim2.new(0, 14, 0, HEADER_HEIGHT + 12)
	content.Size = UDim2.new(1, -28, 1, -(HEADER_HEIGHT + 70))
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ScrollBarImageColor3 = UiTheme.Colors.Brand
	content.ScrollBarThickness = 6
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.ZIndex = 12
	content.Parent = panel

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 12)
	contentLayout.Parent = content
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 4)
	contentPadding.PaddingBottom = UDim.new(0, 8)
	contentPadding.PaddingLeft = UDim.new(0, 4)
	contentPadding.Parent = content

	-- Seção: testes da partida (só neste servidor).
	local testHeight = 52 + (#TEST_ROWS * (TEST_ROW_HEIGHT + TEST_ROW_GAP)) + 22
	local testSection = createSection(content, "TestSection", "TESTES DA PARTIDA", "🧪", UiTheme.Colors.Green, testHeight, 0)
	local testCaption = UiTheme.createLabel(testSection, "Caption", "Só neste servidor • nível dos bots vale da próxima partida", UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft)
	testCaption.Position = UDim2.fromOffset(15, testHeight - 26)
	testCaption.Size = UDim2.new(1, -30, 0, 18)
	testCaption.TextXAlignment = Enum.TextXAlignment.Left
	testCaption.ZIndex = 13
	local testButtons: { { button: ButtonHandle, spec: TestButton } } = {}
	for rowIndex, row in ipairs(TEST_ROWS) do
		local rowFrame = Instance.new("Frame")
		rowFrame.Name = `TestRow{rowIndex}`
		rowFrame.Position = UDim2.fromOffset(14, 52 + ((rowIndex - 1) * (TEST_ROW_HEIGHT + TEST_ROW_GAP)))
		rowFrame.Size = UDim2.new(1, -28, 0, TEST_ROW_HEIGHT)
		rowFrame.BackgroundTransparency = 1
		rowFrame.ZIndex = 13
		rowFrame.Parent = testSection
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(0, 8)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = rowFrame
		for index, spec in ipairs(row) do
			local button = UiKit.createButton(rowFrame, {
				name = spec.name,
				text = spec.text,
				variant = spec.variant,
				size = UDim2.new(1 / #row, -(8 * (#row - 1)) / #row, 1, 0),
				textSize = 13,
				layoutOrder = index,
				selectionOrder = 102 + (rowIndex * 4) + index,
				zIndex = 13,
			})
			table.insert(testButtons, { button = button, spec = spec })
		end
	end

	-- Seção: aviso para o jogo.
	local announcementSection = createSection(content, "AnnouncementSection", "AVISO PARA O JOGO", "📣", UiTheme.Colors.Blue, 200, 1)

	local announcementBox = createTextBox(announcementSection, "AnnouncementBox", "Mensagem para todos os jogadores", true)
	announcementBox.Position = UDim2.fromOffset(14, 52)
	announcementBox.Size = UDim2.new(1, -28, 0, 74)
	announcementBox.ZIndex = 13
	announcementBox.SelectionOrder = 110

	local announcementCounter = UiTheme.createLabel(announcementSection, "Counter", "", UiTheme.Fonts.BodyBold, 11, UiTheme.Colors.InkSoft)
	announcementCounter.AnchorPoint = Vector2.new(1, 0)
	announcementCounter.Position = UDim2.new(1, -16, 0, 18)
	announcementCounter.Size = UDim2.fromOffset(80, 16)
	announcementCounter.TextXAlignment = Enum.TextXAlignment.Right
	announcementCounter.ZIndex = 13

	local announceButton = UiKit.createButton(announcementSection, {
		name = "AnnounceButton",
		text = "ENVIAR AVISO",
		variant = "Primary",
		size = UDim2.new(1, -28, 0, 50),
		position = UDim2.fromOffset(14, 136),
		textSize = 17,
		selectionOrder = 111,
		zIndex = 13,
	})

	-- Seção: moderação.
	local moderationSection = createSection(content, "ModerationSection", "MODERAÇÃO", "🛡", UiTheme.Colors.Orange, 382, 2)

	local playersCaption = UiTheme.createLabel(moderationSection, "PlayersCaption", "Jogadores neste servidor — toque para selecionar", UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft)
	playersCaption.Position = UDim2.fromOffset(15, 46)
	playersCaption.Size = UDim2.new(1, -30, 0, 18)
	playersCaption.TextXAlignment = Enum.TextXAlignment.Left
	playersCaption.ZIndex = 13

	local playerList = Instance.new("ScrollingFrame")
	playerList.Name = "PlayerList"
	playerList.Position = UDim2.fromOffset(14, 68)
	playerList.Size = UDim2.new(1, -28, 0, 106)
	playerList.BackgroundColor3 = UiTheme.Colors.Track
	playerList.BackgroundTransparency = 0.2
	playerList.BorderSizePixel = 0
	playerList.CanvasSize = UDim2.new()
	playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	playerList.ScrollBarImageColor3 = UiTheme.Colors.Brand
	playerList.ScrollBarThickness = 5
	playerList.ZIndex = 13
	playerList.Parent = moderationSection
	UiTheme.addCorner(playerList, 12)
	UiTheme.addPadding(playerList, 6, 6)
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = playerList

	local emptyLabel = UiTheme.createLabel(playerList, "Empty", "Nenhum outro jogador no servidor.", UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft)
	emptyLabel.Size = UDim2.new(1, -12, 0, 90)
	emptyLabel.ZIndex = 14

	local targetBox = createTextBox(moderationSection, "TargetUserId", "User ID do jogador", false)
	targetBox.Position = UDim2.fromOffset(14, 186)
	targetBox.Size = UDim2.new(1, -28, 0, 44)
	targetBox.ZIndex = 13
	targetBox.SelectionOrder = 120

	local reasonBox = createTextBox(moderationSection, "Reason", "Motivo (opcional)", false)
	reasonBox.Position = UDim2.fromOffset(14, 240)
	reasonBox.Size = UDim2.new(1, -28, 0, 44)
	reasonBox.ZIndex = 13
	reasonBox.SelectionOrder = 121

	local reasonCounter = UiTheme.createLabel(moderationSection, "ReasonCounter", "", UiTheme.Fonts.BodyBold, 11, UiTheme.Colors.InkSoft)
	reasonCounter.AnchorPoint = Vector2.new(1, 0.5)
	reasonCounter.Position = UDim2.new(1, -26, 0, 262)
	reasonCounter.Size = UDim2.fromOffset(70, 16)
	reasonCounter.TextXAlignment = Enum.TextXAlignment.Right
	reasonCounter.ZIndex = 14

	local actionRow = Instance.new("Frame")
	actionRow.Name = "ActionRow"
	actionRow.Position = UDim2.fromOffset(14, 300)
	actionRow.Size = UDim2.new(1, -28, 0, 56)
	actionRow.BackgroundTransparency = 1
	actionRow.ZIndex = 13
	actionRow.Parent = moderationSection

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	actionLayout.Padding = UDim.new(0, 10)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = actionRow

	local function createAction(name: string, text: string, variant: UiKit.ButtonVariant, order: number): ButtonHandle
		return UiKit.createButton(actionRow, {
			name = name,
			text = text,
			variant = variant,
			size = UDim2.new(1 / 3, -7, 1, 0),
			textSize = 15,
			layoutOrder = order,
			selectionOrder = 121 + order,
			zIndex = 13,
		})
	end
	local kickButton = createAction("KickButton", "EXPULSAR", "Warning", 1)
	local banButton = createAction("BanButton", "BANIR", "Danger", 2)
	local unbanButton = createAction("UnbanButton", "DESBANIR", "Success", 3)

	-- Pílula de status fixa no rodapé do painel.
	local statusPill = Instance.new("Frame")
	statusPill.Name = "StatusPill"
	statusPill.AnchorPoint = Vector2.new(0.5, 1)
	statusPill.Position = UDim2.new(0.5, 0, 1, -12)
	statusPill.Size = UDim2.new(1, -28, 0, 38)
	statusPill.BackgroundColor3 = UiTheme.Colors.Track
	statusPill.BackgroundTransparency = 0.1
	statusPill.BorderSizePixel = 0
	statusPill.ZIndex = 12
	statusPill.Parent = panel
	UiTheme.addCorner(statusPill, 19)
	local statusStroke = UiTheme.addStroke(statusPill, UiTheme.Colors.Border, 1.5)

	local statusLabel = UiTheme.createLabel(statusPill, "Feedback", "⌨  F2 abre ou fecha • ações registradas pelo servidor", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.InkSoft)
	statusLabel.Size = UDim2.new(1, -24, 1, 0)
	statusLabel.Position = UDim2.fromOffset(12, 0)
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.ZIndex = 13

	local connections: { RBXScriptConnection } = {}
	local playerEntryConnections: { RBXScriptConnection } = {}
	table.insert(connections, constrainText(announcementBox, ANNOUNCEMENT_LIMIT, announcementCounter))
	table.insert(connections, constrainText(reasonBox, REASON_LIMIT, reasonCounter))
	table.insert(connections, constrainText(targetBox, TARGET_LIMIT, nil))

	local busy = false
	-- Ação aguardando resposta, para limpar o campo certo quando der certo.
	local pendingAction: string? = nil
	local actionButtons = { announceButton, kickButton, banButton, unbanButton }
	for _, entry in ipairs(testButtons) do
		table.insert(actionButtons, entry.button)
	end
	local entryStrokes: { [number]: UIStroke } = {}

	local function isGamepadInput(inputType: Enum.UserInputType): boolean
		return string.find(inputType.Name, "Gamepad") ~= nil
	end

	local function updateSelection(visible: boolean)
		if isGamepadInput(UserInputService:GetLastInputType()) then
			GuiService.SelectedObject = if visible then closeButton.button else openButton.button
		else
			GuiService.SelectedObject = nil
		end
	end

	local function setStatus(message: string, color: Color3)
		statusLabel.Text = message
		statusLabel.TextColor3 = color
		statusStroke.Color = color
		UiKit.pop(statusPill, 0.05)
	end

	local function highlightTarget()
		local selectedId = tonumber(targetBox.Text)
		for userId, stroke in pairs(entryStrokes) do
			local isSelected = userId == selectedId
			stroke.Color = if isSelected then UiTheme.Colors.Gold else UiTheme.Colors.Border
			stroke.Thickness = if isSelected then 2.5 else 1
			stroke.Transparency = if isSelected then 0 else 0.5
		end
	end
	table.insert(connections, targetBox:GetPropertyChangedSignal("Text"):Connect(highlightTarget))

	local function setVisible(visible: boolean)
		overlay.Visible = visible
		openButton.root.Visible = not visible
		if visible then
			fitToScreen()
			panelScale.Scale = fitScale * 0.88
			TweenService:Create(panelScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fitScale }):Play()
			updateSelection(true)
		else
			announcementBox:ReleaseFocus()
			targetBox:ReleaseFocus()
			reasonBox:ReleaseFocus()
			updateSelection(false)
		end
	end

	table.insert(connections, openButton.button.Activated:Connect(function()
		setVisible(true)
	end))
	table.insert(connections, closeButton.button.Activated:Connect(function()
		setVisible(false)
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F2 then
			setVisible(not overlay.Visible)
		elseif input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
			setVisible(false)
		end
	end))
	table.insert(connections, UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if isGamepadInput(inputType) then
			updateSelection(overlay.Visible)
		elseif GuiService.SelectedObject == openButton.button or GuiService.SelectedObject == closeButton.button then
			GuiService.SelectedObject = nil
		end
	end))

	table.insert(connections, announceButton.button.Activated:Connect(function()
		if not busy then
			pendingAction = "Announce"
			callbacks.onAnnounce(announcementBox.Text)
		end
	end))

	local function moderate(action: string)
		if not busy then
			pendingAction = action
			callbacks.onModerate(action, targetBox.Text, reasonBox.Text)
		end
	end
	for _, entry in ipairs(testButtons) do
		table.insert(connections, entry.button.button.Activated:Connect(function()
			if not busy then
				pendingAction = entry.spec.action
				callbacks.onTest(entry.spec.action, entry.spec.option)
			end
		end))
	end
	table.insert(connections, kickButton.button.Activated:Connect(function()
		moderate("Kick")
	end))
	table.insert(connections, banButton.button.Activated:Connect(function()
		moderate("Ban")
	end))
	table.insert(connections, unbanButton.button.Activated:Connect(function()
		moderate("Unban")
	end))

	local function createPlayerEntry(playerEntry: PlayerEntry, index: number)
		local entry = Instance.new("TextButton")
		entry.Name = `Player_{playerEntry.userId}`
		entry:SetAttribute("AdminPlayerEntry", true)
		entry.Size = UDim2.new(1, -4, 0, ENTRY_HEIGHT)
		entry.LayoutOrder = index
		entry.BackgroundColor3 = UiTheme.Colors.Surface
		entry.BorderSizePixel = 0
		entry.AutoButtonColor = true
		entry.Text = ""
		entry.Selectable = true
		entry.SelectionOrder = 130 + index
		entry.ZIndex = 14
		entry.Parent = playerList
		UiTheme.addCorner(entry, 10)
		local stroke = UiTheme.addStroke(entry, UiTheme.Colors.Border, 1)
		stroke.Transparency = 0.5
		entryStrokes[playerEntry.userId] = stroke

		-- Avatar com a inicial do nome, colorido de forma estável pelo User ID.
		local palette = { UiTheme.Colors.Brand, UiTheme.Colors.Blue, UiTheme.Colors.Green, UiTheme.Colors.Pink, UiTheme.Colors.Orange }
		local avatar = UiTheme.createLabel(entry, "Avatar", string.upper(string.sub(playerEntry.displayName, 1, 1)), UiTheme.Fonts.Display, 16, UiTheme.Colors.Outline)
		avatar.AnchorPoint = Vector2.new(0, 0.5)
		avatar.Position = UDim2.new(0, 7, 0.5, 0)
		avatar.Size = UDim2.fromOffset(30, 30)
		avatar.BackgroundColor3 = palette[(playerEntry.userId % #palette) + 1]
		avatar.BackgroundTransparency = 0
		avatar.ZIndex = 15
		UiTheme.addCorner(avatar, 999)

		local nameLabel = UiTheme.createLabel(entry, "Name", playerEntry.displayName, UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.Ink)
		nameLabel.Position = UDim2.fromOffset(46, 4)
		nameLabel.Size = UDim2.new(1, -56, 0, 20)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.ZIndex = 15

		local detailLabel = UiTheme.createLabel(entry, "Detail", string.format("@%s  •  %d", playerEntry.username, playerEntry.userId), UiTheme.Fonts.Body, 11, UiTheme.Colors.InkSoft)
		detailLabel.Position = UDim2.fromOffset(46, 23)
		detailLabel.Size = UDim2.new(1, -56, 0, 16)
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
		detailLabel.ZIndex = 15

		table.insert(playerEntryConnections, entry.Activated:Connect(function()
			targetBox.Text = tostring(playerEntry.userId)
			UiKit.playClick(1.3)
		end))
	end

	local handle = {} :: AdminPanelViewHandle
	handle.setPlayers = function(players: { PlayerEntry })
		for _, connection in ipairs(playerEntryConnections) do
			connection:Disconnect()
		end
		table.clear(playerEntryConnections)
		table.clear(entryStrokes)

		for _, child in ipairs(playerList:GetChildren()) do
			if child:GetAttribute("AdminPlayerEntry") == true then
				child:Destroy()
			end
		end

		for index, playerEntry in ipairs(players) do
			createPlayerEntry(playerEntry, index)
		end
		emptyLabel.Visible = #players == 0
		highlightTarget()
	end

	handle.setBusy = function(newBusy: boolean)
		busy = newBusy
		for _, button in ipairs(actionButtons) do
			button.setEnabled(not newBusy)
		end
		if newBusy then
			setStatus("⏳  Processando ação no servidor…", UiTheme.Colors.InkSoft)
		end
	end

	handle.setFeedback = function(message: string, ok: boolean)
		if ok then
			if pendingAction == "Announce" then
				announcementBox.Text = ""
			elseif pendingAction == "Kick" or pendingAction == "Ban" or pendingAction == "Unban" then
				reasonBox.Text = ""
			end
		end
		pendingAction = nil
		setStatus(
			string.format("%s  %s", if ok then "✔" else "✖", message),
			if ok then UiTheme.Colors.Green else UiTheme.Colors.Danger
		)
	end

	handle.setVisible = setVisible
	handle.destroy = function()
		for _, connection in ipairs(playerEntryConnections) do
			connection:Disconnect()
		end
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		screenGui:Destroy()
		topbarGui:Destroy()
	end

	return handle
end

return table.freeze(AdminPanelView)
