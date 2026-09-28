--!strict

-- Inventário de Puffs guardado no perfil (Fase 4.1). Funções puras: leem o
-- que veio do DataStore, calculam desbloqueios e devolvem tabelas NOVAS
-- (nunca alteram as recebidas).
--
-- Cada item guarda um `uid` único e a origem: é a base para ownership e
-- trading no futuro (trading continua desligado, ver PuffCatalog).
-- A chave é o id do Puff, então o mesmo Puff nunca entra duas vezes (nem
-- ao reconectar); Puffs repetidos da Puff Machine (4.2) somam em `count`.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)

type PuffOrigin = PuffTypes.PuffOrigin
type OwnedPuff = PuffTypes.OwnedPuff

export type PuffRecord = {
	obtainedAt: number,
	count: number,
	origin: PuffOrigin,
	uid: string,
}

export type Inventory = { [string]: PuffRecord }

local MAX_ITEMS = 500
local MAX_COUNT = 9999
local MAX_UID_LENGTH = 64

local PuffInventory = {}

local function cleanCount(value: unknown): number
	if typeof(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(math.floor(value), 1, MAX_COUNT)
end

local function readOrigin(value: unknown): PuffOrigin
	if typeof(value) == "string" and table.find(PuffTypes.Origins, value :: any) ~= nil then
		return value :: PuffOrigin
	end
	return "Feat"
end

-- Limpa o inventário salvo. Ids desconhecidos (Puff removido do catálogo ou
-- de uma versão futura) são mantidos para não perder dados; o cliente só
-- recebe os que existem no catálogo.
function PuffInventory.fromStored(raw: unknown, now: number): Inventory
	local inventory: Inventory = {}
	if typeof(raw) ~= "table" then
		return inventory
	end
	local size = 0
	for id, value in pairs(raw :: { [unknown]: unknown }) do
		if size >= MAX_ITEMS then
			break
		end
		if typeof(id) == "string" and #id <= PuffCatalog.MaxIdLength and typeof(value) == "table" then
			local data = value :: { [string]: unknown }
			local obtainedAt = data.obtainedAt
			local uid = data.uid
			inventory[id] = {
				obtainedAt = if typeof(obtainedAt) == "number" and obtainedAt == obtainedAt
					then math.max(0, math.floor(obtainedAt))
					else now,
				count = cleanCount(data.count),
				origin = readOrigin(data.origin),
				uid = if typeof(uid) == "string" and #uid > 0 and #uid <= MAX_UID_LENGTH then uid else HttpService:GenerateGUID(false),
			}
			size += 1
		end
	end
	return inventory
end

function PuffInventory.toStored(inventory: Inventory): { [string]: any }
	local stored: { [string]: any } = {}
	for id, record in pairs(inventory) do
		stored[id] = table.clone(record)
	end
	return stored
end

function PuffInventory.owns(inventory: Inventory, id: string): boolean
	return inventory[id] ~= nil and PuffCatalog.get(id) ~= nil
end

-- Puff equipado válido: precisa existir no catálogo e estar no inventário.
function PuffInventory.validEquipped(inventory: Inventory, id: unknown): string
	if typeof(id) == "string" and PuffInventory.owns(inventory, id) then
		return id
	end
	return PuffCatalog.DefaultId
end

-- Concede tudo que o perfil já cumpre e ainda não tem. Devolve o novo
-- inventário e os ids novos (na ordem do catálogo).
function PuffInventory.grantUnlocks(inventory: Inventory, stats: { [string]: number }, level: number, now: number): (Inventory, { string })
	local granted: { string } = {}
	local result: Inventory? = nil
	for _, entry in ipairs(PuffCatalog.all()) do
		if inventory[entry.id] == nil and entry.unlock.kind ~= "Machine" and PuffCatalog.meetsRule(entry, stats, level) then
			local updated = result or table.clone(inventory)
			updated[entry.id] = {
				obtainedAt = now,
				count = 1,
				origin = entry.origin,
				uid = HttpService:GenerateGUID(false),
			}
			result = updated
			table.insert(granted, entry.id)
		end
	end
	return result or inventory, granted
end

-- Acrescenta um Puff (Puff Machine). Se já tiver, soma em `count` (o uid
-- do item continua o mesmo). Devolve o novo inventário e se era repetido.
function PuffInventory.addPuff(inventory: Inventory, id: string, origin: PuffOrigin, now: number): (Inventory, boolean)
	local updated = table.clone(inventory)
	local existing = inventory[id]
	if existing ~= nil then
		local record = table.clone(existing)
		record.count = math.min(MAX_COUNT, existing.count + 1)
		updated[id] = record
		return updated, true
	end
	updated[id] = {
		obtainedAt = now,
		count = 1,
		origin = origin,
		uid = HttpService:GenerateGUID(false),
	}
	return updated, false
end

-- Cópia para o cliente: só Puffs do catálogo, sem o uid.
function PuffInventory.toOwnedList(inventory: Inventory): { OwnedPuff }
	local list: { OwnedPuff } = {}
	for _, entry in ipairs(PuffCatalog.all()) do
		local record = inventory[entry.id]
		if record ~= nil then
			table.insert(list, { id = entry.id, obtainedAt = record.obtainedAt, count = record.count, origin = record.origin })
		end
	end
	return list
end

-- Quantos Puffs do catálogo o jogador tem.
function PuffInventory.countOwned(inventory: Inventory): number
	local owned = 0
	for _, entry in ipairs(PuffCatalog.all()) do
		if inventory[entry.id] ~= nil then
			owned += 1
		end
	end
	return owned
end

return table.freeze(PuffInventory)
