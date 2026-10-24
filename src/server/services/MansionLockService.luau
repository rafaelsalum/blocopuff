--!strict

-- Acesso às portas trancadas do Casarão (Fase 5C.1): sempre que o perfil
-- muda (relíquia nova, nível novo), publica no Player um atributo por porta
-- (MansionLockConfig.AccessAttributePrefix .. id = true) para o cliente
-- liberar a passagem. A regra é do MansionLockRules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionLockConfig = require(ReplicatedStorage.Shared.config.MansionLockConfig)
local MansionLockRules = require(ReplicatedStorage.Shared.modules.MansionLockRules)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PlayerDataService = require(script.Parent.PlayerDataService)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot

local MansionLockService = {}

local started = false

local function publishAccess(player: Player, snapshot: ProfileSnapshot)
	local owned: { [string]: boolean } = {}
	for _, relic in ipairs(snapshot.relics) do
		owned[relic.id] = true
	end
	for _, lock in ipairs(MansionLockConfig.Locks) do
		local name = MansionLockConfig.AccessAttributePrefix .. lock.id
		local value = if MansionLockRules.hasAccess(lock, owned, snapshot.level, snapshot.prestige) then true else nil
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end
end

function MansionLockService.start()
	if started then
		return
	end
	started = true
	PlayerDataService.addListener(publishAccess)
	for _, player in ipairs(Players:GetPlayers()) do
		local snapshot = PlayerDataService.getSnapshot(player)
		if snapshot ~= nil then
			publishAccess(player, snapshot)
		end
	end
end

return table.freeze(MansionLockService)
