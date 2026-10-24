--!strict

-- Regras puras das portas trancadas do Casarão (Fase 5C.1). Sem Roblox
-- (testes no Lune: tests/MansionLockRules.spec.luau).

local MansionLockRules = {}

export type Lock = {
	kind: string,
	relicId: string?,
	level: number?,
}

-- Porta de chave: tem a relíquia-chave. Porta de nível: chegou ao nível ou
-- já fez prestígio (o prestígio volta o nível para 1).
function MansionLockRules.hasAccess(lock: Lock, owned: { [string]: boolean }, level: number, prestige: number): boolean
	if lock.kind == "Key" then
		local relicId = lock.relicId
		return relicId ~= nil and owned[relicId] == true
	elseif lock.kind == "Level" then
		local required = lock.level
		return required ~= nil and (level >= required or prestige > 0)
	end
	return false
end

return table.freeze(MansionLockRules)
