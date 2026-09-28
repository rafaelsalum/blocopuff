--!strict

-- Ranking global em OrderedDataStores (uma por categoria). Regras:
--   * Os valores vêm SÓ do perfil salvo pelo servidor (PlayerDataService),
--     e só de perfis que estão sendo salvos de verdade (saved = true).
--   * Gravação em lote a cada FLUSH_INTERVAL s (e ao sair / fechar o
--     servidor), só das categorias que mudaram.
--   * Leitura do top a cada REFRESH_INTERVAL s, em segundo plano: o lobby
--     nunca espera o DataStore. Todos recebem a mesma cópia.
--   * Empate: mesmo valor, mesma posição.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local LeaderboardTypes = require(ReplicatedStorage.Shared.types.LeaderboardTypes)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local DataStoreErrors = require(script.Parent.Parent.data.DataStoreErrors)

type LeaderboardData = LeaderboardTypes.LeaderboardData
type Leaderboard = LeaderboardTypes.Leaderboard
type LeaderboardEntry = LeaderboardTypes.LeaderboardEntry
type ProfileSnapshot = ProfileTypes.ProfileSnapshot

export type DataListener = (data: LeaderboardData) -> ()

local STORE_PREFIX = "BlocoPuffLB_v1_"
local FLUSH_INTERVAL = 60
local REFRESH_INTERVAL = 120
local FIRST_REFRESH_DELAY = 3
-- Acima disso o valor é tratado como inválido (não entra no ranking).
local MAX_REASONABLE_VALUE = 10000000
local REQUEST_COOLDOWN = 2
local NAME_CACHE_LIMIT = 500
-- Intervalo entre jogadores na gravação em lote (limite do DataStore).
local FLUSH_STAGGER = 0.2
-- Prazo da gravação ao fechar o servidor (o salvamento dos perfis também
-- roda no BindToClose e é mais importante).
local CLOSE_FLUSH_BUDGET = 15

local LeaderboardService = {}

local started = false
local stores: { [string]: OrderedDataStore } = {}
local available = false
local remote: RemoteEvent? = nil
local listeners: { DataListener } = {}
local current: LeaderboardData = { boards = {}, updatedAt = 0, available = false }
-- Últimos valores confiáveis de cada jogador, esperando gravação.
local pending: { [number]: { [string]: number } } = {}
-- Último valor gravado por jogador e categoria (evita regravar o mesmo).
local written: { [number]: { [string]: number } } = {}
local nameCache: { [number]: string } = {}
local nameCacheSize = 0
local lastRequest: { [Player]: number } = {}

local function emptyBoards(): { Leaderboard }
	local boards: { Leaderboard } = {}
	for _, category in ipairs(LeaderboardTypes.Categories) do
		table.insert(boards, { id = category.id, title = category.title, entries = {} })
	end
	return boards
end

-- Studio sem acesso às APIs: desliga o ranking desta sessão com um aviso só.
local function handleFailure(label: string, failure: unknown): boolean
	if DataStoreErrors.isStudioAccessDenied(failure) then
		if available then
			available = false
			warn(string.format("[BlocoPuff] Leaderboards disabled in this Studio session: %s", DataStoreErrors.StudioHint))
		end
		return true
	end
	warn(string.format("[BlocoPuff] Leaderboard %s failed: %s", label, tostring(failure)))
	return false
end

local function publish()
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireAllClients(current)
	end
	for _, listener in ipairs(listeners) do
		task.spawn(listener, current)
	end
end

-- Não pode esperar nada (sem yield): o PlayerRemoving conta com `pending`
-- já atualizado.
local function onProfile(player: Player, snapshot: ProfileSnapshot)
	if not snapshot.saved then
		return
	end
	local stats = snapshot.stats :: any
	local values: { [string]: number } = {}
	for _, category in ipairs(LeaderboardTypes.Categories) do
		local value = stats[category.stat]
		if typeof(value) == "number" then
			values[category.id] = math.floor(value)
		end
	end
	pending[player.UserId] = values
end

local function flushUser(userId: number)
	local values = pending[userId]
	if values == nil or not available then
		return
	end
	pending[userId] = nil
	local already = written[userId] or {}
	written[userId] = already
	local failed: { [string]: number } = {}
	for _, category in ipairs(LeaderboardTypes.Categories) do
		local value = values[category.id]
		local store = stores[category.id]
		if value ~= nil and store ~= nil and value > 0 and value <= MAX_REASONABLE_VALUE and already[category.id] ~= value then
			local ok, failure = pcall(function()
				store:SetAsync(tostring(userId), value)
			end)
			if ok then
				already[category.id] = value
			else
				if handleFailure(`{category.id} write for {userId}`, failure) then
					return
				end
				failed[category.id] = value
			end
		end
	end
	-- Falhou: volta para a fila (sem sobrescrever um valor mais novo que
	-- tenha chegado enquanto gravava) e tenta de novo no próximo lote.
	if next(failed) ~= nil then
		local newer = pending[userId] or {}
		for categoryId, value in pairs(failed) do
			if newer[categoryId] == nil then
				newer[categoryId] = value
			end
		end
		pending[userId] = newer
	end
end

