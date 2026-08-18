--!strict

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local UiTheme = require(script.Parent.UiTheme)

export type PlayerEntry = {
	userId: number,
	displayName: string,
	username: string,
}

export type AdminPanelCallbacks = {
	onAnnounce: (message: string) -> (),
	onModerate: (action: string, targetUserIdText: string, reason: string) -> (),
}

export type AdminPanelViewHandle = {
	setPlayers: (players: { PlayerEntry }) -> (),
	setBusy: (busy: boolean) -> (),
	setFeedback: (message: string, ok: boolean) -> (),
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffAdminPanel"
local PANEL_WIDTH = 640
local PANEL_HEIGHT = 580

local AdminPanelView = {}

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
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createButton(name: string, parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.06
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = UiTheme.Fonts.BodyBold
	button.Text = text
	button.TextColor3 = UiTheme.Colors.Ink
	button.TextSize = 14
	button.TextWrapped = true
	button.Active = true
	button.Selectable = true
	button.Parent = parent
	UiTheme.addCorner(button, 11)
	UiTheme.addStroke(button, UiTheme.Colors.Border, 1.25)
	return button
end

local function createTextBox(
	name: string,
	parent: Instance,
	placeholder: string,
	multiline: boolean
): TextBox
	local textBox = Instance.new("TextBox")
	textBox.Name = name
	textBox.BackgroundColor3 = UiTheme.Colors.SurfaceSoft
	textBox.BackgroundTransparency = 0.08
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
	UiTheme.addStroke(textBox, UiTheme.Colors.Border, 1.25)
	UiTheme.addPadding(textBox, 13, if multiline then 10 else 4)
	return textBox
end

local function constrainText(textBox: TextBox, maximumLength: number): RBXScriptConnection
	return textBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #textBox.Text > maximumLength then
			textBox.Text = string.sub(textBox.Text, 1, maximumLength)
			textBox.CursorPosition = #textBox.Text + 1
		end
	end)
end

function AdminPanelView.new(playerGui: PlayerGui, callbacks: AdminPanelCallbacks): AdminPanelViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 60)

	local openButton = createButton("OpenButton", screenGui, "ADM", UiTheme.Colors.Surface)
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(1, -16, 0, 92)
	openButton.Size = UDim2.fromOffset(48, 40)
	openButton.TextSize = 11
	openButton.SelectionOrder = 100

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shadow
	overlay.BackgroundTransparency = 0.34
	overlay.BorderSizePixel = 0
	overlay.Active = true
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -32, 1, -56)
	panel.BackgroundColor3 = UiTheme.Colors.Panel
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.ZIndex = 11
	panel.Parent = overlay
	UiTheme.addCorner(panel, 18)
	UiTheme.addStroke(panel, UiTheme.Colors.Border, 1.5)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(300, 300)
	sizeConstraint.MaxSize = Vector2.new(PANEL_WIDTH, PANEL_HEIGHT)
	sizeConstraint.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = UiTheme.Colors.Surface
	header.BackgroundTransparency = 0.04
	header.BorderSizePixel = 0
	header.ZIndex = 12
	header.Parent = panel
	UiTheme.addCorner(header, 17)

	local headerCover = Instance.new("Frame")
	headerCover.Name = "SquareBottom"
	headerCover.Position = UDim2.new(0, 0, 1, -20)
	headerCover.Size = UDim2.new(1, 0, 0, 20)
	headerCover.BackgroundColor3 = UiTheme.Colors.Surface
	headerCover.BorderSizePixel = 0
	headerCover.ZIndex = 12
	headerCover.Parent = header

	local title = createLabel("Title", header, "ADMIN • BLOCO PUFF", UiTheme.Fonts.Heading, 19, UiTheme.Colors.Ink)
	title.Position = UDim2.new(0, 18, 0, 7)
	title.Size = UDim2.new(1, -92, 0, 25)
	title.ZIndex = 13

	local subtitle = createLabel(
		"Subtitle",
		header,
		"Acesso protegido pelo servidor",
		UiTheme.Fonts.BodyBold,
		11,
		UiTheme.Colors.InkSoft
	)
	subtitle.Position = UDim2.new(0, 19, 0, 32)
	subtitle.Size = UDim2.new(1, -80, 0, 20)
	subtitle.ZIndex = 13

	local closeButton = createButton("CloseButton", header, "FECHAR", UiTheme.Colors.SurfaceSoft)
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -12, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(64, 36)
	closeButton.TextSize = 11
	closeButton.ZIndex = 14
	closeButton.SelectionOrder = 101

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Position = UDim2.new(0, 12, 0, 70)
	content.Size = UDim2.new(1, -24, 1, -82)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.fromOffset(0, 622)
	content.ScrollBarImageColor3 = UiTheme.Colors.InkSoft
	content.ScrollBarThickness = 6
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.ZIndex = 12
	content.Parent = panel

	local announcementSection = Instance.new("Frame")
	announcementSection.Name = "AnnouncementSection"
	announcementSection.Size = UDim2.new(1, -8, 0, 184)
	announcementSection.BackgroundColor3 = UiTheme.Colors.Surface
	announcementSection.BackgroundTransparency = 0.12
	announcementSection.BorderSizePixel = 0
	announcementSection.ZIndex = 12
	announcementSection.Parent = content
	UiTheme.addCorner(announcementSection, 16)
	UiTheme.addStroke(announcementSection, UiTheme.Colors.Border, 1)

	local announcementTitle = createLabel(
		"Title",
		announcementSection,
		"AVISO PARA O JOGO",
		UiTheme.Fonts.BodyBold,
		15,
		UiTheme.Colors.Ink
	)
	announcementTitle.Position = UDim2.new(0, 15, 0, 12)
	announcementTitle.Size = UDim2.new(1, -30, 0, 22)
	announcementTitle.ZIndex = 13

	local announcementBox = createTextBox(
		"AnnouncementBox",
		announcementSection,
		"Mensagem para todos os jogadores (máx. 180 caracteres)",
		true
	)
	announcementBox.Position = UDim2.new(0, 14, 0, 42)
	announcementBox.Size = UDim2.new(1, -28, 0, 76)
	announcementBox.ZIndex = 13
	announcementBox.SelectionOrder = 110

	local announceButton = createButton("AnnounceButton", announcementSection, "ENVIAR AVISO", UiTheme.Colors.Blue)
	announceButton.Position = UDim2.new(0, 14, 0, 130)
	announceButton.Size = UDim2.new(1, -28, 0, 42)
	announceButton.ZIndex = 13
	announceButton.SelectionOrder = 111

	local moderationSection = Instance.new("Frame")
	moderationSection.Name = "ModerationSection"
	moderationSection.Position = UDim2.fromOffset(0, 198)
	moderationSection.Size = UDim2.new(1, -8, 0, 348)
	moderationSection.BackgroundColor3 = UiTheme.Colors.Surface
	moderationSection.BackgroundTransparency = 0.12
	moderationSection.BorderSizePixel = 0
	moderationSection.ZIndex = 12
	moderationSection.Parent = content
	UiTheme.addCorner(moderationSection, 16)
	UiTheme.addStroke(moderationSection, UiTheme.Colors.Border, 1)

	local moderationTitle = createLabel(
		"Title",
		moderationSection,
		"MODERAÇÃO",
		UiTheme.Fonts.BodyBold,
		15,
		UiTheme.Colors.Ink
	)
	moderationTitle.Position = UDim2.new(0, 15, 0, 11)
	moderationTitle.Size = UDim2.new(1, -30, 0, 22)
	moderationTitle.ZIndex = 13

	local playersCaption = createLabel(
		"PlayersCaption",
		moderationSection,
		"Jogadores neste servidor — toque para selecionar",
		UiTheme.Fonts.Body,
		12,
		UiTheme.Colors.InkSoft
	)
	playersCaption.Position = UDim2.new(0, 15, 0, 34)
	playersCaption.Size = UDim2.new(1, -30, 0, 20)
	playersCaption.ZIndex = 13

	local playerList = Instance.new("ScrollingFrame")
	playerList.Name = "PlayerList"
	playerList.Position = UDim2.new(0, 14, 0, 58)
	playerList.Size = UDim2.new(1, -28, 0, 96)
	playerList.BackgroundColor3 = UiTheme.Colors.SurfaceSoft
	playerList.BackgroundTransparency = 0.12
	playerList.BorderSizePixel = 0
	playerList.CanvasSize = UDim2.fromOffset(0, 0)
	playerList.ScrollBarImageColor3 = UiTheme.Colors.InkSoft
	playerList.ScrollBarThickness = 5
	playerList.ZIndex = 13
	playerList.Parent = moderationSection
	UiTheme.addCorner(playerList, 10)

	local targetBox = createTextBox("TargetUserId", moderationSection, "User ID do jogador", false)
	targetBox.Position = UDim2.new(0, 14, 0, 166)
	targetBox.Size = UDim2.new(1, -28, 0, 43)
	targetBox.ZIndex = 13
	targetBox.SelectionOrder = 120

	local reasonBox = createTextBox("Reason", moderationSection, "Motivo opcional (máx. 120 caracteres)", false)
	reasonBox.Position = UDim2.new(0, 14, 0, 219)
	reasonBox.Size = UDim2.new(1, -28, 0, 43)
	reasonBox.ZIndex = 13
	reasonBox.SelectionOrder = 121

	local actionRow = Instance.new("Frame")
	actionRow.Name = "ActionRow"
	actionRow.Position = UDim2.new(0, 14, 0, 275)
	actionRow.Size = UDim2.new(1, -28, 0, 55)
	actionRow.BackgroundTransparency = 1
	actionRow.ZIndex = 13
	actionRow.Parent = moderationSection

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	actionLayout.Padding = UDim.new(0, 8)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = actionRow

	local kickButton = createButton("KickButton", actionRow, "EXPULSAR", UiTheme.Colors.Orange)
	kickButton.Size = UDim2.new(1 / 3, -6, 1, 0)
	kickButton.LayoutOrder = 1
	kickButton.ZIndex = 13
	kickButton.SelectionOrder = 122
	kickButton.TextSize = 12

	local banButton = createButton("BanButton", actionRow, "BANIR", UiTheme.Colors.Danger)
	banButton.Size = UDim2.new(1 / 3, -6, 1, 0)
	banButton.LayoutOrder = 2
	banButton.TextColor3 = UiTheme.Colors.White
	banButton.ZIndex = 13
	banButton.SelectionOrder = 123
	banButton.TextSize = 12

	local unbanButton = createButton("UnbanButton", actionRow, "DESBANIR", UiTheme.Colors.Green)
	unbanButton.Size = UDim2.new(1 / 3, -6, 1, 0)
	unbanButton.LayoutOrder = 3
	unbanButton.ZIndex = 13
	unbanButton.SelectionOrder = 124
	unbanButton.TextSize = 12

	local feedbackLabel = createLabel(
		"Feedback",
		content,
		"F2 abre ou fecha o painel • todas as ações são registradas pelo servidor",
		UiTheme.Fonts.BodyBold,
		13,
		UiTheme.Colors.InkSoft
	)
	feedbackLabel.Position = UDim2.fromOffset(4, 558)
	feedbackLabel.Size = UDim2.new(1, -16, 0, 48)
	feedbackLabel.TextXAlignment = Enum.TextXAlignment.Center
	feedbackLabel.ZIndex = 13

	local connections: { RBXScriptConnection } = {}
	local playerEntryConnections: { RBXScriptConnection } = {}
	table.insert(connections, constrainText(announcementBox, 180))
	table.insert(connections, constrainText(reasonBox, 120))
	table.insert(connections, constrainText(targetBox, 20))

	local busy = false
	local actionButtons = { announceButton, kickButton, banButton, unbanButton }

	local function isGamepadInput(inputType: Enum.UserInputType): boolean
		return string.find(inputType.Name, "Gamepad") ~= nil
	end

	local function updateSelection(visible: boolean)
		if isGamepadInput(UserInputService:GetLastInputType()) then
			GuiService.SelectedObject = if visible then closeButton else openButton
		else
			GuiService.SelectedObject = nil
		end
	end

	local function setVisible(visible: boolean)
		overlay.Visible = visible
		openButton.Visible = not visible
		if visible then
			updateSelection(true)
		else
			announcementBox:ReleaseFocus()
			targetBox:ReleaseFocus()
			reasonBox:ReleaseFocus()
			updateSelection(false)
		end
	end

	table.insert(connections, openButton.Activated:Connect(function()
		setVisible(true)
	end))
	table.insert(connections, closeButton.Activated:Connect(function()
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
		elseif GuiService.SelectedObject == openButton or GuiService.SelectedObject == closeButton then
			GuiService.SelectedObject = nil
		end
	end))

	table.insert(connections, announceButton.Activated:Connect(function()
		if not busy then
			callbacks.onAnnounce(announcementBox.Text)
		end
	end))

	local function moderate(action: string)
		if not busy then
			callbacks.onModerate(action, targetBox.Text, reasonBox.Text)
		end
	end
	table.insert(connections, kickButton.Activated:Connect(function()
		moderate("Kick")
	end))
	table.insert(connections, banButton.Activated:Connect(function()
		moderate("Ban")
	end))
	table.insert(connections, unbanButton.Activated:Connect(function()
		moderate("Unban")
	end))

	local handle = {} :: AdminPanelViewHandle
	handle.setPlayers = function(players: { PlayerEntry })
		for _, connection in ipairs(playerEntryConnections) do
			connection:Disconnect()
		end
		table.clear(playerEntryConnections)

		for _, child in ipairs(playerList:GetChildren()) do
			if child:GetAttribute("AdminPlayerEntry") == true then
				child:Destroy()
			end
		end

		local entryHeight = 40
		for index, playerEntry in ipairs(players) do
			local entry = createButton(
				`Player_{playerEntry.userId}`,
				playerList,
				string.format("%s  @%s  •  %d", playerEntry.displayName, playerEntry.username, playerEntry.userId),
				UiTheme.Colors.Panel
			)
			entry:SetAttribute("AdminPlayerEntry", true)
			entry.Position = UDim2.fromOffset(5, (index - 1) * entryHeight + 5)
			entry.Size = UDim2.new(1, -15, 0, entryHeight - 5)
			entry.TextSize = 12
			entry.TextTruncate = Enum.TextTruncate.AtEnd
			entry.TextXAlignment = Enum.TextXAlignment.Left
			entry.ZIndex = 14
			entry.SelectionOrder = 130 + index
			UiTheme.addPadding(entry, 10, 0)
			table.insert(playerEntryConnections, entry.Activated:Connect(function()
				targetBox.Text = tostring(playerEntry.userId)
			end))
		end
		playerList.CanvasSize = UDim2.fromOffset(0, (#players * entryHeight) + 5)
	end

	handle.setBusy = function(newBusy: boolean)
		busy = newBusy
		for _, button in ipairs(actionButtons) do
			button.Active = not newBusy
			button.AutoButtonColor = not newBusy
			button.TextTransparency = if newBusy then 0.45 else 0
		end
		if newBusy then
			feedbackLabel.Text = "Processando ação no servidor…"
			feedbackLabel.TextColor3 = UiTheme.Colors.InkSoft
		end
	end

	handle.setFeedback = function(message: string, ok: boolean)
		feedbackLabel.Text = message
		feedbackLabel.TextColor3 = if ok then UiTheme.Colors.Green else UiTheme.Colors.Danger
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
	end

	return handle
end

return table.freeze(AdminPanelView)
