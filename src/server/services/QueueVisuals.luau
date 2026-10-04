--!strict

-- Visual da fila da partida (MatchQueueService é quem decide):
--   * do lado do Casarão, um portal "🏟 ENTRAR NA FILA" em cada porta do
--     mirante e uma passadeira com setas vindo do Salão Principal;
--   * dentro do mirante, faixa verde na entrada de cada porta;
--   * a barreira de luz dourada que fecha as portas nos últimos segundos;
--   * um painel em cada ponta do mirante com a fila, o tempo, os avatares
--     de quem está na fila e quem mais estourou balões no aquecimento.
-- Só instâncias nativas; o painel só é redesenhado quando algo muda.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)

export type BoardState = {
	-- Jogadores + bots.
	count: number,
	-- Bots RoboPuff (aparecem depois dos jogadores, com o ícone de bot).
	bots: number,
	minimum: number,
	maximum: number,
	-- Segundos até a partida (nil fora da contagem).
	remaining: number?,
	gatesClosed: boolean,
	userIds: { number },
	-- Linha do aquecimento ("🎈 Ana 7 · Rafa 5"), ou "".
	warmup: string,
}

export type QueueVisualsHandle = {
	setGatesClosed: (closed: boolean) -> (),
	setBoard: (state: BoardState) -> (),
}

local FOLDER_NAME = "MatchQueue"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "MatchQueueService"
local GREEN = Color3.fromRGB(79, 214, 160)
local GOLD = Color3.fromRGB(255, 209, 102)
local INK = Color3.fromRGB(255, 248, 238)
local PANEL = Color3.fromRGB(26, 21, 48)
local WOOD = Color3.fromRGB(86, 56, 38)
local BARRIER_COLOR = Color3.fromRGB(255, 196, 80)
local BOARD_SIZE = Vector2.new(18, 6.4)
-- Acima da porta decorativa das paredes das pontas (≈9,4 de altura).
local BOARD_HEIGHT = 13.2
local BOARD_AVATARS = 12
local PORTAL_HEIGHT = 13
local PORTAL_HEADER = Vector2.new(12, 2.4)
local RUNNER_LENGTH = 14
local SIGN_DISTANCE = 80

local QueueVisuals = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Anchored = true
	instance.CanCollide = collide == true
	instance.CanQuery = collide == true
	instance.CanTouch = false
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = color
	instance.Material = material or Enum.Material.SmoothPlastic
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Parent = parent
	return instance
end

local function label(parent: Instance, name: string, text: string, font: Enum.Font, color: Color3, position: UDim2, size: UDim2): TextLabel
	local instance = Instance.new("TextLabel")
	instance.Name = name
	instance.Position = position
	instance.Size = size
	instance.BackgroundTransparency = 1
	instance.Font = font
	instance.Text = text
	instance.TextColor3 = color
	instance.TextScaled = true
	instance.TextStrokeTransparency = 0.35
	instance.Parent = parent
	return instance
end

local function surface(target: BasePart, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.MaxDistance = SIGN_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

-- Portal do lado do Casarão (virado para +X): duas colunas verdes e um
-- letreiro no alto, bem maior que as placas das salas.
local function buildPortal(folder: Instance, index: number, wallX: number, floorY: number, z: number)
	local halfDoor = MansionConfig.PassageSize.X / 2
	for side = -1, 1, 2 do
		part(folder, `Portal{index}Pillar`, Vector3.new(0.8, PORTAL_HEIGHT, 0.8), CFrame.new(wallX + 0.5, floorY + PORTAL_HEIGHT / 2, z + side * (halfDoor + 1)), GREEN, Enum.Material.SmoothPlastic)
	end
	local header = part(
		folder,
		`Portal{index}Header`,
		Vector3.new(PORTAL_HEADER.X, PORTAL_HEADER.Y, 0.4),
		-- Frente (−Z local) virada para dentro do Casarão (+X).
		CFrame.lookAt(Vector3.new(wallX + 0.6, floorY + PORTAL_HEIGHT + 0.4, z), Vector3.new(wallX + 10, floorY + PORTAL_HEIGHT + 0.4, z)),
		PANEL
	)
	local gui = surface(header, 40)
	label(gui, "Title", Lang.t("🏟 ENTRAR NA FILA"), Enum.Font.FredokaOne, GOLD, UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.92, 0.6))
	label(gui, "Subtitle", Lang.t("Entre e saia quando quiser"), Enum.Font.GothamBold, INK, UDim2.fromScale(0.04, 0.64), UDim2.fromScale(0.92, 0.3))
