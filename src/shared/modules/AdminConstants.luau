--!strict

-- Contrato compartilhado do painel administrativo. A lista de pessoas
-- autorizadas permanece exclusivamente no servidor.

export type AdminAction = "Announce" | "Kick" | "Ban" | "Unban"

-- Ações de teste da partida (MatchTestControls), também só para admins.
export type MatchTestAction = "ForceStart" | "SkipToChaos" | "EndRound" | "BotsOn" | "BotsOff" | "BotLevel"

export type AdminRequest = {
	action: string,
	targetUserId: number?,
	message: string?,
	reason: string?,
	-- Parâmetro curto de uma ação de teste (ex.: nível dos bots).
	option: string?,
}

export type AdminResponse = {
	ok: boolean,
	message: string,
}

export type AnnouncementPayload = {
	id: string,
	message: string,
	sender: string,
}

local AdminConstants = table.freeze({
	RemotesContainerName = "BlocoPuffAdminRemotes",
	StatusFunctionName = "GetAdminStatus",
	ActionFunctionName = "RequestAdminAction",
	AnnouncementEventName = "AdminAnnouncement",
	AnnouncementTopic = "BlocoPuffAdminAnnouncementV1",
	ModerationTopic = "BlocoPuffAdminModerationV1",
	BanStoreName = "BlocoPuffAdminBansV1",
	MaximumAnnouncementLength = 180,
	MaximumReasonLength = 120,
	MaximumOptionLength = 16,
	-- Níveis aceitos em "BotLevel" ("Auto" = escolha normal).
	BotLevelOptions = table.freeze({ "Auto", "Easy", "Normal", "Hard" }),
})

return AdminConstants
