--!strict

-- Passagens secretas. Cada corredor tem uma entrada no andar de baixo e
-- outra no de cima; elas sempre existem (dá para atravessar sabendo onde
-- ficam), mas começam escondidas atrás de um painel falso igual à parede.
--
-- A cada rodada um quadro de cada andar é sorteado em segredo. Quem acertar
-- o quadro certo com o Puffador revela, para todos, as entradas daquele
-- andar: o painel falso some e aparece uma moldura dourada acesa. Revelar um
-- andar não revela o outro. Quadros errados só respondem com um som.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local BuildingDecor = require(script.Parent.BuildingDecor)
local ProjectileService = require(script.Parent.ProjectileService)
local MatchAudience = require(script.Parent.MatchAudience)

type Corridor = BuildingLayout.Corridor
type WallSegment = BuildingDecor.WallSegment

type Entrance = {
	floor: number,
	cover: { BasePart },
	glow: { BasePart },
	light: PointLight,
	soundAnchor: BasePart,
}

export type RevealListener = (floor: number, discoverer: Player) -> ()

local FOLDER_NAME = "SecretPassages"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "SecretPassageService"
local HANDLER_KEY = "SecretPassages"
local PAINTING_TAG = "RevealPainting"
local GLOW_COLOR = Color3.fromRGB(255, 206, 90)
local REVEAL_TIME = 0.8
local SOUND_REVEAL = "rbxasset://sounds/electronicpingshort.wav"
local SOUND_WRONG = "rbxasset://sounds/clickfast.wav"
local WRONG_COOLDOWN = 0.6

local SecretPassageService = {}

local folder: Folder? = nil
local remote: RemoteEvent? = nil
local entrances: { Entrance } = {}
local paintingsByFloor: { [number]: { string } } = {}
local paintingParts: { [string]: { BasePart } } = {}
local correctPainting: { [number]: string } = {}
local revealed: { [number]: boolean } = {}
local lastWrong: { [Player]: number } = {}
local roundActive = false
local roundId = 0
local random = Random.new()
local revealListener: RevealListener? = nil

local function isActiveParticipant(player: Player): boolean
	return roundActive
		and player.Parent ~= nil
		and player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) == roundId
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == false
end

