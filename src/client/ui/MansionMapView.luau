--!strict

-- MAPA DO CASARÃO (Fase 5C.4): a planta vista de cima, um andar por vez
-- (Térreo, Sótão, Porão). Os cômodos já visitados aparecem com cor, ícone e
-- nome; os que faltam ficam escuros com "?"; as Salas Secretas só aparecem
-- depois de visitadas. Mostra o "% explorado", você (ponto dourado) e os
-- amigos da Party (pontos azuis). Só visual: tudo vem do perfil e das
-- posições que o cliente já vê.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local MansionMapConfig = require(ReplicatedStorage.Shared.config.MansionMapConfig)
local MansionMapLayout = require(ReplicatedStorage.Shared.modules.MansionMapLayout)
local MansionMapRules = require(ReplicatedStorage.Shared.modules.MansionMapRules)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type MapFloor = MansionMapConfig.MapFloor
type MapRect = MansionMapLayout.MapRect

export type MapDot = {
	position: Vector3,
	isSelf: boolean,
}

export type MansionMapViewHandle = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setVisited: (rooms: { string }) -> (),
	-- Você e a Party (posições no mundo), redesenhados a cada chamada.
	setDots: (dots: { MapDot }) -> (),
	destroy: () -> (),
}

type Tile = {
	rect: MapRect,
	frame: Frame,
	stroke: UIStroke,
	label: TextLabel,
}

local GUI_NAME = "BlocoPuffMansionMap"
local PANEL_SIZE = Vector2.new(840, 450)
local TOP = 64
local TAB_WIDTH = 170
local TAB_HEIGHT = 44
local TAB_GAP = 8
local MAP_X = 16 + TAB_WIDTH + 16
local MAP_SIZE = Vector2.new(PANEL_SIZE.X - MAP_X - 16, PANEL_SIZE.Y - TOP - 16)
-- Margem (px) em volta da planta e entre os cômodos.
local MAP_MARGIN = 14
local TILE_GAP = 2
local DOT_SIZE = 12
local VISITED_COLOR = Color3.fromRGB(96, 74, 150)
local HIDDEN_COLOR = Color3.fromRGB(30, 24, 52)

local MansionMapView = {}

local function roomInfo(id: string): MansionMapConfig.MapRoom?
	for _, room in ipairs(MansionMapConfig.Rooms) do
		if room.id == id then
			return room
		end
	end
	return nil
end

