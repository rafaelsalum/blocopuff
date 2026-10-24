--!strict

-- Modo Arena (Fase 5D.1): a partida de sempre, derrubar e não cair. Reúne o
-- que antes ficava espalhado no RoundService e só existe na Arena: blocos,
-- armadilhas, corredores secretos, Tocas, Barão, cofre, zona de queda e Caos
-- Final. A ordem das chamadas é a mesma de antes da extração.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local RoundModeTypes = require(script.Parent.RoundModeTypes)
local services = script.Parent.Parent.services
local ArenaService = require(services.ArenaService)
local EliminationService = require(services.EliminationService)
local TrapService = require(services.TrapService)
local SecretPassageService = require(services.SecretPassageService)
local TocaService = require(services.TocaService)
local CorridorTelemetryService = require(services.CorridorTelemetryService)
local BaraoService = require(services.BaraoService)
local VaultService = require(services.VaultService)
local FinalChaosService = require(services.FinalChaosService)
local TelemetryService = require(services.TelemetryService)
local ReplicatedState = require(services.ReplicatedStateService)
local BotBrainService = require(services.BotBrainService)
local CombatantRegistry = require(services.CombatantRegistry)

type BeginContext = RoundModeTypes.BeginContext
type TickContext = RoundModeTypes.TickContext
type Outcome = RoundModeTypes.Outcome
type Combatant = CombatantRegistry.Combatant

local awakeningRandom = Random.new()

local function canRun(_humans: number): boolean
	return true
end

-- A arena precisa estar totalmente restaurada e com a destruição habilitada
-- para a nova rodada antes que qualquer jogador chegue nela.
local function prepare(roundId: number)
	ArenaService.restoreAllBlocks()
	ArenaService.beginRound(roundId)
end

local function getSpawnCFrames(count: number): { CFrame }
	return ArenaService.getPlayerSpawnCFrames(count)
end

local function getRoundDuration(default: number): number
	return default
end

local function begin(context: BeginContext)
	TrapService.beginRound()
	SecretPassageService.beginRound(context.roundId)
	TocaService.beginRound(context.roundId)
	CorridorTelemetryService.beginRound(context.roundId)
	-- O Barão acorda e o cofre destranca no mesmo instante sorteado.
	local awakening = context.roundDuration * awakeningRandom:NextNumber(GameConfig.Barao.WakeMinFraction, GameConfig.Barao.WakeMaxFraction)
	BaraoService.beginRound(context.roundId, awakening)
	ReplicatedState.setFinalChaos(false)
	VaultService.beginRound(context.roundId, awakening)
	-- Só inicia o monitoramento da zona depois que os participantes já
	-- estão posicionados na arena, evitando eliminar alguém ainda no lobby.
	EliminationService.beginRound(context.combatants, context.roundId)
end

local function getClimaxDuration(roundDuration: number): number
	return FinalChaosService.getDuration(roundDuration)
end

local function isInClimax(): boolean
	return FinalChaosService.isRunning()
end

local function tick(context: TickContext)
	if context.remaining > context.climaxDuration or FinalChaosService.isRunning() then
		return
	end
	FinalChaosService.begin(context.climaxDuration)
	TrapService.storm(context.climaxDuration, context.alivePlayers())
	ReplicatedState.setFinalChaos(true)
	TelemetryService.finalChaosStarted(context.alivePlayers())
	print(string.format("[BlocoPuff] Round %d entered Final Chaos (%ds)", context.roundId, context.climaxDuration))
end

-- Na Arena só vale o padrão: o último em pé vence (`lastStanding`).
local function evaluate(_timeUp: boolean): Outcome?
	return nil
end

local function getRanking(): { [Combatant]: number }?
	return nil
end

local function start(_remotes: Folder?) end

local function getPuffadorHolders(humans: { Player }): { Player }
	return humans
end

local function onEliminated(_combatant: Combatant) end

local function getWinners(): { [Combatant]: boolean }?
	return nil
end

local function beginBots(bots: { Combatant }, humans: { Player })
	BotBrainService.beginRound(bots, humans)
end

local function endBots()
	BotBrainService.endRound()
end

-- Segunda Chance: um bloco inteiro, de preferência no andar de baixo.
-- Desligada no Caos Final.
local function getRespawnCFrame(): CFrame?
	if FinalChaosService.isRunning() then
		return nil
	end
	for floorIndex = 1, GameConfig.Arena.FloorCount do
		local cframe = ArenaService.getSafeRespawnCFrame(floorIndex)
		if cframe ~= nil then
			return cframe
		end
	end
	return nil
end

local function getRemainingFloorRatio(): number
	local total = ArenaService.getTotalBlockCount()
	return if total > 0 then ArenaService.getRemainingBlockCount() / total else 1
end

local function finish()
	EliminationService.endRound()
	FinalChaosService.stop()
	ReplicatedState.setFinalChaos(false)
	TrapService.endRound()
	SecretPassageService.endRound()
	BaraoService.endRound()
	TocaService.endRound()
	ArenaService.endRound()
	VaultService.endRound()
	CorridorTelemetryService.endRound()
end

-- Restaura depois que os jogadores já saíram da arena, evitando que um bloco
-- reapareça dentro de um personagem.
local function cleanup()
	ArenaService.restoreAllBlocks()
	TrapService.refresh()
end

local function stop()
	EliminationService.stop()
	FinalChaosService.stop()
	ReplicatedState.setFinalChaos(false)
	TrapService.stop()
	SecretPassageService.stop()
	BaraoService.stop()
	TocaService.stop()
	CorridorTelemetryService.stop()
	ArenaService.endRound()
	VaultService.stop()
end

local ArenaMode: RoundModeTypes.RoundMode = {
	id = "Arena",
	start = start,
	canRun = canRun,
	prepare = prepare,
	getSpawnCFrames = getSpawnCFrames,
	getRoundDuration = getRoundDuration,
	begin = begin,
	getClimaxDuration = getClimaxDuration,
	isInClimax = isInClimax,
	tick = tick,
	lastStanding = true,
	evaluate = evaluate,
	getRanking = getRanking,
	getPuffadorHolders = getPuffadorHolders,
	onEliminated = onEliminated,
	getWinners = getWinners,
	beginBots = beginBots,
	endBots = endBots,
	getRespawnCFrame = getRespawnCFrame,
	getRemainingFloorRatio = getRemainingFloorRatio,
	finish = finish,
	cleanup = cleanup,
	stop = stop,
}

return table.freeze(ArenaMode)
