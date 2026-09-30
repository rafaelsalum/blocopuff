--!strict

-- Painel PUFFDEX (Fase 4.1): grade com todos os Puffs da coleção (os
-- bloqueados aparecem como "?" com a raridade e a dica de como conseguir),
-- detalhe do Puff escolhido com a prévia animada do efeito (PuffPreview),
-- a história e o botão EQUIPAR. Os cartões ganham acabamento por raridade e
-- comemoram quando um Puff novo chega (PuffCardFx). Só visual: equipar é um
-- pedido ao servidor, que confere se o jogador tem.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)
local PuffEffects = require(ReplicatedStorage.Shared.modules.PuffEffects)
local PuffCardFx = require(script.Parent.PuffCardFx)
local PuffPreview = require(script.Parent.PuffPreview)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type PuffDefinition = PuffTypes.PuffDefinition
type OwnedPuff = PuffTypes.OwnedPuff
type PuffOrigin = PuffTypes.PuffOrigin

export type PuffdexViewHandle = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setProfile: (snapshot: ProfileSnapshot) -> (),
	-- Marca Puffs como novos (etiqueta "NOVO" até o jogador vê-los).
	markNew: (ids: { string }) -> (),
	destroy: () -> (),
}

type Card = {
	button: TextButton,
	orb: Frame,
	orbGradient: UIGradient,
	mark: TextLabel,
	name: TextLabel,
	stroke: UIStroke,
	equipped: TextLabel,
	newTag: TextLabel,
	effectIcon: TextLabel,
	fx: PuffCardFx.CardFxHandle,
}

local GUI_NAME = "BlocoPuffPuffdex"
local PANEL_SIZE = Vector2.new(620, 440)
local DETAIL_WIDTH = 210
local CARD_SIZE = Vector2.new(86, 96)
local LOCKED_COLOR = Color3.fromRGB(40, 32, 66)
local UNLOCK_SOUND = "rbxasset://sounds/electronicpingshort.wav"
-- Intervalo entre as comemorações quando chegam vários Puffs novos.
local CELEBRATE_STAGGER = 0.25
local CARD_FX_INTERVAL = 1 / 30

local ORIGIN_LABELS: { [PuffOrigin]: string } = {
	Starter = "Inicial",
	Level = "Nível",
	Feat = "Façanha",
	Machine = "Puff Machine",
}

local PuffdexView = {}

local function formatDate(timestamp: number): string
	if timestamp <= 0 then
		return ""
	end
	local date = os.date("*t", timestamp) :: any
	return string.format("%02d/%02d/%d", date.day, date.month, date.year)
end

local function paintOrb(gradient: UIGradient, definition: PuffDefinition, owned: boolean)
	if owned then
		gradient.Color = ColorSequence.new(definition.style.trailStart, definition.style.trailEnd)
	else
		gradient.Color = ColorSequence.new(LOCKED_COLOR, LOCKED_COLOR)
	end
end

local function createOrb(parent: Instance, size: number, zIndex: number): (Frame, UIGradient)
	local orb = Instance.new("Frame")
	orb.Name = "Orb"
	orb.AnchorPoint = Vector2.new(0.5, 0)
	orb.Size = UDim2.fromOffset(size, size)
	orb.BackgroundColor3 = UiTheme.Colors.White
	orb.ZIndex = zIndex
	orb.Parent = parent
	UiTheme.addCorner(orb, 999)
	UiTheme.addStroke(orb, UiTheme.Colors.Outline, 2.5)
	local gradient = UiTheme.addGradient(orb, LOCKED_COLOR, LOCKED_COLOR, 45)
	return orb, gradient
end

