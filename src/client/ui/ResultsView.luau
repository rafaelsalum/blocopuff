--!strict

-- Painel de pós-partida: título (vitória, fim ou empate), pódio com os três
-- primeiros (foto, nome e posição), sua posição e seus números, destaques da
-- rodada, o XP que você ganhou com a barra de nível e um rodapé com o tempo
-- até a próxima rodada. Só visual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local LevelCurve = require(ReplicatedStorage.Shared.modules.LevelCurve)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local ResultTypes = require(ReplicatedStorage.Shared.types.ResultTypes)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

local T = Lang.t

type RoundResult = ResultTypes.RoundResult
type ResultEntry = ResultTypes.ResultEntry
type Highlight = ResultTypes.Highlight
type XpAward = ProfileTypes.XpAward

export type ResultsViewHandle = {
	show: (result: RoundResult, localUserId: number) -> (),
	-- XP da rodada (chega pelo perfil, logo depois do resultado).
	setXp: (award: XpAward, totalXp: number) -> (),
	setFooter: (text: string) -> (),
	hide: () -> (),
	isVisible: () -> boolean,
	destroy: () -> (),
}

type PodiumSlot = {
	frame: Frame,
	avatar: ImageLabel,
	name: TextLabel,
	medal: TextLabel,
	stand: Frame,
}

type Chip = {
	frame: Frame,
	icon: TextLabel,
	title: TextLabel,
	detail: TextLabel,
}

local GUI_NAME = "BlocoPuffResults"
local PANEL_SIZE = Vector2.new(480, 548)
local MAX_CHIPS = 5
-- Ordem visual do pódio: 2º à esquerda, 1º no meio, 3º à direita.
local PODIUM_ORDER = { 2, 1, 3 }
local STAND_HEIGHTS = { 56, 40, 28 }
local MEDAL_COLORS = {
	Color3.fromRGB(255, 209, 102),
	Color3.fromRGB(205, 214, 230),
	Color3.fromRGB(222, 150, 96),
}

local HIGHLIGHT_ICONS: { [string]: string } = {
	Demolisher = "💥",
	Knockouts = "👊",
	Vault = "🗝️",
	BaraoEscapes = "🐶",
	Secrets = "🖼️",
	Comeback = "🔥",
}

-- Mapeamento de fonte de XP para o nome exibido
-- Nota: os valores são constantes que são traduzidas dinamicamente com T() onde exibidas
local XP_SOURCE_NAMES: { [string]: string } = {
	Participation = "Partida",
	Placement = "Colocação",
	Win = "Vitória",
	Knockouts = "Derrubadas",
	Blocks = "Blocos",
	Secrets = "Segredos",
	VaultOpened = "Cofre aberto",
	VaultConquered = "Cofre conquistado",
	BaraoEscapes = "Fugas do Barão",
	Comeback = "Volta por Cima",
	BlocksBuilt = "Construções",
}

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
	local word = if count == 1 then T(singular) else T(pluralForm)
	return string.format("%d %s", count, word)
end

local function describe(result: RoundResult, mine: ResultEntry?, localUserId: number): (string, string, Color3)
	if result.winnerUserId ~= 0 and result.winnerUserId == localUserId then
		return T("VITÓRIA!"), T("Você foi o último na arena"), UiTheme.Colors.Gold
	elseif result.draw then
		local survivors = 0
		for _, entry in ipairs(result.entries) do
			if entry.survived then
				survivors += 1
			end
		end
		if survivors == 0 then
			return T("EMPATE!"), T("Os últimos caíram ao mesmo tempo"), UiTheme.Colors.Brand
		end
		return T("EMPATE!"), T("%d jogadores resistiram até o fim", survivors), UiTheme.Colors.Brand
	elseif result.winnerUserId ~= 0 then
		return T("FIM DA RODADA"), T("%s venceu a rodada", result.winnerName), UiTheme.Colors.Brand
	end
	return T("FIM DA RODADA"), if mine ~= nil then T("Ninguém sobrou na arena") else T("Rodada encerrada"), UiTheme.Colors.Brand
end

