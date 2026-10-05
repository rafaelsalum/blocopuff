--!strict

-- Cartão de perfil no canto superior esquerdo do lobby: nível (e prestígio),
-- barra de XP e um botão que abre as estatísticas da carreira. Embaixo, uma
-- fileira de atalhos: 🏆 ranking global, ✨ Puffdex, 🎰 Puff Machine (com o
-- saldo de tickets), 📋 desafios, 📜 Álbum do Casarão, 👥 Party e 💌
-- convite. O painel PERFIL mostra o título do Álbum (o melhor ganho). Some durante a partida (o HUD
-- de combate usa esse canto). Só visual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local LevelCurve = require(ReplicatedStorage.Shared.modules.LevelCurve)
local MysteryConfig = require(ReplicatedStorage.Shared.config.MysteryConfig)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot

export type ProfileCardViewHandle = {
	setProfile: (snapshot: ProfileSnapshot) -> (),
	setVisible: (visible: boolean) -> (),
	-- Membros da Party (0 = sem Party), mostrado no selo do botão 👥.
	setPartySize: (size: number) -> (),
	celebrateLevel: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffProfileCard"
local CARD_SIZE = Vector2.new(266, 66)
local SHORTCUT_GAP = 4
local SHORTCUT_HEIGHT = 44
local SHORTCUT_PADDING = 1
local SHORTCUT_Y = CARD_SIZE.Y + 6
local CORNER_HEIGHT = SHORTCUT_Y + SHORTCUT_HEIGHT + 14
-- Painel das estatísticas: abre ao lado do cartão (no celular deitado não
-- cabe embaixo), com linhas e letras maiores para ler fácil.
local STATS_GAP = 10
local STAT_ROW_HEIGHT = 26
local STAT_ROW_GAP = 2
local STAT_TEXT_SIZE = 16
local STAT_VALUE_WIDTH = 72
local NOTICE_HEIGHT = 34
local STATS_WIDTH = 320

-- Estatísticas mostradas no painel, na ordem.
local STAT_ROWS: { { key: string, label: string } } = {
	{ key = "matches", label = Lang.t("Partidas") },
	{ key = "wins", label = Lang.t("Vitórias") },
	{ key = "top3", label = Lang.t("Top 3") },
	{ key = "knockouts", label = Lang.t("Derrubadas") },
	{ key = "blocksDestroyed", label = Lang.t("Blocos destruídos") },
	{ key = "vaultsConquered", label = Lang.t("Cofres conquistados") },
	{ key = "baraoEscapes", label = Lang.t("Fugas do Barão") },
	{ key = "secretsFound", label = Lang.t("Passagens descobertas") },
	{ key = "comebacks", label = Lang.t("Voltas por Cima") },
	{ key = "botWins", label = Lang.t("Vitórias contra RoboPuffs") },
}

local ProfileCardView = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

-- `onRanking`: abre o painel RANKING (botão 🏆 ao lado do cartão).
-- `onPuffdex`: abre o PUFFDEX (botão ✨). `onMachine`: abre a PUFF MACHINE (🎰).
-- `onChallenges`: abre os DESAFIOS (📋). `onParty`: abre a PARTY (👥).
-- `onInvite`: convida amigos com recompensa (💌). `onAlbum`: abre o ÁLBUM
-- DO CASARÃO (📜).
function ProfileCardView.new(
	playerGui: PlayerGui,
	onRanking: () -> (),
	onPuffdex: () -> (),
	onMachine: () -> (),
	onChallenges: () -> (),
	onParty: () -> (),
	onInvite: () -> (),
	onAlbum: () -> ()
): ProfileCardViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 12)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Position = UDim2.fromOffset(18, 16)
	root.Size = UDim2.fromOffset(CARD_SIZE.X, CORNER_HEIGHT)
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

	local title = UiTheme.createLabel(card, "Title", Lang.t("NÍVEL %d%s", 1, ""), UiTheme.Fonts.Display, 18, UiTheme.Colors.Ink)
	title.Position = UDim2.fromOffset(68, 8)
	title.Size = UDim2.new(1, -156, 0, 22)
	-- Nível alto ou com prestígio: a letra encolhe em vez de quebrar a linha.
	title.TextWrapped = false
	title.TextScaled = true
	UiTheme.addTextConstraint(title, 11, 18)
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
		text = Lang.t("PERFIL"),
		variant = "Neutral",
		size = UDim2.fromOffset(78, 28),
		position = UDim2.new(1, -8, 0, 6),
		anchorPoint = Vector2.new(1, 0),
		textSize = 14,
		zIndex = 4,
	})

	-- Fileira de atalhos embaixo do cartão (cabe no mesmo canto em celular).
	local shortcuts: { { name: string, text: string, variant: UiKit.ButtonVariant, action: () -> () } } = {
		{ name = "RankingButton", text = "🏆", variant = "Gold", action = onRanking },
		{ name = "PuffdexButton", text = "✨", variant = "Primary", action = onPuffdex },
		{ name = "MachineButton", text = "🎰", variant = "Gold", action = onMachine },
		{ name = "ChallengesButton", text = "📋", variant = "Success", action = onChallenges },
		{ name = "AlbumButton", text = "📜", variant = "Gold", action = onAlbum },
		{ name = "PartyButton", text = "👥", variant = "Primary", action = onParty },
		{ name = "InviteButton", text = "💌", variant = "Success", action = onInvite },
	}
	local buttonWidth = (CARD_SIZE.X - SHORTCUT_GAP * (#shortcuts - 1)) / #shortcuts
	local buttons: { [string]: UiKit.ButtonHandle } = {}
	-- Abrir outro painel fecha as estatísticas (os modais ficam por cima).
	local closeStats: () -> () = function() end
	for index, shortcut in ipairs(shortcuts) do
		local button = UiKit.createButton(root, {
			name = shortcut.name,
			text = shortcut.text,
			variant = shortcut.variant,
			size = UDim2.fromOffset(buttonWidth, SHORTCUT_HEIGHT),
			position = UDim2.fromOffset((index - 1) * (buttonWidth + SHORTCUT_GAP), SHORTCUT_Y),
			textSize = 22,
			zIndex = 4,
		})
		-- Botão estreito: o ícone precisa de quase toda a largura (com a
		-- margem padrão e quebra de linha, o emoji não cabe e some).
		local padding = button.button:FindFirstChildOfClass("UIPadding")
		if padding ~= nil then
			padding.PaddingLeft = UDim.new(0, SHORTCUT_PADDING)
			padding.PaddingRight = UDim.new(0, SHORTCUT_PADDING)
		end
		local icon = button.button:FindFirstChild("Label")
		if icon ~= nil and icon:IsA("TextLabel") then
			icon.TextWrapped = false
		end
		button.button.Activated:Connect(function()
			UiKit.playClick()
			closeStats()
			shortcut.action()
		end)
		buttons[shortcut.name] = button
	end

	-- Aviso de desafio pendente (bolinha) quando ainda há desafio do dia a fazer.
	local pendingDot = Instance.new("Frame")
	pendingDot.Name = "Pending"
	pendingDot.AnchorPoint = Vector2.new(0.5, 0.5)
	pendingDot.Position = UDim2.new(1, -4, 0, 4)
	pendingDot.Size = UDim2.fromOffset(12, 12)
	pendingDot.BackgroundColor3 = UiTheme.Colors.Danger
	pendingDot.ZIndex = 8
	pendingDot.Visible = false
	pendingDot.Parent = buttons.ChallengesButton.root
	UiTheme.addCorner(pendingDot, 999)
	UiTheme.addStroke(pendingDot, UiTheme.Colors.Outline, 1.5)

	-- Tamanho da Party num selo no botão 👥.
	local partyBadge = UiTheme.createLabel(buttons.PartyButton.root, "PartySize", "", UiTheme.Fonts.Display, 11, UiTheme.Colors.White)
	partyBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	partyBadge.Position = UDim2.new(1, -4, 0, 4)
	partyBadge.Size = UDim2.fromOffset(18, 18)
	partyBadge.BackgroundTransparency = 0
	partyBadge.BackgroundColor3 = UiTheme.Colors.Green
	partyBadge.ZIndex = 8
	partyBadge.Visible = false
	UiTheme.addCorner(partyBadge, 999)

	-- Saldo de tickets num selo embaixo do botão.
	local ticketBadge = UiTheme.createLabel(buttons.MachineButton.root, "Tickets", "🎟 0", UiTheme.Fonts.Display, 11, UiTheme.Colors.White)
	ticketBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	ticketBadge.Position = UDim2.new(0.5, 0, 1, -2)
	ticketBadge.Size = UDim2.fromOffset(buttonWidth + 10, 18)
	ticketBadge.BackgroundTransparency = 0
	ticketBadge.BackgroundColor3 = UiTheme.Colors.Outline
	ticketBadge.TextScaled = true
	ticketBadge.ZIndex = 8
	UiTheme.addTextConstraint(ticketBadge, 8, 11)
	UiTheme.addCorner(ticketBadge, 999)

	-- Painel das estatísticas (abre ao lado do cartão).
	local statsHeight = 20 + ((#STAT_ROWS + 1) * (STAT_ROW_HEIGHT + STAT_ROW_GAP)) + NOTICE_HEIGHT
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Position = UDim2.fromOffset(CARD_SIZE.X + STATS_GAP, 0)
	stats.Size = UDim2.fromOffset(STATS_WIDTH, statsHeight)
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
	layout.Padding = UDim.new(0, STAT_ROW_GAP)
	layout.Parent = list

	-- Título do Álbum do Casarão (o melhor ganho), no alto do painel.
	local titleLine = UiTheme.createLabel(list, "RelicTitle", "", UiTheme.Fonts.BodyBold, STAT_TEXT_SIZE, UiTheme.Colors.Gold)
	titleLine.LayoutOrder = 0
	titleLine.Size = UDim2.new(1, 0, 0, STAT_ROW_HEIGHT)
	titleLine.TextWrapped = false
	titleLine.TextScaled = true
	UiTheme.addTextConstraint(titleLine, 11, STAT_TEXT_SIZE)
	titleLine.TextXAlignment = Enum.TextXAlignment.Left
	titleLine.ZIndex = 3
	local valueLabels: { [string]: TextLabel } = {}
	for index, row in ipairs(STAT_ROWS) do
		local line = Instance.new("Frame")
		line.Name = row.key
		line.LayoutOrder = index
		line.Size = UDim2.new(1, 0, 0, STAT_ROW_HEIGHT)
		line.BackgroundTransparency = 1
		line.ZIndex = 2
		line.Parent = list
		local name = UiTheme.createLabel(line, "Name", row.label, UiTheme.Fonts.Body, STAT_TEXT_SIZE, UiTheme.Colors.InkSoft)
		name.Size = UDim2.new(1, -STAT_VALUE_WIDTH, 1, 0)
		name.TextWrapped = false
		name.TextScaled = true
		UiTheme.addTextConstraint(name, 11, STAT_TEXT_SIZE)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 3
		local value = UiTheme.createLabel(line, "Value", "0", UiTheme.Fonts.BodyBold, STAT_TEXT_SIZE, UiTheme.Colors.Ink)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.fromScale(1, 0)
		value.Size = UDim2.new(0, STAT_VALUE_WIDTH, 1, 0)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.ZIndex = 3
		valueLabels[row.key] = value
	end
	local notice = UiTheme.createLabel(list, "Notice", "", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.Orange)
	notice.LayoutOrder = #STAT_ROWS + 1
	notice.Size = UDim2.new(1, 0, 0, NOTICE_HEIGHT)
	notice.TextXAlignment = Enum.TextXAlignment.Left
	notice.ZIndex = 3
	notice.Visible = false

	closeStats = function()
		stats.Visible = false
		statsButton.setText(Lang.t("PERFIL"))
	end

	statsButton.button.Activated:Connect(function()
		stats.Visible = not stats.Visible
		statsButton.setText(if stats.Visible then Lang.t("FECHAR") else Lang.t("PERFIL"))
	end)

	local handle = {} :: ProfileCardViewHandle

	handle.setProfile = function(snapshot: ProfileSnapshot)
		local progress = LevelCurve.progress(snapshot.xp)
		levelLabel.Text = tostring(progress.level)
		local prestigeText = if snapshot.prestige > 0 then string.format("  ★%d", snapshot.prestige) else ""
		title.Text = Lang.t("NÍVEL %d%s", progress.level, prestigeText)
		local ratio = if progress.isMax then 1 else math.clamp(progress.current / math.max(1, progress.needed), 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
		xpLabel.Text = if progress.isMax
			then Lang.t("NÍVEL MÁXIMO")
			else string.format("%s / %s XP", formatNumber(progress.current), formatNumber(progress.needed))
		local statsTable = snapshot.stats :: any
		for key, value in pairs(valueLabels) do
			value.Text = formatNumber(statsTable[key] or 0)
		end
		ticketBadge.Text = string.format("🎟 %s", formatNumber(snapshot.tickets))
		local pending = false
		for _, state in ipairs(snapshot.challenges) do
			if not state.done then
				pending = true
			end
		end
		pendingDot.Visible = pending
		local relics: { [string]: boolean } = {}
		for _, state in ipairs(snapshot.relics) do
			relics[state.id] = true
		end
		local titles = RelicCatalog.titlesFor(relics, snapshot.dailyRelicCount)
		if MysteryConfig.allSolved(snapshot.mysteries) then
			table.insert(titles, MysteryConfig.AllTitle)
		end
		titleLine.Text = if #titles > 0 then Lang.t("🏅 %s", Lang.t(titles[1])) else Lang.t("🏅 Sem título ainda (veja o 📜 Álbum)")
		notice.Visible = not snapshot.saved
		notice.Text = Lang.t("Progresso desta sessão não está sendo salvo")
	end

	handle.setVisible = function(visible: boolean)
		root.Visible = visible
		if not visible then
			closeStats()
		end
	end

	handle.setPartySize = function(size: number)
		partyBadge.Visible = size > 1
		partyBadge.Text = tostring(size)
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
