--!strict

-- Geometria de uma janela-armadilha (Fase 5), igual no servidor e no
-- cliente: o ponto do piso junto da parede bem embaixo da janela, as
-- direções para dentro da sala e ao longo da parede, e as áreas das
-- variações (faixa dos Pombos e chão molhado da Chuva).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)

local CONFIG = TrapConfig.Window
-- Abaixo do piso que ainda conta como "no chão" (pés afundando um pouco).
local BELOW_FLOOR = 1

export type Frame = {
	-- Ponto no piso, junto da parede, bem embaixo da janela.
	base: Vector3,
	inward: Vector3,
	along: Vector3,
	floor: number,
}

local WindowGeometry = {}

function WindowGeometry.frameOf(glass: BasePart): Frame?
	local floor = glass:GetAttribute(TrapConstants.FloorAttribute)
	local inwardValue = glass:GetAttribute(TrapConstants.InwardAttribute)
	if typeof(floor) ~= "number" or typeof(inwardValue) ~= "Vector3" then
		return nil
	end
	local flat = Vector3.new(inwardValue.X, 0, inwardValue.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	local inward = flat.Unit
	local floorY = BuildingLayout.getFloorSurfaceY(GameConfig.Arena, floor)
	return {
		base = Vector3.new(glass.Position.X, floorY, glass.Position.Z),
		inward = inward,
		along = inward:Cross(Vector3.yAxis),
		floor = floor,
	}
end

-- Distância para dentro da sala, distância ao longo da parede e altura
-- acima do piso de `position`.
function WindowGeometry.local3(frame: Frame, position: Vector3): (number, number, number)
	local offset = position - frame.base
	return offset:Dot(frame.inward), offset:Dot(frame.along), offset.Y
end

-- Dentro da faixa reta por onde o bando de pombos passa.
function WindowGeometry.inPigeonLane(frame: Frame, position: Vector3): boolean
	local depth, lateral, height = WindowGeometry.local3(frame, position)
	return depth >= 0
		and depth <= CONFIG.PigeonLaneLength
		and math.abs(lateral) <= CONFIG.PigeonLaneWidth / 2
		and height >= -BELOW_FLOOR
		and height <= CONFIG.PigeonLaneHeight
end

-- Dentro do chão molhado em frente à janela da Chuva.
function WindowGeometry.inRain(frame: Frame, position: Vector3): boolean
	local depth, lateral, height = WindowGeometry.local3(frame, position)
	return depth >= 0
		and depth <= CONFIG.RainLength
		and math.abs(lateral) <= CONFIG.RainWidth / 2
		and height >= -BELOW_FLOOR
		and height <= CONFIG.RainHeight
end

-- Variação da rodada (a Ventania, se ainda não foi sorteada).
function WindowGeometry.variantOf(glass: BasePart): TrapConfig.WindowVariant
	local value = glass:GetAttribute(TrapConstants.WindowVariantAttribute)
	if value == "Pigeons" or value == "Rain" then
		return value
	end
	return "Gust"
end

return table.freeze(WindowGeometry)
