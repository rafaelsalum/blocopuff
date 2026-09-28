--!strict

-- Tickets e Puff Machine (Fase 4.2). Tickets são moeda NÃO competitiva:
-- saem só jogando (e, na 4.3, de desafios e retorno diário) e só servem
-- para a Puff Machine, que só dá Puffs cosméticos. Não existe compra com
-- Robux, nem pacote pago, nem forma de trocar tickets por poder.
--
-- Anti-frustração, sem estrutura predatória:
--   * probabilidades fixas e mostradas na própria máquina;
--   * Épico ou melhor garantido a cada `PityThreshold` giros sem um;
--   * Puff repetido devolve `DuplicateRefund` tickets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)

type PuffRarity = PuffTypes.PuffRarity

export type RarityWeight = {
	rarity: PuffRarity,
	-- Chance em porcentagem (a soma dá 100).
	percent: number,
}

export type RewardConfig = {
	-- Tickets por rodada (só para quem jogou de verdade: ganhou XP).
	TicketsPerRound: number,
	TicketsTop3: number,
	TicketsWin: number,
	-- Por nível ganho.
	TicketsPerLevelUp: number,
	-- Eliminado que ficou assistindo até o fim da partida (torcida, 4.4).
	TicketsSpectator: number,
	-- Teto por rodada (defesa extra).
	MaxTicketsPerRound: number,
	MaxTickets: number,

	MachineCost: number,
	MachineOdds: { RarityWeight },
	PityThreshold: number,
	DuplicateRefund: number,
	-- Tempo mínimo entre giros no servidor. A revelação no cliente dura mais
	-- que isso, então quem gira normalmente nunca esbarra no limite.
	MachineCooldown: number,
	MachineRevealTime: number,
}

local RewardConfig: RewardConfig = {
	TicketsPerRound = 1,
	TicketsTop3 = 1,
	TicketsWin = 1,
	TicketsPerLevelUp = 2,
	TicketsSpectator = 1,
	MaxTicketsPerRound = 12,
	MaxTickets = 99999,

	MachineCost = 5,
	MachineOdds = table.freeze({
		table.freeze({ rarity = "Common", percent = 60 }),
		table.freeze({ rarity = "Rare", percent = 28 }),
		table.freeze({ rarity = "Epic", percent = 10 }),
		table.freeze({ rarity = "Legendary", percent = 2 }),
	} :: { RarityWeight }),
	PityThreshold = 10,
	DuplicateRefund = 2,
	MachineCooldown = 1.5,
	MachineRevealTime = 1.8,
}

local total = 0
for _, weight in ipairs(RewardConfig.MachineOdds) do
	total += weight.percent
end
assert(total == 100, "Puff Machine odds must add up to 100")

return table.freeze(RewardConfig)
