--!strict

-- Persistência do perfil (Fase 3). Trocar StoreName apaga, na prática, todo
-- o progresso (novo DataStore): só faça isso de propósito.

export type ProfileConfig = {
	StoreName: string,
	KeyPrefix: string,
	-- Salva o perfil a cada AutosaveInterval s (também renova a trava).
	AutosaveInterval: number,
	-- Trava de sessão considerada abandonada depois deste tempo (s).
	SessionLockTimeout: number,
	-- Tentativas de carregar quando o perfil está preso em outro servidor.
	LoadLockedRetries: number,
	LoadRetryDelay: number,
	-- Tentativas quando o DataStore falha (rede, limites, Studio sem API).
	RequestRetries: number,
	-- Últimas rodadas aplicadas guardadas no perfil (evita somar duas vezes).
	AppliedRoundsKept: number,
}

local ProfileConfig: ProfileConfig = {
	StoreName = "BlocoPuffProfiles_v1",
	KeyPrefix = "u_",
	AutosaveInterval = 120,
	SessionLockTimeout = 600,
	LoadLockedRetries = 6,
	LoadRetryDelay = 5,
	RequestRetries = 3,
	AppliedRoundsKept = 10,
}

return table.freeze(ProfileConfig)
