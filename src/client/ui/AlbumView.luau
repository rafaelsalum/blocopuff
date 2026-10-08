--!strict

-- ÁLBUM DO CASARÃO (Fase 5C.2): uma página por cômodo com as 5 relíquias
-- (foto 3D de cada uma; as que faltam aparecem só como silhueta escura,
-- com uma pista em charada), o título de
-- cada cômodo, as páginas das Temporadas (por tempo limitado), a página da
-- Relíquia do Dia, o Diário do Barão (tocar numa página encontrada abre a
-- leitura) e os títulos ganhos. Só visual: tudo vem do perfil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local BaronRoomsConfig = require(ReplicatedStorage.Shared.config.BaronRoomsConfig)
local MysteryConfig = require(ReplicatedStorage.Shared.config.MysteryConfig)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local DiaryPageView = require(script.Parent.DiaryPageView)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type RelicRoom = RelicCatalog.RelicGroup

export type AlbumViewHandle = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	-- `foundToday`: já pegou a Relíquia do Dia de hoje (nil = não se sabe).
	setProfile: (snapshot: ProfileSnapshot, foundToday: boolean?) -> (),
	-- Abre a leitura de uma página do Diário (já encontrada).
	readPage: (relicId: string) -> (),
	destroy: () -> (),
}

type RelicCard = {
	frame: Frame,
	stroke: UIStroke,
	icon: TextLabel,
	photo: ViewportFrame,
	camera: Camera,
	model: Model?,
	shownId: string?,
	name: TextLabel,
	hint: TextLabel,
	-- Toque na carta (só nas páginas do Diário já encontradas).
	read: TextButton,
	relicId: string?,
}

local GUI_NAME = "BlocoPuffAlbum"
-- Deitado (o celular só joga deitado): cômodos à esquerda, página à direita.
local PANEL_SIZE = Vector2.new(840, 450)
local TOP = 64
local TAB_WIDTH = 210
local TAB_HEIGHT = 36
local TAB_GAP = 3
local PAGE_X = 16 + TAB_WIDTH + 16
local PAGE_WIDTH = PANEL_SIZE.X - PAGE_X - 16
local CARD_GAP = 10
local CARD_HEIGHT = 196
local CARDS_Y = 62
local DAILY_PAGE = "Daily"

-- Reserva enquanto as fotos 3D não chegam (só emojis que o Roblox desenha).
local SHAPE_ICONS: { [string]: string } = {
	Puff = "☁️",
	Watch = "⌚",
	GoldCoin = "💰",
	SilverCoin = "🥈",
	Key = "🔑",
	King = "👑",
	Rook = "🏰",
	Bishop = "🎩",
	Teacup = "☕",
	Book = "📕",
	Compass = "🧭",
	Potion = "🧪",
	Pumpkin = "🎃",
	Page = "📜",
}
-- Páginas com pelo menos 5 cartas por linha; temporadas maiores usam duas.
local CARDS_PER_ROW = 5
-- Foto 3D: câmera de frente, um pouco de cima e de lado.
local PHOTO_FOV = 30
local PHOTO_VIEW = Vector3.new(0.55, 0.6, -1).Unit
local SILHOUETTE = Color3.fromRGB(10, 8, 22)
local SMALL_CARD_HEIGHT = 120

local AlbumView = {}

local function label(parent: Instance, name: string, text: string, font: Enum.Font, size: number, color: Color3, position: UDim2, frameSize: UDim2): TextLabel
	local created = UiTheme.createLabel(parent, name, text, font, size, color)
	created.Position = position
	created.Size = frameSize
	created.TextXAlignment = Enum.TextXAlignment.Left
	created.ZIndex = 4
	return created
end

local function ownedSet(snapshot: ProfileSnapshot): { [string]: number }
	local owned: { [string]: number } = {}
	for _, state in ipairs(snapshot.relics) do
		owned[state.id] = state.obtainedAt
	end
	return owned
end

