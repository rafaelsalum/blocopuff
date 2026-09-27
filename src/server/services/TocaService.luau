--!strict

-- Tocas Seguras: nichos nos corredores secretos, para um jogador por vez.
-- Quem está numa Toca fica protegido do Barão, mas não do Puffador dos
-- outros: um empurrão tira o ocupante do nicho e a Toca fica livre. Para
-- não virar esconderijo permanente, cada ocupação dura no máximo
-- GameConfig.Toca.MaxStay segundos; depois o ocupante é empurrado para o
-- corredor e passa um tempo sem poder usar Tocas.
--
-- A luz sobre a boca de cada Toca mostra o estado: verde livre, laranja
-- ocupada. O ocupante recebe avisos pelo remote de feedback do Puffador.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local CorridorBuilder = require(script.Parent.CorridorBuilder)

type Toca = BuildingLayout.Toca

export type Sender = (player: Player, kind: string, value: any) -> ()

type TocaState = {
	toca: Toca,
	lamp: BasePart?,
	occupant: Player?,
	enteredAt: number,
	warned: boolean,
}

local FREE_COLOR = Color3.fromRGB(110, 230, 130)
local BUSY_COLOR = Color3.fromRGB(255, 150, 60)

local TocaService = {}

local started = false
local active = false
local roundId = 0
local states: { TocaState } = {}
local cooldownUntil: { [Player]: number } = {}
local sendToPlayer: Sender? = nil
local heartbeat: RBXScriptConnection? = nil
local playerRemoving: RBXScriptConnection? = nil

local function isActiveParticipant(player: Player): boolean
	return active
		and player.Parent ~= nil
		and player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) == roundId
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == false
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function send(player: Player, kind: string, value: any)
	local sender = sendToPlayer
	if sender ~= nil then
		sender(player, kind, value)
	end
end

local function paint(state: TocaState)
	local lamp = state.lamp
	if lamp == nil then
		return
	end
	local color = if state.occupant ~= nil then BUSY_COLOR else FREE_COLOR
	lamp.Color = color
	local light = lamp:FindFirstChildOfClass("PointLight")
	if light ~= nil then
		light.Color = color
	end
end

local function release(state: TocaState)
	state.occupant = nil
	state.warned = false
	paint(state)
end

local function occupiedToca(player: Player): TocaState?
	for _, state in ipairs(states) do
		if state.occupant == player then
			return state
		end
	end
	return nil
end

-- Fim do tempo: empurra o ocupante para o meio do corredor e aplica o
-- tempo de espera antes de poder usar outra Toca.
local function eject(state: TocaState, player: Player, now: number)
	release(state)
	cooldownUntil[player] = now + GameConfig.Toca.Cooldown
	local config = GameConfig.Toca
	local velocity = (state.toca.corridor.inward * config.EjectSpeed) + Vector3.new(0, config.EjectSpeed * 0.35, 0)
	send(player, "Knockback", velocity)
	send(player, "TocaEject", config.Cooldown)
end

local function updateOccupied(state: TocaState, player: Player, now: number)
	local root = getRoot(player)
	if not isActiveParticipant(player) or root == nil or not BuildingLayout.isInsideToca(state.toca, root.Position) then
		release(state)
		send(player, "TocaLeave", 0)
		return
	end
	local config = GameConfig.Toca
	local elapsed = now - state.enteredAt
	if elapsed >= config.MaxStay then
		eject(state, player, now)
	elseif not state.warned and elapsed >= config.MaxStay - config.WarningAt then
		state.warned = true
		send(player, "TocaWarning", math.ceil(config.MaxStay - elapsed))
	end
end

-- A primeira pessoa válida dentro de uma Toca livre passa a ocupá-la. Quem
-- ainda está no tempo de espera não ocupa (e continua vulnerável ao Barão).
local function claim(state: TocaState, candidates: { [Player]: Vector3 }, now: number)
	for player, position in pairs(candidates) do
		local waitUntil = cooldownUntil[player]
		local canUse = waitUntil == nil or now >= waitUntil
		if canUse and occupiedToca(player) == nil and BuildingLayout.isInsideToca(state.toca, position) then
			state.occupant = player
			state.enteredAt = now
			state.warned = false
			paint(state)
			send(player, "TocaEnter", GameConfig.Toca.MaxStay)
			return
		end
	end
end

local function step()
	local now = os.clock()
	for _, state in ipairs(states) do
		local occupant = state.occupant
		if occupant ~= nil then
			updateOccupied(state, occupant, now)
		end
	end

	local candidates: { [Player]: Vector3 } = {}
	local any = false
	for _, player in ipairs(Players:GetPlayers()) do
		if isActiveParticipant(player) and occupiedToca(player) == nil then
			local root = getRoot(player)
			if root ~= nil then
				candidates[player] = root.Position
				any = true
			end
		end
	end
	if not any then
		return
	end
	for _, state in ipairs(states) do
		if state.occupant == nil then
			claim(state, candidates, now)
		end
	end
end

-- Verdadeiro se o jogador está ocupando uma Toca agora (o Barão o ignora).
function TocaService.isProtected(player: Player): boolean
	return active and occupiedToca(player) ~= nil
end

function TocaService.beginRound(newRoundId: number)
	roundId = newRoundId
	active = true
	table.clear(cooldownUntil)
	for _, state in ipairs(states) do
		release(state)
	end
end

function TocaService.endRound()
	active = false
	for _, state in ipairs(states) do
		release(state)
	end
	table.clear(cooldownUntil)
end

function TocaService.start(world: Instance, sender: Sender)
	if started then
		return
	end
	started = true
	sendToPlayer = sender

	local lamps: { [string]: BasePart } = {}
	for _, instance in ipairs(CollectionService:GetTagged(CorridorBuilder.TocaLampTag)) do
		local name = instance:GetAttribute("TocaName")
		if instance:IsA("BasePart") and typeof(name) == "string" and instance:IsDescendantOf(world) then
			lamps[name] = instance
		end
	end

	for _, corridor in ipairs(BuildingLayout.getCorridors(GameConfig.Arena, GameConfig.Building)) do
		for _, toca in ipairs(BuildingLayout.getTocas(corridor, GameConfig.Building)) do
			local lamp = lamps[toca.name]
			if lamp == nil then
				warn(string.format("[BlocoPuff] Toca %s has no lamp", toca.name))
			end
			local state: TocaState = { toca = toca, lamp = lamp, occupant = nil, enteredAt = 0, warned = false }
			table.insert(states, state)
			paint(state)
		end
	end

	-- Todo quadro, no mesmo ritmo do Barão: quem mergulha na Toca fica
	-- protegido antes do próximo teste de contato dele.
	heartbeat = RunService.Heartbeat:Connect(function()
		if active then
			step()
		end
	end)

	playerRemoving = Players.PlayerRemoving:Connect(function(player: Player)
		cooldownUntil[player] = nil
		local state = occupiedToca(player)
		if state ~= nil then
			release(state)
		end
	end)
end

function TocaService.stop()
	active = false
	local connection = heartbeat
	if connection ~= nil then
		connection:Disconnect()
		heartbeat = nil
	end
	local removing = playerRemoving
	if removing ~= nil then
		removing:Disconnect()
		playerRemoving = nil
	end
	for _, state in ipairs(states) do
		release(state)
	end
	table.clear(states)
	table.clear(cooldownUntil)
	sendToPlayer = nil
	started = false
end

return table.freeze(TocaService)
