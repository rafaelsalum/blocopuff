--!strict

-- Recebe do servidor os disparos para desenhar (remote "PuffShots") e
-- repassa ao PuffShotRenderer:
--   "Fired", id, dono, cano, origem da mira, direção, Puff, cor
--   "Ended", id, distância, ponto do impacto?, normal?
--   "Clear"
-- O disparo do próprio jogador é desenhado na hora do clique (predict), sem
-- esperar o servidor; quando o "Fired" dele chega, só é ligado ao id.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PuffShotRenderer = require(script.Parent.Parent.effects.PuffShotRenderer)

type Shot = PuffShotRenderer.Shot

local WAIT_TIMEOUT = 15
-- Disparos previstos esperando a confirmação do servidor.
local PENDING_SECONDS = 2
local MAX_PENDING = 4
-- Mesma direção (cosseno do ângulo entre a prevista e a confirmada).
local MATCH_DOT = 0.98

type Pending = { shot: Shot, clock: number }

local PuffShotController = {}

local started = false
local pending: { Pending } = {}

local function isVector3(value: unknown): boolean
	return typeof(value) == "Vector3"
end

-- O disparo previsto que corresponde ao confirmado pelo servidor: o mais
-- antigo ainda recente e na mesma direção (um previsto que o servidor
-- recusou não rouba a confirmação do próximo).
local function takePending(direction: Vector3): Shot?
	local now = os.clock()
	for index = #pending, 1, -1 do
		if now - pending[index].clock > PENDING_SECONDS then
			table.remove(pending, index)
		end
	end
	for index, entry in ipairs(pending) do
		if entry.shot.direction:Dot(direction) >= MATCH_DOT then
			table.remove(pending, index)
			return entry.shot
		end
	end
	return nil
end

local function onFired(id: unknown, ownerUserId: unknown, origin: unknown, aimOrigin: unknown, direction: unknown, puffId: unknown, color: unknown)
	if typeof(id) ~= "number" or typeof(ownerUserId) ~= "number" then
		return
	end
	if not isVector3(origin) or not isVector3(aimOrigin) or not isVector3(direction) or typeof(color) ~= "Color3" then
		return
	end
	local localPlayer = Players.LocalPlayer
	if localPlayer ~= nil and ownerUserId == localPlayer.UserId then
		local predicted = takePending(direction :: Vector3)
		if predicted ~= nil then
			PuffShotRenderer.bind(predicted, id, color :: Color3)
			return
		end
	end
	local shot = PuffShotRenderer.spawn({
		ownerUserId = ownerUserId :: number,
		origin = origin :: Vector3,
		aimOrigin = aimOrigin :: Vector3,
		direction = direction :: Vector3,
		puffId = if typeof(puffId) == "string" then puffId else "",
		color = color :: Color3,
	}, false)
	if shot ~= nil then
		PuffShotRenderer.bind(shot, id, color :: Color3)
	end
end

local function onMessage(kind: unknown, ...: unknown)
	if kind == "Fired" then
		onFired(...)
	elseif kind == "Ended" then
		local id, distance, position, normal = ...
		if typeof(id) == "number" and typeof(distance) == "number" then
			local impact = if isVector3(position) and isVector3(normal) then position :: Vector3 else nil
			PuffShotRenderer.ended(id, distance, impact, if impact ~= nil then normal :: Vector3 else nil)
		end
	elseif kind == "Clear" then
		table.clear(pending)
		PuffShotRenderer.clear()
	end
end

-- Desenha o disparo do próprio jogador na hora (o servidor confirma depois).
function PuffShotController.predict(origin: Vector3, aimOrigin: Vector3, aimTarget: Vector3, color: Color3)
	local player = Players.LocalPlayer
	local delta = aimTarget - aimOrigin
	if player == nil or delta.Magnitude < 1e-3 then
		return
	end
	-- Eliminado não dispara (o servidor recusaria): nada de disparo fantasma.
	if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == true then
		return
	end
	local puffId = player:GetAttribute(StateAttributeNames.PlayerEquippedPuff)
	local shot = PuffShotRenderer.spawn({
		ownerUserId = player.UserId,
		origin = origin,
		aimOrigin = aimOrigin,
		direction = delta.Unit,
		puffId = if typeof(puffId) == "string" then puffId else "",
		color = color,
	}, true)
	if shot == nil then
		return
	end
	if #pending >= MAX_PENDING then
		table.remove(pending, 1)
	end
	table.insert(pending, { shot = shot, clock = os.clock() })
end

function PuffShotController.start()
	if started then
		return
	end
	started = true
	PuffShotRenderer.start()
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local remote = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.PuffShotsRemoteName, WAIT_TIMEOUT) else nil
		if remote == nil or not remote:IsA("RemoteEvent") then
			warn("[BlocoPuff] Puff shots remote not found")
			return
		end
		remote.OnClientEvent:Connect(onMessage)
	end)
end

return table.freeze(PuffShotController)
