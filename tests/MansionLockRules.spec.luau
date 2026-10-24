--!strict

-- Testes das portas trancadas do Casarão (Fase 5C.1)
-- (rodar com: lune run tests/MansionLockRules.spec.luau).

local MansionLockConfig = require("../src/shared/config/MansionLockConfig")
local MansionLockRules = require("../src/shared/modules/MansionLockRules")

local passed = 0
local failures = 0
local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

local music = MansionLockConfig.Locks[1]
local trophy = MansionLockConfig.Locks[2]
check("music is the key door", music.id == "Music" and music.kind == "Key")
check("trophy is the level door", trophy.id == "Trophy" and trophy.kind == "Level")

check("key door closed without the key", not MansionLockRules.hasAccess(music, {}, 50, 3))
check("key door closed with another key", not MansionLockRules.hasAccess(music, { musica_chave = true }, 1, 0))
check("key door open with the brass key", MansionLockRules.hasAccess(music, { biblioteca_chave = true }, 1, 0))

check("level door closed below the level", not MansionLockRules.hasAccess(trophy, {}, 9, 0))
check("level door open at the level", MansionLockRules.hasAccess(trophy, {}, 10, 0))
check("level door open after prestige", MansionLockRules.hasAccess(trophy, {}, 1, 1))
check("level door ignores relics", not MansionLockRules.hasAccess(trophy, { biblioteca_chave = true }, 2, 0))

check("unknown kind stays closed", not MansionLockRules.hasAccess({ kind = "Other" }, {}, 50, 5))
check("key door without relic stays closed", not MansionLockRules.hasAccess({ kind = "Key" }, {}, 50, 5))

local ids: { [string]: boolean } = {}
local unique = true
for _, lock in ipairs(MansionLockConfig.Locks) do
	if ids[lock.id] then
		unique = false
	end
	ids[lock.id] = true
end
check("lock ids are unique", unique)

print(`MansionLockRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error("MansionLockRules tests failed")
end
