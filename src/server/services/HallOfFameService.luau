--!strict

-- Hall da Fama: cinco painéis no alto da parede leste da galeria (o lobby),
-- acima dos quadros e janelas. Da esquerda para a direita, olhando para a
-- parede: Vitórias, Derrubadas, a Lenda do BlocoPuff (1º em vitórias, com
-- foto), Blocos destruídos e Cofres conquistados. Mostram o top 5; o top 10
-- completo fica no painel RANKING do cliente. O texto é desenhado pelo
-- servidor (SurfaceGui), atualizado a cada leitura do LeaderboardService.
-- Também registra, uma vez por sessão, quem ficou olhando os painéis.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local LeaderboardTypes = require(ReplicatedStorage.Shared.types.LeaderboardTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local TelemetryService = require(script.Parent.TelemetryService)

type LeaderboardData = LeaderboardTypes.LeaderboardData
type Leaderboard = LeaderboardTypes.Leaderboard

type BoardView = {
	title: TextLabel,
	rows: { { frame: Frame, rank: TextLabel, name: TextLabel, value: TextLabel } },
	empty: TextLabel,
}

type LegendView = {
	avatar: ImageLabel,
	name: TextLabel,
	detail: TextLabel,
}

local FOLDER_NAME = "HallOfFame"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "HallOfFameService"
-- Entre o topo das janelas (+12) e a sanca do teto (+18,8) da galeria.
local BOARD_SIZE = Vector2.new(14, 5.6)
local BOARD_SPACING = 17
local BOARD_CENTER_HEIGHT = 15.4
local WALL_OFFSET = 0.35
local PIXELS_PER_STUD = 50
local VISIBLE_ROWS = 5
local VIEW_SECONDS = 3
local VIEW_CHECK_INTERVAL = 1

local PANEL_COLOR = Color3.fromRGB(34, 26, 58)
local FRAME_COLOR = Color3.fromRGB(196, 150, 72)
local GOLD = Color3.fromRGB(255, 209, 102)
local INK = Color3.fromRGB(255, 248, 238)
local INK_SOFT = Color3.fromRGB(190, 180, 220)
local MEDALS = { "🥇", "🥈", "🥉" }

local HallOfFameService = {}

local started = false
local folder: Folder? = nil
local boardViews: { [string]: BoardView } = {}
local legendView: LegendView? = nil
local viewedSeconds: { [Player]: number } = {}
local viewed: { [Player]: boolean } = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

local function textLabel(parent: Instance, text: string, font: Enum.Font, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Position = position
	label.Size = size
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(14, 10, 28)
	stroke.Parent = label
	return label
end

-- Placa com moldura dourada; devolve o SurfaceGui para o conteúdo.
local function createPlaque(parent: Instance, name: string, center: Vector3, width: number): SurfaceGui
	local facing = Vector3.new(-1, 0, 0)
	local frame = Instance.new("Part")
	frame.Name = `{name}Frame`
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanQuery = false
	frame.CanTouch = false
	frame.Material = Enum.Material.Metal
	frame.Color = FRAME_COLOR
	frame.Size = Vector3.new(width + 0.6, BOARD_SIZE.Y + 0.6, 0.2)
	frame.CFrame = CFrame.lookAt(center - (facing * 0.12), center - (facing * 0.12) + facing)
	frame.Parent = parent

	local board = Instance.new("Part")
	board.Name = name
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.Material = Enum.Material.SmoothPlastic
	board.Color = PANEL_COLOR
	board.Size = Vector3.new(width, BOARD_SIZE.Y, 0.2)
	board.CFrame = CFrame.lookAt(center, center + facing)
	board.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = board
	return gui
end

local function createBoard(parent: Instance, id: string, title: string, icon: string, center: Vector3)
	local gui = createPlaque(parent, `Board_{id}`, center, BOARD_SIZE.X)
	local titleLabel = textLabel(gui, `{icon} {title}`, Enum.Font.FredokaOne, GOLD, UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.2))
	local rows = {}
	for index = 1, VISIBLE_ROWS do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(14, 10, 28)
		row.BackgroundTransparency = if index % 2 == 0 then 0.75 else 0.55
		row.Position = UDim2.fromScale(0.04, 0.25 + ((index - 1) * 0.145))
		row.Size = UDim2.fromScale(0.92, 0.13)
		row.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = row
		local rank = textLabel(row, "", Enum.Font.FredokaOne, GOLD, UDim2.fromScale(0.02, 0.1), UDim2.fromScale(0.12, 0.8))
		local name = textLabel(row, "", Enum.Font.GothamBold, INK, UDim2.fromScale(0.16, 0.12), UDim2.fromScale(0.56, 0.76))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local value = textLabel(row, "", Enum.Font.FredokaOne, INK, UDim2.fromScale(0.72, 0.1), UDim2.fromScale(0.26, 0.8))
		value.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, { frame = row, rank = rank, name = name, value = value })
	end
	local empty = textLabel(gui, Lang.t("Seja o primeiro!"), Enum.Font.GothamBold, INK_SOFT, UDim2.fromScale(0.1, 0.45), UDim2.fromScale(0.8, 0.15))
	boardViews[id] = { title = titleLabel, rows = rows, empty = empty }
end

