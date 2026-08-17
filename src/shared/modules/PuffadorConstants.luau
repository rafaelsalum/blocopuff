--!strict

-- Identidade e nomes usados pelo Puffador: ferramenta, projéteis e o
-- RemoteEvent de disparo. Fonte única para servidor (PuffadorService,
-- ProjectileService) e cliente (PuffadorController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

export type PuffadorConstantsModule = {
	ToolName: string,
	HandleName: string,
	MuzzleAttachmentName: string,

	ProjectileName: string,
	ProjectileTag: string,
	ProjectilesContainerName: string,

	RemotesContainerName: string,
	RequestPuffRemoteName: string,
	PuffFeedbackRemoteName: string,

	OwnerUserIdAttribute: string,
	RoundIdAttribute: string,
	ProjectileIdAttribute: string,
	ShotSoundName: string,
	HitSoundName: string,

	PuffadorPrimaryColor: Color3,
	PuffadorAccentColor: Color3,
	ProjectileColor: Color3,
}

local PuffadorConstants: PuffadorConstantsModule = {
	ToolName = "Puffador",
	HandleName = "Handle",
	MuzzleAttachmentName = "Muzzle",

	ProjectileName = "PuffadorProjectile",
	ProjectileTag = "PuffadorProjectile",
	ProjectilesContainerName = "Projectiles",

	RemotesContainerName = "BlocoPuffRemotes",
	RequestPuffRemoteName = "RequestPuff",
	PuffFeedbackRemoteName = "PuffFeedback",

	OwnerUserIdAttribute = "OwnerUserId",
	RoundIdAttribute = StateAttributeNames.RoundId,
	ProjectileIdAttribute = "ProjectileId",
	ShotSoundName = "ShotSound",
	HitSoundName = "HitSound",

	PuffadorPrimaryColor = Color3.fromRGB(194, 168, 255),
	PuffadorAccentColor = Color3.fromRGB(255, 230, 148),
	ProjectileColor = Color3.fromRGB(255, 250, 240),
}

return table.freeze(PuffadorConstants)
