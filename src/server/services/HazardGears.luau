--!strict

-- Engrenagens que caem do mecanismo do relógio (Fase 5F.3, no lugar dos
-- caixotes, baús e quadros da 5D.2): uma sombra marca o lugar à frente de
-- um corredor, e a engrenagem cai girando. Quem estiver na sombra quando
-- ela bate é atingido.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RaceConfig = require(ReplicatedStorage.Shared.config.RaceConfig)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local HazardContext = require(script.Parent.HazardContext)
local HazardProps = require(script.Parent.HazardProps)

type Context = HazardContext.Context

local SHADOW_COLOR = Color3.fromRGB(40, 20, 20)
local SHADOW_TRANSPARENCY = 0.35
local GEAR_RADIUS = 3.6
-- Diferença de altura máxima para a engrenagem acertar alguém.
local HIT_HEIGHT = 6
-- Quanto à frente do corredor (em voltas) ela cai.
local AHEAD_MIN = 0.1
local AHEAD_MAX = 0.3
local LINGER = 1.2
local FALL_SPINS = 2

local HazardGears = {}

local function shadowAt(context: Context, spot: Vector3): Part
	local radius = RaceConfig.Hazards.DropHitRadius
	local shadow = Instance.new("Part")
	shadow.Name = "DropShadow"
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Size = Vector3.new(0.2, radius * 2, radius * 2)
	shadow.CFrame = CFrame.new(spot + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	shadow.Color = SHADOW_COLOR
	shadow.Material = Enum.Material.Neon
	shadow.Transparency = SHADOW_TRANSPARENCY
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanQuery = false
	shadow.CastShadow = false
	shadow.Parent = context.folder
	context.track(shadow)
	return shadow
end

local function fadeAndDestroy(gear: Model)
	task.delay(LINGER, function()
		if gear.Parent == nil then
			return
		end
		for _, part in ipairs(gear:GetDescendants()) do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.45)
		gear:Destroy()
	end)
end

-- Cai e espera a queda; devolve se a corrida ainda vale.
local function fall(context: Context, gear: Model, landing: CFrame): boolean
	local hazards = RaceConfig.Hazards
	local startedAt = os.clock()
	local done = false
	while not done do
		if not context.isLive() or gear.Parent == nil then
			return false
		end
		local alpha = math.clamp((os.clock() - startedAt) / hazards.DropFallTime, 0, 1)
		local height = hazards.DropHeight * (1 - alpha * alpha)
		gear:PivotTo(landing * CFrame.new(0, height, 0) * CFrame.Angles((1 - alpha) * FALL_SPINS * math.pi * 2, 0, 0))
		done = alpha >= 1
		if not done then
			RunService.Heartbeat:Wait()
		end
	end
	return true
end

-- Uma engrenagem à frente de `target` (um corredor).
function HazardGears.drop(context: Context, target: CombatantRegistry.Combatant)
	local root = CombatantRegistry.getRoot(target)
	if root == nil then
		return
	end
	local hazards = RaceConfig.Hazards
	local tower = context.tower
	local t = math.min(context.turnsAt(root.Position) + context.random:NextNumber(AHEAD_MIN, AHEAD_MAX), tower.spiral.turns - 0.05)
	local spot = tower.pointAt(t)
	local shadow = shadowAt(context, spot)
	task.delay(hazards.DropWarning, function()
		if not context.isLive() then
			return
		end
		local tangent = tower.tangentAt(t)
		local flat = Vector3.new(tangent.X, 0, tangent.Z).Unit
		-- Roda de pé, atravessada na rampa (o eixo ao longo da subida).
		local landing = CFrame.lookAt(spot, spot + flat) * CFrame.Angles(0, math.rad(90), 0) + Vector3.new(0, GEAR_RADIUS + 0.4, 0)
		local gear = HazardProps.gear(GEAR_RADIUS)
		gear:PivotTo(landing + Vector3.new(0, hazards.DropHeight, 0))
		gear.Parent = context.folder
		context.track(gear)
		local live = fall(context, gear, landing)
		shadow:Destroy()
		if not live then
			return
		end
		for _, combatant in ipairs(context.racers()) do
			local victimRoot = CombatantRegistry.getRoot(combatant)
			if victimRoot ~= nil then
				local offset = victimRoot.Position - spot
				local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if horizontal <= hazards.DropHitRadius and math.abs(offset.Y) <= HIT_HEIGHT then
					context.hit(combatant, t, "Gears")
				end
			end
		end
		fadeAndDestroy(gear)
	end)
end

return table.freeze(HazardGears)