local function highlightDetail(highlight: Highlight): string
	local value = highlight.value
	if highlight.kind == "Demolisher" then
		return string.format("%s · %s", highlight.name, plural(value, "bloco", "blocos"))
	elseif highlight.kind == "Knockouts" then
		return string.format("%s · %s", highlight.name, plural(value, "derrubada", "derrubadas"))
	elseif highlight.kind == "Vault" then
		return string.format("%s · %s", highlight.name, if value >= 2 then T("pegou o Puffador") else T("abriu o cofre"))
	elseif highlight.kind == "BaraoEscapes" then
		return string.format("%s · %s", highlight.name, plural(value, "fuga", "fugas"))
	elseif highlight.kind == "Secrets" then
		return string.format("%s · %s", highlight.name, plural(value, "passagem", "passagens"))
	end
	return highlight.name
end

local function createPodiumSlot(parent: Instance, rank: number, x: number): PodiumSlot
	local frame = Instance.new("Frame")
	frame.Name = string.format("Podium%d", rank)
	frame.Position = UDim2.fromOffset(x, 0)
	frame.Size = UDim2.fromOffset(136, 146)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 3
	frame.Parent = parent

	local standHeight = STAND_HEIGHTS[rank]
	local avatarSize = if rank == 1 then 58 else 48
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.AnchorPoint = Vector2.new(0.5, 1)
	avatar.Position = UDim2.new(0.5, 0, 1, -(standHeight + 22))
	avatar.Size = UDim2.fromOffset(avatarSize, avatarSize)
	avatar.BackgroundColor3 = UiTheme.Colors.SurfaceSoft
	avatar.ZIndex = 4
	avatar.Parent = frame
	UiTheme.addCorner(avatar, 999)
	UiTheme.addStroke(avatar, MEDAL_COLORS[rank], 3)

	local name = label(frame, "Name", "", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.White, UDim2.new(0, 0, 1, -(standHeight + 20)), UDim2.new(1, 0, 0, 18))
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false

	local stand = Instance.new("Frame")
	stand.Name = "Stand"
	stand.AnchorPoint = Vector2.new(0.5, 1)
	stand.Position = UDim2.new(0.5, 0, 1, 0)
	stand.Size = UDim2.new(1, -16, 0, standHeight)
	stand.BackgroundColor3 = UiTheme.Colors.White
	stand.ZIndex = 3
	stand.Parent = frame
	UiTheme.addCorner(stand, 10)
	UiTheme.addGradient(stand, MEDAL_COLORS[rank], MEDAL_COLORS[rank]:Lerp(UiTheme.Colors.Outline, 0.45))

	local medal = UiTheme.createLabel(stand, "Medal", Lang.ordinal(rank), UiTheme.Fonts.Display, if rank == 1 then 26 else 20, UiTheme.Colors.White)
	medal.Size = UDim2.fromScale(1, 1)
	medal.ZIndex = 4
	UiTheme.addTextOutline(medal, 2)

	return { frame = frame, avatar = avatar, name = name, medal = medal, stand = stand }
end

