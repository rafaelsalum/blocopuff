--!strict

-- Livros voadores (Fase 5F.3): um brilho roxo aparece na coluna à frente de
-- um corredor e, logo depois, um bando de livros sai dela batendo as capas e
-- cruza a rampa de dentro para fora, na altura do peito. Pulando, dá para
-- passar por cima.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local HazardContext = require(script.Parent.HazardContext)
local HazardProps = require(script.Parent.HazardProps)
local RaceRules = require(script.Parent.Parent.data.RaceRules)

type Context = HazardContext.Context
type Combatant = CombatantRegistry.Combatant

local RUNE_COLOR = Color3.fromRGB(170, 110, 255)
local RUNE_SIZE = 7
-- De onde o bando sai (dentro da coluna) até onde some (fora da mureta).
local START_INSET = 3
local END_OUTSET = 8
local AHEAD_MIN = 0.12
local AHEAD_MAX = 0.25
local SPACING = 2.2
local FLAP_SPEED = 18
local FLAP_ANGLE = math.rad(30)
local WAVE_HEIGHT = 0.4

local HazardBooks = {}

local function rune(context: Context, position: Vector3, outward: Vector3): Part
	local glow = Instance.new("Part")
	glow.Name = "BookRune"
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.2, RUNE_SIZE, RUNE_SIZE)
	glow.CFrame = CFrame.fromMatrix(position, outward, Vector3.yAxis)
	glow.Color = RUNE_COLOR
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.3
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = RUNE_COLOR
	light.Range = 14
	light.Brightness = 2
	light.Parent = glow
	glow.Parent = context.folder
	context.track(glow)
	return glow
end

local function angleDelta(from: number, to: number): number
	return math.atan2(math.sin(to - from), math.cos(to - from))
end

-- Acerta quem está na faixa do bando agora (cada um, uma vez por bando).
local function checkHits(context: Context, bandAngle: number, frontRadius: number, rampY: number, t: number, already: { [Combatant]: boolean })
	local hazards = RaceConfig.Hazards
	local center = context.tower.center
	for _, combatant in ipairs(context.racers()) do
		local root = CombatantRegistry.getRoot(combatant)
		if root ~= nil and not already[combatant] then
			local offset = root.Position - center
			local radius = Vector3.new(offset.X, 0, offset.Z).Magnitude
			local along = angleDelta(bandAngle, math.atan2(offset.Z, offset.X)) * radius
			if RaceRules.bandHits(along, radius - frontRadius, root.Position.Y - rampY, hazards.BookHalfLength, hazards.BookHalfWidth, hazards.BookClearHeight) then
				already[combatant] = true
				context.hit(combatant, t, "Books")
			end
		end
	end
end

local function fly(context: Context, t: number)
	local hazards = RaceConfig.Hazards
	local tower = context.tower
	local config = RaceConfig.Tower
	local spot = tower.pointAt(t)
	local angle = t * 2 * math.pi
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local tangent = tower.tangentAt(t)
	local side = Vector3.new(tangent.X, 0, tangent.Z).Unit
	local innerRadius = config.Radius - config.RampWidth / 2
	local fromRadius = innerRadius - START_INSET
	local toRadius = config.Radius + config.RampWidth / 2 + END_OUTSET
	local axis = Vector3.new(tower.center.X, 0, tower.center.Z)
	local height = spot.Y + hazards.BookHeight

	local books: { { model: Model, along: number, phase: number } } = {}
	for index = 1, hazards.BooksPerFlock do
		local along = (index - (hazards.BooksPerFlock + 1) / 2) * SPACING + context.random:NextNumber(-0.4, 0.4)
		local book = HazardProps.book(context.random)
		book.Parent = context.folder
		context.track(book)
		table.insert(books, { model = book, along = along, phase = context.random:NextNumber(0, math.pi * 2) })
	end
	local already: { [Combatant]: boolean } = {}
	local startedAt = os.clock()
	while context.isLive() do
		local alpha = (os.clock() - startedAt) / hazards.BookFlightTime
		if alpha > 1 then
			break
		end
		local radius = fromRadius + (toRadius - fromRadius) * alpha
		local now = os.clock()
		for _, entry in ipairs(books) do
			local position = axis + outward * radius + side * entry.along + Vector3.new(0, height + math.sin(now * 6 + entry.phase) * WAVE_HEIGHT, 0)
			local flap = math.sin(now * FLAP_SPEED + entry.phase) * FLAP_ANGLE
			entry.model:PivotTo(CFrame.lookAt(position, position + outward) * CFrame.Angles(0, math.rad(90), flap))
		end
		if radius >= innerRadius then
			checkHits(context, angle, radius, spot.Y, t, already)
		end
		RunService.Heartbeat:Wait()
	end
	for _, entry in ipairs(books) do
		entry.model:Destroy()
	end
end

-- Um bando à frente de `target` (um corredor).
function HazardBooks.launch(context: Context, target: Combatant)
	local root = CombatantRegistry.getRoot(target)
	if root == nil then
		return
	end
	local hazards = RaceConfig.Hazards
	local tower = context.tower
	local t = math.min(context.turnsAt(root.Position) + context.random:NextNumber(AHEAD_MIN, AHEAD_MAX), tower.spiral.turns - 0.08)
	local angle = t * 2 * math.pi
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local columnRadius = RaceConfig.Tower.Radius - RaceConfig.Tower.RampWidth / 2
	local runeCenter = Vector3.new(tower.center.X, tower.pointAt(t).Y + hazards.BookHeight + 1, tower.center.Z) + outward * (columnRadius + 0.15)
	local glow = rune(context, runeCenter, outward)
	task.delay(hazards.BookWarning, function()
		glow:Destroy()
		if context.isLive() then
			fly(context, t)
		end
	end)
end

return table.freeze(HazardBooks)
