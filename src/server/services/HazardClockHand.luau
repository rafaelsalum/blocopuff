--!strict

-- Ponteiro gigante (Fase 5F.3): num trecho da terceira volta, um ponteiro
-- de ferro com a ponta dourada sai devagar da coluna (é o aviso), varre a
-- rampa rente ao chão de uma ponta à outra do trecho e volta para dentro. Na
-- vez seguinte varre no sentido contrário. Quem está no chão quando ele
-- passa é atingido; pulando na hora certa, passa por cima. Um mostrador de
-- relógio na coluna marca o trecho.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local ClockFace = require(ReplicatedStorage.Shared.modules.ClockFace)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local HazardContext = require(script.Parent.HazardContext)
local HazardProps = require(script.Parent.HazardProps)
local RaceRules = require(script.Parent.Parent.data.RaceRules)

type Context = HazardContext.Context
type Combatant = CombatantRegistry.Combatant

local HAND_HEIGHT = 1.2
-- Sobra do ponteiro para dentro da coluna quando está varrendo.
local HAND_INSET = 1
local FACE_DIAMETER = 12
local FACE_LIFT = 16
-- Respiro na largada antes da primeira varrida.
local FIRST_DELAY = 4

local HazardClockHand = {}

local function sectionAngles(): (number, number)
	local hazards = RaceConfig.Hazards
	return hazards.ClockHandFromTurn * 2 * math.pi, hazards.ClockHandToTurn * 2 * math.pi
end

-- Volta (t) da rampa no ângulo `angle`, dentro do trecho do ponteiro.
local function turnAt(angle: number): number
	local hazards = RaceConfig.Hazards
	local fromAngle = sectionAngles()
	local offset = math.atan2(math.sin(angle - fromAngle), math.cos(angle - fromAngle))
	return math.clamp(hazards.ClockHandFromTurn + offset / (2 * math.pi), hazards.ClockHandFromTurn - 0.05, hazards.ClockHandToTurn + 0.05)
end

local function face(context: Context)
	local tower = context.tower
	local config = RaceConfig.Tower
	local fromAngle, toAngle = sectionAngles()
	local angle = (fromAngle + toAngle) / 2
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local columnRadius = config.Radius - config.RampWidth / 2
	local y = tower.pointAt(turnAt(angle)).Y + FACE_LIFT
	local position = Vector3.new(tower.center.X, y, tower.center.Z) + outward * (columnRadius + 0.3)
	local plate = Instance.new("Part")
	plate.Name = "HandClockFace"
	plate.Size = Vector3.new(FACE_DIAMETER, FACE_DIAMETER, 0.2)
	plate.CFrame = CFrame.lookAt(position, position + outward)
	plate.Transparency = 1
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = plate
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	ClockFace.draw(holder, 1)
	ClockFace.set(gui, 12, 0)
	plate.Parent = context.folder
	context.track(plate)
end

-- Ponteiro no ângulo `angle`, com o meio a `middleRadius` do centro.
local function place(context: Context, hand: Model, angle: number, middleRadius: number)
	local tower = context.tower
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local y = tower.pointAt(turnAt(angle)).Y + HAND_HEIGHT / 2 + 0.05
	local position = Vector3.new(tower.center.X, y, tower.center.Z) + outward * middleRadius
	hand:PivotTo(CFrame.fromMatrix(position, outward, Vector3.yAxis))
end

-- Espera `seconds` mexendo o ponteiro com `step(alpha)`; para se a corrida
-- acabar. Devolve se ainda vale.
local function animate(context: Context, seconds: number, step: (alpha: number) -> ()): boolean
	local startedAt = os.clock()
	while context.isLive() do
		local alpha = math.clamp((os.clock() - startedAt) / seconds, 0, 1)
		step(alpha)
		if alpha >= 1 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return false
end

local function checkHits(context: Context, previous: number, current: number, innerRadius: number, outerRadius: number, already: { [Combatant]: boolean })
	local center = context.tower.center
	local clearHeight = RaceConfig.Hazards.ClockHandClearHeight
	for _, combatant in ipairs(context.racers()) do
		local root = CombatantRegistry.getRoot(combatant)
		if root ~= nil and not already[combatant] then
			local offset = root.Position - center
			local radius = Vector3.new(offset.X, 0, offset.Z).Magnitude
			local angle = math.atan2(offset.Z, offset.X)
			local t = turnAt(angle)
			local heightAbove = root.Position.Y - context.tower.pointAt(t).Y
			if RaceRules.handSweeps(previous, current, angle, radius, innerRadius, outerRadius, heightAbove, clearHeight) then
				already[combatant] = true
				context.hit(combatant, t)
			end
		end
	end
end

local function cycle(context: Context, hand: Model, fromAngle: number, toAngle: number): boolean
	local hazards = RaceConfig.Hazards
	local config = RaceConfig.Tower
	local length = config.RampWidth + HAND_INSET
	local innerRadius = config.Radius - config.RampWidth / 2
	local outerRadius = config.Radius + config.RampWidth / 2
	local outMiddle = innerRadius - HAND_INSET + length / 2
	local inMiddle = innerRadius - length / 2 - 1
	if not animate(context, hazards.ClockHandExtendTime, function(alpha)
		place(context, hand, fromAngle, inMiddle + (outMiddle - inMiddle) * alpha)
	end) then
		return false
	end
	local already: { [Combatant]: boolean } = {}
	local previous = fromAngle
	if not animate(context, hazards.ClockHandSweepTime, function(alpha)
		local current = fromAngle + (toAngle - fromAngle) * alpha
		place(context, hand, current, outMiddle)
		checkHits(context, previous, current, innerRadius, outerRadius + 1, already)
		previous = current
	end) then
		return false
	end
	return animate(context, hazards.ClockHandRetractTime, function(alpha)
		place(context, hand, toAngle, outMiddle + (inMiddle - outMiddle) * alpha)
	end)
end

-- Liga o ponteiro durante a corrida (para sozinho quando ela acaba).
function HazardClockHand.start(context: Context)
	local hazards = RaceConfig.Hazards
	local config = RaceConfig.Tower
	face(context)
	local hand = HazardProps.clockHand(config.RampWidth + HAND_INSET, HAND_HEIGHT)
	local fromAngle, toAngle = sectionAngles()
	place(context, hand, fromAngle, config.Radius - config.RampWidth / 2 - (config.RampWidth + HAND_INSET) / 2 - 1)
	hand.Parent = context.folder
	context.track(hand)
	task.spawn(function()
		task.wait(FIRST_DELAY)
		local forward = true
		while context.isLive() do
			local cycleStart = os.clock()
			local live = if forward then cycle(context, hand, fromAngle, toAngle) else cycle(context, hand, toAngle, fromAngle)
			if not live then
				return
			end
			forward = not forward
			task.wait(math.max(0.5, hazards.ClockHandPeriod - (os.clock() - cycleStart)))
		end
	end)
end

return table.freeze(HazardClockHand)
