--!strict

-- Posições recentes de quem está na partida do Assassinato, para o golpe da
-- faca valer pelo que o Assassino viu: na tela dele os outros aparecem um
-- pouco atrasados (a rede e a suavização do cliente), e quem foge já está
-- mais longe no servidor. O golpe confere o alvo agora e nas posições dos
-- últimos instantes (MurderRules.stabRewind). Guarda também para onde cada
-- um olhava: a mira do Assassino é conferida contra a frente do corpo dele
-- nesses instantes (no servidor ela chega atrasada quando ele vira).

local RunService = game:GetService("RunService")

local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

type Sample = {
	at: number,
	position: Vector3,
	front: Vector3,
}

-- Quanto histórico guardar (s): um pouco mais que o máximo rebobinado.
local KEEP_SECONDS = 0.6

local MurderStabHistory = {}

local samples: { [Combatant]: { Sample } } = {}
local connection: RBXScriptConnection? = nil

local function record(combatant: Combatant, now: number)
	local root = CombatantRegistry.getRoot(combatant)
	if root == nil then
		return
	end
	local list = samples[combatant]
	if list == nil then
		list = {}
		samples[combatant] = list
	end
	table.insert(list, { at = now, position = root.Position, front = root.CFrame.LookVector })
	while #list > 0 and now - list[1].at > KEEP_SECONDS do
		table.remove(list, 1)
	end
end

-- Começa a guardar as posições de `tracked()` a cada quadro.
function MurderStabHistory.start(tracked: () -> { Combatant })
	MurderStabHistory.stop()
	connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local alive: { [Combatant]: boolean } = {}
		for _, combatant in ipairs(tracked()) do
			alive[combatant] = true
			record(combatant, now)
		end
		-- Quem saiu da partida deixa de ter histórico.
		for combatant in pairs(samples) do
			if not alive[combatant] then
				samples[combatant] = nil
			end
		end
	end)
end

function MurderStabHistory.stop()
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	table.clear(samples)
end

-- Amostras de `combatant` nos últimos `rewind` segundos, da mais nova para
-- a mais antiga, começando pela de agora.
local function recentSamples(combatant: Combatant, rewind: number): { Sample }
	local found: { Sample } = {}
	local root = CombatantRegistry.getRoot(combatant)
	local now = os.clock()
	if root ~= nil then
		table.insert(found, { at = now, position = root.Position, front = root.CFrame.LookVector })
	end
	local list = samples[combatant]
	if list == nil then
		return found
	end
	local oldest = now - rewind
	for index = #list, 1, -1 do
		local sample = list[index]
		if sample.at < oldest then
			break
		end
		table.insert(found, sample)
	end
	return found
end

-- Posições de `combatant` nos últimos `rewind` segundos, da mais nova para
-- a mais antiga, começando pela de agora.
function MurderStabHistory.recent(combatant: Combatant, rewind: number): { Vector3 }
	local positions: { Vector3 } = {}
	for _, sample in ipairs(recentSamples(combatant, rewind)) do
		table.insert(positions, sample.position)
	end
	return positions
end

-- Para onde `combatant` olhava nos últimos `rewind` segundos (a de agora
-- primeiro).
function MurderStabHistory.fronts(combatant: Combatant, rewind: number): { Vector3 }
	local fronts: { Vector3 } = {}
	for _, sample in ipairs(recentSamples(combatant, rewind)) do
		table.insert(fronts, sample.front)
	end
	return fronts
end

return table.freeze(MurderStabHistory)
