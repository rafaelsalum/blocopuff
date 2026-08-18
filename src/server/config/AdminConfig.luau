--!strict

export type AdminConfig = {
	AdminUserIds: { [number]: boolean },
	ActionCooldown: number,
	AnnouncementCooldown: number,
}

-- Somente o proprietário atual da experiência possui acesso inicial.
-- Administradores adicionais devem ser incluídos explicitamente e passar
-- pela mesma validação autoritativa do servidor.
local adminUserIds: { [number]: boolean } = {
	[4328593410] = true,
}

table.freeze(adminUserIds)

local AdminConfig: AdminConfig = {
	AdminUserIds = adminUserIds,
	ActionCooldown = 0.75,
	AnnouncementCooldown = 8,
}

return table.freeze(AdminConfig)