function AlbumView.new(playerGui: PlayerGui, onOpened: () -> ()): AlbumViewHandle
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
	UiTheme.stylePanel(card, { accent = UiTheme.Colors.Gold, radius = 20 })

	local title = label(card, "Title", Lang.t("📜 ÁLBUM DO CASARÃO"), UiTheme.Fonts.Display, 30, UiTheme.Colors.Gold, UDim2.fromOffset(20, 12), UDim2.fromOffset(400, 40))
	UiTheme.addTextOutline(title, 2.5)
	local totalLabel = label(card, "Total", "", UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.InkSoft, UDim2.new(1, -404, 0, 22), UDim2.fromOffset(320, 24))
	totalLabel.TextXAlignment = Enum.TextXAlignment.Right

	local closeButton = UiKit.createButton(card, {
		name = "Close",
		text = "X",
		variant = "Neutral",
		size = UDim2.fromOffset(56, 48),
		position = UDim2.new(1, -14, 0, 10),
		anchorPoint = Vector2.new(1, 0),
		textSize = 24,
		zIndex = 4,
	})

	-- Abas (com rolagem): o Diário, as temporadas, os cômodos e a Relíquia
	-- do Dia.
	local rooms = RelicCatalog.rooms()
	local pages: { RelicRoom } = { RelicCatalog.diary() }
	-- Temporadas (só aparecem depois de começar; encerradas continuam).
	for _, season in ipairs(RelicCatalog.seasons()) do
		table.insert(pages, season)
	end
	for _, room in ipairs(rooms) do
		table.insert(pages, room)
	end
	local tabs: { [string]: UiKit.ButtonHandle } = {}
	local selected = rooms[1].id
	local refresh: () -> () = function() end
	local tabIds: { string } = {}
	for _, page in ipairs(pages) do
		table.insert(tabIds, page.id)
	end
	table.insert(tabIds, DAILY_PAGE)
	local tabList = Instance.new("ScrollingFrame")
	tabList.Name = "Tabs"
	tabList.Position = UDim2.fromOffset(16, TOP)
	tabList.Size = UDim2.fromOffset(TAB_WIDTH + 8, PANEL_SIZE.Y - TOP - 16)
	tabList.BackgroundTransparency = 1
	tabList.BorderSizePixel = 0
	tabList.ScrollBarThickness = 4
	tabList.ScrollingDirection = Enum.ScrollingDirection.Y
	tabList.CanvasSize = UDim2.fromOffset(0, #tabIds * (TAB_HEIGHT + TAB_GAP))
	tabList.ZIndex = 4
	tabList.Parent = card
	for index, id in ipairs(tabIds) do
		local tab = UiKit.createButton(tabList, {
			name = `Tab{id}`,
			text = "",
			variant = "Neutral",
			size = UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT),
			position = UDim2.fromOffset(0, (index - 1) * (TAB_HEIGHT + TAB_GAP)),
			textSize = 15,
			zIndex = 5,
		})
		tab.button.Activated:Connect(function()
			UiKit.playClick()
			selected = id
			refresh()
		end)
		tabs[id] = tab
	end

	-- Página de um cômodo.
	local roomPage = Instance.new("Frame")
	roomPage.Name = "RoomPage"
	roomPage.Position = UDim2.fromOffset(PAGE_X, TOP)
	roomPage.Size = UDim2.fromOffset(PAGE_WIDTH, PANEL_SIZE.Y - TOP - 16)
	roomPage.BackgroundTransparency = 1
	roomPage.ZIndex = 3
	roomPage.Parent = card
	local pageTitle = label(roomPage, "PageTitle", "", UiTheme.Fonts.Display, 24, UiTheme.Colors.Ink, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 28))
	UiTheme.addTextOutline(pageTitle, 1.5)
	local rewardLabel = label(roomPage, "Reward", "", UiTheme.Fonts.BodyBold, 15, UiTheme.Colors.Gold, UDim2.fromOffset(0, 32), UDim2.new(1, 0, 0, 22))
	-- Leitura das páginas do Diário (definida depois do cache do perfil).
	local diaryReader = DiaryPageView.new(playerGui)
	local readPageFor: (relicId: string) -> () = function() end
	local cardWidth = (PAGE_WIDTH - CARD_GAP * (CARDS_PER_ROW - 1)) / CARDS_PER_ROW
	local maxCards = CARDS_PER_ROW
	for _, page in ipairs(pages) do
		maxCards = math.max(maxCards, #page.relics)
	end
	local cards: { RelicCard } = {}
	for index = 1, maxCards do
		local frame = Instance.new("Frame")
		frame.Name = `Relic{index}`
		frame.Size = UDim2.fromOffset(cardWidth, CARD_HEIGHT)
		frame.BackgroundColor3 = UiTheme.Colors.Surface
		frame.ZIndex = 4
		frame.Parent = roomPage
		UiTheme.addCorner(frame, 12)
		local stroke = UiTheme.addStroke(frame, UiTheme.Colors.Border, 1.5)
		local icon = UiTheme.createLabel(frame, "Icon", "❔", UiTheme.Fonts.Display, 44, UiTheme.Colors.Ink)
		icon.Position = UDim2.fromOffset(0, 10)
		icon.Size = UDim2.new(1, 0, 0, 64)
		icon.ZIndex = 5
		local photo = Instance.new("ViewportFrame")
		photo.Name = "Photo"
		photo.BackgroundTransparency = 1
		photo.Ambient = Color3.fromRGB(170, 165, 190)
		photo.LightColor = Color3.fromRGB(255, 245, 230)
		photo.LightDirection = Vector3.new(-0.6, -1, 0.5)
		photo.Visible = false
		photo.ZIndex = 5
		photo.Parent = frame
		local camera = Instance.new("Camera")
		camera.FieldOfView = PHOTO_FOV
		camera.Parent = photo
		photo.CurrentCamera = camera
		local name = UiTheme.createLabel(frame, "Name", "???", UiTheme.Fonts.BodyBold, 15, UiTheme.Colors.Ink)
		name.Position = UDim2.fromOffset(6, 80)
		name.Size = UDim2.new(1, -12, 0, 52)
		name.TextScaled = true
		name.ZIndex = 5
		UiTheme.addTextConstraint(name, 10, 15)
		local hint = UiTheme.createLabel(frame, "Hint", "", UiTheme.Fonts.Body, 13, UiTheme.Colors.InkSoft)
		hint.Position = UDim2.fromOffset(6, 136)
		hint.Size = UDim2.new(1, -12, 0, 52)
		hint.TextScaled = true
		hint.ZIndex = 5
		UiTheme.addTextConstraint(hint, 9, 13)
		local read = Instance.new("TextButton")
		read.Name = "Read"
		read.Size = UDim2.fromScale(1, 1)
		read.BackgroundTransparency = 1
		read.Text = ""
		read.Visible = false
		read.ZIndex = 6
		read.Parent = frame
		local cardItem: RelicCard = { frame = frame, stroke = stroke, icon = icon, photo = photo, camera = camera, model = nil, shownId = nil, name = name, hint = hint, read = read, relicId = nil }
		read.Activated:Connect(function()
			local relicId = cardItem.relicId
			if relicId ~= nil then
				UiKit.playClick()
				readPageFor(relicId)
			end
		end)
		table.insert(cards, cardItem)
	end
	-- Até 5 relíquias: uma fileira de cartas altas; mais (temporadas): duas
	-- fileiras de cartas baixas.
	local function layoutCards(count: number)
		local small = count > CARDS_PER_ROW
		local height = if small then SMALL_CARD_HEIGHT else CARD_HEIGHT
		for index, cardItem in ipairs(cards) do
			local row = math.floor((index - 1) / CARDS_PER_ROW)
			local column = (index - 1) % CARDS_PER_ROW
			cardItem.frame.Position = UDim2.fromOffset(column * (cardWidth + CARD_GAP), CARDS_Y + row * (height + CARD_GAP))
			cardItem.frame.Size = UDim2.fromOffset(cardWidth, height)
			cardItem.icon.Position = UDim2.fromOffset(0, if small then 4 else 10)
			cardItem.icon.Size = UDim2.new(1, 0, 0, if small then 36 else 64)
			cardItem.icon.TextSize = if small then 30 else 44
			cardItem.photo.Position = cardItem.icon.Position
			cardItem.photo.Size = cardItem.icon.Size
			cardItem.name.Position = UDim2.fromOffset(6, if small then 40 else 80)
			cardItem.name.Size = UDim2.new(1, -12, 0, if small then 34 else 52)
			cardItem.hint.Position = UDim2.fromOffset(6, if small then 76 else 136)
			cardItem.hint.Size = UDim2.new(1, -12, 0, if small then 40 else 52)
		end
	end
	local titlesLabel = label(roomPage, "Titles", "", UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.Ink, UDim2.fromOffset(0, CARDS_Y + CARD_HEIGHT + 14), UDim2.new(1, 0, 0, 44))
	titlesLabel.TextWrapped = true
	titlesLabel.TextYAlignment = Enum.TextYAlignment.Top
	local prizeLabel = label(roomPage, "Prize", "", UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.InkSoft, UDim2.fromOffset(0, CARDS_Y + CARD_HEIGHT + 62), UDim2.new(1, 0, 0, 40))
	prizeLabel.TextWrapped = true
	prizeLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- Página da Relíquia do Dia.
	local dailyPage = Instance.new("Frame")
	dailyPage.Name = "DailyPage"
	dailyPage.Position = roomPage.Position
	dailyPage.Size = roomPage.Size
	dailyPage.BackgroundTransparency = 1
	dailyPage.ZIndex = 3
	dailyPage.Visible = false
	dailyPage.Parent = card
	local dailyTitle = label(dailyPage, "Title", Lang.t("🌟 RELÍQUIA DO DIA"), UiTheme.Fonts.Display, 24, UiTheme.Colors.Ink, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 28))
	UiTheme.addTextOutline(dailyTitle, 1.5)
	local dailyAbout = label(
		dailyPage,
		"About",
		Lang.t("Todo dia uma relíquia especial aparece num lugar diferente do Casarão. Ache e pegue!"),
		UiTheme.Fonts.Body,
		15,
		UiTheme.Colors.InkSoft,
		UDim2.fromOffset(0, 34),
		UDim2.new(1, 0, 0, 44)
	)
	dailyAbout.TextWrapped = true
	dailyAbout.TextYAlignment = Enum.TextYAlignment.Top
	local todayLabel = label(dailyPage, "Today", "", UiTheme.Fonts.Display, 20, UiTheme.Colors.Gold, UDim2.fromOffset(0, 92), UDim2.new(1, 0, 0, 28))
	local countLabel = label(dailyPage, "Count", "", UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.Ink, UDim2.fromOffset(0, 136), UDim2.new(1, 0, 0, 22))
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, 164)
	track.Size = UDim2.new(1, 0, 0, 16)
	track.BackgroundColor3 = UiTheme.Colors.Track
	track.ZIndex = 4
	track.Parent = dailyPage
	UiTheme.addCorner(track, 999)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UiTheme.Colors.White
	fill.ZIndex = 5
	fill.Parent = track
	UiTheme.addCorner(fill, 999)
	UiTheme.addGradient(fill, UiTheme.Colors.Gold, UiTheme.Colors.Orange, 0)
	local rewards = RelicCatalog.Rewards
	local dailyReward = label(
		dailyPage,
		"Reward",
		Lang.t("+%d 🎟 por relíquia · ao juntar %d: título %s e +%d 🎟", rewards.DailyTickets, rewards.DailyGoal, Lang.t(RelicCatalog.DailyTitle), rewards.DailyGoalTickets),
		UiTheme.Fonts.BodyBold,
		15,
		UiTheme.Colors.Gold,
		UDim2.fromOffset(0, 194),
		UDim2.new(1, 0, 0, 44)
	)
	dailyReward.TextWrapped = true
	dailyReward.TextYAlignment = Enum.TextYAlignment.Top

	local snapshotCache: ProfileSnapshot? = nil

	readPageFor = function(relicId: string)
		local snapshot = snapshotCache
		if snapshot == nil then
			return
		end
		local owned = ownedSet(snapshot)
		if owned[relicId] ~= nil then
			diaryReader.show(relicId, owned)
		end
	end
	local foundTodayCache: boolean? = nil

	local function roomTabText(room: RelicRoom, count: number): string
		local mark = if count >= #room.relics then " ✓" else ""
		return string.format("%s %s  %d/%d%s", room.emoji, Lang.t(room.name), count, #room.relics, mark)
	end

	-- Linha do prêmio da página (cômodo ou temporada).
	local function rewardText(room: RelicRoom, complete: boolean): string
		if complete then
			return Lang.t("🏅 Título ganho: %s", Lang.t(room.title))
		elseif room.diary then
			return Lang.t("📖 Ache as %d páginas: título %s e +%d 🎟", #room.relics, Lang.t(room.title), room.tickets)
		elseif not room.season then
			return Lang.t("🔒 Complete o cômodo: título %s e +%d 🎟", Lang.t(room.title), room.tickets)
		elseif RelicCatalog.isActive(room, os.time()) then
			local dateFormat = if Lang.current() == "en" then "!%b %d" else "!%d/%m"
			return Lang.t("⏳ Só até %s · complete: título %s e +%d 🎟", os.date(dateFormat, room.endsAt - 1), Lang.t(room.title), room.tickets)
		end
		return Lang.t("⏳ Temporada encerrada · fique de olho nas próximas!")
	end

	-- Foto 3D da relíquia (cópia da miniatura que o servidor publica). Falso
	-- enquanto as miniaturas não chegaram (fica o emoji).
	local function setPhoto(cardItem: RelicCard, relicId: string): boolean
		if cardItem.shownId == relicId then
			return true
		end
		local icons = ReplicatedStorage:FindFirstChild(RelicCatalog.IconsFolder)
		local source = if icons ~= nil then icons:FindFirstChild(relicId) else nil
		if source == nil or not source:IsA("Model") then
			return false
		end
		local previous = cardItem.model
		if previous ~= nil then
			previous:Destroy()
		end
		local model = source:Clone()
		model.Parent = cardItem.photo
		cardItem.model = model
		cardItem.shownId = relicId
		local center, size = model:GetBoundingBox()
		local radius = math.max(size.Magnitude / 2, 0.1)
		local distance = radius / math.sin(math.rad(PHOTO_FOV / 2))
		cardItem.camera.CFrame = CFrame.lookAt(center.Position + PHOTO_VIEW * distance, center.Position)
		return true
	end

	local function showRoom(room: RelicRoom, owned: { [string]: number })
		local count = RelicCatalog.groupCount(owned, room.id)
		local complete = count >= #room.relics
		pageTitle.Text = string.format("%s %s  ·  %d/%d", room.emoji, Lang.t(room.name), count, #room.relics)
		rewardLabel.Text = rewardText(room, complete)
		rewardLabel.TextColor3 = if complete then UiTheme.Colors.Gold else UiTheme.Colors.InkSoft
		layoutCards(#room.relics)
		local tall = #room.relics <= CARDS_PER_ROW
		titlesLabel.Position = UDim2.fromOffset(0, CARDS_Y + (if tall then CARD_HEIGHT else SMALL_CARD_HEIGHT * 2 + CARD_GAP) + 14)
		prizeLabel.Visible = tall
		for index, cardItem in ipairs(cards) do
			local definition = room.relics[index]
			cardItem.frame.Visible = definition ~= nil
			if definition ~= nil then
				local has = owned[definition.id] ~= nil
				local photo = setPhoto(cardItem, definition.id)
				cardItem.photo.Visible = photo
				-- Faltando: só a silhueta (dá vontade de achar sem mostrar a cor).
				cardItem.photo.ImageColor3 = if has then UiTheme.Colors.White else SILHOUETTE
				cardItem.photo.ImageTransparency = if has then 0 else 0.2
				cardItem.icon.Visible = not photo
				cardItem.icon.Text = if has then SHAPE_ICONS[definition.shape] or "📜" else "❔"
				cardItem.icon.TextTransparency = if has then 0 else 0.35
				local readable = has and room.diary
				cardItem.relicId = if readable then definition.id else nil
				cardItem.read.Visible = readable
				cardItem.name.Text = if has then Lang.t(definition.name) else "???"
				cardItem.name.TextColor3 = if has then UiTheme.Colors.Gold else UiTheme.Colors.InkSoft
				cardItem.hint.Text = if readable
					then Lang.t("📖 Toque para ler")
					elseif has then Lang.t("Encontrada!")
					else Lang.t(definition.hint)
				cardItem.stroke.Color = if has then UiTheme.Colors.Gold else UiTheme.Colors.Border
				cardItem.frame.BackgroundColor3 = if has then UiTheme.Colors.SurfaceSoft else UiTheme.Colors.Surface
			end
		end
	end

	local function showDaily(snapshot: ProfileSnapshot, foundToday: boolean?)
		local count = snapshot.dailyRelicCount
		todayLabel.Text = if foundToday == true then Lang.t("✓ A de hoje já é sua!") else Lang.t("Hoje: procure pelo Casarão!")
		todayLabel.TextColor3 = if foundToday == true then UiTheme.Colors.Green else UiTheme.Colors.Gold
		countLabel.Text = Lang.t("Relíquias do Dia: %d de %d", math.min(count, rewards.DailyGoal), rewards.DailyGoal)
		local ratio = math.clamp(count / math.max(1, rewards.DailyGoal), 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
	end

	refresh = function()
		local snapshot = snapshotCache
		if snapshot == nil then
			return
		end
		local owned = ownedSet(snapshot)
		local total = 0
		for _, id in ipairs(RelicCatalog.allIds()) do
			if owned[id] ~= nil then
				total += 1
			end
		end
		totalLabel.Text = Lang.t("%d/%d relíquias", total, #RelicCatalog.allIds())
		local now = os.time()
		local row = 0
		for _, id in ipairs(tabIds) do
			local page = RelicCatalog.group(id)
			local tab = tabs[id]
			local visible = page == nil or not page.season or now >= page.startsAt
			tab.root.Visible = visible
			if visible then
				tab.root.Position = UDim2.fromOffset(0, row * (TAB_HEIGHT + TAB_GAP))
				row += 1
			end
			if page ~= nil then
				tab.setText(roomTabText(page, RelicCatalog.groupCount(owned, page.id)))
				tab.setSelected(selected == page.id)
			end
		end
		tabList.CanvasSize = UDim2.fromOffset(0, row * (TAB_HEIGHT + TAB_GAP))
		local dailyTab = tabs[DAILY_PAGE]
		dailyTab.setText(Lang.t("🌟 Relíquia do Dia  %d/%d", math.min(snapshot.dailyRelicCount, rewards.DailyGoal), rewards.DailyGoal))
		dailyTab.setSelected(selected == DAILY_PAGE)

		local room = RelicCatalog.group(selected)
		roomPage.Visible = room ~= nil
		dailyPage.Visible = room == nil
		if room ~= nil then
			showRoom(room, owned)
		else
			showDaily(snapshot, foundTodayCache)
		end

		local titles = RelicCatalog.titlesFor(owned, snapshot.dailyRelicCount)
		if MysteryConfig.allSolved(snapshot.mysteries) then
			table.insert(titles, MysteryConfig.AllTitle)
		end
		for _, title in ipairs(BaronRoomsConfig.titlesFor(snapshot.baronRooms)) do
			table.insert(titles, title)
		end
		local translated: { string } = {}
		for _, text in ipairs(titles) do
			table.insert(translated, Lang.t(text))
		end
		titlesLabel.Text = if #translated > 0
			then Lang.t("🏅 Seus títulos: %s", table.concat(translated, ", "))
			else Lang.t("🏅 Complete um cômodo para ganhar seu primeiro título.")
		local puff = PuffCatalog.get(RelicCatalog.AlbumPuffId)
		local puffName = if puff ~= nil then Lang.t(puff.name) else ""
		prizeLabel.Text = if total >= #RelicCatalog.allIds()
			then Lang.t("📖 Álbum completo! Você ganhou o %s.", puffName)
			else Lang.t("📖 Complete as %d relíquias: %s e o título %s.", #RelicCatalog.allIds(), puffName, Lang.t(RelicCatalog.AlbumTitle))
	end

	-- Miniaturas ainda não chegaram (o servidor publica depois de carregar
	-- as malhas): quando chegarem, troca os emojis pelas fotos.
	local iconsConnection: RBXScriptConnection? = nil
	if ReplicatedStorage:FindFirstChild(RelicCatalog.IconsFolder) == nil then
		iconsConnection = ReplicatedStorage.ChildAdded:Connect(function(child: Instance)
			if child.Name ~= RelicCatalog.IconsFolder then
				return
			end
			local connection = iconsConnection
			if connection ~= nil then
				connection:Disconnect()
				iconsConnection = nil
			end
			if screenGui.Enabled then
				refresh()
			end
		end)
	end

	local handle = {} :: AlbumViewHandle

	handle.readPage = function(relicId: string)
		readPageFor(relicId)
	end

	handle.setProfile = function(snapshot: ProfileSnapshot, foundToday: boolean?)
		snapshotCache = snapshot
		foundTodayCache = foundToday
		refresh()
	end

	handle.open = function()
		screenGui.Enabled = true
		responsive.pop(0.9, 0.25)
		refresh()
		onOpened()
	end

	handle.close = function()
		diaryReader.close()
		screenGui.Enabled = false
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.destroy = function()
		diaryReader.destroy()
		local connection = iconsConnection
		if connection ~= nil then
			connection:Disconnect()
			iconsConnection = nil
		end
		responsive.destroy()
		screenGui:Destroy()
	end

	closeButton.button.Activated:Connect(function()
		UiKit.playClick()
		handle.close()
	end)

	return handle
end

return table.freeze(AlbumView)