function MansionMapView.new(playerGui: PlayerGui, onOpened: () -> ()): MansionMapViewHandle
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

	local title = UiTheme.createLabel(card, "Title", Lang.t("🗺️ MAPA DO CASARÃO"), UiTheme.Fonts.Display, 32, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(0, 420, 0, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	UiTheme.addTextOutline(title, 2.5)

	local progress = UiTheme.createLabel(card, "Progress", "", UiTheme.Fonts.BodyBold, 18, UiTheme.Colors.Ink)
	progress.AnchorPoint = Vector2.new(1, 0)
	progress.Position = UDim2.new(1, -84, 0, 20)
	progress.Size = UDim2.fromOffset(300, 26)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	progress.ZIndex = 3

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

	local legend = UiTheme.createLabel(card, "Legend", Lang.t("🟡 Você   🔵 Party"), UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.InkSoft)
	legend.Position = UDim2.fromOffset(16, PANEL_SIZE.Y - 44)
	legend.Size = UDim2.fromOffset(TAB_WIDTH, 28)
	legend.TextXAlignment = Enum.TextXAlignment.Left
	legend.ZIndex = 3

	local mapArea = Instance.new("Frame")
	mapArea.Name = "Map"
	mapArea.Position = UDim2.fromOffset(MAP_X, TOP)
	mapArea.Size = UDim2.fromOffset(MAP_SIZE.X, MAP_SIZE.Y)
	mapArea.BackgroundColor3 = UiTheme.Colors.Outline
	mapArea.BackgroundTransparency = 0.3
	mapArea.ClipsDescendants = true
	mapArea.ZIndex = 3
	mapArea.Parent = card
	UiTheme.addCorner(mapArea, 14)

	local visited: { [string]: boolean } = {}
	local currentFloor: MapFloor = "Main"
	local tiles: { Tile } = {}
	local dots: { Frame } = {}
	-- Conversão do mundo (X, Z) para pixels do andar mostrado.
	local scale = 1
	local originX, originZ = 0, 0
	local offsetX, offsetY = 0, 0
	local tabs: { [string]: UiKit.ButtonHandle } = {}

	local function toPixels(x: number, z: number): Vector2
		return Vector2.new(offsetX + (x - originX) * scale, offsetY + (z - originZ) * scale)
	end

	local function paintTile(tile: Tile)
		local room = roomInfo(tile.rect.id)
		local known = visited[tile.rect.id] == true
		local secret = room ~= nil and room.secret
		tile.frame.Visible = known or not secret
		tile.frame.BackgroundColor3 = if known then VISITED_COLOR else HIDDEN_COLOR
		tile.stroke.Color = if known then UiTheme.Colors.Gold else UiTheme.Colors.Border
		tile.label.Text = if known and room ~= nil then `{room.icon}\n{Lang.t(room.name)}` else "?"
		tile.label.TextColor3 = if known then UiTheme.Colors.Ink else UiTheme.Colors.InkSoft
	end

	local function buildFloor(floor: MapFloor)
		currentFloor = floor
		for _, tile in ipairs(tiles) do
			tile.frame:Destroy()
		end
		table.clear(tiles)
		local rects: { MapRect } = {}
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, entry in ipairs(MansionMapLayout.rects()) do
			if entry.floor == floor then
				table.insert(rects, entry)
				minX, maxX = math.min(minX, entry.minX), math.max(maxX, entry.maxX)
				minZ, maxZ = math.min(minZ, entry.minZ), math.max(maxZ, entry.maxZ)
			end
		end
		if #rects == 0 then
			return
		end
		local width, depth = math.max(1, maxX - minX), math.max(1, maxZ - minZ)
		scale = math.min((MAP_SIZE.X - MAP_MARGIN * 2) / width, (MAP_SIZE.Y - MAP_MARGIN * 2) / depth)
		originX, originZ = minX, minZ
		offsetX = (MAP_SIZE.X - width * scale) / 2
		offsetY = (MAP_SIZE.Y - depth * scale) / 2
		for _, entry in ipairs(rects) do
			local topLeft = toPixels(entry.minX, entry.minZ)
			local bottomRight = toPixels(entry.maxX, entry.maxZ)
			local frame = Instance.new("Frame")
			frame.Name = entry.id
			frame.Position = UDim2.fromOffset(topLeft.X + TILE_GAP, topLeft.Y + TILE_GAP)
			frame.Size = UDim2.fromOffset(bottomRight.X - topLeft.X - TILE_GAP * 2, bottomRight.Y - topLeft.Y - TILE_GAP * 2)
			frame.ZIndex = 4
			frame.Parent = mapArea
			UiTheme.addCorner(frame, 8)
			local stroke = UiTheme.addStroke(frame, UiTheme.Colors.Border, 1.5)
			local label = UiTheme.createLabel(frame, "Name", "", UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.Ink)
			label.Size = UDim2.fromScale(1, 1)
			label.TextScaled = true
			label.ZIndex = 5
			UiTheme.addTextConstraint(label, 8, 16)
			local tile: Tile = { rect = entry, frame = frame, stroke = stroke, label = label }
			paintTile(tile)
			table.insert(tiles, tile)
		end
		for id, tab in pairs(tabs) do
			tab.setVariant(if id == floor then "Gold" else "Primary")
		end
	end

	local handle = {} :: MansionMapViewHandle

	for index, floorInfo in ipairs(MansionMapConfig.Floors) do
		local tab = UiKit.createButton(card, {
			name = `Floor{floorInfo.id}`,
			text = Lang.t(floorInfo.name),
			variant = "Primary",
			size = UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT),
			position = UDim2.fromOffset(16, TOP + (index - 1) * (TAB_HEIGHT + TAB_GAP)),
			textSize = 20,
			zIndex = 4,
		})
		tab.button.Activated:Connect(function()
			UiKit.playClick()
			buildFloor(floorInfo.id)
		end)
		tabs[floorInfo.id] = tab
	end

	handle.setVisited = function(rooms: { string })
		table.clear(visited)
		for _, id in ipairs(rooms) do
			visited[id] = true
		end
		for _, tile in ipairs(tiles) do
			paintTile(tile)
		end
		local count, total = MansionMapRules.progress(MansionMapConfig.Rooms, visited)
		local percent = MansionMapRules.percent(MansionMapConfig.Rooms, visited)
		progress.Text = Lang.t("Explorado: %d%% (%d/%d)", percent, count, total)
		progress.TextColor3 = if percent >= 100 then UiTheme.Colors.Gold else UiTheme.Colors.Ink
	end

	handle.setDots = function(points: { MapDot })
		for _, dot in ipairs(dots) do
			dot:Destroy()
		end
		table.clear(dots)
		for _, point in ipairs(points) do
			if MansionMapLayout.floorAt(point.position) == currentFloor then
				local pixel = toPixels(point.position.X, point.position.Z)
				local dot = Instance.new("Frame")
				dot.Name = if point.isSelf then "Self" else "Friend"
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Position = UDim2.fromOffset(pixel.X, pixel.Y)
				dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
				dot.BackgroundColor3 = if point.isSelf then UiTheme.Colors.Gold else UiTheme.Colors.Blue
				dot.ZIndex = if point.isSelf then 7 else 6
				dot.Parent = mapArea
				UiTheme.addCorner(dot, 999)
				UiTheme.addStroke(dot, UiTheme.Colors.Outline, 2)
				table.insert(dots, dot)
			end
		end
	end

	handle.open = function()
		screenGui.Enabled = true
		responsive.pop(0.9, 0.25)
		onOpened()
	end

	handle.close = function()
		screenGui.Enabled = false
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.destroy = function()
		responsive.destroy()
		screenGui:Destroy()
	end

	closeButton.button.Activated:Connect(function()
		UiKit.playClick()
		handle.close()
	end)

	buildFloor("Main")
	handle.setVisited({})
	return handle
end

return table.freeze(MansionMapView)