end

-- Passadeira com setas do Salão Principal até a porta.
local function buildRunner(folder: Instance, index: number, wallX: number, floorY: number, z: number)
	local width = MansionConfig.PassageSize.X - 2
	part(folder, `Runner{index}`, Vector3.new(RUNNER_LENGTH, 0.12, width), CFrame.new(wallX + RUNNER_LENGTH / 2, floorY + 0.12, z), GREEN:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric)
	for arrow = 1, 3 do
		local x = wallX + 3 + (arrow - 1) * 4
		-- Chevron apontando para a porta (−X): duas barras em V.
		for side = -1, 1, 2 do
			part(
				folder,
				`Runner{index}Arrow`,
				Vector3.new(2.2, 0.06, 0.5),
				CFrame.new(x, floorY + 0.2, z + side * 0.7) * CFrame.Angles(0, math.rad(-side * 35), 0),
				GOLD,
				Enum.Material.SmoothPlastic
			)
		end
	end
end

-- Barreira de luz dentro do vão da porta (desligada até fechar o embarque).
local function buildBarrier(folder: Instance, index: number, wallX: number, floorY: number, z: number): Part
	local thickness = GameConfig.Building.WallThickness
	local size = MansionConfig.PassageSize
	local barrier = part(folder, `Barrier{index}`, Vector3.new(thickness, size.Y, size.X), CFrame.new(wallX - thickness / 2, floorY + size.Y / 2, z), BARRIER_COLOR, Enum.Material.ForceField)
	barrier.Transparency = 1
	barrier.CastShadow = false
	return barrier
end

-- Quem estiver parado no vão quando a barreira liga é empurrado para o
-- lado do Casarão (fora da fila), em vez de ficar preso dentro dela.
local function pushOutOfDoorway(barrier: BasePart)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { barrier }
	local moved: { [Model]: boolean } = {}
	for _, hit in ipairs(Workspace:GetPartBoundsInBox(barrier.CFrame, barrier.Size + Vector3.new(1, 0, 0), params)) do
		local character = hit:FindFirstAncestorOfClass("Model")
		if character ~= nil and not moved[character] and Players:GetPlayerFromCharacter(character) ~= nil then
			moved[character] = true
			local root = character:FindFirstChild("HumanoidRootPart")
			if root ~= nil and root:IsA("BasePart") then
				local target = Vector3.new(barrier.Position.X + barrier.Size.X / 2 + 3, root.Position.Y, root.Position.Z)
				character:PivotTo(CFrame.new(target) * root.CFrame.Rotation)
			end
		end
	end
end

type Board = {
	count: TextLabel,
	status: TextLabel,
	warmup: TextLabel,
	avatars: { ImageLabel },
}

local function buildBoard(folder: Instance, name: string, cframe: CFrame): Board
	local frame = part(folder, `{name}Frame`, Vector3.new(BOARD_SIZE.X + 0.6, BOARD_SIZE.Y + 0.6, 0.2), cframe * CFrame.new(0, 0, 0.12), WOOD, Enum.Material.Wood)
	frame.CastShadow = false
	local board = part(folder, name, Vector3.new(BOARD_SIZE.X, BOARD_SIZE.Y, 0.2), cframe, PANEL)
	local gui = surface(board, 30)
	label(gui, "Title", Lang.t("🏟 FILA DA PARTIDA"), Enum.Font.FredokaOne, GOLD, UDim2.fromScale(0.03, 0.03), UDim2.fromScale(0.94, 0.2))
	local count = label(gui, "Count", "", Enum.Font.FredokaOne, INK, UDim2.fromScale(0.03, 0.24), UDim2.fromScale(0.94, 0.2))
	local status = label(gui, "Status", "", Enum.Font.GothamBold, GREEN, UDim2.fromScale(0.03, 0.45), UDim2.fromScale(0.94, 0.13))
	local row = Instance.new("Frame")
	row.Name = "Avatars"
	row.Position = UDim2.fromScale(0.03, 0.61)
	row.Size = UDim2.fromScale(0.94, 0.2)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.008, 0)
	layout.Parent = row
	local avatars: { ImageLabel } = {}
	for index = 1, BOARD_AVATARS do
		local avatar = Instance.new("ImageLabel")
		avatar.Name = `Avatar{index}`
		avatar.LayoutOrder = index
		avatar.Size = UDim2.fromScale(0.075, 1)
		avatar.BackgroundColor3 = Color3.fromRGB(58, 47, 96)
		avatar.Visible = false
		avatar.Parent = row
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.Parent = avatar
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = avatar
		local botIcon = Instance.new("TextLabel")
		botIcon.Name = "BotIcon"
		botIcon.Size = UDim2.fromScale(1, 1)
		botIcon.BackgroundTransparency = 1
		botIcon.Text = BotConfig.Body.Tag
		botIcon.TextScaled = true
		botIcon.Visible = false
		botIcon.Parent = avatar
		table.insert(avatars, avatar)
	end
	local warmup = label(gui, "Warmup", "", Enum.Font.GothamBold, INK, UDim2.fromScale(0.03, 0.84), UDim2.fromScale(0.94, 0.12))
	return { count = count, status = status, warmup = warmup, avatars = avatars }
