--!strict

-- Persistência do perfil (Fase 3). Trocar StoreName apaga, na prática, todo
-- o progresso (novo DataStore): só faça isso de propósito.

export type ProfileConfig = {
	StoreName: string,
	-- Cópia de segurança: guarda tudo o que o jogador já teve (só soma) e
	-- devolve ao perfil principal o que ele tiver perdido.
	BackupStoreName: string,
	-- No Studio, perfil e cópia ficam em DataStores próprios (nome + este
	-- sufixo): um teste no Studio nunca trava o perfil real (quem entrasse
	-- no jogo publicado ao mesmo tempo ficaria sem perfil até a trava sair).
	-- Na primeira vez, o perfil de teste começa como cópia do real.
	StudioSuffix: string,
	-- A cópia é atualizada a cada BackupInterval s e ao sair.
	BackupInterval: number,
	KeyPrefix: string,
	-- Salva o perfil a cada AutosaveInterval s (também renova a trava).
	AutosaveInterval: number,
	-- Trava de sessão considerada abandonada depois deste tempo (s).
	SessionLockTimeout: number,
	-- Tentativas de carregar quando o perfil está preso em outro servidor.
	LoadLockedRetries: number,
	LoadRetryDelay: number,
	-- Depois disso, continua tentando a cada LoadRetryMaxDelay s enquanto o
	-- jogador estiver no servidor: nunca entra com um perfil vazio no lugar
	-- do dele.
	LoadRetryMaxDelay: number,
	-- Rodadas guardadas enquanto o perfil carrega (somadas ao carregar).
	MaxPendingRounds: number,
	-- Tentativas quando o DataStore falha (rede, limites, Studio sem API).
	RequestRetries: number,
	-- Últimas rodadas aplicadas guardadas no perfil (evita somar duas vezes).
	AppliedRoundsKept: number,
}

local ProfileConfig: ProfileConfig = {
	StoreName = "BlocoPuffProfiles_v1",
	BackupStoreName = "BlocoPuffProfiles_backup_v1",
	StudioSuffix = "_studio",
	BackupInterval = 600,
	KeyPrefix = "u_",
	AutosaveInterval = 120,
	SessionLockTimeout = 600,
	LoadLockedRetries = 6,
	LoadRetryDelay = 5,
	LoadRetryMaxDelay = 20,
	MaxPendingRounds = 20,
	RequestRetries = 3,
	AppliedRoundsKept = 10,
}

return table.freeze(ProfileConfig)
