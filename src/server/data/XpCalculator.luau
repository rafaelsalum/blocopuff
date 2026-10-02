--!strict

-- XP de uma rodada para um jogador, por fonte. Só usa dados calculados no
-- servidor. Limites por fonte e o multiplicador por número de
-- participantes evitam farming trivial (partidas de 2 com conta alternativa,
-- ficar parado, repetir a mesma ação).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)

type XpLine = ProfileTypes.XpLine

export type XpInput = {
	position: number,
	participantCount: number,
	won: boolean,
	knockouts: number,
	blocksDestroyed: number,
	secretsFound: number,
	vaultsOpened: number,
	vaultsConquered: number,
	baraoEscapes: number,
	comebacks: number,
	blocksBuilt: number,
	shots: number,
	-- Partida com bots RoboPuff (BotRewardRules); ausentes = regra normal.
	-- Derrubadas de bots, que valem `botKnockoutFactor` do XP de derrubada.
	botKnockouts: number?,
	botKnockoutFactor: number?,
	-- Quantos contam para o multiplicador (os humanos) e o piso dele.
	multiplierCount: number?,
	minMultiplier: number?,
}

local XpCalculator = {}

local function participantMultiplier(count: number): number
	local multipliers = ProgressionConfig.ParticipantMultipliers
	local index = math.clamp(math.floor(count), 1, #multipliers)
	return multipliers[index]
end

-- Linhas de XP (já com o multiplicador) e o total.
function XpCalculator.compute(input: XpInput): ({ XpLine }, number)
	local xp = ProgressionConfig.Xp
	local botKnockouts = math.max(0, input.botKnockouts or 0)
	local active = not ProgressionConfig.RequireActivity
		or input.shots > 0
		or input.blocksBuilt > 0
		or input.knockouts > 0
		or botKnockouts > 0
	local raw: { XpLine } = {}
	local function add(source: string, amount: number)
		if amount > 0 then
			table.insert(raw, { source = source, xp = amount })
		end
	end

	if active then
		add("Participation", xp.Participation)
		if input.participantCount > 1 then
			local share = (input.participantCount - math.clamp(input.position, 1, input.participantCount)) / (input.participantCount - 1)
			add("Placement", math.floor(xp.PlacementMax * share))
		end
	end
	-- Vencer sem ter jogado (adversários saíram) não rende o bônus.
	if input.won and active then
		add("Win", xp.Win)
	end
	-- O teto de derrubadas vale para a soma; as de humanos entram primeiro.
	local humanKnockouts = math.min(input.knockouts, xp.MaxKnockouts)
	local cheapKnockouts = math.min(botKnockouts, xp.MaxKnockouts - humanKnockouts)
	add("Knockouts", math.floor((xp.PerKnockout * humanKnockouts) + (xp.PerKnockout * (input.botKnockoutFactor or 1) * cheapKnockouts)))
	add("Blocks", math.min(xp.MaxBlockXp, math.floor(input.blocksDestroyed / math.max(1, xp.BlocksPerXp))))
	add("Secrets", xp.PerSecretFound * input.secretsFound)
	add("VaultOpened", xp.VaultOpened * math.min(1, input.vaultsOpened))
	add("VaultConquered", xp.VaultConquered * math.min(1, input.vaultsConquered))
	add("BaraoEscapes", xp.PerBaraoEscape * math.min(input.baraoEscapes, xp.MaxBaraoEscapes))
	add("Comeback", xp.Comeback * math.min(1, input.comebacks))
	add("BlocksBuilt", xp.PerBlockBuilt * input.blocksBuilt)

	local multiplier = math.max(participantMultiplier(input.multiplierCount or input.participantCount), input.minMultiplier or 0)
	local lines: { XpLine } = {}
	local total = 0
	for _, line in ipairs(raw) do
		local amount = math.floor((line.xp * multiplier) + 0.5)
		if amount > 0 then
			table.insert(lines, { source = line.source, xp = amount })
			total += amount
		end
	end
	return lines, total
end

return table.freeze(XpCalculator)
