-- Recuperação de perfil do BlocoPuff. Rodar na Command Bar do Studio, com o
-- jogo PUBLICADO aberto (File > Open from Roblox), os scripts sincronizados
-- pelo Rojo e Game Settings > Security > Enable Studio Access to API
-- Services ligado. Instruções em tools/profile-recovery/README.md.
--
-- ACTION = "list": mostra o perfil atual, a cópia de segurança e as versões
-- antigas do perfil (o Roblox guarda 30 dias), com quantos Puffs cada uma
-- tem. Só lê, não muda nada.
-- ACTION = "restore": devolve ao perfil tudo o que a versão escolhida tinha
-- a mais (Puffs, conquistas, estatísticas, XP). Nada do perfil atual é
-- perdido: é a mesma junção do ProfileGuard. O jogador precisa estar fora
-- do jogo. Com DRY_RUN = true (padrão) só mostra o antes e o depois, sem
-- gravar; troque para false para gravar de verdade.

local USER_ID = 0 -- UserId do jogador (número no link do perfil do Roblox)
local ACTION = "list" -- "list" ou "restore"
local SOURCE = "main" -- ao restaurar: "main" (versão antiga) ou "backup" (cópia de segurança)
local VERSION = "" -- ao restaurar do "main": a versão, copiada da lista
local DETAILS = 10 -- quantas versões antigas abrir na lista
local DRY_RUN = true -- true: só mostra o resultado; false: grava
-- true: mantém os tickets de agora (a versão antiga pode ter tickets que já
-- foram gastos). false: se a versão antiga ganhou mais tickets, volta a
-- carteira dela inteira.
local KEEP_WALLET = true

local DataStoreService = game:GetService("DataStoreService")
local server = game:GetService("ServerScriptService"):WaitForChild("Server")
local ProfileGuard = require(server.data.ProfileGuard)
local ProfileConfig = require(server.config.ProfileConfig)
local ProfileSchema = require(server.data.ProfileSchema)

local key = ProfileConfig.KeyPrefix .. tostring(USER_ID)
local main = DataStoreService:GetDataStore(ProfileConfig.StoreName)
local backup = DataStoreService:GetDataStore(ProfileConfig.BackupStoreName)

local function date(seconds)
	return if typeof(seconds) == "number" then os.date("!%d/%m/%Y %H:%M UTC", seconds) else "?"
end

local function summary(data)
	if typeof(data) ~= "table" then
		return "vazio"
	end
	local stats = if typeof(data.stats) == "table" then data.stats else {}
	local session = if typeof(data.session) == "table" then `preso por {data.session.jobId} desde {date(data.session.lockedAt)}` else "livre"
	return string.format(
		"puffs=%d xp=%s nivel=%s tickets=%s partidas=%s | gravado %s | %s",
		ProfileGuard.countPuffs(data),
		tostring(data.xp),
		tostring(data.level),
		tostring(data.tickets),
		tostring(stats.matches),
		date(data.updatedAt),
		session
	)
end

local function list()
	print(`== Perfil {key}`)
	print("Atual:  " .. summary(main:GetAsync(key)))
	print("Cópia:  " .. summary(backup:GetAsync(key)))
	local pages = main:ListVersionsAsync(key, Enum.SortDirection.Descending, nil, nil, 50)
	local versions = pages:GetCurrentPage()
	print(`Versões antigas: {#versions} (mais novas primeiro)`)
	for index, info in ipairs(versions) do
		local line = `{info.Version}  {date(math.floor(info.CreatedTime / 1000))}`
		if info.IsDeleted then
			line ..= "  (apagada)"
		elseif index <= DETAILS then
			local ok, data = pcall(function()
				return main:GetVersionAsync(key, info.Version)
			end)
			line ..= "  " .. (if ok then summary(data) else `erro: {data}`)
		end
		print(line)
	end
end

local function restore()
	local old
	if SOURCE == "backup" then
		old = backup:GetAsync(key)
	else
		assert(VERSION ~= "", "Escolha a VERSION na lista (ACTION = \"list\")")
		old = main:GetVersionAsync(key, VERSION)
	end
	assert(typeof(old) == "table", "Essa versão está vazia")
	local function newer(data)
		return typeof(data) == "table" and typeof(data.version) == "number" and data.version > ProfileSchema.CurrentVersion
	end
	assert(not newer(old), "Essa versão é de um formato mais novo que estes scripts; sincronize o código atual")

	-- Junta a versão escolhida ao perfil atual; devolve nil se não puder.
	local function combine(current)
		if newer(current) then
			return nil, "o perfil atual é de um formato mais novo que estes scripts"
		end
		if typeof(current) == "table" and typeof(current.session) == "table" then
			local lockedAt = current.session.lockedAt
			if typeof(lockedAt) == "number" and os.time() - lockedAt < ProfileConfig.SessionLockTimeout then
				return nil, "o jogador está no jogo agora (perfil preso); peça para ele sair e rode de novo"
			end
		end
		local base = if typeof(current) == "table" then current else old
		local merged, anomalies = ProfileGuard.mergeForSave(old, base)
		if KEEP_WALLET and typeof(current) == "table" then
			for _, field in ipairs(ProfileGuard.WalletFields) do
				merged[field] = current[field]
			end
		end
		merged.version = ProfileSchema.CurrentVersion
		merged.session = nil
		merged.updatedAt = os.time()
		return merged, anomalies
	end

	if DRY_RUN then
		local merged, result = combine(main:GetAsync(key))
		if merged == nil then
			warn("Não dá para restaurar: " .. result)
			return
		end
		print("SIMULAÇÃO (nada foi gravado). Troque DRY_RUN para false para gravar.")
		print("Antes:  " .. summary(main:GetAsync(key)))
		print("Depois: " .. summary(merged))
		print(`Volta: {if #result > 0 then table.concat(result, ", ") else "nada faltava"}`)
		return
	end

	local problem = nil
	local found = {}
	main:UpdateAsync(key, function(current)
		local merged, result = combine(current)
		if merged == nil then
			problem = result
			return nil
		end
		found = result
		return merged
	end)
	if problem ~= nil then
		warn("Não restaurado: " .. problem)
		return
	end
	print(`Restaurado: {if #found > 0 then table.concat(found, ", ") else "nada faltava"}`)
	print("Agora:  " .. summary(main:GetAsync(key)))
end

assert(USER_ID > 0, "Preencha USER_ID")
if ACTION == "restore" then
	restore()
else
	list()
end
