--!strict

-- Caos Final: nos últimos segundos da rodada, blocos aleatórios dos dois
-- andares piscam em vermelho e caem. A quantidade por onda cresce ao longo
-- do Caos, para a rodada terminar com clímax em vez de se arrastar. O aviso
-- visual (atributo CollapseWarning) dá tempo de o jogador reagir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local ArenaService = require(script.Parent.ArenaService)

local FinalChaosService = {}

local token = 0
local running = false
local random = Random.new()

local function pickRandom(blocks: { Part }, count: number): { Part }
	local picked: { Part } = {}
	local pool = table.clone(blocks)
	for _ = 1, math.min(count, #pool) do
		local index = random:NextInteger(1, #pool)
		table.insert(picked, pool[index])
		pool[index] = pool[#pool]
		pool[#pool] = nil
	end
	return picked
end

local function runWaves(myToken: number, duration: number)
	local config = GameConfig.FinalChaos
	local started = os.clock()
	while running and token == myToken do
		local progress = math.clamp((os.clock() - started) / math.max(duration, 1), 0, 1)
		local count = math.floor(config.CollapseStartCount + ((config.CollapseMaxCount - config.CollapseStartCount) * progress) + 0.5)
		local wave = pickRandom(ArenaService.getIntactBlocks(), count)
		for _, block in ipairs(wave) do
			ArenaService.setCollapseWarning(block, true)
		end
		task.delay(config.WarningTime, function()
			if token ~= myToken then
				return
			end
			for _, block in ipairs(wave) do
				ArenaService.collapseBlock(block)
			end
		end)
		task.wait(config.CollapseInterval)
	end
end

-- Duração efetiva do Caos para uma rodada de `roundDuration` segundos.
function FinalChaosService.getDuration(roundDuration: number): number
	local config = GameConfig.FinalChaos
	return math.floor(math.min(config.Duration, roundDuration * config.MaxRoundFraction))
end

function FinalChaosService.begin(duration: number)
	if running then
		return
	end
	running = true
	token += 1
	task.spawn(runWaves, token, duration)
end

function FinalChaosService.stop()
	running = false
	token += 1
end

function FinalChaosService.isRunning(): boolean
	return running
end

return table.freeze(FinalChaosService)
