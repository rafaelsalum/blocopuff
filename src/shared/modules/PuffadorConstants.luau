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
	VaultEventRemoteName: string,
	RoundResultRemoteName: string,
	ReportDeviceRemoteName: string,
	SecretEventRemoteName: string,
	RequestBuildRemoteName: string,
	PuffMomentRemoteName: string,
	ProfileSnapshotRemoteName: string,
	LeaderboardRemoteName: string,
	PuffdexRemoteName: string,
	PuffMachineRemoteName: string,
	PartyRemoteName: string,
	ReactionRemoteName: string,
	MatchQueueRemoteName: string,
	ReferralRemoteName: string,
	DashRemoteName: string,
	PuffShotsRemoteName: string,
	MysteryRemoteName: string,

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
	VaultEventRemoteName = "VaultEvent",
	RoundResultRemoteName = "RoundResult",
	ReportDeviceRemoteName = "ReportDevice",
	SecretEventRemoteName = "SecretEvent",
	RequestBuildRemoteName = "RequestBuild",
	PuffMomentRemoteName = "PuffMoment",
	ProfileSnapshotRemoteName = "ProfileSnapshot",
	LeaderboardRemoteName = "Leaderboards",
	PuffdexRemoteName = "Puffdex",
	PuffMachineRemoteName = "PuffMachine",
	PartyRemoteName = "Party",
	ReactionRemoteName = "Reaction",
	MatchQueueRemoteName = "MatchQueue",
	-- Convite com recompensa: avisos de prêmio e convites enviados.
	ReferralRemoteName = "Referral",
	-- Cliente → servidor: impulso usado (validação e efeito para todos).
	DashRemoteName = "Dash",
	-- Servidor → clientes: disparos para desenhar (ProjectileService).
	PuffShotsRemoteName = "PuffShots",
	-- Mistérios do Barão (5C.3): tentativas e respostas.
	MysteryRemoteName = "Mystery",

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
