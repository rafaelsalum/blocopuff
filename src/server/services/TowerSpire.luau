--!strict

-- Alto da Torre do Relógio Encantada (Fase 5F): no meio do terraço, o bloco
-- do relógio com 4 mostradores (ClockFace) que marcam a hora de Brasília, os
-- pináculos dos cantos, o campanário aberto com o sino e o telhado cônico de
-- ardósia com a ponta dourada. O sino toca quando alguém chega ao topo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClockFace = require(ReplicatedStorage.Shared.modules.ClockFace)
local TowerKit = require(script.Parent.TowerKit)

-- "Church Bell Toll - Daily Sounds" (Creator Store, asset 87058958593472).
local BELL_SOUND_ID = "rbxassetid://87058958593472"
local BELL_VOLUME = 1.2
local BELL_ROLLOFF = 600

local STAGE_SIZE = 26
local STAGE_HEIGHT = 28
local FACE_DIAMETER = 18
local FACE_HEIGHT = 15
local FACE_PIXELS_PER_STUD = 24
local BELFRY_HEIGHT = 16
local BELFRY_PILLAR = 3
local ROOF_RADIUS = 15
local ROOF_HEIGHT = 34
local PINNACLE_RADIUS = 2.2
local PINNACLE_HEIGHT = 10
local CLOCK_UPDATE_SECONDS = 15
-- Hora de Brasília (UTC-3).
local CLOCK_UTC_OFFSET_HOURS = -3

local COLORS = TowerKit.COLORS
local part = TowerKit.part

local TowerSpire = {}

local function clockFace(parent: Instance, position: Vector3, normal: Vector3): SurfaceGui
	-- Aro de madeira escura atrás do mostrador (eixo do cilindro = normal).
	local rim = part(parent, "ClockRim", Vector3.new(0.8, FACE_DIAMETER + 2, FACE_DIAMETER + 2), CFrame.fromMatrix(position, normal, Vector3.yAxis), COLORS.clockRim, Enum.Material.Wood)
	rim.Shape = Enum.PartType.Cylinder
	TowerKit.decor(rim)
	local facePosition = position + normal * 0.5
	local plate = part(parent, "ClockPlate", Vector3.new(FACE_DIAMETER, FACE_DIAMETER, 0.2), CFrame.lookAt(facePosition, facePosition + normal), COLORS.stoneLight, Enum.Material.SmoothPlastic)
	plate.Transparency = 1
	TowerKit.decor(plate)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ClockGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = FACE_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Parent = plate
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	ClockFace.draw(holder, 1)
	return gui
end

local function startClock(model: Instance, faces: { SurfaceGui })
	task.spawn(function()
		while model.Parent ~= nil do
			local now = os.date("!*t", os.time() + CLOCK_UTC_OFFSET_HOURS * 3600)
			for _, face in ipairs(faces) do
				ClockFace.set(face, now.hour % 12, now.min)
			end
			task.wait(CLOCK_UPDATE_SECONDS)
		end
	end)
end

