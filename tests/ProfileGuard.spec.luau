-- Testes do ProfileGuard (nada que o jogador conquistou pode sumir).
-- Rodar: lune run tests/ProfileGuard.spec

local ProfileGuard = require("../src/server/data/ProfileGuard")

local failures = 0
local passed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

local function puff(count: number?, obtainedAt: number?)
	return { count = count or 1, obtainedAt = obtainedAt or 100, origin = "Machine", uid = "uid" }
end

local function profile(overrides: { [string]: any }?)
	local data: { [string]: any } = {
		version = 5,
		stats = { matches = 10, wins = 2 },
		xp = 500,
		level = 4,
		prestige = 0,
		levelReachedAt = 50,
		puffs = { branco = puff(), neon = puff(2) },
		secrets = { passagem = 10 },
		tickets = 30,
		ticketsEarned = 100,
		ticketsSpent = 70,
		machinePulls = 5,
		machinePity = 2,
		challengesCompleted = 3,
		createdAt = 10,
	}
	for key, value in pairs(overrides or {}) do
		data[key] = value
	end
	return data
end

-- Nada gravado: grava o que veio, sem correções.
do
	local outgoing = profile()
	local merged, anomalies = ProfileGuard.mergeForSave(nil, outgoing)
	check("nil stored keeps outgoing", merged == outgoing and #anomalies == 0)
end

-- Uso normal: o perfil novo tem tudo e mais. Nenhuma correção.
do
	local stored = profile()
	local outgoing = profile({
		xp = 600,
		puffs = { branco = puff(), neon = puff(3), aurora = puff() },
		tickets = 10,
		ticketsEarned = 110,
		ticketsSpent = 100,
		stats = { matches = 11, wins = 2 },
	})
	local merged, anomalies = ProfileGuard.mergeForSave(stored, outgoing)
	check("normal save has no anomalies", #anomalies == 0)
	check("normal save keeps spent tickets", merged.tickets == 10)
	check("normal save keeps new puff", merged.puffs.aurora ~= nil)
	check("normal save keeps new count", merged.puffs.neon.count == 3)
end

-- Perfil vazio por cima de um cheio: tudo volta.
do
	local stored = profile()
	local empty = {
		version = 5,
		stats = { matches = 0, wins = 0 },
		xp = 0,
		level = 1,
		prestige = 0,
		puffs = {},
		secrets = {},
		tickets = 0,
		ticketsEarned = 0,
		ticketsSpent = 0,
		machinePulls = 0,
		machinePity = 0,
		challengesCompleted = 0,
		createdAt = 999,
	}
	local merged, anomalies = ProfileGuard.mergeForSave(stored, empty)
	check("wipe restores puffs", merged.puffs.branco ~= nil and merged.puffs.neon ~= nil)
	check("wipe restores count", merged.puffs.neon.count == 2)
	check("wipe restores secrets", merged.secrets.passagem == 10)
	check("wipe restores stats", merged.stats.matches == 10 and merged.stats.wins == 2)
	check("wipe restores xp and level", merged.xp == 500 and merged.level == 4)
	check("wipe restores wallet", merged.tickets == 30 and merged.ticketsEarned == 100 and merged.machinePulls == 5)
	check("wipe restores challenges", merged.challengesCompleted == 3)
	check("wipe keeps oldest createdAt", merged.createdAt == 10)
	check("wipe reports anomalies", #anomalies >= 5)
end

-- Um Puff sumido volta; os outros campos da sessão ficam.
do
	local stored = profile()
	local outgoing = profile({ puffs = { branco = puff() }, xp = 700 })
	local merged, anomalies = ProfileGuard.mergeForSave(stored, outgoing)
	check("missing puff comes back", merged.puffs.neon ~= nil and merged.puffs.neon.count == 2)
	check("session xp kept", merged.xp == 700)
	check("one anomaly for one puff", #anomalies == 1 and anomalies[1] == "puffs+1")
end

-- Count menor volta para o maior.
do
	local stored = profile()
	local outgoing = profile({ puffs = { branco = puff(), neon = puff(1) } })
	local merged = ProfileGuard.mergeForSave(stored, outgoing)
	check("count never drops", merged.puffs.neon.count == 2)
end

-- Prestígio zera o XP de propósito: não é corrigido.
do
	local stored = profile({ xp = 9000, level = 50 })
	local outgoing = profile({ xp = 0, level = 1, prestige = 1 })
	local merged, anomalies = ProfileGuard.mergeForSave(stored, outgoing)
	check("prestige reset allowed", merged.xp == 0 and merged.prestige == 1 and #anomalies == 0)
end

-- Prestígio que caiu volta, com o XP daquele prestígio.
do
	local stored = profile({ prestige = 2, xp = 100, level = 2 })
	local outgoing = profile({ prestige = 1, xp = 5000, level = 30 })
	local merged = ProfileGuard.mergeForSave(stored, outgoing)
	check("prestige never drops", merged.prestige == 2 and merged.xp == 100)
end

-- Não altera as tabelas recebidas.
do
	local stored = profile()
	local outgoing = profile({ puffs = {} })
	ProfileGuard.mergeForSave(stored, outgoing)
	check("outgoing not mutated", next(outgoing.puffs) == nil)
	check("stored not mutated", stored.puffs.neon.count == 2)
end

-- Dados corrompidos não quebram.
do
	local outgoing = profile()
	local ok, merged = pcall(ProfileGuard.mergeForSave, { puffs = "x", stats = 5, secrets = { [1] = true }, xp = 0 / 0 }, outgoing)
	check("garbage stored does not throw", ok)
	check("garbage stored keeps outgoing puffs", ok and merged.puffs.neon ~= nil)
end

-- Gasto e reembolso de tickets (total ganho igual): nada é corrigido.
do
	local stored = profile()
	local outgoing = profile({ tickets = 5, ticketsSpent = 95, machinePity = 0, machinePulls = 6 })
	local merged, anomalies = ProfileGuard.mergeForSave(stored, outgoing)
	check("spend keeps lower tickets", merged.tickets == 5 and #anomalies == 0)
	check("pity reset allowed", merged.machinePity == 0)
end

-- Estatística desconhecida (de outra versão) continua gravada.
do
	local stored = profile({ stats = { matches = 10, wins = 2, oldStat = 7 } })
	local merged = ProfileGuard.mergeForSave(stored, profile())
	check("unknown stat kept", merged.stats.oldStat == 7)
end

-- O registro devolvido é uma cópia com os mesmos campos.
do
	local stored = profile({ puffs = { neon = puff(2, 42) } })
	local merged = ProfileGuard.mergeForSave(stored, profile({ puffs = {} }))
	local record = merged.puffs.neon
	check("restored record fields", record.count == 2 and record.obtainedAt == 42 and record.origin == "Machine" and record.uid == "uid")
	record.count = 99
	check("restored record is a copy", stored.puffs.neon.count == 2)
end

-- Relíquias (5C.2): nenhuma some e a contagem do dia nunca cai.
do
	local stored = profile({ relics = { biblioteca_chave = 7 }, dailyRelicDay = 20, dailyRelicCount = 5 })
	local merged, anomalies = ProfileGuard.mergeForSave(stored, profile({ relics = { musica_puff = 9 }, dailyRelicDay = 3, dailyRelicCount = 1 }))
	check("relics are restored", merged.relics.biblioteca_chave == 7 and merged.relics.musica_puff == 9)
	check("daily relic count never drops", merged.dailyRelicCount == 5 and merged.dailyRelicDay == 20)
	check("relic anomalies reported", table.find(anomalies, "relics+1") ~= nil and table.find(anomalies, "dailyRelics") ~= nil)
	local fresh, none = ProfileGuard.mergeForSave(stored, profile({ relics = { biblioteca_chave = 7, musica_puff = 9 }, dailyRelicDay = 21, dailyRelicCount = 6 }))
	check("normal relic save has no anomalies", #none == 0 and fresh.dailyRelicCount == 6)
end

-- Salas Secretas do Barão: prêmio pego nunca some.
do
	local stored = profile({ baronRooms = { Study = 7 } })
	local merged, anomalies = ProfileGuard.mergeForSave(stored, profile({ baronRooms = { Treasure = 9 } }))
	check("baron rooms are restored", merged.baronRooms.Study == 7 and merged.baronRooms.Treasure == 9)
	check("baron rooms anomaly reported", table.find(anomalies, "baronRooms+1") ~= nil)
	local fresh, none = ProfileGuard.mergeForSave(stored, profile({ baronRooms = { Study = 7, Treasure = 9 } }))
	check("normal baron rooms save has no anomalies", #none == 0 and fresh.baronRooms.Treasure == 9)
end

-- Contagem de Puffs.
check("countPuffs", ProfileGuard.countPuffs(profile()) == 2)
check("countPuffs nil", ProfileGuard.countPuffs(nil) == 0)

print(`{passed} passed, {failures} failed`)
if failures > 0 then
	error("ProfileGuard tests failed")
end
