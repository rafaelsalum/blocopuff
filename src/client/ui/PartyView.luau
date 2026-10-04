--!strict

-- Painel PARTY (Fase 4.4): quem está na sua Party (👑 = líder, que pode
-- remover alguém), a lista de jogadores do servidor para chamar (amigos
-- com ⭐ primeiro) e o botão que abre o convite nativo do Roblox para
-- chamar amigos de fora do servidor. Só visual: tudo é pedido ao servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local SocialConfig = require(ReplicatedStorage.Shared.config.SocialConfig)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

export type PartyMember = {
	userId: number,
	name: string,
}

export type PartyState = {
	id: string,
	leaderUserId: number,
	members: { PartyMember },
	maxSize: number,
}

export type Candidate = {
	userId: number,
	name: string,
	friend: boolean,
}

export type PartyViewCallbacks = {
	invite: (userId: number) -> (),
	kick: (userId: number) -> (),
	leave: () -> (),
	inviteFriends: () -> (),
}

export type PartyViewHandle = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setState: (state: PartyState?, localUserId: number) -> (),
	setCandidates: (candidates: { Candidate }) -> (),
	setStatus: (text: string) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffParty"
local PANEL_SIZE = Vector2.new(720, 450)
-- A lista cabe a Party cheia (4) sem rolar.
local ROW_HEIGHT = 44
local LIST_TOP = 112
local LIST_HEIGHT = 212
local ROW_BUTTON_SIZE = UDim2.fromOffset(112, 36)
local ROW_BUTTON_TEXT = 15

local PartyView = {}

