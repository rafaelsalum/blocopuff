--!strict

-- Portas trancadas do Casarão (Fase 5C.1): em cada vão trancado, uma
-- barreira invisível (com colisão para todo mundo no servidor) e uma placa
-- com o cadeado do lado de fora ("🔒 CHAVE DE LATÃO", "🔒 NÍVEL 10"). A porta
-- dupla do vão ganha o id da tranca, para o cliente só abrir uma fresta. O
-- cliente de quem tem acesso tira a colisão da barreira
-- (MansionLockController). Chamado pelo MansionWing, depois das portas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionLockConfig = require(ReplicatedStorage.Shared.config.MansionLockConfig)
local MansionLockLayout = require(ReplicatedStorage.Shared.modules.MansionLockLayout)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local MansionPlaque = require(script.Parent.MansionPlaque)

type BuildingConfig = GameConfig.BuildingConfig

local BARRIER_THICKNESS = 0.6
-- A placa do cadeado fica acima da placa com o nome do cômodo.
local PADLOCK_LIFT = 2.2

local MansionLocks = {}

local function barrier(parent: Instance, spot: MansionLockLayout.LockSpot)
	local doorway = spot.doorway
	local size = doorway.size
	local barrierPart = Instance.new("Part")
	barrierPart.Name = `{doorway.name}LockBarrier`
	barrierPart.Size = Vector3.new(size.X, size.Y, BARRIER_THICKNESS)
	barrierPart.CFrame = CFrame.fromMatrix(doorway.center + Vector3.new(0, size.Y / 2, 0), doorway.along, Vector3.yAxis)
	barrierPart.Anchored = true
	barrierPart.CanCollide = true
	barrierPart.CanQuery = false
	barrierPart.CanTouch = false
	barrierPart.Transparency = 1
	barrierPart.CastShadow = false
	barrierPart:SetAttribute(MansionLockConfig.LockAttribute, spot.info.id)
	barrierPart.Parent = parent
end

local function padlockPlaque(parent: Instance, spot: MansionLockLayout.LockSpot, depth: number, style: BuildingConfig)
	local doorway = spot.doorway
	local inward = doorway.normal * spot.outside
	local along = inward:Cross(Vector3.yAxis)
	local y = doorway.center.Y + doorway.size.Y + MansionPlaque.Lift + PADLOCK_LIFT
	local position = Vector3.new(doorway.center.X, y, doorway.center.Z) + inward * (depth + 0.55)
	MansionPlaque.create(parent, `{doorway.name}Padlock`, CFrame.fromMatrix(position, along, Vector3.yAxis), Lang.t(spot.info.label), style)
end

function MansionLocks.build(wingModel: Instance, style: BuildingConfig)
	local folder = Instance.new("Folder")
	folder.Name = "MansionLocks"
	for _, spot in ipairs(MansionLockLayout.all()) do
		barrier(folder, spot)
		-- As portas internas ficam numa divisória; a da Sala dos Troféus, na
		-- parede externa da ala.
		local internal = spot.doorway.normal == Vector3.zAxis
		padlockPlaque(folder, spot, if internal then MansionConfig.PartitionThickness / 2 else GameConfig.Building.WallThickness / 2, style)
		for _, descendant in ipairs(wingModel:GetDescendants()) do
			if descendant:IsA("Model") and descendant.Name == spot.doorway.name then
				descendant:SetAttribute(MansionLockConfig.LockAttribute, spot.info.id)
			end
		end
	end
	folder.Parent = wingModel
end

return table.freeze(MansionLocks)
