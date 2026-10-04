--!strict

-- Tipos do Puffdex (Fase 4): catálogo de Puffs colecionáveis e o que cada
-- jogador tem. Puffs são só visuais (rastro, brilho e faíscas do disparo):
-- nunca mudam hitbox, empurrão, cadência, alcance ou dano.

export type PuffRarity = "Common" | "Rare" | "Epic" | "Legendary"

-- De onde o Puff veio. "Machine" fica reservado para a Puff Machine (4.2) e
-- "Album" para quem completa o Álbum do Casarão (5C.2).
export type PuffOrigin = "Starter" | "Level" | "Feat" | "Machine" | "Album"

-- Como desbloquear:
--   Starter: todo mundo começa com ele.
--   Level:   chegar ao nível `target`.
--   Stat:    chegar a `target` na estatística `stat` do perfil.
--   Machine: só pela Puff Machine (4.2).
--   Album:   só completando o Álbum do Casarão (5C.2).
export type PuffUnlockKind = "Starter" | "Level" | "Stat" | "Machine" | "Album"

export type PuffUnlockRule = {
	kind: PuffUnlockKind,
	stat: string?,
	target: number?,
}

-- Formato do efeito do Puff (partículas e movimento do rastro), ver
-- PuffEffects. Só visual.
export type PuffEffect = "Soft" | "Sparkle" | "Bubbles" | "Cloud" | "Flakes" | "Zigzag" | "Spiral" | "Confetti" | "Flames" | "Rainbow"

-- Cores e efeito do disparo. O projétil em si continua do mesmo tamanho e
-- cor (branco bem visível); o Puff muda o rastro, o brilho, as partículas e
-- as faíscas do impacto. Tamanho, velocidade e acerto são iguais para todos.
export type PuffStyle = {
	trailStart: Color3,
	trailEnd: Color3,
	glow: Color3,
	spark: Color3,
	effect: PuffEffect,
}

export type PuffDefinition = {
	id: string,
	name: string,
	rarity: PuffRarity,
	origin: PuffOrigin,
	unlock: PuffUnlockRule,
	-- Frase curta de como conseguir (para crianças: sem textos longos).
	hint: string,
	-- Uma linha de "história" do Puff, curta e divertida.
	lore: string,
	-- Ilustração do cartão (rbxassetid://…), quando existir (Camada B).
	image: string?,
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
	Origins = table.freeze({ "Starter", "Level", "Feat", "Machine", "Album" } :: { PuffOrigin }),
}

return table.freeze(PuffTypes)
