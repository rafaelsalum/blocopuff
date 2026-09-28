--!strict

-- Party e espectador social (Fase 4.4).
--
-- Party: grupo de amigos no mesmo servidor que entra junto nas partidas.
-- Limite de 4 (um terço da sala de 12): sobra espaço para quem joga sozinho
-- e várias Parties cabem na mesma partida.
--
-- Reações: emojis fixos (sem texto livre, então nada a filtrar), só de quem
-- não está competindo e só vistos por quem não está competindo: não
-- atrapalham a partida.

export type SocialConfig = {
	PartyMaxSize: number,
	InviteLifetime: number,
	InviteCooldown: number,
	Reactions: { string },
	ReactionCooldown: number,
}

local SocialConfig: SocialConfig = {
	PartyMaxSize = 4,
	InviteLifetime = 30,
	InviteCooldown = 2,
	Reactions = table.freeze({ "👏", "😮", "😂", "🔥", "💜" }),
	ReactionCooldown = 1.5,
}

return table.freeze(SocialConfig)
