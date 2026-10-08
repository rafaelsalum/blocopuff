--!strict

-- Guarda do progresso salvo: o que o jogador conquistou nunca diminui.
--
-- `mergeForSave(stored, outgoing)` recebe o que está gravado e o que vai
-- ser gravado (os dois no formato do DataStore) e devolve o que gravar:
-- `outgoing`, com de volta tudo o que `stored` tinha a mais.
--   * Puffs: todo Puff gravado continua; `count` fica com o maior valor.
--   * Conquistas secretas, relíquias e mistérios resolvidos: todo gravado
--     continua.
--   * Relíquia do Dia: a contagem e o último dia nunca caem.
--   * Estatísticas, nível, XP e prestígio: ficam com o maior valor (o XP só
--     pode cair quando o prestígio sobe, que zera o nível de propósito).
--   * Tickets: gastar é normal, mas o total ganho nunca cai; se cair, a
--     carteira gravada volta inteira.
-- A lista de volta diz o que precisou ser corrigido (para log e
-- telemetria). Em uso normal ela vem sempre vazia.
--
-- Também serve para juntar a cópia de segurança com o perfil principal e
-- para a ferramenta de recuperação (tools/profile-recovery). Não depende do
-- Roblox: os testes rodam no Lune (tests/ProfileGuard.spec.luau).

local ProfileGuard = {}

type Data = { [string]: any }

local function isTable(value: unknown): boolean
	return typeof(value) == "table"
end

local function number(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value :: number
end

local function numberOr(value: unknown, fallback: number): number
	return number(value) or fallback
end

-- Todo Puff de `stored` continua; `count` fica com o maior valor.
local function mergePuffs(stored: unknown, outgoing: unknown): (Data, number)
	local result: Data = {}
	if isTable(outgoing) then
		for id, record in pairs(outgoing :: Data) do
			result[id] = record
		end
	end
	local restored = 0
	if not isTable(stored) then
		return result, restored
	end
	for id, record in pairs(stored :: Data) do
		if typeof(id) == "string" and isTable(record) then
			local current = result[id]
			if not isTable(current) then
				result[id] = table.clone(record)
				restored += 1
			else
				local storedCount = numberOr(record.count, 1)
				if storedCount > numberOr(current.count, 1) then
					local fixed = table.clone(current)
					fixed.count = storedCount
					result[id] = fixed
					restored += 1
				end
			end
		end
	end
	return result, restored
end

local function mergeSecrets(stored: unknown, outgoing: unknown): (Data, number)
	local result: Data = if isTable(outgoing) then table.clone(outgoing :: Data) else {}
	local restored = 0
	if isTable(stored) then
		for id, obtainedAt in pairs(stored :: Data) do
			if typeof(id) == "string" and result[id] == nil then
				result[id] = obtainedAt
				restored += 1
			end
		end
	end
	return result, restored
end

local function mergeStats(stored: unknown, outgoing: unknown): (Data, number)
	local result: Data = if isTable(outgoing) then table.clone(outgoing :: Data) else {}
	local restored = 0
	if isTable(stored) then
		for key, value in pairs(stored :: Data) do
			local storedValue = number(value)
			if typeof(key) == "string" and storedValue ~= nil and storedValue > numberOr(result[key], 0) then
				result[key] = storedValue
				restored += 1
			end
		end
	end
	return result, restored
end

-- Campos da carteira de tickets (voltam juntos, nunca um sozinho).
local WALLET_FIELDS = table.freeze({ "tickets", "ticketsEarned", "ticketsSpent", "machinePulls", "machinePity" })
ProfileGuard.WalletFields = WALLET_FIELDS

function ProfileGuard.mergeForSave(stored: unknown, outgoing: Data): (Data, { string })
	local anomalies: { string } = {}
	if not isTable(stored) then
		return outgoing, anomalies
	end
	local old = stored :: Data
	local merged = table.clone(outgoing)

	local puffs, restoredPuffs = mergePuffs(old.puffs, outgoing.puffs)
	merged.puffs = puffs
	if restoredPuffs > 0 then
		table.insert(anomalies, `puffs+{restoredPuffs}`)
	end

	local secrets, restoredSecrets = mergeSecrets(old.secrets, outgoing.secrets)
	merged.secrets = secrets
	if restoredSecrets > 0 then
		table.insert(anomalies, `secrets+{restoredSecrets}`)
	end

	local relics, restoredRelics = mergeSecrets(old.relics, outgoing.relics)
	merged.relics = relics
	if restoredRelics > 0 then
		table.insert(anomalies, `relics+{restoredRelics}`)
	end

	local mysteries, restoredMysteries = mergeSecrets(old.mysteries, outgoing.mysteries)
	merged.mysteries = mysteries
	if restoredMysteries > 0 then
		table.insert(anomalies, `mysteries+{restoredMysteries}`)
	end

	local baronRooms, restoredRooms = mergeSecrets(old.baronRooms, outgoing.baronRooms)
	merged.baronRooms = baronRooms
	if restoredRooms > 0 then
		table.insert(anomalies, `baronRooms+{restoredRooms}`)
	end

	if numberOr(old.dailyRelicCount, 0) > numberOr(outgoing.dailyRelicCount, 0) then
		merged.dailyRelicCount = old.dailyRelicCount
		merged.dailyRelicDay = math.max(numberOr(old.dailyRelicDay, 0), numberOr(outgoing.dailyRelicDay, 0))
		table.insert(anomalies, "dailyRelics")
	end

	local stats, restoredStats = mergeStats(old.stats, outgoing.stats)
	merged.stats = stats
	if restoredStats > 0 then
		table.insert(anomalies, `stats+{restoredStats}`)
	end

	local oldPrestige = numberOr(old.prestige, 0)
	local newPrestige = numberOr(outgoing.prestige, 0)
	if oldPrestige > newPrestige then
		merged.prestige = oldPrestige
		merged.xp = old.xp
		merged.level = old.level
		merged.levelReachedAt = old.levelReachedAt
		table.insert(anomalies, "prestige")
	elseif oldPrestige == newPrestige and numberOr(old.xp, 0) > numberOr(outgoing.xp, 0) then
		merged.xp = old.xp
		merged.level = old.level
		merged.levelReachedAt = old.levelReachedAt
		table.insert(anomalies, "xp")
	end

	if numberOr(old.ticketsEarned, 0) > numberOr(outgoing.ticketsEarned, 0) then
		for _, field in ipairs(WALLET_FIELDS) do
			merged[field] = old[field]
		end
		table.insert(anomalies, "tickets")
	end

	if numberOr(old.challengesCompleted, 0) > numberOr(outgoing.challengesCompleted, 0) then
		merged.challengesCompleted = old.challengesCompleted
		table.insert(anomalies, "challenges")
	end

	local oldCreated = number(old.createdAt)
	if oldCreated ~= nil and oldCreated < numberOr(outgoing.createdAt, math.huge) then
		merged.createdAt = oldCreated
	end
	return merged, anomalies
end

-- Quantos Puffs um perfil gravado tem (para logs e para a recuperação).
function ProfileGuard.countPuffs(data: unknown): number
	if not isTable(data) or not isTable((data :: Data).puffs) then
		return 0
	end
	local count = 0
	for _ in pairs((data :: Data).puffs) do
		count += 1
	end
	return count
end

return table.freeze(ProfileGuard)