local function createLegend(parent: Instance, center: Vector3)
	local gui = createPlaque(parent, "Board_Legend", center, BOARD_SIZE.X)
	textLabel(gui, Lang.t("👑 LENDA DO BLOCOPUFF"), Enum.Font.FredokaOne, GOLD, UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.2))
	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundColor3 = Color3.fromRGB(58, 47, 96)
	avatar.Position = UDim2.fromScale(0.06, 0.27)
	avatar.Size = UDim2.fromScale(0.26, 0.57)
	avatar.Parent = gui
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatar
	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Color = GOLD
	avatarStroke.Thickness = 4
	avatarStroke.Parent = avatar
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = avatar
	local name = textLabel(gui, "", Enum.Font.FredokaOne, INK, UDim2.fromScale(0.36, 0.32), UDim2.fromScale(0.6, 0.22))
	name.TextXAlignment = Enum.TextXAlignment.Left
	local detail = textLabel(gui, "", Enum.Font.GothamBold, GOLD, UDim2.fromScale(0.36, 0.56), UDim2.fromScale(0.6, 0.14))
	detail.TextXAlignment = Enum.TextXAlignment.Left
	-- Espaço reservado para o ranking sazonal (Fase 6).
	textLabel(gui, Lang.t("Ranking da temporada: em breve"), Enum.Font.GothamMedium, INK_SOFT, UDim2.fromScale(0.1, 0.87), UDim2.fromScale(0.8, 0.1))
	legendView = { avatar = avatar, name = name, detail = detail }
end

local function renderBoard(board: Leaderboard, available: boolean)
	local view = boardViews[board.id]
	if view == nil then
		return
	end
	for index, row in ipairs(view.rows) do
		local entry = board.entries[index]
		row.frame.Visible = entry ~= nil
		if entry ~= nil then
			row.rank.Text = MEDALS[entry.rank] or `{entry.rank}º`
			row.name.Text = entry.name
			row.value.Text = formatNumber(entry.value)
		end
	end
	view.empty.Visible = #board.entries == 0
	view.empty.Text = if available then Lang.t("Seja o primeiro!") else Lang.t("Ranking indisponível")
end

local function render(data: LeaderboardData)
	for _, board in ipairs(data.boards) do
		renderBoard(board, data.available)
	end
	local legend = legendView
	if legend == nil then
		return
	end
	local legendBoard: Leaderboard? = nil
	for _, board in ipairs(data.boards) do
		if board.id == LeaderboardTypes.LegendCategory then
			legendBoard = board
		end
	end
	local top = if legendBoard ~= nil then legendBoard.entries[1] else nil
	if top == nil then
		legend.avatar.Image = ""
		legend.name.Text = Lang.t("Ainda sem lenda")
		legend.detail.Text = Lang.t("Vença partidas para entrar aqui")
		return
	end
	legend.avatar.Image = `rbxthumb://type=AvatarHeadShot&id={top.userId}&w=420&h=420`
	legend.name.Text = top.name
	legend.detail.Text = Lang.t("%s vitórias", formatNumber(top.value))
end

-- Quem está na galeria virado para a parede leste por VIEW_SECONDS conta
-- como "viu o Hall da Fama" (uma vez por sessão).
local function trackViewers(dt: number)
	local gallery = BuildingLayout.getGallery(GameConfig.Arena, GameConfig.Building)
	local eastX = gallery.innerX + GameConfig.Building.GalleryDepth
	for _, player in ipairs(Players:GetPlayers()) do
		if not viewed[player] then
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			local competing = player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
				and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
			if root ~= nil and root:IsA("BasePart") and not competing then
				local position = root.Position
				local inGallery = position.X > gallery.innerX and position.X < eastX and math.abs(position.Y - gallery.floorY) < 8
				if inGallery and root.CFrame.LookVector.X > 0.6 then
					local total = (viewedSeconds[player] or 0) + dt
					viewedSeconds[player] = total
					if total >= VIEW_SECONDS then
						viewed[player] = true
						TelemetryService.lobbyEvent(player, "HallOfFameViewed", math.floor(total))
					end
				end
			end
		end
	end
end

-- Cria os painéis. `subscribe` recebe a função que redesenha a cada leitura.
function HallOfFameService.start(worldRoot: Instance, subscribe: ((LeaderboardData) -> ()) -> ())
	if started then
		return
	end
	started = true

	local existing = worldRoot:FindFirstChild(FOLDER_NAME)
	if existing ~= nil and existing:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME then
		existing:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	newFolder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newFolder.Parent = worldRoot
	folder = newFolder

	local gallery = BuildingLayout.getGallery(GameConfig.Arena, GameConfig.Building)
	local wallX = gallery.innerX + GameConfig.Building.GalleryDepth - WALL_OFFSET
	local y = gallery.floorY + BOARD_CENTER_HEIGHT
	local z = gallery.center.Z
	-- Olhando para a parede leste (+X), a direita é +Z.
	local categories = LeaderboardTypes.Categories
	local layout: { { kind: string, index: number, offset: number } } = {
		{ kind = "Board", index = 1, offset = -2 },
		{ kind = "Board", index = 2, offset = -1 },
		{ kind = "Legend", index = 0, offset = 0 },
		{ kind = "Board", index = 3, offset = 1 },
		{ kind = "Board", index = 4, offset = 2 },
	}
	for _, slot in ipairs(layout) do
		local center = Vector3.new(wallX, y, z + (slot.offset * BOARD_SPACING))
		if slot.kind == "Legend" then
			createLegend(newFolder, center)
		else
			local category = categories[slot.index]
			if category ~= nil then
				createBoard(newFolder, category.id, category.title, category.icon, center)
			end
		end
	end

	subscribe(render)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= VIEW_CHECK_INTERVAL then
			trackViewers(accumulator)
			accumulator = 0
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		viewedSeconds[player] = nil
		viewed[player] = nil
	end)
end

function HallOfFameService.getFolder(): Folder?
	return folder
end

return table.freeze(HallOfFameService)