local function playSound(anchor: BasePart, soundId: string, speed: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.RollOffMaxDistance = 80
	sound.Parent = anchor
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function segmentFor(corridor: Corridor): WallSegment
	return {
		name = corridor.name,
		origin = corridor.wallCenter,
		inward = corridor.inward,
		length = 0,
		bottomY = -math.huge,
		topY = math.huge,
	}
end

-- Painel falso: papel de parede, lambri, rodapé e guarda-cadeira iguais aos
-- da parede daquele andar, cobrindo o vão. Não colide (dá para atravessar).
local function createCover(parent: Instance, segment: WallSegment, offset: number, bottom: number, floor: number): { BasePart }
	local building = GameConfig.Building
	local size = BuildingLayout.SecretDoorSize
	local wallpapers = building.StoryWallpaperColors
	local wallpaper = wallpapers[math.min(floor, #wallpapers)]
	local pieces = {
		{ name = "Wallpaper", height = size.Y, y = bottom, depth = 0.1, color = wallpaper, material = Enum.Material.Plaster },
		{ name = "Wainscot", height = 4.5, y = bottom, depth = 0.3, color = building.WainscotColor, material = Enum.Material.WoodPlanks },
		{ name = "Baseboard", height = 0.8, y = bottom, depth = 0.45, color = building.BaseboardColor, material = Enum.Material.Wood },
		{ name = "ChairRail", height = 0.4, y = bottom + 4.3, depth = 0.5, color = building.TrimColor, material = Enum.Material.Wood },
	}
	local cover: { BasePart } = {}
	for _, piece in ipairs(pieces) do
		local part = BuildingDecor.createPart(
			parent,
			`Cover{piece.name}`,
			Vector3.new(size.X, piece.height, piece.depth),
			BuildingDecor.wallCFrame(segment, offset, piece.y + (piece.height / 2), piece.depth / 2),
			piece.color,
			{ material = piece.material }
		)
		table.insert(cover, part)
	end
	return cover
end

-- Moldura dourada acesa, invisível até a revelação.
local function createGlow(parent: Instance, segment: WallSegment, offset: number, bottom: number): ({ BasePart }, PointLight)
	local size = BuildingLayout.SecretDoorSize
	local glow: { BasePart } = {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(glow, BuildingDecor.createPart(
			parent,
			"GlowJamb",
			Vector3.new(0.35, size.Y + 0.4, 0.35),
			BuildingDecor.wallCFrame(segment, offset + (side * ((size.X / 2) + 0.2)), bottom + ((size.Y + 0.4) / 2), 0.2),
			GLOW_COLOR,
			{ material = Enum.Material.Neon, transparency = 1 }
		))
	end
	local lintel = BuildingDecor.createPart(
		parent,
		"GlowLintel",
		Vector3.new(size.X + 0.75, 0.35, 0.35),
		BuildingDecor.wallCFrame(segment, offset, bottom + size.Y + 0.2, 0.2),
		GLOW_COLOR,
		{ material = Enum.Material.Neon, transparency = 1 }
	)
	table.insert(glow, lintel)
	local light = Instance.new("PointLight")
	light.Color = GLOW_COLOR
	light.Range = 14
	light.Brightness = 0
	light.Shadows = false
	light.Parent = lintel
	return glow, light
end

local function setEntranceRevealed(entrance: Entrance, isRevealed: boolean, animate: boolean)
	local info = TweenInfo.new(if animate then REVEAL_TIME else 0, Enum.EasingStyle.Quad)
	for _, part in ipairs(entrance.cover) do
		TweenService:Create(part, info, { Transparency = if isRevealed then 1 else 0 }):Play()
	end
	for _, part in ipairs(entrance.glow) do
		TweenService:Create(part, info, { Transparency = if isRevealed then 0.1 else 1 }):Play()
	end
	TweenService:Create(entrance.light, info, { Brightness = if isRevealed then 1.1 else 0 }):Play()
end

local function hideAll()
	table.clear(revealed)
	for _, entrance in ipairs(entrances) do
		setEntranceRevealed(entrance, false, false)
	end
end

local function reveal(floor: number, discoverer: Player)
	revealed[floor] = true
	for _, entrance in ipairs(entrances) do
		if entrance.floor == floor then
			setEntranceRevealed(entrance, true, true)
			playSound(entrance.soundAnchor, SOUND_REVEAL, 1.5, 0.8)
		end
	end
	local secretRemote = remote
	if secretRemote ~= nil then
		MatchAudience.fire(secretRemote, "Revealed", floor, discoverer.DisplayName, discoverer.UserId)
	end
	local listener = revealListener
	if listener ~= nil then
		task.spawn(listener, floor, discoverer)
	end
end

local function onSurfaceHit(shooter: Player, instance: Instance, _position: Vector3)
	if not isActiveParticipant(shooter) then
		return
	end
	local paintingId = instance:GetAttribute("PaintingId")
	local floor = instance:GetAttribute("PaintingFloor")
	if typeof(paintingId) ~= "string" or typeof(floor) ~= "number" or revealed[floor] then
		return
	end
	if correctPainting[floor] == paintingId then
		reveal(floor, shooter)
		return
	end

	local now = os.clock()
	local last = lastWrong[shooter]
	if last ~= nil and now - last < WRONG_COOLDOWN then
		return
	end
	lastWrong[shooter] = now
	if instance:IsA("BasePart") then
		playSound(instance, SOUND_WRONG, 0.6, 0.7)
	end
	local secretRemote = remote
	if secretRemote ~= nil then
		secretRemote:FireClient(shooter, "WrongPainting", floor)
	end
end

local function collectPaintings()
	table.clear(paintingsByFloor)
	table.clear(paintingParts)
	for _, instance in ipairs(CollectionService:GetTagged(PAINTING_TAG)) do
		local paintingId = instance:GetAttribute("PaintingId")
		local floor = instance:GetAttribute("PaintingFloor")
		if instance:IsA("BasePart") and typeof(paintingId) == "string" and typeof(floor) == "number" then
			if paintingParts[paintingId] == nil then
				paintingParts[paintingId] = {}
				local list = paintingsByFloor[floor] or {}
				paintingsByFloor[floor] = list
				table.insert(list, paintingId)
			end
			table.insert(paintingParts[paintingId], instance)
		end
	end
end

function SecretPassageService.isRevealed(floor: number): boolean
	return revealed[floor] == true
end

function SecretPassageService.setRevealListener(listener: RevealListener?)
	revealListener = listener
end

function SecretPassageService.beginRound(newRoundId: number)
	roundId = newRoundId
	roundActive = true
	hideAll()
	table.clear(correctPainting)
	table.clear(lastWrong)
	for floor, ids in pairs(paintingsByFloor) do
		if #ids > 0 then
			correctPainting[floor] = ids[random:NextInteger(1, #ids)]
		end
	end
end

function SecretPassageService.endRound()
	roundActive = false
	hideAll()
end

function SecretPassageService.start(worldRoot: Model, remotesFolder: Folder?)
	if folder ~= nil then
		return
	end
	local existing = worldRoot:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	newFolder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newFolder.Parent = worldRoot
	folder = newFolder

	local arena = GameConfig.Arena
	for _, corridor in ipairs(BuildingLayout.getCorridors(arena, GameConfig.Building)) do
		local segment = segmentFor(corridor)
		local definitions = {
			{ floor = 1, offset = corridor.lowerAlong, bottom = corridor.lowerY },
			{ floor = arena.FloorCount, offset = corridor.upperAlong, bottom = corridor.upperY },
		}
		for _, definition in ipairs(definitions) do
			local model = Instance.new("Model")
			model.Name = string.format("%sEntranceF%d", corridor.name, definition.floor)
			local cover = createCover(model, segment, definition.offset, definition.bottom, definition.floor)
			local glow, light = createGlow(model, segment, definition.offset, definition.bottom)
			model.Parent = newFolder
			table.insert(entrances, {
				floor = definition.floor,
				cover = cover,
				glow = glow,
				light = light,
				soundAnchor = glow[#glow],
			})
		end
	end

	collectPaintings()

	if remotesFolder ~= nil then
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = PuffadorConstants.SecretEventRemoteName
		newRemote.Parent = remotesFolder
		remote = newRemote
	else
		warn("[BlocoPuff] SecretPassageService: remotes folder not found; reveal alerts disabled")
	end

	ProjectileService.setSurfaceHitHandler(HANDLER_KEY, onSurfaceHit)
end

function SecretPassageService.stop()
	roundActive = false
	ProjectileService.setSurfaceHitHandler(HANDLER_KEY, nil)
	table.clear(entrances)
	if remote ~= nil then
		remote:Destroy()
		remote = nil
	end
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end

return table.freeze(SecretPassageService)
