--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
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
local PartySelection = require(script.Parent.Parent.data.PartySelection)
local XpCalculator = require(script.Parent.Parent.data.XpCalculator)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local ResultTypes = require(ReplicatedStorage.Shared.types.ResultTypes)

local awakeningRandom = Random.new()
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)

type RoundState = RoundTypes.RoundState
type RoundTimings = GameConfig.RoundTimings
type EliminationReason = EliminationTypes.EliminationReason

type Participant = {
	player: Player,
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

-- Atributos autoritativos escritos pelo servidor em cada Player, usados pelo
-- cliente para saber se participa da rodada atual sem inferir pela posição.
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

local participants: { [Player]: Participant } = {}
local participantOrder: { Player } = {}
local rotationQueue: { Player } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local playerRemovingConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local winner: Winner? = nil
local respawnGraceUntil: { [Player]: number } = {}
-- Quem já usou a Segunda Chance nesta rodada (Momento Puff "Volta por Cima").
local usedSecondChance: { [Player]: boolean } = {}
-- Posição final de quem foi eliminado (1 = vencedor): quantos seguiam vivos
-- depois da eliminação + 1.
local eliminationPositions: { [Player]: number } = {}
-- Momento de cada eliminação: quedas no mesmo instante viram empate.
local eliminationTimes: { [Player]: number } = {}
local resultRemote: RemoteEvent? = nil

local function countConnectedPlayers(): number
	return #Players:GetPlayers()
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
-- são avisadas (PartySelection).
local function selectParticipants(): { Player }
	local selected, waiting, deferredParties = PartySelection.select(rotationQueue, PartyService.groupOf, GameConfig.MaximumPlayers)
	rotationQueue = waiting
	publishQueuePositions()
	PartyService.roundSelected(selected, deferredParties)

	return selected
end

local function teleportParticipantsToArena(players: { Player })
	local spawnCFrames = ArenaService.getPlayerSpawnCFrames(#players)

	for index, player in ipairs(players) do
		local cframe = spawnCFrames[index]
		if cframe == nil then
			break
		end

		local character = player.Character
		if character == nil then
			warn(string.format("[BlocoPuff] Skipping arena teleport for %s: character not found", player.Name))
			continue
		end

		if not moveCharacterTo(character, cframe) then
			warn(string.format("[BlocoPuff] Failed to move %s into the arena", player.Name))
		end
	end
end

local function resetParticipantAttributes(player: Player)
	player:SetAttribute(ATTR_IS_PARTICIPANT, false)
	player:SetAttribute(ATTR_PARTICIPATING_ROUND_ID, 0)
	player:SetAttribute(ATTR_IS_ELIMINATED, false)
	player:SetAttribute(ATTR_ELIMINATION_REASON, EliminationTypes.None)
	player:SetAttribute(ATTR_ELIMINATED_AT_ROUND_ID, 0)
	player:SetAttribute(ATTR_ROUND_BLOCKS_DESTROYED, 0)
	player:SetAttribute(ATTR_HAS_SECOND_CHANCE, false)
	player:SetAttribute(ATTR_ROUND_KNOCKOUTS, 0)
end

local function markParticipantAttributes(player: Player, roundId: number)
	-- Antes de IsRoundParticipant: o cliente não deve ver um participante
	-- sem Segunda Chance nem por um instante.
	player:SetAttribute(ATTR_HAS_SECOND_CHANCE, GameConfig.SecondChance.Enabled)
	player:SetAttribute(ATTR_IS_PARTICIPANT, true)
	player:SetAttribute(ATTR_PARTICIPATING_ROUND_ID, roundId)
	player:SetAttribute(ATTR_IS_ELIMINATED, false)
	player:SetAttribute(ATTR_ELIMINATION_REASON, EliminationTypes.None)
	player:SetAttribute(ATTR_ELIMINATED_AT_ROUND_ID, 0)
	player:SetAttribute(ATTR_ROUND_BLOCKS_DESTROYED, 0)
	player:SetAttribute(ATTR_ROUND_KNOCKOUTS, 0)
end

local function onPlayerAdded(player: Player)
	resetParticipantAttributes(player)
	enqueuePlayer(player)
end

-- Ponto único e idempotente de eliminação: usado tanto pelo handler de morte
-- (Humanoid.Died) quanto pelo callback fornecido ao EliminationService para
-- a zona de queda. Marca o participante inativo antes de zerar o Humanoid,
-- para que um Died disparado por essa própria chamada não sobrescreva a causa.
-- Volta por Cima: Momento Puff e estatística, no máximo uma vez por rodada.
local function recordComeback(player: Player, detail: string)
	if RoundStatsService.get(player).comebacks == 0 then
		RoundStatsService.comeback(player)
	end
	PuffMomentService.record(player, "Comeback", detail)
end

-- Credita a derrubada a quem empurrou o jogador por último, se foi há pouco.
local function creditKnockout(victim: Player)
	local attacker = KnockbackService.getRecentAttacker(victim)
	KnockbackService.forget(victim)
	if attacker == nil or attacker == victim or participants[attacker] == nil then
		return
	end
	local current = attacker:GetAttribute(ATTR_ROUND_KNOCKOUTS)
	local count = if typeof(current) == "number" then current else 0
	attacker:SetAttribute(ATTR_ROUND_KNOCKOUTS, count + 1)
	if usedSecondChance[attacker] then
		recordComeback(attacker, "Knockout")
	end
end

-- Primeira queda para fora da arena: devolve o jogador a um bloco inteiro
-- (de preferência no andar de baixo) em vez de eliminá-lo. Desligada no
-- Caos Final. Retorna true se a Segunda Chance foi usada.
local function trySecondChance(player: Player): boolean
	if player:GetAttribute(ATTR_HAS_SECOND_CHANCE) ~= true or FinalChaosService.isRunning() then
		return false
	end
	local character = player.Character
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

	player:SetAttribute(ATTR_HAS_SECOND_CHANCE, false)
	usedSecondChance[player] = true
	respawnGraceUntil[player] = os.clock() + RESPAWN_FALL_GRACE
	KnockbackService.protect(player, GameConfig.SecondChance.RespawnProtection)
	-- O personagem é simulado pelo cliente: ele também zera a própria
	-- velocidade de queda ao receber este aviso.
	PuffadorService.sendFeedback(player, "Respawn", cframe)
	print(string.format("[BlocoPuff] %s used their Second Chance", player.Name))
	return true
end

local function eliminateParticipant(player: Player, reason: EliminationReason)
	local participant = participants[player]
	if participant == nil or not participant.alive then
		return
	end

	if reason == EliminationTypes.FellFromArena then
		local fallCharacter = player.Character
		local fallRoot = if fallCharacter ~= nil then getHumanoidRootPart(fallCharacter) else nil
		local fallPosition = if fallRoot ~= nil then fallRoot.Position else Vector3.zero
		-- Logo após a Segunda Chance o servidor ainda pode receber a posição
		-- antiga (abaixo da zona) antes do teleporte chegar ao cliente.
		local grace = respawnGraceUntil[player]
		if grace ~= nil and os.clock() < grace then
			return
		end
		creditKnockout(player)
		if trySecondChance(player) then
			TelemetryService.fell(player, fallPosition, true)
			TelemetryService.secondChanceUsed(player)
			return
		end
		TelemetryService.fell(player, fallPosition, false)
	end

	participant.alive = false
	local stillAlive = 0
	for _, other in pairs(participants) do
		if other.alive then
			stillAlive += 1
		end
	end
	eliminationPositions[player] = stillAlive + 1
	eliminationTimes[player] = os.clock()
	TelemetryService.eliminated(player, reason, stillAlive + 1)
	player:SetAttribute(ATTR_IS_ELIMINATED, true)
	player:SetAttribute(ATTR_ELIMINATION_REASON, reason)
	player:SetAttribute(ATTR_ELIMINATED_AT_ROUND_ID, currentRoundId)
	PuffadorService.revokeFrom(player)

	local character = player.Character
	if character ~= nil then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end

	print(string.format("[BlocoPuff] %s eliminated: %s", player.Name, reason))
end

local function onParticipantDied(player: Player)
	eliminateParticipant(player, EliminationTypes.CharacterDied)
end

local function connectParticipantDeathHandlers(players: { Player })
	for _, player in ipairs(players) do
		local character = player.Character
		if character == nil then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			continue
		end

		deathConnections[player] = humanoid.Died:Connect(function()
			onParticipantDied(player)
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

	for _, player in ipairs(participantOrder) do
		local participant = participants[player]
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

local function onPlayerRemoving(player: Player)
	local participant = participants[player]
	if participant ~= nil then
		if participant.alive then
			print(string.format("[BlocoPuff] %s eliminated: %s", player.Name, EliminationTypes.PlayerLeft))
		end
		if currentState == RoundTypes.Active and participant.alive then
			CorridorTelemetryService.leftMidRound(player)
			TelemetryService.leftMidRound(player)
		end

		participants[player] = nil
		for index, participantPlayer in ipairs(participantOrder) do
			if participantPlayer == player then
				table.remove(participantOrder, index)
				break
			end
		end
	end

	local connection = deathConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		deathConnections[player] = nil
	end

	PuffadorService.revokeFrom(player)
	dequeuePlayer(player)
end

local function runWaitingForPlayers()
	setState(RoundTypes.WaitingForPlayers)
	ReplicatedState.setTimeRemaining(0)
	ReplicatedState.clearWinner()
	ReplicatedState.setStatusMessage(RoundMessages.WaitingForPlayers)
	ReplicatedState.setParticipantCount(countConnectedPlayers())

	while isRunning and countConnectedPlayers() < GameConfig.MinimumPlayers do
		task.wait(POLL_INTERVAL)
		ReplicatedState.setParticipantCount(countConnectedPlayers())
	end
end

local function runCountdown(timings: RoundTimings): boolean
	setState(RoundTypes.Countdown)

	local remaining = timings.LobbyCountdown
	ReplicatedState.setTimeRemaining(remaining)
	ReplicatedState.setStatusMessage(RoundMessages.countdown(remaining))
	ReplicatedState.setParticipantCount(countConnectedPlayers())

	while isRunning and remaining > 0 do
		task.wait(TICK_INTERVAL)

		if not isRunning then
			return false
		end

		if countConnectedPlayers() < GameConfig.MinimumPlayers then
			return false
		end

		remaining -= 1
		ReplicatedState.setTimeRemaining(remaining)
		ReplicatedState.setStatusMessage(RoundMessages.countdown(remaining))
		ReplicatedState.setParticipantCount(countConnectedPlayers())
	end

	return isRunning
end

local function beginRound(timings: RoundTimings)
	currentRoundId += 1
	currentRoundStartedAt = os.time()

	-- A arena precisa estar totalmente restaurada e com a destruição
	-- habilitada para a nova rodada antes que qualquer jogador chegue nela.
	ArenaService.restoreAllBlocks()
	ArenaService.beginRound(currentRoundId)

	local selected = selectParticipants()
	clearRoundParticipants()
	for _, player in ipairs(selected) do
		participants[player] = { player = player, alive = true }
		table.insert(participantOrder, player)
		markParticipantAttributes(player, currentRoundId)
	end

	teleportParticipantsToArena(participantOrder)
	connectParticipantDeathHandlers(participantOrder)
	PuffadorService.beginRound(participantOrder, currentRoundId)
	KnockbackService.beginRound(currentRoundId)
	SecretPassageService.beginRound(currentRoundId)
	TocaService.beginRound(currentRoundId)
	PuffMomentService.beginRound()
	RoundStatsService.beginRound()
	SecretAchievementService.beginRound()
	PlayerDataService.roundStarted(participantOrder)
	CorridorTelemetryService.beginRound(currentRoundId)
	-- O Barão acorda e o cofre destranca no mesmo instante sorteado.
	local awakening = timings.RoundDuration * awakeningRandom:NextNumber(GameConfig.Barao.WakeMinFraction, GameConfig.Barao.WakeMaxFraction)
	BaraoService.beginRound(currentRoundId, awakening)
	TelemetryService.roundStarted(participantOrder)
	ReplicatedState.setFinalChaos(false)
	VaultService.beginRound(currentRoundId, awakening)

	-- Só inicia o monitoramento da zona depois que os participantes já
	-- estão posicionados na arena, evitando eliminar alguém ainda no lobby.
	EliminationService.beginRound(participantOrder, currentRoundId)

	setState(RoundTypes.Active)
	ReplicatedState.setRoundId(currentRoundId)
	ReplicatedState.setParticipantCount(#participantOrder)
	ReplicatedState.setTimeRemaining(timings.RoundDuration)
	ReplicatedState.setStatusMessage(RoundMessages.Active)

	print(string.format("[BlocoPuff] Round %d started with %d participants", currentRoundId, #participantOrder))
end

local function startFinalChaos(duration: number)
	FinalChaosService.begin(duration)
	ReplicatedState.setFinalChaos(true)
	local alivePlayers: { Player } = {}
	for _, player in ipairs(participantOrder) do
		local participant = participants[player]
		if participant ~= nil and participant.alive then
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
		local aliveCount, soleActive = evaluateActiveParticipants()

		if aliveCount == 0 then
			-- Todos caíram antes do próximo tique: vence quem caiu por último,
			-- se caiu sozinho; quedas no mesmo instante terminam em empate.
			local lastPlayers = RoundResultBuilder.getLastEliminated(eliminationTimes)
			winner = if #lastPlayers == 1
				then { userId = lastPlayers[1].UserId, name = lastPlayers[1].Name }
				else nil
			break
		elseif aliveCount == 1 then
			winner = if soleActive ~= nil
				then { userId = soleActive.player.UserId, name = soleActive.player.Name }
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
local function commitProfiles(result: ResultTypes.RoundResult)
	local roundKey = PlayerDataService.roundKey(currentRoundId, currentRoundStartedAt)
	for _, entry in ipairs(result.entries) do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player ~= nil and participants[player] ~= nil then
			local extra = RoundStatsService.get(player)
			local won = not result.draw and result.winnerUserId == entry.userId
			local podium = won or (entry.position <= 3 and result.participantCount >= TOP3_MIN_PARTICIPANTS)
			local delta = {
				matches = 1,
				wins = if won then 1 else 0,
				top3 = if podium then 1 else 0,
				knockouts = entry.knockouts,
				blocksDestroyed = entry.blocks,
				vaultsOpened = extra.vaultsOpened,
				vaultsConquered = extra.vaultsConquered,
				baraoEscapes = extra.baraoEscapes,
				secretsFound = extra.secretsFound,
				blocksBuilt = extra.blocksBuilt,
				comebacks = extra.comebacks,
			}
			-- O XP usa os mesmos números já limitados que vão para o perfil
			-- (o applyRound limita de novo e registra as anomalias).
			local trusted = ProfileSchema.clampDelta(delta)
			local xpLines, xpTotal = XpCalculator.compute({
				position = entry.position,
				participantCount = result.participantCount,
				won = won,
				knockouts = trusted.knockouts,
				blocksDestroyed = trusted.blocksDestroyed,
				secretsFound = trusted.secretsFound,
				vaultsOpened = trusted.vaultsOpened,
				vaultsConquered = trusted.vaultsConquered,
				baraoEscapes = trusted.baraoEscapes,
				comebacks = trusted.comebacks,
				blocksBuilt = trusted.blocksBuilt,
				shots = extra.shots,
			})
			PlayerDataService.applyRound(player, roundKey, delta, {
				roundId = currentRoundId,
				lines = xpLines,
				total = xpTotal,
				won = won,
				stayedAsSpectator = not entry.survived,
			})
		end
	end
end

local function publishResult()
	local remote = resultRemote
	local snapshots: { RoundResultBuilder.ParticipantSnapshot } = {}
	local winnerPlayer: Player? = nil
	for _, player in ipairs(participantOrder) do
		local participant = participants[player]
		if participant ~= nil and player.Parent ~= nil then
			local extra = RoundStatsService.get(player)
			table.insert(snapshots, {
				player = player,
				alive = participant.alive,
				eliminatedPosition = eliminationPositions[player],
				eliminatedAt = eliminationTimes[player],
				vaultsOpened = extra.vaultsOpened,
				vaultsConquered = extra.vaultsConquered,
				baraoEscapes = extra.baraoEscapes,
				secretsFound = extra.secretsFound,
				comebacks = extra.comebacks,
			})
			if winner ~= nil and player.UserId == winner.userId then
				winnerPlayer = player
			end
		end
	end
	local result = RoundResultBuilder.build(currentRoundId, snapshots, winnerPlayer)
	local committed, commitFailure = pcall(commitProfiles, result)
	if not committed then
		warn(string.format("[BlocoPuff] Could not save round to profiles: %s", tostring(commitFailure)))
	end
	-- Conquista "Por um Fio" (arena quase vazia); chamada antes de restaurar os pisos.
	local total = ArenaService.getTotalBlockCount()
	local remainingRatio = if total > 0 then ArenaService.getRemainingBlockCount() / total else 1
	local secretWinner = if result.draw then nil else winnerPlayer
	local secretsOk, secretsFailure = pcall(SecretAchievementService.roundFinished, secretWinner, remainingRatio)
	if not secretsOk then
		warn(string.format("[BlocoPuff] Secret achievements check failed: %s", tostring(secretsFailure)))
	end
	RoundStatsService.endRound()
	if remote == nil then
		return
	end
	local ok, failure = pcall(function()
		remote:FireAllClients(result)
	end)
	if not ok then
		warn(string.format("[BlocoPuff] Could not publish round result: %s", tostring(failure)))
	end
end

local function runEnding(timings: RoundTimings)
	setState(RoundTypes.Ending)
	EliminationService.endRound()
	FinalChaosService.stop()
	ReplicatedState.setFinalChaos(false)
	KnockbackService.endRound()
	SecretPassageService.endRound()
	BaraoService.endRound()
	TocaService.endRound()
	ArenaService.endRound()
	VaultService.endRound()
	CorridorTelemetryService.endRound()
	-- Volta por Cima também vale para quem venceu depois da Segunda Chance.
	local roundWinner = winner
	if roundWinner ~= nil then
		for _, player in ipairs(participantOrder) do
			if player.UserId == roundWinner.userId and usedSecondChance[player] then
				recordComeback(player, "Win")
			end
		end
	end
	PuffMomentService.endRound()
	publishResult()
	-- Mesma regra de empate do resultado: tempo esgotado com vários vivos
	-- ou os últimos caindo no mesmo instante.
	local survivors = 0
	for _, player in ipairs(participantOrder) do
		local participant = participants[player]
		if participant ~= nil and participant.alive then
			survivors += 1
		end
	end
	local tiedLast = if survivors == 0 then RoundResultBuilder.getLastEliminated(eliminationTimes) else {}
	local isDraw = winner == nil and (survivors > 1 or #tiedLast > 1)
	local outcomes: { [Player]: string } = {}
	for _, player in ipairs(participantOrder) do
		local participant = participants[player]
		if participant ~= nil then
			local won = winner ~= nil and player.UserId == winner.userId
			local inDraw = isDraw and (participant.alive or table.find(tiedLast, player) ~= nil)
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

	LobbyService.returnToLobby(participantOrder)
	-- Restaura depois que os jogadores já saíram da arena, evitando que um
	-- bloco reapareça dentro de um personagem.
	ArenaService.restoreAllBlocks()
	for _, player in ipairs(participantOrder) do
		resetParticipantAttributes(player)
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

		beginRound(timings)
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
	EliminationService.stop()
	FinalChaosService.stop()
	ReplicatedState.setFinalChaos(false)
	KnockbackService.stop()
	SecretPassageService.stop()
	BaraoService.stop()
	TocaService.stop()
	PuffMomentService.stop()
	CorridorTelemetryService.stop()
	ArenaService.endRound()
	VaultService.stop()
	BuildModeService.stop()
	PuffadorService.stop()
	LobbyService.returnToLobby(participantOrder)
	ArenaService.restoreAllBlocks()
	for _, player in ipairs(participantOrder) do
		resetParticipantAttributes(player)
	end
	clearRoundParticipants()
	winner = nil
end

function RoundService.getState(): RoundState
	return currentState
end

function RoundService.getParticipants(): { Player }
	local copy: { Player } = {}
	for _, player in ipairs(participantOrder) do
		table.insert(copy, player)
	end

	return copy
end

-- Exposto para ser passado como callback tipado ao EliminationService.start,
-- evitando que EliminationService precise depender de RoundService.
RoundService.eliminateParticipant = eliminateParticipant

return table.freeze(RoundService)
