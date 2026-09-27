--!strict

-- Barão, o mascote que guarda os corredores secretos. Há um só Barão por
-- rodada: ele começa dormindo no patamar de baixo de um corredor, acorda
-- no instante sorteado pelo RoundService (o mesmo em que o cofre destranca)
-- e passa a patrulhar. Quando alguém abre o cofre ele fica bravo por um
-- tempo: late mais e corre um pouco mais. Quando
-- vê alguém no mesmo corredor, persegue; se só houver gente no outro
-- corredor por um tempo, ele reaparece lá, pela ponta oposta.
--
-- O Barão anda numa linha ao longo do corredor (com um pouco de desvio
-- lateral para alcançar quem cola na parede) e segue a altura do piso,
-- inclusive na rampa. Ao encostar em alguém, dá um empurrão forte para
-- longe dele, na direção de uma das saídas, e toca um som engraçado. Não há
-- dano. Quem está na Toca Segura é ignorado, e dá para pular por cima dele:
-- o contato só conta com os pés abaixo de JumpClearance.
--
-- A única pista é o som: passos em loop e latidos em intervalos
-- irregulares, com áudio 3D na peça do corpo (sem indicador de distância).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local BaraoModel = require(script.Parent.BaraoModel)
local TocaService = require(script.Parent.TocaService)

type Corridor = BuildingLayout.Corridor
type Mode = "Sleeping" | "Patrol" | "Chase" | "Pause"

export type Sender = (player: Player, kind: string, value: any) -> ()
-- Encontro (começou a perseguir alguém), contato (empurrou) e fuga ("Jump"
-- pulou por cima, "Run" escapou de uma perseguição sem ser pego).
export type EventKind = "Encounter" | "Contact" | "Escape"
export type EventListener = (kind: EventKind, player: Player, detail: string?) -> ()

type Intruder = {
	player: Player,
	root: BasePart,
	along: number,
	lateral: number,
}

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "BaraoService"
local STATE_ATTRIBUTE = "BaraoState"
-- UserId de quem o Barão está perseguindo (0 = ninguém); o cliente usa para
-- a trilha de tensão, que não diz direção nem distância.
local TARGET_ATTRIBUTE = "BaraoTarget"
local BARAO_TAG = "Barao"
local ESCAPE_MIN_CHASE = 3
local ENCOUNTER_COOLDOWN = 10
local JUMP_ESCAPE_COOLDOWN = 3
local EDGE_MARGIN = 1.6
local LATERAL_MARGIN = 1.2
local SLEEP_ALONG = -(BuildingLayout.CorridorHalfLength - 3)
local SLEEP_SINK = 0.9
-- Distância dos pés à raiz do personagem em pé (HipHeight 2 + metade da raiz).
local ROOT_TO_FEET = 3
local ARRIVE_DISTANCE = 0.6
local SNIFF_TIME = NumberRange.new(0.8, 2.2)
local SOUND_MIN_DISTANCE = 8
local SOUND_MAX_DISTANCE = 75

local BaraoService = {}

local started = false
local active = false
local roundId = 0
local model: Model? = nil
local soundPart: BasePart? = nil
local footsteps: Sound? = nil
local corridors: { Corridor } = {}
local sendToPlayer: Sender? = nil
local heartbeat: RBXScriptConnection? = nil
local playerRemoving: RBXScriptConnection? = nil
local random = Random.new()

local corridorIndex = 1
local along = SLEEP_ALONG
local lateral = 0
local facing = 1
local mode: Mode = "Sleeping"
local wakeAt = 0
local pauseUntil = 0
local patrolTarget = 0
local nextBarkAt = 0
local otherCorridorSince: number? = nil
local enragedUntil = 0
local lastContact: { [Player]: number } = {}
local eventListener: EventListener? = nil
local chaseTarget: Player? = nil
local chaseStartedAt = 0
local chaseCaught = false
local chaseJumped = false
local lastEncounter: { [Player]: number } = {}
local lastJumpEscape: { [Player]: number } = {}

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