function PuffdexView.new(playerGui: PlayerGui, onEquip: (id: string) -> (), onOpened: () -> ()): PuffdexViewHandle
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
	UiTheme.stylePanel(card, { accent = UiTheme.Colors.Brand, radius = 20 })

	local title = UiTheme.createLabel(card, "Title", "✨ PUFFDEX", UiTheme.Fonts.Display, 28, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(0, 220, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	UiTheme.addTextOutline(title, 2.5)

	local progressLabel = UiTheme.createLabel(card, "Progress", "0 / 0", UiTheme.Fonts.Display, 18, UiTheme.Colors.Ink)
	progressLabel.AnchorPoint = Vector2.new(1, 0)
	progressLabel.Position = UDim2.new(1, -68, 0, 18)
	progressLabel.Size = UDim2.fromOffset(160, 26)
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	progressLabel.ZIndex = 3
	UiTheme.addTextOutline(progressLabel, 1.5)

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

	-- Grade (esquerda).
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(16, 58)
	grid.Size = UDim2.new(1, -(DETAIL_WIDTH + 40), 1, -96)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = UiTheme.Colors.Border
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ZIndex = 3
	grid.Parent = card
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	UiTheme.addPadding(grid, 4, 4)

	-- Detalhe (direita).
	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(1, 0)
	detail.Position = UDim2.new(1, -16, 0, 58)
	detail.Size = UDim2.new(0, DETAIL_WIDTH, 1, -96)
	detail.BackgroundColor3 = UiTheme.Colors.Outline
	detail.BackgroundTransparency = 0.35
	detail.ZIndex = 3
	detail.Parent = card
	UiTheme.addCorner(detail, 14)

	local previewHolder = Instance.new("Frame")
	previewHolder.Name = "PreviewHolder"
	previewHolder.AnchorPoint = Vector2.new(0.5, 0)
	previewHolder.Position = UDim2.new(0.5, 0, 0, 10)
	previewHolder.Size = UDim2.new(1, -20, 0, 90)
	previewHolder.BackgroundTransparency = 1
	previewHolder.ZIndex = 4
	previewHolder.Parent = detail
	local preview = PuffPreview.new(previewHolder, 4)

	local detailName = UiTheme.createLabel(detail, "Name", "", UiTheme.Fonts.Display, 20, UiTheme.Colors.Ink)
	detailName.Position = UDim2.fromOffset(10, 104)
	detailName.Size = UDim2.new(1, -20, 0, 26)
	detailName.TextScaled = true
	detailName.ZIndex = 4
	UiTheme.addTextConstraint(detailName, 12, 20)
	UiTheme.addTextOutline(detailName, 1.5)

	local detailRarity = UiTheme.createLabel(detail, "Rarity", "", UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.Ink)
	detailRarity.Position = UDim2.fromOffset(10, 131)
	detailRarity.Size = UDim2.new(1, -20, 0, 17)
	detailRarity.TextScaled = true
	detailRarity.ZIndex = 4
	UiTheme.addTextConstraint(detailRarity, 10, 13)

	local detailLore = UiTheme.createLabel(detail, "Lore", "", UiTheme.Fonts.Body, 12, UiTheme.Colors.Ink)
	detailLore.Position = UDim2.fromOffset(12, 148)
	detailLore.Size = UDim2.new(1, -24, 0, 32)
	detailLore.TextWrapped = true
	detailLore.TextScaled = true
	detailLore.ZIndex = 4
	UiTheme.addTextConstraint(detailLore, 9, 12)

	local detailInfo = UiTheme.createLabel(detail, "Info", "", UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft)
	detailInfo.Position = UDim2.fromOffset(12, 184)
	detailInfo.Size = UDim2.new(1, -24, 0, 46)
	detailInfo.TextTruncate = Enum.TextTruncate.AtEnd
	detailInfo.TextYAlignment = Enum.TextYAlignment.Top
	detailInfo.ZIndex = 4

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "UnlockTrack"
	progressTrack.Position = UDim2.fromOffset(16, 234)
	progressTrack.Size = UDim2.new(1, -32, 0, 10)
	progressTrack.BackgroundColor3 = UiTheme.Colors.Track
	progressTrack.ZIndex = 4
	progressTrack.Parent = detail
	UiTheme.addCorner(progressTrack, 999)
	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = UiTheme.Colors.White
	progressFill.ZIndex = 5
	progressFill.Parent = progressTrack
	UiTheme.addCorner(progressFill, 999)
	UiTheme.addGradient(progressFill, UiTheme.Colors.Gold, UiTheme.Colors.Brand, 0)

	local equipButton = UiKit.createButton(detail, {
		name = "Equip",
		text = "EQUIPAR",
		variant = "Success",
		size = UDim2.new(1, -24, 0, 38),
		position = UDim2.new(0.5, 0, 1, -12),
		anchorPoint = Vector2.new(0.5, 1),
		textSize = 16,
		zIndex = 5,
	})

	local footer = UiTheme.createLabel(card, "Footer", "Puffs só mudam o visual do disparo. Não dão vantagem.", UiTheme.Fonts.Body, 12, UiTheme.Colors.InkSoft)
	footer.Position = UDim2.new(0, 20, 1, -32)
	footer.Size = UDim2.new(1, -40, 0, 20)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.ZIndex = 3

	local owned: { [string]: OwnedPuff } = {}
	local equippedId = PuffCatalog.DefaultId
	local stats: { [string]: number } = {}
	local level = 1
	local selectedId = PuffCatalog.DefaultId
	local newIds: { [string]: boolean } = {}
	local cards: { [string]: Card } = {}
	local renderDetail: () -> () = function() end
	local renderCards: () -> () = function() end

	for index, definition in ipairs(PuffCatalog.all()) do
		local rarityInfo = PuffCatalog.rarity(definition.rarity)
		local button = Instance.new("TextButton")
		button.Name = definition.id
		button.LayoutOrder = index
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = UiTheme.Colors.Surface
		button.ZIndex = 4
		button.Parent = grid
		UiTheme.addCorner(button, 12)
		local stroke = UiTheme.addStroke(button, rarityInfo.color, 2)

		local orb, orbGradient = createOrb(button, 44, 5)
		orb.Position = UDim2.new(0.5, 0, 0, 8)
		local mark = UiTheme.createLabel(orb, "Mark", "?", UiTheme.Fonts.Display, 24, UiTheme.Colors.InkSoft)
		mark.Size = UDim2.fromScale(1, 1)
		mark.ZIndex = 6

		local name = UiTheme.createLabel(button, "Name", "", UiTheme.Fonts.BodyBold, 11, UiTheme.Colors.Ink)
		name.Position = UDim2.fromOffset(4, 56)
		name.Size = UDim2.new(1, -8, 0, 34)
		name.TextScaled = true
		name.ZIndex = 5
		UiTheme.addTextConstraint(name, 8, 11)

		local equipped = UiTheme.createLabel(button, "Equipped", "✓", UiTheme.Fonts.Display, 14, UiTheme.Colors.Outline)
		equipped.Position = UDim2.fromOffset(4, 4)
		equipped.Size = UDim2.fromOffset(20, 20)
		equipped.BackgroundTransparency = 0
		equipped.BackgroundColor3 = UiTheme.Colors.Green
		equipped.ZIndex = 7
		equipped.Visible = false
		UiTheme.addCorner(equipped, 999)

		local newTag = UiTheme.createLabel(button, "New", "NOVO", UiTheme.Fonts.Display, 10, UiTheme.Colors.Outline)
		newTag.AnchorPoint = Vector2.new(1, 0)
		newTag.Position = UDim2.new(1, -4, 0, 4)
		newTag.Size = UDim2.fromOffset(36, 16)
		newTag.BackgroundTransparency = 0
		newTag.BackgroundColor3 = UiTheme.Colors.Gold
		newTag.ZIndex = 7
		newTag.Visible = false
		UiTheme.addCorner(newTag, 6)

		local effectIcon = UiTheme.createLabel(button, "Effect", PuffEffects.info(definition.style.effect).icon, UiTheme.Fonts.Display, 14, UiTheme.Colors.Ink)
		effectIcon.AnchorPoint = Vector2.new(0.5, 0)
		effectIcon.Position = UDim2.new(0.5, 20, 0, 34)
		effectIcon.Size = UDim2.fromOffset(20, 20)
		effectIcon.ZIndex = 7
		effectIcon.Visible = false

		local fx = PuffCardFx.decorate(button, stroke, definition.rarity, rarityInfo.color, 6)

		button.Activated:Connect(function()
			UiKit.playClick()
			selectedId = definition.id
			newIds[definition.id] = nil
			renderCards()
			renderDetail()
		end)

		cards[definition.id] = {
			button = button,
			orb = orb,
			orbGradient = orbGradient,
			mark = mark,
			name = name,
			stroke = stroke,
			equipped = equipped,
			newTag = newTag,
			effectIcon = effectIcon,
			fx = fx,
		}
	end

	renderCards = function()
		local count = 0
		for _, definition in ipairs(PuffCatalog.all()) do
			local item = cards[definition.id]
			local has = owned[definition.id] ~= nil
			if has then
				count += 1
			end
			paintOrb(item.orbGradient, definition, has)
			item.mark.Visible = not has
			item.name.Text = if has then definition.name else "???"
			item.equipped.Visible = has and definition.id == equippedId
			item.newTag.Visible = has and newIds[definition.id] == true
			item.effectIcon.Visible = has
			item.fx.setOwned(has)
			item.stroke.Thickness = if definition.id == selectedId then 3.5 else 2
			item.button.BackgroundColor3 = if definition.id == selectedId then UiTheme.Colors.SurfaceSoft else UiTheme.Colors.Surface
		end
		progressLabel.Text = string.format("%d / %d", count, #PuffCatalog.all())
	end

	renderDetail = function()
		local definition = PuffCatalog.get(selectedId)
		if definition == nil then
			return
		end
		local rarityInfo = PuffCatalog.rarity(definition.rarity)
		local ownedPuff = owned[definition.id]
		local has = ownedPuff ~= nil
		preview.setPuff(definition, has)
		detailName.Text = if has then definition.name else "???"
		local effectInfo = PuffEffects.info(definition.style.effect)
		detailRarity.Text = if has then `{rarityInfo.label} · {effectInfo.icon} {effectInfo.label}` else rarityInfo.label
		detailLore.Text = if has then `“{definition.lore}”` else "Um Puff misterioso…"
		detailRarity.TextColor3 = rarityInfo.color

		local current, target = PuffCatalog.progress(definition, stats, level)
		local showProgress = not has and current ~= nil and target ~= nil
		progressTrack.Visible = showProgress
		if showProgress and current ~= nil and target ~= nil then
			TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.fromScale(math.clamp(current / math.max(1, target), 0, 1), 1),
			}):Play()
		end
		if ownedPuff ~= nil then
			local origin = ORIGIN_LABELS[ownedPuff.origin] or ""
			local date = formatDate(ownedPuff.obtainedAt)
			detailInfo.Text = if date ~= "" then `{origin} · desde {date}` else origin
		elseif definition.unlock.kind == "Machine" then
			detailInfo.Text = "Sai na Puff Machine"
		elseif current ~= nil and target ~= nil then
			detailInfo.Text = `{definition.hint}\n{current} / {target}`
		else
			detailInfo.Text = definition.hint
		end

		if not has then
			equipButton.setText("BLOQUEADO")
			equipButton.setEnabled(false)
		elseif definition.id == equippedId then
			equipButton.setText("EQUIPADO")
			equipButton.setEnabled(false)
		else
			equipButton.setText("EQUIPAR")
			equipButton.setEnabled(true)
		end
	end

	equipButton.button.Activated:Connect(function()
		local definition = PuffCatalog.get(selectedId)
		if definition == nil or owned[definition.id] == nil or definition.id == equippedId then
			return
		end
		UiKit.playClick(1.2)
		onEquip(definition.id)
	end)

	-- Animações (prévia e cartões) só com o painel aberto.
	local animation: RBXScriptConnection? = nil
	local function startAnimation()
		if animation ~= nil then
			return
		end
		local cardClock = 0
		animation = RunService.RenderStepped:Connect(function(deltaTime: number)
			preview.step(deltaTime)
			-- Bordas e reflexos dos cartões a ~30 quadros por segundo bastam.
			cardClock += deltaTime
			if cardClock < CARD_FX_INTERVAL then
				return
			end
			for _, item in pairs(cards) do
				item.fx.step(cardClock)
			end
			cardClock = 0
		end)
	end
	local function stopAnimation()
		local connection = animation
		if connection ~= nil then
			connection:Disconnect()
			animation = nil
		end
	end

	local function playUnlockSound(pitch: number)
		local sound = Instance.new("Sound")
		sound.SoundId = UNLOCK_SOUND
		sound.PlaybackSpeed = pitch
		sound.Volume = 0.6
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, 3)
		sound:Play()
	end

	-- Puffs novos comemoram ao abrir o painel (um de cada vez).
	-- Só marca como comemorado quando a comemoração acontece de fato (se o
	-- painel fechar antes, fica para a próxima abertura).
	local celebrated: { [string]: boolean } = {}
	local scheduled: { [string]: boolean } = {}
	local nextSlot = 0
	local function celebrateNew()
		for _, definition in ipairs(PuffCatalog.all()) do
			local id = definition.id
			local item = cards[id]
			if newIds[id] and not celebrated[id] and not scheduled[id] and owned[id] ~= nil and item ~= nil then
				scheduled[id] = true
				local now = os.clock()
				local slot = math.max(now + 0.2, nextSlot)
				nextSlot = slot + CELEBRATE_STAGGER
				task.delay(slot - now, function()
					scheduled[id] = nil
					if screenGui.Enabled and screenGui.Parent ~= nil then
						celebrated[id] = true
						item.fx.celebrate()
						playUnlockSound(1.2 + (PuffCatalog.rarity(definition.rarity).order * 0.1))
					end
				end)
			end
		end
	end

	local handle = {} :: PuffdexViewHandle

	handle.open = function()
		renderCards()
		renderDetail()
		screenGui.Enabled = true
		startAnimation()
		celebrateNew()
		pop.Scale = 0.9
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onOpened()
	end

	handle.close = function()
		screenGui.Enabled = false
		stopAnimation()
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.setProfile = function(snapshot: ProfileSnapshot)
		local nextOwned: { [string]: OwnedPuff } = {}
		for _, item in ipairs(snapshot.puffs) do
			nextOwned[item.id] = item
		end
		owned = nextOwned
		local previousEquipped = equippedId
		equippedId = snapshot.equippedPuff
		stats = snapshot.stats :: any
		level = snapshot.level
		if previousEquipped ~= equippedId and cards[equippedId] ~= nil then
			UiKit.pop(cards[equippedId].orb, 0.25)
		end
		if screenGui.Enabled then
			renderCards()
			renderDetail()
			celebrateNew()
		end
	end

	handle.markNew = function(ids: { string })
		for _, id in ipairs(ids) do
			newIds[id] = true
		end
		if #ids > 0 then
			selectedId = ids[1]
		end
		if screenGui.Enabled then
			renderCards()
			renderDetail()
			celebrateNew()
		end
	end

	handle.destroy = function()
		stopAnimation()
		preview.destroy()
		responsive.destroy()
		screenGui:Destroy()
	end

	closeButton.button.Activated:Connect(function()
		UiKit.playClick()
		handle.close()
	end)

	return handle
end

return table.freeze(PuffdexView)
