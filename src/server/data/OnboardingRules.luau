--!strict

-- Regras puras do funil da primeira sessão (Funil de Onboarding do Creator
-- Dashboard), sem Roblox. Os testes rodam no Lune
-- (tests/OnboardingRules.spec.luau).
--
--   * Cada passo é enviado uma vez na vida do jogador: o perfil guarda os
--     passos já enviados num conjunto de bits (`onboardingSteps`).
--   * Perfis que já tinham partidas antes do funil existir entram com
--     todos os passos marcados: não são jogadores novos e não sujariam o
--     funil.
--   * O tipo da primeira partida (só humanos ou com bots) acompanha o
--     jogador para comparar a retenção dos dois grupos.

local OnboardingRules = {}

-- Ordem do funil (o número do passo é a posição na lista).
OnboardingRules.Steps = table.freeze({
	"Joined",
	"FirstShot",
	"QueueEntered",
	"MatchStarted",
	"FirstBlockDown",
	"MatchFinished",
	"SecondMatch",
	"ReturnedAnotherDay",
})

OnboardingRules.Step = table.freeze({
	Joined = 1,
	FirstShot = 2,
	QueueEntered = 3,
	MatchStarted = 4,
	FirstBlockDown = 5,
	MatchFinished = 6,
	SecondMatch = 7,
	ReturnedAnotherDay = 8,
})

OnboardingRules.AllSteps = 2 ^ #OnboardingRules.Steps - 1

-- Tipo da primeira partida guardado no perfil (`firstMatchKind`).
OnboardingRules.FirstMatch = table.freeze({
	None = 0,
	Humans = 1,
	Bots = 2,
})

local SECONDS_PER_DAY = 86400

local function bitOf(step: number): number
	return 2 ^ (step - 1)
end

function OnboardingRules.has(mask: number, step: number): boolean
	return math.floor(mask / bitOf(step)) % 2 == 1
end

-- Marca o passo. Devolve o novo conjunto e se o passo é novo.
function OnboardingRules.mark(mask: number, step: number): (number, boolean)
	if step < 1 or step > #OnboardingRules.Steps or step ~= math.floor(step) then
		return mask, false
	end
	if OnboardingRules.has(mask, step) then
		return mask, false
	end
	return mask + bitOf(step), true
end

-- Conjunto ao carregar: quem já jogou antes do funil existir fica de fora.
function OnboardingRules.initial(mask: number, matches: number): number
	if mask <= 0 and matches > 0 then
		return OnboardingRules.AllSteps
	end
	return math.clamp(math.floor(mask), 0, OnboardingRules.AllSteps)
end

-- Passos que o próprio perfil comprova (partidas e volta em outro dia).
function OnboardingRules.stepsFromProfile(matches: number, createdAt: number, now: number): { number }
	local steps: { number } = {}
	if matches >= 1 then
		table.insert(steps, OnboardingRules.Step.MatchFinished)
	end
	if matches >= 2 then
		table.insert(steps, OnboardingRules.Step.SecondMatch)
	end
	if now - createdAt >= SECONDS_PER_DAY then
		table.insert(steps, OnboardingRules.Step.ReturnedAnotherDay)
	end
	return steps
end

-- Rótulo do tipo da primeira partida para a telemetria.
function OnboardingRules.firstMatchLabel(kind: number): string
	if kind == OnboardingRules.FirstMatch.Bots then
		return "FirstBots"
	elseif kind == OnboardingRules.FirstMatch.Humans then
		return "FirstHumans"
	end
	return "FirstNone"
end

-- Tipo a gravar depois de uma rodada: só a primeira partida conta.
function OnboardingRules.firstMatchKind(current: number, matchesBefore: number, matchesGained: number, withBots: boolean): number
	if current ~= OnboardingRules.FirstMatch.None or matchesBefore > 0 or matchesGained <= 0 then
		return current
	end
	return if withBots then OnboardingRules.FirstMatch.Bots else OnboardingRules.FirstMatch.Humans
end

return table.freeze(OnboardingRules)