end

local function statusText(state: BoardState): string
	if state.gatesClosed then
		return Lang.t("🔒 Embarque encerrado · a partida vai começar!")
	end
	local remaining = state.remaining
	if remaining ~= nil then
		return Lang.t("Partida em %ds · entre agora!", math.max(0, math.floor(remaining)))
	end
	local missing = math.max(0, state.minimum - state.count)
	if missing <= 0 then
		return Lang.t("A contagem já vai começar")
	end
	return if missing == 1 then Lang.t("Falta 1 jogador para começar") else Lang.t("Faltam %d jogadores para começar", missing)
end

local function render(board: Board, state: BoardState)
	board.count.Text = Lang.t("%d / %d na fila", state.count, state.maximum)
	board.status.Text = statusText(state)
	board.status.TextColor3 = if state.gatesClosed then GOLD else GREEN
	board.warmup.Text = state.warmup
	local humans = #state.userIds
	for index, avatar in ipairs(board.avatars) do
		local userId = state.userIds[index]
		local isBot = userId == nil and index <= humans + state.bots
		avatar.Visible = userId ~= nil or isBot
		avatar.Image = if userId ~= nil then `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` else ""
		local botIcon = avatar:FindFirstChild("BotIcon")
		if botIcon ~= nil and botIcon:IsA("TextLabel") then
			botIcon.Visible = isBot
		end
	end
end

function QueueVisuals.build(worldRoot: Model): QueueVisualsHandle
	local existing = worldRoot:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	folder.Parent = worldRoot

	local gallery = BuildingLayout.getGallery(GameConfig.Arena, GameConfig.Building)
	local mansion = MansionLayout.get()
	local eastX = gallery.innerX + GameConfig.Building.GalleryDepth
	local floorY = gallery.floorY
	local barriers: { Part } = {}
	for index, z in ipairs(mansion.passages) do
		buildPortal(folder, index, mansion.galleryWallX, floorY, z)
		buildRunner(folder, index, mansion.galleryWallX, floorY, z)
		table.insert(barriers, buildBarrier(folder, index, mansion.galleryWallX, floorY, z))
		part(folder, `QueueMat{index}`, Vector3.new(1.2, 0.14, MansionConfig.PassageSize.X), CFrame.new(eastX - 1.2, floorY + 0.07, z), GREEN, Enum.Material.SmoothPlastic)
	end

	-- Painéis nas paredes das pontas, virados para dentro do mirante.
	local halfDepth = gallery.size.Z / 2
	local centerX = gallery.center.X
	local y = floorY + BOARD_HEIGHT
	local boards: { Board } = {
		buildBoard(folder, "BoardNorth", CFrame.lookAt(Vector3.new(centerX, y, gallery.center.Z - halfDepth + 0.35), Vector3.new(centerX, y, gallery.center.Z))),
		buildBoard(folder, "BoardSouth", CFrame.lookAt(Vector3.new(centerX, y, gallery.center.Z + halfDepth - 0.35), Vector3.new(centerX, y, gallery.center.Z))),
	}

	local handle = {} :: QueueVisualsHandle
	handle.setGatesClosed = function(closed: boolean)
		for _, barrier in ipairs(barriers) do
			if closed then
				pushOutOfDoorway(barrier)
			end
			barrier.CanCollide = closed
			barrier.Transparency = if closed then 0.35 else 1
		end
	end
	handle.setBoard = function(state: BoardState)
		for _, board in ipairs(boards) do
			render(board, state)
		end
	end
	return handle
end

return table.freeze(QueueVisuals)
