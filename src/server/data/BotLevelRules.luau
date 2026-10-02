--!strict

-- Nível dos bots RoboPuff de uma partida (Fase 5B), sem Roblox. Os testes
-- rodam no Lune (tests/BotLevelRules.spec.luau).
--
--   * Algum novato na partida (menos de `BeginnerMatches` partidas): todos
--     os bots no modo fácil, para a primeira vitória vir cedo.
--   * Senão, o humano de maior nível decide: até `ExperiencedLevel`, bots
--     Fácil e Normal misturados; acima, Normal e Esperto misturados.

export type Level = "Easy" | "Normal" | "Hard"

export type HumanInfo = {
	matches: number,
	level: number,
}

export type LevelRules = {
	BeginnerMatches: number,
	ExperiencedLevel: number,
}

local BotLevelRules = {}

-- Níveis de `count` bots, alternando os dois do grupo (o mais fraco primeiro).
function BotLevelRules.choose(count: number, humans: { HumanInfo }, rules: LevelRules): { Level }
	local levels: { Level } = {}
	if count <= 0 then
		return levels
	end
	local beginner = #humans == 0
	local topLevel = 0
	for _, human in ipairs(humans) do
		if human.matches < rules.BeginnerMatches then
			beginner = true
		end
		topLevel = math.max(topLevel, human.level)
	end
	local tier: { Level } = if beginner
		then { "Easy", "Easy" }
		elseif topLevel <= rules.ExperiencedLevel then { "Easy", "Normal" }
		else { "Normal", "Hard" }
	for index = 1, count do
		table.insert(levels, tier[((index - 1) % 2) + 1])
	end
	return levels
end

return table.freeze(BotLevelRules)