local function laneCenter(): number
	return GameConfig.Building.WallThickness + (BuildingLayout.CorridorWidth / 2)
end

local function maxAlong(): number
	return BuildingLayout.CorridorHalfLength - EDGE_MARGIN
end

local function maxLateral(): number
	return (BuildingLayout.CorridorWidth / 2) - LATERAL_MARGIN
end

local function setMode(newMode: Mode)
	mode = newMode
	local current = model
	if current ~= nil then
		current:SetAttribute(STATE_ATTRIBUTE, newMode)
	end
end

local function emit(kind: EventKind, player: Player, detail: string?)
	local listener = eventListener
	if listener ~= nil then
		task.spawn(listener, kind, player, detail)
	end
end

local function setTargetAttribute(player: Player?)
	local current = model
	if current ~= nil then
		current:SetAttribute(TARGET_ATTRIBUTE, if player ~= nil then player.UserId else 0)
	end
end

-- Fim de uma perseguição: se durou o bastante e ninguém foi pego (nem
-- já contou como pulo), vale como fuga.
local function endChase(now: number)
	local previous = chaseTarget
	if previous ~= nil and not chaseCaught and not chaseJumped and now - chaseStartedAt >= ESCAPE_MIN_CHASE and previous.Parent ~= nil then
		emit("Escape", previous, "Run")
	end
	chaseTarget = nil
	chaseCaught = false
	chaseJumped = false
	setTargetAttribute(nil)
end

local function beginChase(player: Player, now: number)
	if chaseTarget == player then
		return
	end
	endChase(now)
	chaseTarget = player
	chaseStartedAt = now
	setTargetAttribute(player)
	local last = lastEncounter[player]
	if last == nil or now - last >= ENCOUNTER_COOLDOWN then
		lastEncounter[player] = now
		emit("Encounter", player, nil)
	end
end

