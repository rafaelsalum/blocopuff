--!strict

-- Olhos dos retratos da família Puff (Fase 5C.4, parte 2): as pupilas
-- seguem o seu personagem quando você passa na frente e, de vez em quando,
-- o retrato pisca. Só anima o que está perto; longe, nada roda.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MansionAmbienceConfig = require(ReplicatedStorage.Shared.config.MansionAmbienceConfig)
local AmbienceMath = require(ReplicatedStorage.Shared.modules.AmbienceMath)

local TUNING = MansionAmbienceConfig.Portrait
-- Folga (studs) somada à distância no cálculo do olhar: perto da tela o
-- olho não "vira" de uma vez.
local DEPTH_SOFTEN = 2.5
-- Além do alcance do olhar, um pouco de folga para as pupilas voltarem ao
-- centro antes de parar de animar.
local ACTIVE_MARGIN = 8
-- Abaixo disso (fração da tela) não vale reescrever a pupila.
local LOOK_EPSILON = 0.002
-- Tentativas de achar os olhos se a SurfaceGui chegar aos poucos.
local EYE_TRIES = 6
local EYE_RETRY = 0.5

type Eye = {
	pupil: Frame,
	lid: Frame,
}

type Entry = {
	canvas: BasePart,
	eyes: { Eye },
	look: Vector2,
	applied: Vector2,
	appliedClosed: number,
	nextBlink: number,
	blinkAt: number?,
}

local PortraitEyes = {}

local entries: { [BasePart]: Entry } = {}
local random = Random.new()

local function eyesOf(canvas: BasePart): { Eye }
	local list: { Eye } = {}
	local gui = canvas:FindFirstChildOfClass("SurfaceGui")
	local art = if gui ~= nil then gui:FindFirstChild("Art") else nil
	if art == nil then
		return list
	end
	for _, name in ipairs({ "EyeL", "EyeR" }) do
		local white = art:FindFirstChild(name)
		local pupil = if white ~= nil then white:FindFirstChild("Pupil") else nil
		local lid = if white ~= nil then white:FindFirstChild("Lid") else nil
		if pupil ~= nil and pupil:IsA("Frame") and lid ~= nil and lid:IsA("Frame") then
			table.insert(list, { pupil = pupil, lid = lid })
		end
	end
	return list
end

function PortraitEyes.add(instance: Instance)
	if not instance:IsA("BasePart") or entries[instance] ~= nil then
		return
	end
	-- A SurfaceGui pode chegar um pouco depois da peça.
	local gui = instance:FindFirstChildOfClass("SurfaceGui") or instance:WaitForChild("Portrait", 10)
	if gui == nil or instance.Parent == nil then
		return
	end
	local eyes = eyesOf(instance)
	for _ = 1, EYE_TRIES do
		if #eyes > 0 or instance.Parent == nil then
			break
		end
		task.wait(EYE_RETRY)
		eyes = eyesOf(instance)
	end
	-- A tag pode ter saído enquanto esperava (remove já passou).
	if #eyes == 0 or instance.Parent == nil or entries[instance] ~= nil or not CollectionService:HasTag(instance, TUNING.Tag) then
		return
	end
	entries[instance] = {
		canvas = instance,
		eyes = eyes,
		look = Vector2.zero,
		applied = Vector2.zero,
		appliedClosed = 0,
		nextBlink = os.clock() + random:NextNumber(TUNING.BlinkMin, TUNING.BlinkMax),
		blinkAt = nil,
	}
end

function PortraitEyes.remove(instance: Instance)
	if instance:IsA("BasePart") then
		entries[instance] = nil
	end
end

local function target(): Vector3?
	local character = Players.LocalPlayer.Character
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	if head ~= nil and head:IsA("BasePart") then
		return head.Position
	end
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.CFrame.Position else nil
end

-- Para onde o retrato olha (−1..1 em cada eixo da tela).
local function lookFor(canvas: BasePart, position: Vector3?): Vector2
	if position == nil then
		return Vector2.zero
	end
	local relative = canvas.CFrame:PointToObjectSpace(position)
	local x, y = AmbienceMath.lookOffset(relative.X, relative.Y, relative.Z, TUNING.FollowDistance, DEPTH_SOFTEN)
	return Vector2.new(x, y)
end

local function blinkAmount(entry: Entry, clock: number): number
	local started = entry.blinkAt
	if started == nil then
		if clock >= entry.nextBlink then
			entry.blinkAt = clock
		end
		return 0
	end
	local t = (clock - started) / TUNING.BlinkTime
	if t >= 2 then
		entry.blinkAt = nil
		entry.nextBlink = clock + random:NextNumber(TUNING.BlinkMin, TUNING.BlinkMax)
		return 0
	end
	return if t <= 1 then t else 2 - t
end

-- Perto e à frente da câmera (atrás dela ninguém vê o retrato).
local function active(canvas: BasePart, camera: CFrame): boolean
	local offset = canvas.Position - camera.Position
	return offset.Magnitude <= TUNING.FollowDistance + ACTIVE_MARGIN and camera.LookVector:Dot(offset) > -2
end

-- Só mexe na SurfaceGui quando o olhar ou a pálpebra mudaram.
local function apply(entry: Entry, closed: number)
	if (entry.look - entry.applied).Magnitude >= LOOK_EPSILON then
		entry.applied = entry.look
		local offset = entry.look * TUNING.PupilTravel
		for _, eye in ipairs(entry.eyes) do
			eye.pupil.Position = UDim2.fromScale(0.5 + offset.X, 0.5 + offset.Y)
		end
	end
	if closed ~= entry.appliedClosed then
		entry.appliedClosed = closed
		for _, eye in ipairs(entry.eyes) do
			eye.lid.Size = UDim2.fromScale(1.1, closed * 1.05)
		end
	end
end

function PortraitEyes.step(dt: number, camera: CFrame)
	local clock = os.clock()
	local position = target()
	for canvas, entry in pairs(entries) do
		if canvas.Parent == nil then
			entries[canvas] = nil
			continue
		end
		if not active(canvas, camera) then
			continue
		end
		local goal = lookFor(canvas, position)
		entry.look = entry.look:Lerp(goal, 1 - math.exp(-dt * TUNING.FollowRate))
		apply(entry, blinkAmount(entry, clock))
	end
end

return table.freeze(PortraitEyes)