local function buildBelfry(model: Instance, base: Vector3): BasePart
	local half = STAGE_SIZE / 2 - BELFRY_PILLAR / 2 - 1
	for _, corner in ipairs({ Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) }) do
		local foot = base + corner * half
		TowerKit.decor(part(model, "BelfryPillar", Vector3.new(BELFRY_PILLAR, BELFRY_HEIGHT, BELFRY_PILLAR), CFrame.new(foot + Vector3.new(0, BELFRY_HEIGHT / 2, 0)), COLORS.stoneLight, Enum.Material.Cobblestone))
	end
	local roofBase = base + Vector3.new(0, BELFRY_HEIGHT, 0)
	TowerKit.decor(part(model, "BelfryCap", Vector3.new(STAGE_SIZE, 1.5, STAGE_SIZE), CFrame.new(roofBase + Vector3.new(0, 0.75, 0)), COLORS.stoneDark, Enum.Material.Cobblestone))
	TowerKit.decor(TowerKit.cone(model, "Roof", ROOF_RADIUS, ROOF_HEIGHT, roofBase + Vector3.new(0, 1.5, 0), COLORS.roof, Enum.Material.Slate))
	local tip = roofBase + Vector3.new(0, 1.5 + ROOF_HEIGHT, 0)
	TowerKit.decor(part(model, "Finial", Vector3.new(0.6, 8, 0.6), CFrame.new(tip + Vector3.new(0, 3, 0)), COLORS.gold, Enum.Material.Metal))
	local orb = part(model, "FinialOrb", Vector3.new(1.6, 1.6, 1.6), CFrame.new(tip + Vector3.new(0, 7, 0)), COLORS.gold, Enum.Material.Metal)
	orb.Shape = Enum.PartType.Ball
	TowerKit.decor(orb)

	local bell = part(model, "Bell", Vector3.new(6, 6, 6), CFrame.new(base + Vector3.new(0, BELFRY_HEIGHT - 6, 0)), COLORS.gold, Enum.Material.Metal)
	bell.Shape = Enum.PartType.Ball
	TowerKit.decor(bell)
	TowerKit.decor(part(model, "BellRope", Vector3.new(0.4, 3, 0.4), CFrame.new(base + Vector3.new(0, BELFRY_HEIGHT - 1.5, 0)), COLORS.wood, Enum.Material.Wood))
	local light = Instance.new("PointLight")
	light.Color = COLORS.window
	light.Range = 32
	light.Brightness = 2
	light.Parent = bell
	local sound = Instance.new("Sound")
	sound.Name = "Toll"
	sound.SoundId = BELL_SOUND_ID
	sound.Volume = BELL_VOLUME
	sound.RollOffMaxDistance = BELL_ROLLOFF
	sound.Parent = bell
	return bell
end

-- Monta o alto da torre com o chão do terraço em `top`. Devolve o sino.
function TowerSpire.build(parent: Instance, top: Vector3): BasePart
	local model = Instance.new("Model")
	model.Name = "ClockSpire"
	local stageCenter = top + Vector3.new(0, STAGE_HEIGHT / 2, 0)
	part(model, "ClockStage", Vector3.new(STAGE_SIZE, STAGE_HEIGHT, STAGE_SIZE), CFrame.new(stageCenter), COLORS.stone, Enum.Material.Cobblestone)
	TowerKit.decor(part(model, "StageCornice", Vector3.new(STAGE_SIZE + 2, 1.5, STAGE_SIZE + 2), CFrame.new(top + Vector3.new(0, STAGE_HEIGHT - 0.75, 0)), COLORS.stoneDark, Enum.Material.Cobblestone))
	TowerKit.decor(part(model, "StagePlinth", Vector3.new(STAGE_SIZE + 2, 2, STAGE_SIZE + 2), CFrame.new(top + Vector3.new(0, 1, 0)), COLORS.stoneDark, Enum.Material.Cobblestone))

	local faces: { SurfaceGui } = {}
	for _, normal in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
		local position = top + Vector3.new(0, FACE_HEIGHT, 0) + normal * (STAGE_SIZE / 2 + 0.4)
		table.insert(faces, clockFace(model, position, normal))
	end
	local stageTop = top + Vector3.new(0, STAGE_HEIGHT, 0)
	local half = STAGE_SIZE / 2
	for _, corner in ipairs({ Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) }) do
		TowerKit.decor(TowerKit.cone(model, "Pinnacle", PINNACLE_RADIUS, PINNACLE_HEIGHT, stageTop + corner * half, COLORS.roof, Enum.Material.Slate))
	end
	local bell = buildBelfry(model, stageTop)
	model.Parent = parent
	startClock(model, faces)
	return bell
end

-- Badalada do sino (se o som existir).
function TowerSpire.ring(bell: BasePart?)
	if bell == nil then
		return
	end
	local sound = bell:FindFirstChild("Toll")
	if sound ~= nil and sound:IsA("Sound") then
		sound.TimePosition = 0
		sound:Play()
	end
end

return table.freeze(TowerSpire)
