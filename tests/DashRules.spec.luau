-- Testes das regras do impulso.
-- Rodar: lune run tests/DashRules.spec

local DashRules = require("../src/shared/modules/DashRules")

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

local config = { Cooldown = 3, AirDashesPerJump = 1, ServerTolerance = 0.35 }

-- Intervalo entre impulsos.
local state = DashRules.new()
check("fresh state can dash on the ground", DashRules.canDash(state, 0, true, config))
state = DashRules.afterDash(state, 10, true, config)
check("cooldown blocks", not DashRules.canDash(state, 12.9, true, config))
check("ready after cooldown", DashRules.canDash(state, 13, true, config))
check("remaining time", math.abs(DashRules.remaining(state, 11) - 2) < 1e-9 and DashRules.remaining(state, 20) == 0)

-- Uma vez por pulo no ar.
state = DashRules.afterDash(DashRules.new(), 0, false, config)
check("air dash spends the jump", state.airDashes == 1)
check("second air dash blocked even after cooldown", not DashRules.canDash(state, 5, false, config))
check("ground dash still allowed", DashRules.canDash(state, 5, true, config))
local landed = DashRules.landed(state)
check("landing restores air dash", landed.airDashes == 0 and DashRules.canDash(landed, 5, false, config))
check("landing keeps cooldown", landed.readyAt == state.readyAt)
local before = state.airDashes
DashRules.landed(state)
check("does not mutate", state.airDashes == before)
state = DashRules.afterDash(DashRules.new(), 0, true, config)
check("ground dash does not spend the air dash", state.airDashes == 0)

-- Conferência do servidor (com folga de rede).
check("server accepts first dash", DashRules.serverAccepts(nil, 100, config))
check("server accepts within tolerance", DashRules.serverAccepts(100, 102.7, config))
check("server rejects spam", not DashRules.serverAccepts(100, 101, config))
check("server accepts after cooldown", DashRules.serverAccepts(100, 103, config))

print(`DashRules: {passed} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} DashRules checks failed`)
end
