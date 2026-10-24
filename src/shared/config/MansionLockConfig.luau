--!strict

-- Portas trancadas do Casarão (Fase 5C.1):
--   * Music: a porta da Escadaria para a Sala de Música só abre para quem
--     achou a Chave de Latão, escondida na Biblioteca;
--   * Trophy: a Sala dos Troféus do Vovô Puff, na parede leste da
--     Escadaria, só abre a partir do nível 10 (ou com qualquer prestígio).
-- Fechada, a porta só abre uma fresta para mostrar o outro lado. O servidor
-- publica o acesso no Player (MansionLockService); o cliente libera a
-- passagem (MansionLockController). Ids ficam nos atributos: não renomeie.
-- Sem dependências (os testes do Lune carregam este arquivo direto).

export type LockKind = "Key" | "Level"

export type LockInfo = {
	id: string,
	kind: LockKind,
	-- Nome do vão (MansionWingLayout.doorways ou TrophyRoomLayout).
	doorway: string,
	-- Chave (id da relíquia), para as portas de chave.
	relicId: string?,
	-- Nível mínimo, para as portas de nível (qualquer prestígio também abre).
	level: number?,
	-- Placa do lado trancado e o aviso de quem tenta passar.
	label: string,
	hint: string,
}

local MansionLockConfig = {}

MansionLockConfig.Locks = table.freeze({
	table.freeze({
		id = "Music",
		kind = "Key" :: LockKind,
		doorway = "MusicInnerDoor",
		relicId = "biblioteca_chave",
		label = "🔒 CHAVE DE LATÃO",
		hint = "Trancada · a Chave de Latão está escondida na Biblioteca",
	}),
	table.freeze({
		id = "Trophy",
		kind = "Level" :: LockKind,
		doorway = "TrophyDoor",
		level = 10,
		label = "🔒 NÍVEL 10",
		hint = "Sala dos Troféus · abre a partir do nível 10",
	}),
} :: { LockInfo })

-- Atributo no Player com o acesso a cada porta (true ou nil).
MansionLockConfig.AccessAttributePrefix = "MansionLock_"
-- Atributo na porta (Model) e na barreira do vão com o id da tranca.
MansionLockConfig.LockAttribute = "MansionLock"
-- Fração da abertura da porta para quem não tem acesso (a fresta).
MansionLockConfig.CrackFraction = 0.14
-- Distância (studs) do vão para mostrar o aviso a quem não tem acesso, e o
-- intervalo mínimo entre dois avisos (s).
MansionLockConfig.HintDistance = 7
MansionLockConfig.HintInterval = 8
MansionLockConfig.RattleSoundId = "rbxassetid://9114153270"

return table.freeze(MansionLockConfig)
