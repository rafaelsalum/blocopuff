--!strict

-- Tontura de quem é atingido na Corrida da Torre do Relógio (Fase 5F.3):
-- anda devagar por um instante, com estrelinhas girando em cima da cabeça.
-- Depois volta à velocidade de antes (se ninguém mudou nesse meio tempo).

local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

local STARS_NAME = "DizzyStars"
local STARS_TEXT = "💫"
local STARS_OFFSET = Vector3.new(0, 3.2, 0)

local RaceDizzy = {}

-- Velocidade de antes da tontura e até quando ela vai, por personagem.
local dizzy: { [Humanoid]: { speed: number, untilClock: number, slowed: number } } = {}

local function stars(root: BasePart, seconds: number)
	local existing = root:FindFirstChild(STARS_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = STARS_NAME
	gui.Size = UDim2.fromOffset(60, 40)
	gui.StudsOffset = STARS_OFFSET
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = STARS_TEXT
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = root
	task.delay(seconds, function()
		if gui.Parent ~= nil then
			gui:Destroy()
		end
	end)
end

function RaceDizzy.apply(combatant: Combatant, seconds: number, walkSpeed: number)
	local humanoid = CombatantRegistry.getHumanoid(combatant)
	local root = CombatantRegistry.getRoot(combatant)
	if humanoid == nil or root == nil or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local state = dizzy[humanoid]
	if state == nil then
		state = { speed = humanoid.WalkSpeed, untilClock = now + seconds, slowed = walkSpeed }
		dizzy[humanoid] = state
	else
		state.untilClock = now + seconds
	end
	humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, walkSpeed)
	state.slowed = humanoid.WalkSpeed
	stars(root, seconds)
	task.delay(seconds, function()
		local current = dizzy[humanoid]
		if current == nil or os.clock() < current.untilClock - 1e-3 then
			return
		end
		dizzy[humanoid] = nil
		if humanoid.Parent ~= nil and humanoid.WalkSpeed == current.slowed then
			humanoid.WalkSpeed = current.speed
		end
	end)
end

-- Fim da corrida: devolve a velocidade de quem ainda estava tonto.
function RaceDizzy.clear()
	for humanoid, state in pairs(dizzy) do
		if humanoid.Parent ~= nil and humanoid.WalkSpeed == state.slowed then
			humanoid.WalkSpeed = state.speed
		end
	end
	table.clear(dizzy)
end

return table.freeze(RaceDizzy)