local function playOneShot(soundId: string, speed: number, volume: number)
	local anchor = soundPart
	if anchor == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = SOUND_MIN_DISTANCE
	sound.RollOffMaxDistance = SOUND_MAX_DISTANCE
	sound.Parent = anchor
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function pick(list: { string }): string?
	if #list == 0 then
		return nil
	end
	return list[random:NextInteger(1, #list)]
end

-- Latido: um ou dois "au", com tom variado para não soar repetido.
local function bark()
	local soundId = pick(GameConfig.Barao.BarkSoundIds)
	if soundId == nil then
		return
	end
	local count = random:NextInteger(1, 2)
	for index = 1, count do
		task.delay((index - 1) * 0.28, function()
			if model ~= nil then
				playOneShot(soundId, random:NextNumber(1.35, 1.7), 0.9)
			end
		end)
	end
end

local function isEnraged(now: number): boolean
	return now < enragedUntil
end

local function scheduleBark(now: number)
	local range = if mode == "Chase" or isEnraged(now) then GameConfig.Barao.BarkIntervalChase else GameConfig.Barao.BarkIntervalPatrol
	nextBarkAt = now + random:NextNumber(range.Min, range.Max)
end

local function worldPosition(corridor: Corridor, alongValue: number, lateralValue: number, floorY: number): Vector3
	local outward = -corridor.inward
	local flat = corridor.wallCenter + (corridor.along * alongValue) + (outward * (laneCenter() + lateralValue))
	return Vector3.new(flat.X, floorY, flat.Z)
end

-- Coloca o modelo no ponto atual, olhando para onde anda e inclinado na rampa.
local function place(bob: number)
	local current = model
	local corridor = corridors[corridorIndex]
	if current == nil or corridor == nil then
		return
	end
	local floorY = BuildingLayout.getCorridorFloorY(corridor, along)
	local sink = if mode == "Sleeping" then SLEEP_SINK else 0
	local position = worldPosition(corridor, along, lateral, floorY - sink + bob)
	local aheadY = BuildingLayout.getCorridorFloorY(corridor, along + facing)
	local look = (corridor.along * facing) + Vector3.new(0, aheadY - floorY, 0)
	current:PivotTo(CFrame.lookAt(position, position + look))
end

local function goToSleep()
	chaseTarget = nil
	chaseCaught = false
	chaseJumped = false
	setTargetAttribute(nil)
	table.clear(lastEncounter)
	table.clear(lastJumpEscape)
	corridorIndex = random:NextInteger(1, math.max(1, #corridors))
	along = SLEEP_ALONG
	lateral = 0
	facing = 1
	otherCorridorSince = nil
	table.clear(lastContact)
	setMode("Sleeping")
	local steps = footsteps
	if steps ~= nil then
		steps.Playing = false
	end
	place(0)
end

local function readIntruders(corridor: Corridor): { Intruder }
	local found: { Intruder } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if isActiveParticipant(player) and not TocaService.isProtected(player) then
			local root = getRoot(player)
			if root ~= nil and BuildingLayout.isInsideCorridor(corridor, GameConfig.Building, root.Position) then
				local relative = root.Position - corridor.wallCenter
				table.insert(found, {
					player = player,
					root = root,
					along = relative:Dot(corridor.along),
					lateral = -relative:Dot(corridor.inward) - laneCenter(),
				})
			end
		end
	end
	return found
end

local function nearest(intruders: { Intruder }): Intruder?
	local best: Intruder? = nil
	local bestDistance = GameConfig.Barao.SightRange
	for _, intruder in ipairs(intruders) do
		local distance = math.abs(intruder.along - along)
		if distance <= bestDistance then
			best = intruder
			bestDistance = distance
		end
	end
	return best
end

local function approach(current: number, target: number, maxStep: number): number
	local delta = target - current
	if math.abs(delta) <= maxStep then
		return target
	end
	return current + (math.sign(delta) * maxStep)
end

-- Anda até o alvo ao longo do corredor; devolve a distância percorrida.
local function moveTowards(targetAlong: number, targetLateral: number, speed: number, dt: number): number
	local limit = maxAlong()
	local clampedTarget = math.clamp(targetAlong, -limit, limit)
	local before = along
	along = approach(along, clampedTarget, speed * dt)
	local lateralLimit = maxLateral()
	lateral = approach(lateral, math.clamp(targetLateral, -lateralLimit, lateralLimit), GameConfig.Barao.LateralSpeed * dt)
	local moved = along - before
	if math.abs(moved) > 1e-3 then
		facing = if moved > 0 then 1 else -1
	end
	return math.abs(moved)
end

local function isInDoorway(intruder: Intruder): boolean
	return intruder.lateral < -(BuildingLayout.CorridorWidth / 2)
end

local function isInNiche(intruder: Intruder): boolean
	return intruder.lateral > BuildingLayout.CorridorWidth / 2
end

-- Empurra para longe do Barão, rumo à saída daquele lado do corredor. Quem
-- está no vão de uma entrada é jogado para dentro do prédio, e quem está
-- numa Toca sem proteção é puxado de volta para o corredor.
local function push(player: Player, intruder: Intruder, now: number, corridor: Corridor)
	local config = GameConfig.Barao
	local difference = intruder.along - along
	local direction = if math.abs(difference) > 0.3 then math.sign(difference) else (if intruder.along >= 0 then 1 else -1)
	local horizontal = corridor.along * direction
	if isInDoorway(intruder) then
		horizontal = corridor.inward
	elseif isInNiche(intruder) then
		horizontal = ((corridor.along * direction * 0.5) + corridor.inward).Unit
	end
	local velocity = (horizontal * config.PushSpeed) + Vector3.new(0, config.PushLift, 0)
	lastContact[player] = now
	if player == chaseTarget then
		chaseCaught = true
	end
	emit("Contact", player, nil)
	local sender = sendToPlayer
	if sender ~= nil then
		sender(player, "Knockback", velocity)
		sender(player, "BaraoContact", 0)
	end
	local funny = pick(config.FunnySoundIds)
	if funny ~= nil then
		playOneShot(funny, random:NextNumber(0.85, 1.35), 1)
	end
	pauseUntil = now + config.ContactPause
	setMode("Pause")
end

local function checkContacts(intruders: { Intruder }, now: number, corridor: Corridor)
	local config = GameConfig.Barao
	local floorY = BuildingLayout.getCorridorFloorY(corridor, along)
	local dogPosition = worldPosition(corridor, along, lateral, floorY)
	for _, intruder in ipairs(intruders) do
		local last = lastContact[intruder.player]
		if last == nil or now - last >= config.ContactCooldown then
			local offset = intruder.root.Position - dogPosition
			local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if isInNiche(intruder) then
				-- O nicho é raso: o Barão alcança com o focinho quem não
				-- está protegido lá dentro.
				horizontal = math.abs(intruder.along - along)
			end
			local intruderFloorY = BuildingLayout.getCorridorFloorY(corridor, intruder.along)
			local feetHeight = (intruder.root.Position.Y - ROOT_TO_FEET) - intruderFloorY
			if horizontal <= config.ContactRadius and feetHeight < config.JumpClearance then
				push(intruder.player, intruder, now, corridor)
				return
			elseif horizontal <= config.ContactRadius then
				-- Passou por cima dele no ar: fuga pelo pulo.
				local lastJump = lastJumpEscape[intruder.player]
				if lastJump == nil or now - lastJump >= JUMP_ESCAPE_COOLDOWN then
					lastJumpEscape[intruder.player] = now
					if intruder.player == chaseTarget then
						chaseJumped = true
					end
					emit("Escape", intruder.player, "Jump")
				end
			end
		end
	end
end

-- Só há gente no outro corredor há um tempo: reaparece lá, pela ponta mais
-- longe de quem entrou, para dar tempo de ouvir e reagir.
local function maybeSwitchCorridor(now: number)
	if #corridors < 2 then
		return
	end
	local otherIndex = if corridorIndex == 1 then 2 else 1
	local others = readIntruders(corridors[otherIndex])
	if #others == 0 then
		otherCorridorSince = nil
		return
	end
	local since = otherCorridorSince
	if since == nil then
		otherCorridorSince = now
		return
	end
	if now - since < GameConfig.Barao.SwitchCorridorDelay then
		return
	end
	otherCorridorSince = nil
	corridorIndex = otherIndex
	local side = if others[1].along >= 0 then -1 else 1
	along = side * maxAlong()
	lateral = 0
	facing = -side
	patrolTarget = 0
	bark()
	scheduleBark(now)
end

local function wake(now: number)
	setMode("Patrol")
	patrolTarget = random:NextNumber(-maxAlong(), maxAlong())
	bark()
	task.delay(0.7, function()
		if active and model ~= nil then
			bark()
		end
	end)
	scheduleBark(now)
end

local function step(dt: number)
	local now = os.clock()
	if mode == "Sleeping" then
		if now >= wakeAt then
			wake(now)
		end
		return
	end

	local corridor = corridors[corridorIndex]
	if corridor == nil then
		return
	end
	local intruders = readIntruders(corridor)
	local moved = 0

	if mode == "Pause" then
		if now >= pauseUntil then
			setMode("Patrol")
		end
	else
		local target = nearest(intruders)
		if target ~= nil then
			if mode ~= "Chase" then
				setMode("Chase")
				bark()
				scheduleBark(now)
			end
			otherCorridorSince = nil
			beginChase(target.player, now)
			local multiplier = if isEnraged(now) then GameConfig.Barao.EnragedSpeedMultiplier else 1
			moved = moveTowards(target.along, target.lateral, GameConfig.Barao.ChaseSpeed * multiplier, dt)
		else
			if mode == "Chase" then
				setMode("Patrol")
				pauseUntil = now + random:NextNumber(SNIFF_TIME.Min, SNIFF_TIME.Max)
			end
			if chaseTarget ~= nil then
				endChase(now)
			end
			if #intruders == 0 then
				maybeSwitchCorridor(now)
			end
			if now >= pauseUntil then
				moved = moveTowards(patrolTarget, 0, GameConfig.Barao.PatrolSpeed, dt)
				if math.abs(along - patrolTarget) <= ARRIVE_DISTANCE or math.abs(patrolTarget) > maxAlong() then
					patrolTarget = random:NextNumber(-maxAlong(), maxAlong())
					pauseUntil = now + random:NextNumber(SNIFF_TIME.Min, SNIFF_TIME.Max)
				end
			end
		end
		checkContacts(intruders, now, corridor)
	end

	if now >= nextBarkAt then
		bark()
		scheduleBark(now)
	end

	local speed = moved / math.max(dt, 1e-3)
	local steps = footsteps
	if steps ~= nil then
		steps.Playing = speed > 0.5
		steps.PlaybackSpeed = 0.9 + (speed / 20)
	end
	local bob = if speed > 0.5 then math.abs(math.sin(now * speed * 1.2)) * 0.18 else 0
	place(bob)
end

-- Avisado de encontros, contatos e fugas (telemetria e Momentos Puff).
function BaraoService.setEventListener(listener: EventListener?)
	eventListener = listener
end

function BaraoService.beginRound(newRoundId: number, wakeDelay: number)
	if model == nil then
		return
	end
	roundId = newRoundId
	active = true
	enragedUntil = 0
	goToSleep()
	wakeAt = os.clock() + math.max(0, wakeDelay)
	nextBarkAt = wakeAt
end

-- Chamado quando alguém abre o cofre: acorda na hora (se ainda dormia),
-- late e fica bravo por EnragedDuration segundos.
function BaraoService.enrage()
	if not active or model == nil then
		return
	end
	local now = os.clock()
	if mode == "Sleeping" then
		wakeAt = now
		wake(now)
	end
	enragedUntil = now + GameConfig.Barao.EnragedDuration
	bark()
	scheduleBark(now)
end

function BaraoService.endRound()
	active = false
	enragedUntil = 0
	if model ~= nil then
		goToSleep()
	end
end

function BaraoService.start(worldRoot: Instance, sender: Sender)
	if started then
		return
	end
	started = true
	if not GameConfig.Barao.Enabled then
		return
	end
	sendToPlayer = sender
	corridors = BuildingLayout.getCorridors(GameConfig.Arena, GameConfig.Building)
	if #corridors == 0 then
		warn("[BlocoPuff] Barao not started: no corridors")
		return
	end

	local newModel = BaraoModel.build()
	newModel:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newModel:SetAttribute(TARGET_ATTRIBUTE, 0)
	CollectionService:AddTag(newModel, BARAO_TAG)
	local body = newModel:FindFirstChild(BaraoModel.SoundPartName)
	if body ~= nil and body:IsA("BasePart") then
		soundPart = body
		local steps = Instance.new("Sound")
		steps.Name = "Footsteps"
		steps.SoundId = GameConfig.Barao.FootstepSoundId
		steps.Looped = true
		steps.Volume = 0.8
		steps.RollOffMode = Enum.RollOffMode.InverseTapered
		steps.RollOffMinDistance = SOUND_MIN_DISTANCE
		steps.RollOffMaxDistance = SOUND_MAX_DISTANCE * 0.7
		steps.Parent = body
		footsteps = steps
	end
	newModel.Parent = worldRoot
	model = newModel
	goToSleep()

	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		if active then
			step(dt)
		end
	end)
	playerRemoving = Players.PlayerRemoving:Connect(function(player: Player)
		lastContact[player] = nil
		lastEncounter[player] = nil
		lastJumpEscape[player] = nil
		if chaseTarget == player then
			chaseTarget = nil
			setTargetAttribute(nil)
		end
	end)
end

function BaraoService.stop()
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
	local current = model
	if current ~= nil then
		current:Destroy()
	end
	model = nil
	soundPart = nil
	footsteps = nil
	sendToPlayer = nil
	eventListener = nil
	table.clear(lastContact)
	started = false
end

return table.freeze(BaraoService)
