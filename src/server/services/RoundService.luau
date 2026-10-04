--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local RoundMessages = require(ReplicatedStorage.Shared.modules.RoundMessages)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local EliminationTypes = require(ReplicatedStorage.Shared.types.EliminationTypes)
local ArenaService = require(script.Parent.ArenaService)
local LobbyService = require(script.Parent.LobbyService)
local ReplicatedState = require(script.Parent.ReplicatedStateService)
local PuffadorService = require(script.Parent.PuffadorService)
local EliminationService = require(script.Parent.EliminationService)
local VaultService = require(script.Parent.VaultService)
local KnockbackService = require(script.Parent.KnockbackService)
local TrapService = require(script.Parent.TrapService)
local FinalChaosService = require(script.Parent.FinalChaosService)
local RoundResultBuilder = require(script.Parent.RoundResultBuilder)
local TelemetryService = require(script.Parent.TelemetryService)
local SecretPassageService = require(script.Parent.SecretPassageService)
local TocaService = require(script.Parent.TocaService)
local BaraoService = require(script.Parent.BaraoService)
local BuildModeService = require(script.Parent.BuildModeService)
local PuffMomentService = require(script.Parent.PuffMomentService)
local CorridorTelemetryService = require(script.Parent.CorridorTelemetryService)
local RoundStatsService = require(script.Parent.RoundStatsService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SecretAchievementService = require(script.Parent.SecretAchievementService)
local PartyService = require(script.Parent.PartyService)
local MatchQueueService = require(script.Parent.MatchQueueService)
local PartySelection = require(script.Parent.Parent.data.PartySelection)
local XpCalculator = require(script.Parent.Parent.data.XpCalculator)
local BotRewardRules = require(script.Parent.Parent.data.BotRewardRules)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local ResultTypes = require(ReplicatedStorage.Shared.types.ResultTypes)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local BotFillService = require(script.Parent.BotFillService)
local BotBrainService = require(script.Parent.BotBrainService)

local awakeningRandom = Random.new()
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local CharacterImpulse = require(ReplicatedStorage.Shared.modules.CharacterImpulse)

type RoundState = RoundTypes.RoundState
type RoundTimings = GameConfig.RoundTimings
type EliminationReason = EliminationTypes.EliminationReason
type Combatant = CombatantRegistry.Combatant

type Participant = {
	combatant: Combatant,
	alive: boolean,
}

type Winner = {
	userId: number,
	name: string,
}

local POLL_INTERVAL = 1
-- Tempo em que quedas são ignoradas logo após a Segunda Chance: só cobre a
-- posição antiga ainda chegando do cliente, não uma nova queda de verdade.
local RESPAWN_FALL_GRACE = 1
-- Top 3 só conta no perfil em partidas com pelo menos 4 participantes.
local TOP3_MIN_PARTICIPANTS = 4
local TICK_INTERVAL = 1

-- Atributos autoritativos escritos pelo servidor em cada Player (ou no corpo
-- do bot), usados pelo cliente para saber se participa da rodada atual sem
-- inferir pela posição.
-- IsRoundParticipant: true enquanto o jogador integra a rodada em andamento.
-- ParticipatingRoundId: RoundId da rodada em que participa (0 = nenhuma).
-- IsEliminated: true se o participante foi eliminado durante Active.
-- EliminationReason: causa da eliminação (None enquanto ativo).
-- EliminatedAtRoundId: RoundId em que a eliminação ocorreu (0 = nenhuma).
local ATTR_IS_PARTICIPANT = StateAttributeNames.PlayerIsParticipant
local ATTR_PARTICIPATING_ROUND_ID = StateAttributeNames.PlayerParticipatingRoundId
local ATTR_IS_ELIMINATED = StateAttributeNames.PlayerIsEliminated
local ATTR_ELIMINATION_REASON = StateAttributeNames.PlayerEliminationReason
local ATTR_ELIMINATED_AT_ROUND_ID = StateAttributeNames.PlayerEliminatedAtRoundId
local ATTR_ROUNDS_UNTIL_TURN = StateAttributeNames.PlayerRoundsUntilTurn
local ATTR_ROUND_BLOCKS_DESTROYED = StateAttributeNames.PlayerRoundBlocksDestroyed
local ATTR_HAS_SECOND_CHANCE = StateAttributeNames.PlayerHasSecondChance
local ATTR_ROUND_KNOCKOUTS = StateAttributeNames.PlayerRoundKnockouts

local RoundService = {}

local isRunning = false
local currentState: RoundState = RoundTypes.WaitingForPlayers
local currentRoundId = 0
-- os.time() do início da rodada, parte da chave única usada no perfil.
local currentRoundStartedAt = 0

local participants: { [Combatant]: Participant } = {}
local participantOrder: { Combatant } = {}
local rotationQueue: { Player } = {}
local deathConnections: { [Combatant]: RBXScriptConnection } = {}
local playerRemovingConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local winner: Winner? = nil
local respawnGraceUntil: { [Combatant]: number } = {}
-- Quem já usou a Segunda Chance nesta rodada (Momento Puff "Volta por Cima").
local usedSecondChance: { [Combatant]: boolean } = {}
-- Posição final de quem foi eliminado (1 = vencedor): quantos seguiam vivos
-- depois da eliminação + 1.
local eliminationPositions: { [Combatant]: number } = {}
-- Momento de cada eliminação: quedas no mesmo instante viram empate.
local eliminationTimes: { [Combatant]: number } = {}
local resultRemote: RemoteEvent? = nil
-- Comandos de teste do painel admin (MatchTestControls).
-- Início forçado vale até este os.clock() (pedido na espera aguarda a
-- contagem começar, mas não fica valendo para sempre).
local forceStartUntil = 0
local skipToChaosRequested = false
local endRoundRequested = false
-- Contagem que sobra ao forçar o início.
local FORCED_COUNTDOWN = 3
local FORCE_START_WINDOW = 30

-- Quantos estão na fila da partida (no mirante, com as Parties, mais os
-- bots RoboPuff que vieram completar).
local function countQueued(): number
	MatchQueueService.refresh()
	return MatchQueueService.count() + BotFillService.count()
end

local function setState(newState: RoundState)
	if currentState == newState then
		return
	end

	currentState = newState
	ReplicatedState.setRoundState(newState)
	print(string.format("[BlocoPuff] Round state: %s", newState))
end

local function getHumanoidRootPart(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function moveCharacterTo(character: Model, cframe: CFrame): boolean
	local rootPart = getHumanoidRootPart(character)
	if rootPart == nil then
		return false
	end

	local ok = pcall(function()
		character:PivotTo(cframe)
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end)

	return ok
end

-- Publica, para cada jogador na fila, em quantas rodadas (contando a
-- próxima como 1) ele deve ser selecionado, assumindo que a fila não mude
-- até lá. É uma estimativa best-effort: reavaliada a cada entrada, saída ou
-- seleção, então fica correta sempre que a fila estiver estável.
local function publishQueuePositions()
	for index, player in ipairs(rotationQueue) do
		local roundsUntilTurn = math.ceil(index / GameConfig.MaximumPlayers)
		player:SetAttribute(ATTR_ROUNDS_UNTIL_TURN, roundsUntilTurn)
	end
end

local function enqueuePlayer(player: Player)
	for _, queued in ipairs(rotationQueue) do
		if queued == player then
			return
		end
	end

	table.insert(rotationQueue, player)
	publishQueuePositions()
end

local function dequeuePlayer(player: Player)
	for index, queued in ipairs(rotationQueue) do
		if queued == player then
			table.remove(rotationQueue, index)
			publishQueuePositions()
			return
		end
	end
end

-- Fila de rotação justa: em vez de sempre pegar os primeiros jogadores
-- conectados, seleciona a partir da frente da fila e manda quem acabou de
-- jogar para o fim dela, dando prioridade a quem ainda está esperando.
-- Parties entram inteiras; se não couberem, esperam na frente da fila e
-- são avisadas (PartySelection). Só joga quem está na fila (no mirante, com
-- a Ficha da Partida ou com alguém da Party assim); os demais seguem
-- passeando e mantêm a posição.
local function selectParticipants(): { Player }
	MatchQueueService.refresh()
	local selected, waiting, deferredParties = PartySelection.select(rotationQueue, PartyService.groupOf, GameConfig.MaximumPlayers, MatchQueueService.hasPlace)
	rotationQueue = waiting
	publishQueuePositions()
	PartyService.roundSelected(selected, deferredParties)

	return selected
end

local function teleportParticipantsToArena(combatants: { Combatant })
	local spawnCFrames = ArenaService.getPlayerSpawnCFrames(#combatants)

	for index, combatant in ipairs(combatants) do
		local cframe = spawnCFrames[index]
		if cframe == nil then
			break
		end

		local character = CombatantRegistry.getCharacter(combatant)
		if character == nil then
			warn(string.format("[BlocoPuff] Skipping arena teleport for %s: character not found", combatant.name))
			continue
		end

		if not moveCharacterTo(character, cframe) then
			warn(string.format("[BlocoPuff] Failed to move %s into the arena", combatant.name))
		end
	end
end

local function resetParticipantAttributes(combatant: Combatant)
	CombatantRegistry.setAttribute(combatant, ATTR_IS_PARTICIPANT, false)
	CombatantRegistry.setAttribute(combatant, ATTR_PARTICIPATING_ROUND_ID, 0)
	CombatantRegistry.setAttribute(combatant, ATTR_IS_ELIMINATED, false)
	CombatantRegistry.setAttribute(combatant, ATTR_ELIMINATION_REASON, EliminationTypes.None)
	CombatantRegistry.setAttribute(combatant, ATTR_ELIMINATED_AT_ROUND_ID, 0)
	CombatantRegistry.setAttribute(combatant, ATTR_ROUND_BLOCKS_DESTROYED, 0)
	CombatantRegistry.setAttribute(combatant, ATTR_HAS_SECOND_CHANCE, false)
	CombatantRegistry.setAttribute(combatant, ATTR_ROUND_KNOCKOUTS, 0)
end

local function markParticipantAttributes(combatant: Combatant, roundId: number)
	-- Antes de IsRoundParticipant: o cliente não deve ver um participante
	-- sem Segunda Chance nem por um instante.
	CombatantRegistry.setAttribute(combatant, ATTR_HAS_SECOND_CHANCE, GameConfig.SecondChance.Enabled)
	CombatantRegistry.setAttribute(combatant, ATTR_IS_PARTICIPANT, true)
	CombatantRegistry.setAttribute(combatant, ATTR_PARTICIPATING_ROUND_ID, roundId)
	CombatantRegistry.setAttribute(combatant, ATTR_IS_ELIMINATED, false)
	CombatantRegistry.setAttribute(combatant, ATTR_ELIMINATION_REASON, EliminationTypes.None)
	CombatantRegistry.setAttribute(combatant, ATTR_ELIMINATED_AT_ROUND_ID, 0)
	CombatantRegistry.setAttribute(combatant, ATTR_ROUND_BLOCKS_DESTROYED, 0)
	CombatantRegistry.setAttribute(combatant, ATTR_ROUND_KNOCKOUTS, 0)
end

-- Jogadores reais da rodada (perfil, telemetria, remotes, lobby).
local function participantPlayers(): { Player }
	return CombatantRegistry.playersOf(participantOrder)
end

local function onPlayerAdded(player: Player)
	resetParticipantAttributes(CombatantRegistry.forPlayer(player))
	enqueuePlayer(player)
end

-- Ponto único e idempotente de eliminação: usado tanto pelo handler de morte
-- (Humanoid.Died) quanto pelo callback fornecido ao EliminationService para
-- a zona de queda. Marca o participante inativo antes de zerar o Humanoid,
-- para que um Died disparado por essa própria chamada não sobrescreva a causa.
-- Volta por Cima: Momento Puff e estatística, no máximo uma vez por rodada.
local function recordComeback(combatant: Combatant, detail: string)
	if RoundStatsService.get(combatant).comebacks == 0 then
		RoundStatsService.comeback(combatant)
	end
	local player = combatant.player
	if player ~= nil then
		PuffMomentService.record(player, "Comeback", detail)
	end
end

-- Credita a derrubada a quem empurrou o combatente por último, se foi há pouco.
local function creditKnockout(victim: Combatant)
	local attacker = KnockbackService.getRecentAttacker(victim)
	KnockbackService.forget(victim)
	if attacker == nil or attacker == victim or participants[attacker] == nil then
		return
	end
	local count = CombatantRegistry.readCount(attacker, ATTR_ROUND_KNOCKOUTS)
	CombatantRegistry.setAttribute(attacker, ATTR_ROUND_KNOCKOUTS, count + 1)
	if CombatantRegistry.isBot(victim) then
		RoundStatsService.botKnockout(attacker)
	end
	if usedSecondChance[attacker] then
		recordComeback(attacker, "Knockout")
	end
end

-- Primeira queda para fora da arena: devolve o jogador a um bloco inteiro
-- (de preferência no andar de baixo) em vez de eliminá-lo. Desligada no
-- Caos Final. Retorna true se a Segunda Chance foi usada.
local function trySecondChance(combatant: Combatant): boolean
	if CombatantRegistry.getAttribute(combatant, ATTR_HAS_SECOND_CHANCE) ~= true or FinalChaosService.isRunning() then
		return false
	end
	local character = CombatantRegistry.getCharacter(combatant)
	if character == nil then
		return false
	end

	local cframe: CFrame? = nil
	for floorIndex = 1, GameConfig.Arena.FloorCount do
		cframe = ArenaService.getSafeRespawnCFrame(floorIndex)
		if cframe ~= nil then
			break
		end
	end
	if cframe == nil or not moveCharacterTo(character, cframe) then
		return false
	end

	CombatantRegistry.setAttribute(combatant, ATTR_HAS_SECOND_CHANCE, false)
	usedSecondChance[combatant] = true
	respawnGraceUntil[combatant] = os.clock() + RESPAWN_FALL_GRACE
	KnockbackService.protect(combatant, GameConfig.SecondChance.RespawnProtection)
	-- O personagem do jogador é simulado pelo cliente: ele também zera a
	-- própria velocidade de queda ao receber este aviso.
	local player = combatant.player
	if player ~= nil then
		PuffadorService.sendFeedback(player, "Respawn", cframe)
	else
		local root = CombatantRegistry.getRoot(combatant)
		if root ~= nil then
			CharacterImpulse.stopFalling(root, cframe)
		end
	end
	print(string.format("[BlocoPuff] %s used their Second Chance", combatant.name))
	return true
end

local function eliminateParticipant(combatant: Combatant, reason: EliminationReason)
	local participant = participants[combatant]
	if participant == nil or not participant.alive then
		return
	end
	local player = combatant.player

	if reason == EliminationTypes.FellFromArena then
		local fallRoot = CombatantRegistry.getRoot(combatant)
		local fallPosition = if fallRoot ~= nil then fallRoot.Position else Vector3.zero
		-- Logo após a Segunda Chance o servidor ainda pode receber a posição
		-- antiga (abaixo da zona) antes do teleporte chegar ao cliente.
		local grace = respawnGraceUntil[combatant]
		if grace ~= nil and os.clock() < grace then
			return
		end
		creditKnockout(combatant)
		if trySecondChance(combatant) then
			if player ~= nil then
				TelemetryService.fell(player, fallPosition, true)
				TelemetryService.secondChanceUsed(player)
			end
			return
		end
		if player ~= nil then
			TelemetryService.fell(player, fallPosition, false)
		end
	end

	participant.alive = false
	local stillAlive = 0
	for _, other in pairs(participants) do
		if other.alive then
			stillAlive += 1
		end
	end
	eliminationPositions[combatant] = stillAlive + 1
	eliminationTimes[combatant] = os.clock()
	CombatantRegistry.setAttribute(combatant, ATTR_IS_ELIMINATED, true)
	CombatantRegistry.setAttribute(combatant, ATTR_ELIMINATION_REASON, reason)
	CombatantRegistry.setAttribute(combatant, ATTR_ELIMINATED_AT_ROUND_ID, currentRoundId)
	if player ~= nil then
		TelemetryService.eliminated(player, reason, stillAlive + 1)
		PuffadorService.revokeFrom(player)
	end

	local humanoid = CombatantRegistry.getHumanoid(combatant)
	if humanoid ~= nil and humanoid.Health > 0 then
		humanoid.Health = 0
	end

	print(string.format("[BlocoPuff] %s eliminated: %s", combatant.name, reason))
end

local function onParticipantDied(combatant: Combatant)
	eliminateParticipant(combatant, EliminationTypes.CharacterDied)
end

local function connectParticipantDeathHandlers(combatants: { Combatant })
	for _, combatant in ipairs(combatants) do
		local humanoid = CombatantRegistry.getHumanoid(combatant)
		if humanoid == nil then
			continue
		end

		deathConnections[combatant] = humanoid.Died:Connect(function()
			onParticipantDied(combatant)
		end)
	end
end

local function disconnectParticipantDeathHandlers()
	for _, connection in pairs(deathConnections) do
		connection:Disconnect()
	end
	table.clear(deathConnections)
end

local function clearRoundParticipants()
	table.clear(respawnGraceUntil)
	table.clear(usedSecondChance)
	table.clear(eliminationPositions)
	table.clear(eliminationTimes)
	table.clear(participants)
	table.clear(participantOrder)
end

local function evaluateActiveParticipants(): (number, Participant?)
	local aliveCount = 0
	local soleActive: Participant? = nil

	for _, combatant in ipairs(participantOrder) do
		local participant = participants[combatant]
		if participant ~= nil and participant.alive then
			aliveCount += 1
			soleActive = participant
		end
	end

	if aliveCount == 1 then
		return 1, soleActive
	end

	return aliveCount, nil
end

-- Tira um combatente da rodada em andamento (jogador que saiu do servidor
-- ou bot removido), sem posição nem resultado.
local function removeParticipant(combatant: Combatant)
	local participant = participants[combatant]
	if participant ~= nil then
		if participant.alive then
			print(string.format("[BlocoPuff] %s eliminated: %s", combatant.name, EliminationTypes.PlayerLeft))
		end
		local player = combatant.player
		if player ~= nil and currentState == RoundTypes.Active and participant.alive then
			CorridorTelemetryService.leftMidRound(player)
			TelemetryService.leftMidRound(player)
		end

		participants[combatant] = nil
		local index = table.find(participantOrder, combatant)
		if index ~= nil then
			table.remove(participantOrder, index)
		end
	end

	local connection = deathConnections[combatant]
	if connection ~= nil then
		connection:Disconnect()
		deathConnections[combatant] = nil
	end
end

local function onPlayerRemoving(player: Player)
	removeParticipant(CombatantRegistry.forPlayer(player))

	PuffadorService.revokeFrom(player)
	dequeuePlayer(player)
end

local function runWaitingForPlayers()
	setState(RoundTypes.WaitingForPlayers)
	MatchQueueService.setOpen(true)
	MatchQueueService.setCountdown(nil)
	ReplicatedState.setTimeRemaining(0)
	ReplicatedState.clearWinner()
	ReplicatedState.setStatusMessage(RoundMessages.WaitingForPlayers)
	ReplicatedState.setParticipantCount(countQueued())

	while isRunning and countQueued() < GameConfig.MinimumPlayers do
		task.wait(POLL_INTERVAL)
		ReplicatedState.setParticipantCount(countQueued())
	end
end

local function runCountdown(timings: RoundTimings): boolean
	setState(RoundTypes.Countdown)

	local remaining = timings.LobbyCountdown
	MatchQueueService.setCountdown(remaining)
	ReplicatedState.setTimeRemaining(remaining)
	ReplicatedState.setStatusMessage(RoundMessages.countdown(remaining))
	ReplicatedState.setParticipantCount(countQueued())

	while isRunning and remaining > 0 do
		task.wait(TICK_INTERVAL)

		if not isRunning then
			return false
		end

		if countQueued() < GameConfig.MinimumPlayers then
			return false
		end

		if os.clock() < forceStartUntil then
			forceStartUntil = 0
			remaining = math.min(remaining, FORCED_COUNTDOWN + 1)
		end
		remaining -= 1
		-- Nos últimos segundos o mirante fecha as portas (embarque).
		MatchQueueService.setCountdown(remaining)
		ReplicatedState.setTimeRemaining(remaining)
		ReplicatedState.setStatusMessage(RoundMessages.countdown(remaining))
		ReplicatedState.setParticipantCount(countQueued())
	end

	return isRunning
end

-- Devolve false (sem começar nada) se a fila esvaziou no último instante
-- e não há participantes suficientes: a espera recomeça.
local function beginRound(timings: RoundTimings): boolean
	local selected = selectParticipants()
	-- Nunca há partida só de bots: eles só completam quem está na fila.
	local botSlots = if #selected > 0 then GameConfig.MaximumPlayers - #selected else 0
	local available = #selected + math.min(botSlots, BotFillService.count())
	if #selected == 0 or available < GameConfig.MinimumPlayers then
		print(string.format("[BlocoPuff] Round start cancelled: only %d in the queue", available))
		return false
	end
	local bots = BotFillService.takeForRound(botSlots)
	MatchQueueService.setOpen(false)
	currentRoundId += 1
	currentRoundStartedAt = os.time()

	-- A arena precisa estar totalmente restaurada e com a destruição
	-- habilitada para a nova rodada antes que qualquer jogador chegue nela.
	ArenaService.restoreAllBlocks()
	ArenaService.beginRound(currentRoundId)

	clearRoundParticipants()
	local combatants = CombatantRegistry.forPlayers(selected)
	for _, bot in ipairs(bots) do
		table.insert(combatants, bot)
	end
	for _, combatant in ipairs(combatants) do
		participants[combatant] = { combatant = combatant, alive = true }
		table.insert(participantOrder, combatant)
		markParticipantAttributes(combatant, currentRoundId)
	end
	local humans = participantPlayers()

	teleportParticipantsToArena(participantOrder)
	-- Os escalados já desceram: o mirante reabre para a fila da próxima.
	MatchQueueService.setCountdown(nil)
	connectParticipantDeathHandlers(participantOrder)
	PuffadorService.beginRound(humans, currentRoundId)
	KnockbackService.beginRound(currentRoundId)
	TrapService.beginRound()
	SecretPassageService.beginRound(currentRoundId)
	TocaService.beginRound(currentRoundId)
	PuffMomentService.beginRound()
	RoundStatsService.beginRound()
	SecretAchievementService.beginRound()
	PlayerDataService.roundStarted(humans)
	CorridorTelemetryService.beginRound(currentRoundId)
	-- O Barão acorda e o cofre destranca no mesmo instante sorteado.
	local awakening = timings.RoundDuration * awakeningRandom:NextNumber(GameConfig.Barao.WakeMinFraction, GameConfig.Barao.WakeMaxFraction)
	BaraoService.beginRound(currentRoundId, awakening)
	TelemetryService.roundStarted(humans, #bots)
	ReplicatedState.setFinalChaos(false)
	VaultService.beginRound(currentRoundId, awakening)

	-- Só inicia o monitoramento da zona depois que os participantes já
	-- estão posicionados na arena, evitando eliminar alguém ainda no lobby.
	EliminationService.beginRound(participantOrder, currentRoundId)
	BotBrainService.beginRound(bots, humans)

	setState(RoundTypes.Active)
	ReplicatedState.setRoundId(currentRoundId)
	ReplicatedState.setParticipantCount(#participantOrder)
	ReplicatedState.setTimeRemaining(timings.RoundDuration)
	ReplicatedState.setStatusMessage(RoundMessages.Active)

	print(string.format("[BlocoPuff] Round %d started with %d participants (%d bots)", currentRoundId, #participantOrder, #bots))
	return true
end

local function startFinalChaos(duration: number)
	FinalChaosService.begin(duration)
	ReplicatedState.setFinalChaos(true)
	local alivePlayers: { Player } = {}
	for _, combatant in ipairs(participantOrder) do
		local participant = participants[combatant]
		local player = combatant.player
		if participant ~= nil and participant.alive and player ~= nil then
			table.insert(alivePlayers, player)
		end
	end
	TelemetryService.finalChaosStarted(alivePlayers)
	print(string.format("[BlocoPuff] Round %d entered Final Chaos (%ds)", currentRoundId, duration))
end

local function runActive(timings: RoundTimings)
	local remaining = timings.RoundDuration
	local chaosDuration = FinalChaosService.getDuration(timings.RoundDuration)

	while isRunning do
		if endRoundRequested then
			endRoundRequested = false
			winner = nil
			break
		end
		if skipToChaosRequested then
			skipToChaosRequested = false
			remaining = math.min(remaining, chaosDuration)
		end

		-- Todos os humanos saíram e só sobraram bots: não há por que seguir.
		if #participantOrder > 0 and #participantPlayers() == 0 then
			winner = nil
			break
		end

		local aliveCount, soleActive = evaluateActiveParticipants()

		if aliveCount == 0 then
			-- Todos caíram antes do próximo tique: vence quem caiu por último,
			-- se caiu sozinho; quedas no mesmo instante terminam em empate.
			local lastPlayers = RoundResultBuilder.getLastEliminated(eliminationTimes)
			winner = if #lastPlayers == 1
				then { userId = lastPlayers[1].id, name = lastPlayers[1].name }
				else nil
			break
		elseif aliveCount == 1 then
			winner = if soleActive ~= nil
				then { userId = soleActive.combatant.id, name = soleActive.combatant.name }
				else nil
			break
		end

		if remaining <= 0 then
			winner = nil
			break
		end

		if remaining <= chaosDuration and not FinalChaosService.isRunning() then
			startFinalChaos(chaosDuration)
		end

		task.wait(TICK_INTERVAL)
		remaining -= 1
		ReplicatedState.setTimeRemaining(remaining)
	end
end

-- Soma a rodada ao perfil de quem terminou a rodada no servidor (quem saiu
-- no meio não recebe). Tudo vem do resultado calculado aqui no servidor.
-- Recompensa cheia nas primeiras partidas da vida do jogador.
local function isBeginner(player: Player): boolean
	local snapshot = PlayerDataService.getSnapshot(player)
	return snapshot ~= nil and snapshot.stats.matches < BotConfig.LevelRules.BeginnerMatches
end

local function commitProfiles(result: ResultTypes.RoundResult)
	local roundKey = PlayerDataService.roundKey(currentRoundId, currentRoundStartedAt)
	-- Bots (id negativo) não têm perfil, mas mudam a recompensa de quem jogou
	-- com eles (BotRewardRules).
	local humans, bots = 0, 0
	for _, entry in ipairs(result.entries) do
		if entry.userId > 0 then
			humans += 1
		else
			bots += 1
		end
	end
	for _, entry in ipairs(result.entries) do
		local player = if entry.userId > 0 then Players:GetPlayerByUserId(entry.userId) else nil
		local combatant = if player ~= nil then CombatantRegistry.forPlayer(player) else nil
		if player ~= nil and combatant ~= nil and participants[combatant] ~= nil then
			local extra = RoundStatsService.get(combatant)
			local won = not result.draw and result.winnerUserId == entry.userId
			local podium = won or (entry.position <= 3 and result.participantCount >= TOP3_MIN_PARTICIPANTS)
			local outcome = BotRewardRules.evaluate({
				won = won,
				podium = podium,
				humans = humans,
				bots = bots,
				knockouts = entry.knockouts,
				botKnockouts = extra.botKnockouts,
				beginner = bots > 0 and isBeginner(player),
			}, BotConfig.Rewards)
			local delta = {
				matches = 1,
				wins = outcome.stats.wins,
				top3 = outcome.stats.top3,
				knockouts = outcome.stats.knockouts,
				blocksDestroyed = entry.blocks,
				vaultsOpened = extra.vaultsOpened,
				vaultsConquered = extra.vaultsConquered,
				baraoEscapes = extra.baraoEscapes,
				secretsFound = extra.secretsFound,
				blocksBuilt = extra.blocksBuilt,
				comebacks = extra.comebacks,
				botWins = outcome.stats.botWins,
			}
			-- O XP usa os mesmos números já limitados que vão para o perfil
			-- (o applyRound limita de novo e registra as anomalias).
			local trusted = ProfileSchema.clampDelta(delta)
			local xpLines, xpTotal = XpCalculator.compute({
				position = entry.position,
				participantCount = result.participantCount,
				won = won,
				knockouts = math.min(outcome.xp.knockouts, GameConfig.MaximumPlayers - 1),
				blocksDestroyed = trusted.blocksDestroyed,
				secretsFound = trusted.secretsFound,
				vaultsOpened = trusted.vaultsOpened,
				vaultsConquered = trusted.vaultsConquered,
				baraoEscapes = trusted.baraoEscapes,
				comebacks = trusted.comebacks,
				blocksBuilt = trusted.blocksBuilt,
				shots = extra.shots,
				botKnockouts = outcome.xp.botKnockouts,
				botKnockoutFactor = outcome.xp.botKnockoutFactor,
				multiplierCount = outcome.xp.multiplierCount,
				minMultiplier = outcome.xp.minMultiplier,
			})
			PlayerDataService.applyRound(player, roundKey, delta, {
				roundId = currentRoundId,
				lines = xpLines,
				total = xpTotal,
				won = won,
				stayedAsSpectator = not entry.survived,
				tickets = if bots > 0
					then { wins = outcome.ticketWins, top3 = outcome.ticketTop3, capped = outcome.cappedTickets }
					else nil,
			})
		end
	end
end

local function publishResult()
	local remote = resultRemote
	local snapshots: { RoundResultBuilder.ParticipantSnapshot } = {}
	local winnerCombatant: Combatant? = nil
	for _, combatant in ipairs(participantOrder) do
		local participant = participants[combatant]
		if participant ~= nil and CombatantRegistry.isPresent(combatant) then
			local extra = RoundStatsService.get(combatant)
			table.insert(snapshots, {
				combatant = combatant,
				alive = participant.alive,
				eliminatedPosition = eliminationPositions[combatant],
				eliminatedAt = eliminationTimes[combatant],
				vaultsOpened = extra.vaultsOpened,
				vaultsConquered = extra.vaultsConquered,
				baraoEscapes = extra.baraoEscapes,
				secretsFound = extra.secretsFound,
				comebacks = extra.comebacks,
			})
			if winner ~= nil and combatant.id == winner.userId then
				winnerCombatant = combatant
			end
		end
	end
	local result = RoundResultBuilder.build(currentRoundId, snapshots, winnerCombatant)
	local committed, commitFailure = pcall(commitProfiles, result)
	if not committed then
		warn(string.format("[BlocoPuff] Could not save round to profiles: %s", tostring(commitFailure)))
	end
	-- Conquista "Por um Fio" (arena quase vazia); chamada antes de restaurar os pisos.
	local total = ArenaService.getTotalBlockCount()
	local remainingRatio = if total > 0 then ArenaService.getRemainingBlockCount() / total else 1
	-- Conquistas são de jogador: um bot vencedor não ganha nada.
	local secretWinner = if result.draw or winnerCombatant == nil then nil else winnerCombatant.player
	local secretsOk, secretsFailure = pcall(SecretAchievementService.roundFinished, secretWinner, remainingRatio)
	if not secretsOk then
		warn(string.format("[BlocoPuff] Secret achievements check failed: %s", tostring(secretsFailure)))
	end
	RoundStatsService.endRound()
	if remote == nil then
		return
	end
	-- Só quem jogou vê o resultado; o lobby segue sem interrupção.
	local ok, failure = pcall(function()
		for _, player in ipairs(participantPlayers()) do
			if player.Parent ~= nil then
				remote:FireClient(player, result)
			end
		end
	end)
	if not ok then
		warn(string.format("[BlocoPuff] Could not publish round result: %s", tostring(failure)))
	end
end

local function runEnding(timings: RoundTimings)
	setState(RoundTypes.Ending)
	forceStartUntil = 0
	skipToChaosRequested = false
	endRoundRequested = false
	BotBrainService.endRound()
	EliminationService.endRound()
	FinalChaosService.stop()
	ReplicatedState.setFinalChaos(false)
	KnockbackService.endRound()
	TrapService.endRound()
	SecretPassageService.endRound()
	BaraoService.endRound()
	TocaService.endRound()
	ArenaService.endRound()
	VaultService.endRound()
	CorridorTelemetryService.endRound()
	-- Volta por Cima também vale para quem venceu depois da Segunda Chance.
	local roundWinner = winner
	if roundWinner ~= nil then
		for _, combatant in ipairs(participantOrder) do
			if combatant.id == roundWinner.userId and usedSecondChance[combatant] then
				recordComeback(combatant, "Win")
			end
		end
	end
	PuffMomentService.endRound()
	publishResult()
	-- Mesma regra de empate do resultado: tempo esgotado com vários vivos
	-- ou os últimos caindo no mesmo instante.
	local survivors = 0
	for _, combatant in ipairs(participantOrder) do
		local participant = participants[combatant]
		if participant ~= nil and participant.alive then
			survivors += 1
		end
	end
	local tiedLast = if survivors == 0 then RoundResultBuilder.getLastEliminated(eliminationTimes) else {}
	local isDraw = winner == nil and (survivors > 1 or #tiedLast > 1)
	local outcomes: { [Player]: string } = {}
	for _, combatant in ipairs(participantOrder) do
		local participant = participants[combatant]
		local player = combatant.player
		if participant ~= nil and player ~= nil then
			local won = winner ~= nil and combatant.id == winner.userId
			local inDraw = isDraw and (participant.alive or table.find(tiedLast, combatant) ~= nil)
			outcomes[player] = if won then "Win" elseif inDraw then "Draw" else "Loss"
		end
	end
	TelemetryService.roundFinished(outcomes)
	PuffadorService.endRound()
	disconnectParticipantDeathHandlers()

	if winner ~= nil then
		ReplicatedState.setWinner(winner.userId, winner.name)
		ReplicatedState.setStatusMessage(RoundMessages.winner(winner.name))
		print(string.format("[BlocoPuff] Round %d ended with winner %s", currentRoundId, winner.name))
	else
		ReplicatedState.clearWinner()
		ReplicatedState.setStatusMessage(RoundMessages.EndedNoWinner)
		print(string.format("[BlocoPuff] Round %d ended without a winner", currentRoundId))
	end

	local remaining = timings.IntermissionDuration
	ReplicatedState.setTimeRemaining(remaining)

	while isRunning and remaining > 0 do
		task.wait(TICK_INTERVAL)
		remaining -= 1
		ReplicatedState.setTimeRemaining(remaining)
	end

	LobbyService.returnToLobby(participantPlayers())
	-- Os corpos dos bots saem antes de os pisos voltarem.
	BotFillService.endRound()
	-- Restaura depois que os jogadores já saíram da arena, evitando que um
	-- bloco reapareça dentro de um personagem.
	ArenaService.restoreAllBlocks()
	TrapService.refresh()
	for _, combatant in ipairs(participantOrder) do
		resetParticipantAttributes(combatant)
	end
	clearRoundParticipants()
	winner = nil
end

local function runRoundLifecycle()
	while isRunning do
		runWaitingForPlayers()
		if not isRunning then
			break
		end

		local timings = GameConfig.getRoundTimings()
		local countdownCompleted = runCountdown(timings)
		if not countdownCompleted then
			continue
		end

		if not beginRound(timings) then
			continue
		end
		runActive(timings)
		if not isRunning then
			break
		end
		runEnding(timings)
	end
end

function RoundService.start()
	if isRunning then
		return
	end

	isRunning = true
	local remotes = PuffadorService.getRemotesFolder()
	if remotes ~= nil and resultRemote == nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = PuffadorConstants.RoundResultRemoteName
		remote.Parent = remotes
		resultRemote = remote
	elseif remotes == nil then
		warn("[BlocoPuff] RoundService: remotes folder not found; round results disabled")
	end
	playerRemovingConnection = Players.PlayerRemoving:Connect(onPlayerRemoving)
	playerAddedConnection = Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	task.spawn(runRoundLifecycle)
end

function RoundService.stop()
	isRunning = false
	resultRemote = nil

	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end

	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end

	disconnectParticipantDeathHandlers()
	BotBrainService.endRound()
	EliminationService.stop()
	FinalChaosService.stop()
	ReplicatedState.setFinalChaos(false)
	KnockbackService.stop()
	TrapService.stop()
	SecretPassageService.stop()
	BaraoService.stop()
	TocaService.stop()
	PuffMomentService.stop()
	CorridorTelemetryService.stop()
	ArenaService.endRound()
	VaultService.stop()
	BuildModeService.stop()
	PuffadorService.stop()
	LobbyService.returnToLobby(participantPlayers())
	BotFillService.stop()
	ArenaService.restoreAllBlocks()
	for _, combatant in ipairs(participantOrder) do
		resetParticipantAttributes(combatant)
	end
	clearRoundParticipants()
	winner = nil
end

function RoundService.getState(): RoundState
	return currentState
end

-- Jogadores reais da rodada em andamento (sem bots).
function RoundService.getParticipants(): { Player }
	return participantPlayers()
end

-- Comandos de teste (painel admin). Devolvem se foram aceitos.
-- Encurta a contagem (ou a próxima, se ainda esperando gente).
function RoundService.requestForceStart(): boolean
	if currentState == RoundTypes.Active or currentState == RoundTypes.Ending then
		return false
	end
	forceStartUntil = os.clock() + FORCE_START_WINDOW
	return true
end

function RoundService.requestSkipToFinalChaos(): boolean
	if currentState ~= RoundTypes.Active or FinalChaosService.isRunning() then
		return false
	end
	skipToChaosRequested = true
	return true
end

-- Termina a partida em andamento sem vencedor.
function RoundService.requestEndRound(): boolean
	if currentState ~= RoundTypes.Active then
		return false
	end
	endRoundRequested = true
	return true
end

-- Exposto para ser passado como callback tipado ao EliminationService.start,
-- evitando que EliminationService precise depender de RoundService.
RoundService.eliminateParticipant = eliminateParticipant

return table.freeze(RoundService)