local function createChip(parent: Instance, index: number): Chip
	local column = (index - 1) % 2
	local row = math.floor((index - 1) / 2)
	local frame = Instance.new("Frame")
	frame.Name = string.format("Highlight%d", index)
	frame.Position = UDim2.new(column * 0.5, if column == 0 then 0 else 4, 0, row * 36)
	frame.Size = UDim2.new(0.5, -4, 0, 32)
	frame.BackgroundColor3 = UiTheme.Colors.Outline
	frame.BackgroundTransparency = 0.35
	frame.ZIndex = 3
	frame.Parent = parent
	UiTheme.addCorner(frame, 10)

	local icon = label(frame, "Icon", "", UiTheme.Fonts.Display, 18, UiTheme.Colors.White, UDim2.fromOffset(6, 0), UDim2.new(0, 26, 1, 0))
	local title = label(frame, "Title", "", UiTheme.Fonts.Display, 12, UiTheme.Colors.Gold, UDim2.fromOffset(36, 2), UDim2.new(1, -42, 0, 14))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local detail = label(frame, "Detail", "", UiTheme.Fonts.Body, 11, UiTheme.Colors.White, UDim2.fromOffset(36, 16), UDim2.new(1, -42, 0, 14))
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	detail.TextWrapped = false
	return { frame = frame, icon = icon, title = title, detail = detail }
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
	local responsive = ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.55, 1.0)
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

	local title = label(card, "Title", "", UiTheme.Fonts.Display, 34, UiTheme.Colors.Gold, UDim2.fromOffset(20, 12), UDim2.new(1, -40, 0, 40))
	UiTheme.addTextOutline(title, 3)
	local subtitle = label(card, "Subtitle", "", UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.White, UDim2.fromOffset(20, 52), UDim2.new(1, -40, 0, 18))

	-- Pódio.
	local podium = Instance.new("Frame")
	podium.Name = "Podium"
	podium.Position = UDim2.new(0.5, -204, 0, 76)
	podium.Size = UDim2.fromOffset(408, 146)
	podium.BackgroundTransparency = 1
	podium.ZIndex = 3
	podium.Parent = card
	local slots: { [number]: PodiumSlot } = {}
	for column, rank in ipairs(PODIUM_ORDER) do
		slots[rank] = createPodiumSlot(podium, rank, (column - 1) * 136)
	end

	-- Sua linha.
	local personal = label(card, "Personal", "", UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.White, UDim2.fromOffset(20, 230), UDim2.new(1, -40, 0, 22))
	personal.RichText = true

	-- Destaques.
	local chipsFrame = Instance.new("Frame")
	chipsFrame.Name = "Highlights"
	chipsFrame.Position = UDim2.fromOffset(20, 260)
	chipsFrame.Size = UDim2.new(1, -40, 0, 104)
	chipsFrame.BackgroundTransparency = 1
	chipsFrame.ZIndex = 3
	chipsFrame.Parent = card
	local chips: { Chip } = {}
	for index = 1, MAX_CHIPS do
		table.insert(chips, createChip(chipsFrame, index))
	end
	local noHighlights = label(chipsFrame, "Empty", T("Sem destaques nesta rodada"), UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 20))

	-- XP da rodada.
	local xpFrame = Instance.new("Frame")
	xpFrame.Name = "Xp"
	xpFrame.Position = UDim2.fromOffset(20, 372)
	xpFrame.Size = UDim2.new(1, -40, 0, 92)
	xpFrame.BackgroundColor3 = UiTheme.Colors.Outline
	xpFrame.BackgroundTransparency = 0.35
	xpFrame.ZIndex = 3
	xpFrame.Parent = card
	UiTheme.addCorner(xpFrame, 14)
	local xpTotal = label(xpFrame, "Total", "", UiTheme.Fonts.Display, 24, UiTheme.Colors.Gold, UDim2.fromOffset(12, 6), UDim2.new(0.4, -12, 0, 28))
	xpTotal.TextXAlignment = Enum.TextXAlignment.Left
	-- Cabe "+XP" e os tickets da rodada na mesma linha.
	xpTotal.TextScaled = true
	xpTotal.TextWrapped = false
	UiTheme.addTextConstraint(xpTotal, 14, 24)
	UiTheme.addTextOutline(xpTotal, 2)
	local xpLevel = label(xpFrame, "Level", "", UiTheme.Fonts.Display, 16, UiTheme.Colors.White, UDim2.new(0.4, 0, 0, 10), UDim2.new(0.6, -12, 0, 22))
	xpLevel.TextXAlignment = Enum.TextXAlignment.Right
	UiTheme.addTextOutline(xpLevel, 1.5)
	local xpTrack = Instance.new("Frame")
	xpTrack.Name = "Track"
	xpTrack.Position = UDim2.fromOffset(12, 40)
	xpTrack.Size = UDim2.new(1, -24, 0, 10)
	xpTrack.BackgroundColor3 = UiTheme.Colors.Track
	xpTrack.ZIndex = 4
	xpTrack.Parent = xpFrame
	UiTheme.addCorner(xpTrack, 999)
	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = UiTheme.Colors.White
	xpFill.ZIndex = 5
	xpFill.Parent = xpTrack
	UiTheme.addCorner(xpFill, 999)
	UiTheme.addGradient(xpFill, UiTheme.Colors.Gold, UiTheme.Colors.Brand, 0)
	local xpLines = label(xpFrame, "Lines", "", UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft, UDim2.fromOffset(12, 56), UDim2.new(1, -24, 0, 30))
	xpLines.TextXAlignment = Enum.TextXAlignment.Left
	xpLines.TextYAlignment = Enum.TextYAlignment.Top

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

	-- Cada exibição tem uma geração: fotos que chegam atrasadas de uma
	-- rodada anterior não sobrescrevem as da atual.
	local generation = 0

	local function loadAvatar(image: ImageLabel, userId: number, token: number)
		image.Image = ""
		-- Bot RoboPuff (id negativo): sem foto, só o ícone de bot.
		local botIcon = image:FindFirstChild("BotIcon")
		if botIcon == nil then
			local label = Instance.new("TextLabel")
			label.Name = "BotIcon"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = BotConfig.Body.Tag
			label.TextScaled = true
			label.ZIndex = image.ZIndex + 1
			label.Parent = image
			botIcon = label
		end
		if botIcon ~= nil and botIcon:IsA("TextLabel") then
			botIcon.Visible = userId < 0
		end
		if userId < 0 then
			return
		end
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok and generation == token and typeof(content) == "string" then
				image.Image = content
			end
		end)
	end

	local function resetXp()
		xpFrame.Visible = false
		xpFill.Size = UDim2.fromScale(0, 1)
	end

	local handle = {} :: ResultsViewHandle

	handle.show = function(result: RoundResult, localUserId: number)
		generation += 1
		local token = generation
		local mine = findEntry(result, localUserId)
		local titleText, subtitleText, accent = describe(result, mine, localUserId)
		title.Text = titleText
		title.TextColor3 = accent
		subtitle.Text = subtitleText
		local strokeGradient = stroke:FindFirstChildOfClass("UIGradient") :: UIGradient?
		if strokeGradient ~= nil then
			strokeGradient.Color = ColorSequence.new(accent, accent:Lerp(UiTheme.Colors.White, 0.3))
		end

		-- Pódio: a n-ésima entrada ordenada ocupa o n-ésimo degrau (empates
		-- mostram a mesma posição no texto).
		for rank = 1, 3 do
			local slot = slots[rank]
			local entry = result.entries[rank]
			slot.frame.Visible = entry ~= nil
			if entry ~= nil then
				slot.name.Text = entry.name
				slot.name.TextColor3 = if entry.userId == localUserId then UiTheme.Colors.Gold else UiTheme.Colors.White
				slot.medal.Text = Lang.ordinal(entry.position)
				loadAvatar(slot.avatar, entry.userId, token)
			end
		end

		if mine ~= nil then
			personal.Text = T("Você: <font color=\"#FFD166\">#%d</font> de %d  ·  %s  ·  %s", mine.position, result.participantCount, plural(mine.blocks, "bloco", "blocos"), plural(mine.knockouts, "derrubada", "derrubadas"))
		else
			personal.Text = T("Você assistiu esta rodada")
		end

		for index, chip in ipairs(chips) do
			local highlight = result.highlights[index]
			chip.frame.Visible = highlight ~= nil
			if highlight ~= nil then
				chip.icon.Text = HIGHLIGHT_ICONS[highlight.kind] or "★"
				chip.title.Text = T(highlight.title)
				chip.detail.Text = highlightDetail(highlight)
				chip.frame.BackgroundColor3 = if highlight.userId == localUserId then UiTheme.Colors.GoldDeep else UiTheme.Colors.Outline
			end
		end
		noHighlights.Visible = #result.highlights == 0

		resetXp()
		screenGui.Enabled = true
		pop.Scale = 0.85
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	handle.setXp = function(award: XpAward, totalXp: number)
		local progress = LevelCurve.progress(totalXp)
		xpFrame.Visible = true
		xpTotal.Text = if award.tickets > 0
			then T("+%d XP  +%d 🎟", award.total, award.tickets)
			else T("+%d XP", award.total)
		xpLevel.Text = if award.levelAfter > award.levelBefore
			then T("NÍVEL %d → %d!", award.levelBefore, award.levelAfter)
			elseif progress.isMax then T("NÍVEL MÁXIMO")
			else T("NÍVEL %d  ·  %d/%d", progress.level, progress.current, progress.needed)
		local ratio = if progress.isMax then 1 else math.clamp(progress.current / math.max(1, progress.needed), 0, 1)
		xpFill.Size = UDim2.fromScale(0, 1)
		TweenService:Create(xpFill, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
		local parts: { string } = {}
		for _, line in ipairs(award.lines) do
			table.insert(parts, string.format("%s +%d", T(XP_SOURCE_NAMES[line.source] or line.source), line.xp))
		end
		xpLines.Text = if #parts > 0 then table.concat(parts, "  ·  ") else T("Dispare pelo menos um Puff para ganhar XP")
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
