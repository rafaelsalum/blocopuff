--!strict

-- Convite com recompensa (Fase 5B). Quem entra no jogo pela primeira vez a
-- convite de um amigo ganha `InviteeTickets` ao terminar a primeira
-- partida; quem convidou ganha `InviterTickets` por amigo, uma vez por
-- amigo, até `InviterMaxPerDay` amigos por dia e `InviterMaxTotal` no total.
-- O amigo precisa jogar uma partida inteira (sair no meio não conta).

export type ReferralConfig = {
	InviteeTickets: number,
	InviterTickets: number,
	InviterMaxPerDay: number,
	InviterMaxTotal: number,
	-- Amigos guardados esperando quem convidou entrar no jogo.
	PendingKeep: number,
	StoreName: string,
	KeyPrefix: string,
	MessageTopic: string,
	PromptMessage: string,
	-- Intervalo mínimo entre dois convites pedidos pelo mesmo jogador.
	InviteCooldown: number,
}

local ReferralConfig: ReferralConfig = {
	InviteeTickets = 5,
	InviterTickets = 5,
	InviterMaxPerDay = 3,
	InviterMaxTotal = 20,
	PendingKeep = 20,
	StoreName = "BlocoPuffReferralsV1",
	KeyPrefix = "inviter_",
	MessageTopic = "BlocoPuffReferralV1",
	PromptMessage = "Vem derrubar blocos comigo no Bloco Puff!",
	InviteCooldown = 3,
}

return table.freeze(ReferralConfig)
