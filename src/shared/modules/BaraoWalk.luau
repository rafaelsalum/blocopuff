--!strict

-- Passeio do Barão do Jardim (Fase 5C.4): sai da caminha, passa pelo arco
-- norte até o Salão da Coleção, volta pelo Jardim, espia o Salão Principal
-- pelo arco do meio e volta a dormir. Sempre pelo meio dos arcos e longe
-- dos móveis; ele não colide com ninguém (não atrapalha a passagem).
--
-- O servidor publica só o início do passeio (horário do servidor) e a
-- pausa do carinho, em atributos do modelo; servidor (aviso de carinho) e
-- cliente (animação) calculam a mesma posição com `pose`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionLifeConfig = require(ReplicatedStorage.Shared.config.MansionLifeConfig)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local WalkPath = require(ReplicatedStorage.Shared.modules.WalkPath)

export type Waypoint = {
	position: Vector3,
	-- Parada (s) ao chegar: cheira o chão e olha em volta.
	wait: number,
}

export type Route = {
	points: { Waypoint },
	legs: { WalkPath.Leg },
	duration: number,
}

local CONFIG = MansionLifeConfig.Barao
-- Altura da caminha: ele dorme em cima dela.
local BED_LIFT = 0.6
local SNIFF = 2.5
local LOOK = 1.5
local SETTLE = 1
-- Distâncias (studs) dos pontos do passeio até os arcos e paredes.
local STEP_OFF = 4.5
local ARCH_CLEAR = 6
local ROOM_DEPTH = 10
local COLLECTION_WALK = 18
local HALL_DEPTH = 10
local SIDE_STEP = 3

local BaraoWalk = {}

local cached: Route? = nil

-- Centro da caminha, no piso.
function BaraoWalk.bedBase(): Vector3
	return MansionLayout.roomCenter("Garden")
end

-- De frente para o arco do Salão Principal (−X); o modelo olha para −Z.
function BaraoWalk.restCFrame(): CFrame
	return CFrame.new(BaraoWalk.bedBase() + Vector3.new(0, BED_LIFT, 0)) * CFrame.Angles(0, math.pi / 2, 0)
end

function BaraoWalk.route(): Route
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local mansion = MansionLayout.get()
	local garden = MansionLayout.room("Garden")
	local bed = BaraoWalk.bedBase()
	local floorY = mansion.floorY
	local northArchX = (garden.minX + garden.maxX) / 2
	local northWall = garden.minZ
	local hallEast = garden.minX
	local centerZ = bed.Z
	local function at(x: number, z: number, wait: number?): Waypoint
		return { position = Vector3.new(x, floorY, z), wait = wait or 0 }
	end
	local points: { Waypoint } = {
		{ position = bed + Vector3.new(0, BED_LIFT, 0), wait = 0 },
		at(bed.X - STEP_OFF, centerZ),
		at(northArchX, northWall + ARCH_CLEAR),
		at(northArchX, northWall - ROOM_DEPTH, SNIFF),
		at(northArchX - COLLECTION_WALK, northWall - ROOM_DEPTH, SNIFF),
		at(northArchX, northWall - ROOM_DEPTH + 1),
		at(northArchX - SIDE_STEP, northWall + ARCH_CLEAR, LOOK),
		at(hallEast + ARCH_CLEAR, centerZ),
		at(hallEast - HALL_DEPTH, centerZ, SNIFF),
		at(hallEast + ARCH_CLEAR, centerZ + SIDE_STEP),
		at(bed.X - STEP_OFF, centerZ),
		{ position = bed + Vector3.new(0, BED_LIFT, 0), wait = 0 },
		-- Trecho parado em cima da caminha: vira para o arco (−X, a frente
		-- de quando dorme) antes de deitar.
		{ position = bed + Vector3.new(0, BED_LIFT, 0), wait = SETTLE },
	}
	local legs: { WalkPath.Leg } = {}
	for index = 2, #points do
		local from = points[index - 1].position
		local to = points[index].position
		table.insert(legs, { length = Vector2.new(to.X - from.X, to.Z - from.Z).Magnitude, wait = points[index].wait })
	end
	local route: Route = { points = points, legs = legs, duration = WalkPath.duration(legs, CONFIG.Speed) }
	cached = route
	return route
end

-- Tempo de passeio a partir dos atributos do modelo (nil: dormindo).
function BaraoWalk.elapsed(model: Instance, serverNow: number): number?
	local start = model:GetAttribute(CONFIG.StartAttribute)
	if typeof(start) ~= "number" or start <= 0 then
		return nil
	end
	local pause = model:GetAttribute(CONFIG.PauseAttribute)
	if typeof(pause) == "number" and pause >= 0 then
		return pause
	end
	return serverNow - start
end

-- Onde ele está `elapsed` segundos depois de sair da caminha: CFrame da
-- raiz (olhando para onde anda), se está andando (não parado cheirando) e
-- se o passeio acabou.
function BaraoWalk.pose(route: Route, elapsed: number): (CFrame, boolean, boolean)
	local spot = WalkPath.locate(route.legs, CONFIG.Speed, elapsed)
	local from = route.points[spot.leg].position
	local to = route.points[spot.leg + 1].position
	local position = from:Lerp(to, spot.fraction)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	-- Trecho sem comprimento (girar no lugar): olha para o arco (−X).
	local direction = if flat.Magnitude > 0.01 then flat.Unit else -Vector3.xAxis
	return CFrame.lookAt(position, position + direction), not spot.waiting and not spot.done, spot.done
end

return table.freeze(BaraoWalk)
