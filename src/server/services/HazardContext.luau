--!strict

-- O que cada obstáculo da Corrida recebe do RaceHazards (Fase 5F.3): a
-- torre, a pasta das peças, se a corrida ainda vale, quem está correndo e
-- como atingir alguém (empurrão rampa abaixo e tontura).

local CombatantRegistry = require(script.Parent.CombatantRegistry)
local TowerBuilder = require(script.Parent.TowerBuilder)

export type Context = {
	tower: TowerBuilder.TowerLayout,
	folder: Instance,
	random: Random,
	-- A corrida que lançou o obstáculo ainda está valendo?
	isLive: () -> boolean,
	racers: () -> { CombatantRegistry.Combatant },
	-- Atinge `combatant`, que está na volta `t` da rampa, com o obstáculo
	-- `kind` (para a telemetria RaceHazardHit).
	hit: (combatant: CombatantRegistry.Combatant, t: number, kind: string) -> (),
	-- Volta (t) da rampa mais perto de `position`.
	turnsAt: (position: Vector3) -> number,
	-- Peça que some quando a corrida para.
	track: (instance: Instance) -> (),
}

return {}
