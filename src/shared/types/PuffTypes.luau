--!strict

-- Tipos do Puffdex (Fase 4): catálogo de Puffs colecionáveis e o que cada
-- jogador tem. Puffs são só visuais (rastro, brilho e faíscas do disparo):
-- nunca mudam hitbox, empurrão, cadência, alcance ou dano.

export type PuffRarity = "Common" | "Rare" | "Epic" | "Legendary"

-- De onde o Puff veio. "Machine" fica reservado para a Puff Machine (4.2).
export type PuffOrigin = "Starter" | "Level" | "Feat" | "Machine"

-- Como desbloquear:
--   Starter: todo mundo começa com ele.
--   Level:   chegar ao nível `target`.
--   Stat:    chegar a `target` na estatística `stat` do perfil.
--   Machine: só pela Puff Machine (4.2).
export type PuffUnlockKind = "Starter" | "Level" | "Stat" | "Machine"

export type PuffUnlockRule = {
	kind: PuffUnlockKind,
	stat: string?,
	target: number?,
}

-- Cores do disparo. O projétil em si continua do mesmo tamanho e cor (branco
-- bem visível); o Puff muda só o rastro, o brilho e as faíscas do impacto.
export type PuffStyle = {
	trailStart: Color3,
	trailEnd: Color3,
	glow: Color3,
	spark: Color3,
}

export type PuffDefinition = {
	id: string,
	name: string,
	rarity: PuffRarity,
	origin: PuffOrigin,
	unlock: PuffUnlockRule,
	-- Frase curta de como conseguir (para crianças: sem textos longos).
	hint: string,
	style: PuffStyle,
	-- Preparação para trading futuro (desligado).
	tradable: boolean,
}

-- Um Puff que o jogador tem (cópia enviada ao cliente).
export type OwnedPuff = {
	id: string,
	obtainedAt: number,
	count: number,
	origin: PuffOrigin,
}

local PuffTypes = {
	Rarities = table.freeze({ "Common", "Rare", "Epic", "Legendary" } :: { PuffRarity }),
	Origins = table.freeze({ "Starter", "Level", "Feat", "Machine" } :: { PuffOrigin }),
}

return table.freeze(PuffTypes)