local function createRow(parent: Instance, name: string, order: number): (Frame, TextLabel)
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = UiTheme.Colors.Surface
	row.ZIndex = 4
	row.Parent = parent
	UiTheme.addCorner(row, 10)
	local label = UiTheme.createLabel(row, "Name", "", UiTheme.Fonts.BodyBold, 18, UiTheme.Colors.Ink)
	label.Position = UDim2.fromOffset(12, 0)
	label.Size = UDim2.new(1, -136, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextWrapped = false
	label.ZIndex = 5
	return row, label
end

local function createList(parent: Instance, name: string, position: UDim2, size: UDim2): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name = name
	list.Position = position
	list.Size = size
	list.BackgroundColor3 = UiTheme.Colors.Outline
	list.BackgroundTransparency = 0.35
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = UiTheme.Colors.Border
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 3
	list.Parent = parent
	UiTheme.addCorner(list, 12)
	UiTheme.addPadding(list, 6, 6)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

function PartyView.new(playerGui: PlayerGui, callbacks: PartyViewCallbacks): PartyViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 27)
	screenGui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	local responsive = ResponsiveScale.fit(root, PANEL_SIZE, ResponsiveScale.Modal)

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 20)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 2
	card.Parent = root
	UiTheme.stylePanel(card, { accent = UiTheme.Colors.Blue, radius = 20 })

	local title = UiTheme.createLabel(card, "Title", Lang.t("👥 PARTY"), UiTheme.Fonts.Display, 32, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(0, 240, 0, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	UiTheme.addTextOutline(title, 2.5)

	local subtitle = UiTheme.createLabel(
		card,
		"Subtitle",
		Lang.t("Até %d jogadores. Vocês entram juntos nas partidas.", SocialConfig.PartyMaxSize),
		UiTheme.Fonts.Body,
		16,
		UiTheme.Colors.InkSoft
	)
	subtitle.Position = UDim2.fromOffset(20, 52)
	subtitle.Size = UDim2.new(1, -100, 0, 22)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.ZIndex = 3

	local closeButton = UiKit.createButton(card, {
		name = "Close",
		text = "✕",
		variant = "Neutral",
		size = UDim2.fromOffset(56, 48),
		position = UDim2.new(1, -14, 0, 10),
		anchorPoint = Vector2.new(1, 0),
		textSize = 24,
		zIndex = 4,
	})

	local columnWidth = (PANEL_SIZE.X - 52) / 2
	local partyTitle = UiTheme.createLabel(card, "PartyTitle", Lang.t("SUA PARTY"), UiTheme.Fonts.Display, 19, UiTheme.Colors.Ink)
	partyTitle.Position = UDim2.fromOffset(20, 82)
	partyTitle.Size = UDim2.fromOffset(columnWidth, 26)
	partyTitle.TextXAlignment = Enum.TextXAlignment.Left
	partyTitle.ZIndex = 3
	local memberList = createList(card, "Members", UDim2.fromOffset(16, LIST_TOP), UDim2.fromOffset(columnWidth, LIST_HEIGHT))

	local inviteTitle = UiTheme.createLabel(card, "InviteTitle", Lang.t("CHAMAR"), UiTheme.Fonts.Display, 19, UiTheme.Colors.Ink)
	inviteTitle.Position = UDim2.fromOffset(36 + columnWidth, 82)
	inviteTitle.Size = UDim2.fromOffset(columnWidth, 26)
	inviteTitle.TextXAlignment = Enum.TextXAlignment.Left
	inviteTitle.ZIndex = 3
	local candidateList = createList(card, "Candidates", UDim2.fromOffset(36 + columnWidth, LIST_TOP), UDim2.fromOffset(columnWidth, LIST_HEIGHT))

	local leaveButton = UiKit.createButton(card, {
		name = "Leave",
		text = Lang.t("SAIR DA PARTY"),
		variant = "Danger",
		size = UDim2.fromOffset(columnWidth, 50),
		position = UDim2.fromOffset(16, LIST_TOP + LIST_HEIGHT + 10),
		textSize = 18,
		zIndex = 4,
	})
	leaveButton.button.Activated:Connect(function()
		UiKit.playClick()
		callbacks.leave()
	end)

	local friendsButton = UiKit.createButton(card, {
		name = "InviteFriends",
		text = Lang.t("CHAMAR AMIGOS PARA O JOGO"),
		variant = "Primary",
		size = UDim2.fromOffset(columnWidth, 50),
		position = UDim2.fromOffset(36 + columnWidth, LIST_TOP + LIST_HEIGHT + 10),
		textSize = 17,
		zIndex = 4,
	})
	friendsButton.button.Activated:Connect(function()
		UiKit.playClick()
		callbacks.inviteFriends()
	end)

	local status = UiTheme.createLabel(card, "Status", "", UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.Gold)
	status.Position = UDim2.new(0, 20, 1, -64)
	status.Size = UDim2.new(1, -40, 0, 22)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.ZIndex = 3

	local footer = UiTheme.createLabel(card, "Footer", Lang.t("Na partida cada um joga por si: a Party só garante que vocês entrem juntos."), UiTheme.Fonts.Body, 14, UiTheme.Colors.InkSoft)
	footer.Position = UDim2.new(0, 20, 1, -36)
	footer.Size = UDim2.new(1, -40, 0, 22)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.ZIndex = 3

	local currentState: PartyState? = nil
	local localUserId = 0
	local candidates: { Candidate } = {}

	local function clear(list: ScrollingFrame)
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function renderMembers()
		clear(memberList)
		local state = currentState
		if state == nil then
			partyTitle.Text = Lang.t("SUA PARTY")
			local _, label = createRow(memberList, "Empty", 1)
			label.Text = Lang.t("Você ainda não está numa Party. Chame alguém ao lado!")
			label.TextWrapped = true
			label.Size = UDim2.new(1, -20, 1, 0)
			label.Font = UiTheme.Fonts.Body
			label.TextSize = 15
			leaveButton.root.Visible = false
			return
		end
		partyTitle.Text = Lang.t("SUA PARTY  %d/%d", #state.members, state.maxSize)
		leaveButton.root.Visible = true
		local isLeader = state.leaderUserId == localUserId
		for index, member in ipairs(state.members) do
			local row, label = createRow(memberList, `Member{member.userId}`, index)
			local crown = if member.userId == state.leaderUserId then "👑 " else ""
			local you = if member.userId == localUserId then Lang.t(" (você)") else ""
			label.Text = `{crown}{member.name}{you}`
			if isLeader and member.userId ~= localUserId then
				local kick = UiKit.createButton(row, {
					name = "Kick",
					text = Lang.t("REMOVER"),
					variant = "Neutral",
					size = ROW_BUTTON_SIZE,
					position = UDim2.new(1, -6, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
					textSize = ROW_BUTTON_TEXT,
					zIndex = 6,
				})
				kick.button.Activated:Connect(function()
					UiKit.playClick()
					callbacks.kick(member.userId)
				end)
			end
		end
	end

	local function renderCandidates()
		clear(candidateList)
		local state = currentState
		local inParty: { [number]: boolean } = {}
		if state ~= nil then
			for _, member in ipairs(state.members) do
				inParty[member.userId] = true
			end
		end
		local full = state ~= nil and #state.members >= state.maxSize
		local shown = 0
		for _, candidate in ipairs(candidates) do
			if not inParty[candidate.userId] then
				shown += 1
				local row, label = createRow(candidateList, `Candidate{candidate.userId}`, shown)
				label.Text = if candidate.friend then `⭐ {candidate.name}` else candidate.name
				local button = UiKit.createButton(row, {
					name = "Invite",
					text = Lang.t("CHAMAR"),
					variant = "Success",
					size = ROW_BUTTON_SIZE,
					position = UDim2.new(1, -6, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
					textSize = ROW_BUTTON_TEXT,
					zIndex = 6,
				})
				button.setEnabled(not full)
				button.button.Activated:Connect(function()
					UiKit.playClick()
					callbacks.invite(candidate.userId)
				end)
			end
		end
		if shown == 0 then
			local _, label = createRow(candidateList, "Empty", 1)
			label.Text = Lang.t("Ninguém para chamar agora. Chame amigos para o jogo!")
			label.TextWrapped = true
			label.Size = UDim2.new(1, -20, 1, 0)
			label.Font = UiTheme.Fonts.Body
			label.TextSize = 15
		end
	end

	local handle = {} :: PartyViewHandle

	handle.open = function()
		renderMembers()
		renderCandidates()
		screenGui.Enabled = true
		responsive.pop(0.9, 0.25)
	end

	handle.close = function()
		screenGui.Enabled = false
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.setState = function(state: PartyState?, userId: number)
		currentState = state
		localUserId = userId
		if screenGui.Enabled then
			renderMembers()
			renderCandidates()
		end
	end

	handle.setCandidates = function(list: { Candidate })
		candidates = list
		if screenGui.Enabled then
			renderCandidates()
		end
	end

	handle.setStatus = function(text: string)
		status.Text = text
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

return table.freeze(PartyView)
