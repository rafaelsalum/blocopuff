--!strict

-- Contrato compartilhado do painel administrativo. A lista de pessoas
-- autorizadas permanece exclusivamente no servidor.

export type AdminAction = "Announce" | "Kick" | "Ban" | "Unban"

export type AdminRequest = {
	action: string,
	targetUserId: number?,
	message: string?,
	reason: string?,
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
})

return AdminConstants