-- `deadline` (os.clock) opcional: para de gravar quando o prazo acaba.
local function flushAll(deadline: number?)
	local userIds: { number } = {}
	for userId in pairs(pending) do
		table.insert(userIds, userId)
	end
	for index, userId in ipairs(userIds) do
		if deadline ~= nil and os.clock() >= deadline then
			warn(string.format("[BlocoPuff] Leaderboard flush stopped at close: %d users left", #userIds - index + 1))
			return
		end
		flushUser(userId)
		if deadline == nil then
			task.wait(FLUSH_STAGGER)
		end
	end
end

-- Nomes de exibição em lote (UserService), com cache.
local function resolveNames(userIds: { number })
	local missing: { number } = {}
	for _, userId in ipairs(userIds) do
		if nameCache[userId] == nil then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end
	if nameCacheSize > NAME_CACHE_LIMIT then
		table.clear(nameCache)
		nameCacheSize = 0
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in ipairs(infos :: { any }) do
			if typeof(info) == "table" and typeof(info.Id) == "number" then
				local name = if typeof(info.DisplayName) == "string" then info.DisplayName else info.Username
				if typeof(name) == "string" then
					nameCache[info.Id] = name
					nameCacheSize += 1
				end
			end
		end
	end
end

local function readBoard(categoryId: string, title: string): Leaderboard?
	local store = stores[categoryId]
	if store == nil or not available then
		return nil
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, LeaderboardTypes.TopCount):GetCurrentPage()
	end)
	if not ok or typeof(page) ~= "table" then
		handleFailure(`{categoryId} read`, page)
		return nil
	end
	local raw: { { userId: number, value: number } } = {}
	for _, item in ipairs(page :: { any }) do
		local userId = tonumber(item.key)
		local value = item.value
		if userId ~= nil and typeof(value) == "number" and value > 0 and value <= MAX_REASONABLE_VALUE then
			table.insert(raw, { userId = userId, value = math.floor(value) })
		end
	end
	local ids: { number } = {}
	for _, item in ipairs(raw) do
		table.insert(ids, item.userId)
	end
	resolveNames(ids)

	local entries: { LeaderboardEntry } = {}
	local rank = 0
	local previous: number? = nil
	for index, item in ipairs(raw) do
		if previous == nil or item.value < previous then
			rank = index
		end
		previous = item.value
		table.insert(entries, {
			rank = rank,
			userId = item.userId,
			name = nameCache[item.userId] or `Jogador {item.userId}`,
			value = item.value,
		})
	end
	return { id = categoryId, title = title, entries = entries }
end

local function refresh()
	if not available then
		current = { boards = emptyBoards(), updatedAt = os.time(), available = false }
		publish()
		return
	end
	local boards: { Leaderboard } = {}
	local succeeded = 0
	for index, category in ipairs(LeaderboardTypes.Categories) do
		-- Mantém a leitura anterior da categoria se esta falhar.
		local fresh = readBoard(category.id, category.title)
		if fresh ~= nil then
			succeeded += 1
		end
		local board = fresh or current.boards[index]
		table.insert(boards, board or { id = category.id, title = category.title, entries = {} })
	end
	current = { boards = boards, updatedAt = os.time(), available = available and (succeeded > 0 or current.available) }
	publish()
end

function LeaderboardService.get(): LeaderboardData
	return current
end

-- Avisado a cada nova leitura (Hall da Fama).
function LeaderboardService.addListener(listener: DataListener)
	table.insert(listeners, listener)
	task.spawn(listener, current)
end

function LeaderboardService.start(remotesFolder: Folder?)
	if started then
		return
	end
	started = true
	current = { boards = emptyBoards(), updatedAt = 0, available = false }

	-- GetOrderedDataStore quase nunca falha (a falha real aparece nas
	-- chamadas); `available` só desliga tudo se nem os stores existirem.
	local ok, failure = pcall(function()
		for _, category in ipairs(LeaderboardTypes.Categories) do
			stores[category.id] = DataStoreService:GetOrderedDataStore(STORE_PREFIX .. category.id)
		end
	end)
	available = ok
	if not ok then
		warn(string.format("[BlocoPuff] Leaderboards unavailable: %s", tostring(failure)))
	end

	if remotesFolder ~= nil then
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = PuffadorConstants.LeaderboardRemoteName
		newRemote.Parent = remotesFolder
		remote = newRemote
		-- O cliente pede a cópia ao abrir o ranking (e isso vira telemetria).
		newRemote.OnServerEvent:Connect(function(player: Player, action: unknown, categoryId: unknown)
			local clock = os.clock()
			local last = lastRequest[player]
			if last ~= nil and clock - last < REQUEST_COOLDOWN then
				return
			end
			lastRequest[player] = clock
			if action == "Opened" then
				local context = if typeof(categoryId) == "string" and #categoryId <= 20 then categoryId else nil
				TelemetryService.lobbyEvent(player, "LeaderboardOpened", 1, context)
			end
			newRemote:FireClient(player, current)
		end)
	end

	PlayerDataService.addListener(onProfile)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRequest[player] = nil
		-- `pending` é atualizado na hora em que o perfil muda (o ouvinte do
		-- PlayerDataService não espera nada), então aqui já está o valor final.
		task.spawn(flushUser, player.UserId)
	end)
	game:BindToClose(function()
		flushAll(os.clock() + CLOSE_FLUSH_BUDGET)
	end)

	task.spawn(function()
		task.wait(FIRST_REFRESH_DELAY)
		refresh()
		local sinceRefresh = 0
		while started do
			task.wait(FLUSH_INTERVAL)
			flushAll(nil)
			sinceRefresh += FLUSH_INTERVAL
			if sinceRefresh >= REFRESH_INTERVAL then
				sinceRefresh = 0
				refresh()
			end
		end
	end)
end

return table.freeze(LeaderboardService)
