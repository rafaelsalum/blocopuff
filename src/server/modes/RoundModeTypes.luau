--!strict

-- Contrato de um modo de partida (Fase 5D.1). O RoundService cuida do ciclo
-- comum (fila, contagem, participantes, eliminação, resultado, perfil e
-- intervalo); o modo cuida do mapa e do que só existe nele (na Arena: blocos,
-- armadilhas, corredores, Tocas, Barão, cofre e Caos Final).

local CombatantRegistry = require(script.Parent.Parent.services.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

export type BeginContext = {
	roundId: number,
	-- Todos os participantes, já posicionados no mapa do modo.
	combatants: { Combatant },
	humans: { Player },
	roundDuration: number,
}

export type TickContext = {
	roundId: number,
	remaining: number,
	climaxDuration: number,
	-- Jogadores reais ainda vivos (só calculado quando o modo pede).
	alivePlayers: () -> { Player },
}

-- Fim decidido pelo próprio modo (a Corrida acaba quando o pódio enche).
export type Outcome = {
	winner: Combatant?,
}

export type RoundMode = {
	id: string,
	-- Pode rodar com esta fila agora? (`humans` = jogadores reais escalados.)
	canRun: (humans: number) -> boolean,
	-- Deixa o mapa pronto antes de qualquer participante chegar.
	prepare: (roundId: number) -> (),
	getSpawnCFrames: (count: number) -> { CFrame },
	-- Duração da partida neste modo (`default` vem do GameConfig).
	getRoundDuration: (default: number) -> number,
	-- Liga os sistemas do modo com os participantes já no mapa.
	begin: (context: BeginContext) -> (),
	-- Duração do clímax do fim da partida (0 = sem clímax).
	getClimaxDuration: (roundDuration: number) -> number,
	isInClimax: () -> boolean,
	tick: (context: TickContext) -> (),
	-- O último em pé vence (Arena)? Sem isso, só `evaluate` e o tempo acabam
	-- a partida.
	lastStanding: boolean,
	-- A partida acabou pelas regras do modo? nil = ainda não. Com `timeUp`
	-- (o tempo acabou), o modo pode dizer quem venceu mesmo assim.
	evaluate: (timeUp: boolean) -> Outcome?,
	-- Posição final de cada participante (nil = pela ordem de eliminação).
	getRanking: () -> { [Combatant]: number }?,
	-- Cérebro dos bots RoboPuff neste modo.
	beginBots: (bots: { Combatant }, humans: { Player }) -> (),
	endBots: () -> (),
	-- Onde reaparece quem usa a Segunda Chance (nil = não pode usar agora).
	getRespawnCFrame: () -> CFrame?,
	-- Fração do mapa ainda de pé no fim (conquista "Por um Fio"; 1 = intacto).
	getRemainingFloorRatio: () -> number,
	-- Desliga os sistemas do modo no fim da partida (antes do resultado).
	finish: () -> (),
	-- Restaura o mapa depois que todos voltaram ao lobby.
	cleanup: () -> (),
	-- Servidor parando: desliga tudo do modo.
	stop: () -> (),
}

return table.freeze({})
