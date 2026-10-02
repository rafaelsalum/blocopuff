--!strict

-- Cérebro dos bots RoboPuff na partida (Fase 5B, entrega 5B.4). Um laço no
-- servidor decide, a cada `BotConfig.Brain.TickSeconds`, para onde cada bot
-- anda e em quem atira. O bot só sabe o que um jogador veria: blocos
-- inteiros, blocos piscando, armadilhas em aviso e quem está à vista.
--
--   * Andar: escolhe um bloco inteiro e seguro, alcançável em linha reta
--     (BotGrid), às vezes perto do alvo, e vai até ele com Humanoid:MoveTo.
--     Pula quando há um buraco logo à frente.
--   * Atirar: escolhe um alvo à vista, espera o tempo de reação do nível e
--     atira com erro de mira, no corpo ou no chão embaixo dele. Às vezes
--     aciona uma armadilha pronta com alguém perto.
-- O nível (Fácil, Normal, Esperto) vem de BotLevelRules, pelos humanos da
-- partida.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local BotGrid = require(script.Parent.Parent.data.BotGrid)
local BotLevelRules = require(script.Parent.Parent.data.BotLevelRules)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local KnockbackService = require(script.Parent.KnockbackService)
local PuffadorService = require(script.Parent.PuffadorService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BotArenaView = require(script.Parent.bots.BotArenaView)

type Combatant = CombatantRegistry.Combatant
type LevelConfig = BotConfig.LevelConfig
type View = BotArenaView.View

type Brain = {
	bot: Combatant,
	level: LevelConfig,
	nextGoalAt: number,
	goalKey: number?,
	goalPosition: Vector3?,
	lastMoveAt: number,
	target: Combatant?,
	targetSince: number,
	nextShotAt: number,
}

-- Altura do centro do corpo acima do topo do bloco.
local ROOT_HEIGHT = 3
-- Quanto à frente (studs) o bot olha para pular buracos.
local LOOKAHEAD = 3.5
-- Reenvia o MoveTo antes do limite de 8 s do Humanoid.
local MOVE_REFRESH = 2
-- Parte do tiro no chão: um pouco abaixo do topo do bloco do alvo.
local FLOOR_AIM_DEPTH = 0.4
-- Antecipa o movimento do alvo (s).
local LEAD_TIME = 0.12

local BotBrainService = {}

local brains: { Brain } = {}
-- Painel admin: todos os bots num nível fixo (nil = BotLevelRules).
local levelOverride: BotConfig.LevelName? = nil
local running = false
local generation = 0
local random = Random.new()

local function aliveRoot(bot: Combatant): (BasePart?, Humanoid?)
	local humanoid = CombatantRegistry.getHumanoid(bot)
	local root = CombatantRegistry.getRoot(bot)
	if humanoid == nil or humanoid.Health <= 0 or root == nil then
		return nil, nil
	end
	return root, humanoid
end

local function activeCombatants(): { Combatant }
	local list: { Combatant } = {}
	for _, combatant in ipairs(CombatantRegistry.all()) do
		if KnockbackService.isActiveParticipant(combatant) and CombatantRegistry.getRoot(combatant) ~= nil then
			table.insert(list, combatant)
		end
	end
	return list
end

-- Ninguém no caminho entre o bot e o alvo (paredes e blocos tapam a vista).
local function canSee(bot: Combatant, from: Vector3, target: Combatant): boolean
	local targetRoot = CombatantRegistry.getRoot(target)
	local ownCharacter = CombatantRegistry.getCharacter(bot)
	if targetRoot == nil or ownCharacter == nil then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ownCharacter }
	local result = Workspace:Raycast(from, targetRoot.Position - from, params)
	if result == nil then
		return true
	end
	local targetCharacter = CombatantRegistry.getCharacter(target)
	return targetCharacter ~= nil and result.Instance:IsDescendantOf(targetCharacter)
end

local function pickTarget(brain: Brain, from: Vector3, combatants: { Combatant }): Combatant?
	local best: Combatant? = nil
	local bestDistance = BotConfig.Brain.SightRange
	for _, other in ipairs(combatants) do
		if other ~= brain.bot then
			local root = CombatantRegistry.getRoot(other)
			local distance = if root ~= nil then (root.Position - from).Magnitude else math.huge
			if distance < bestDistance and canSee(brain.bot, from, other) then
				best = other
				bestDistance = distance
			end
		end
	end
	return best
end

local function moveTo(brain: Brain, humanoid: Humanoid, position: Vector3, now: number)
	brain.goalPosition = position
	brain.lastMoveAt = now
	humanoid:MoveTo(position)
end

-- Escolhe (ou mantém) o destino e pula buracos no caminho.
local function steer(brain: Brain, root: BasePart, humanoid: Humanoid, view: View, now: number)
	local floor = BotArenaView.floorAt(view, root.Position.Y)
	if floor == nil then
		return
	end
	local grid = view.grid
	local level = brain.level
	local row, column = BotGrid.cellOf(grid, root.Position.X, root.Position.Z)
	local avoid = if level.DodgeWarnings then view.danger else {}
	local inDanger = avoid[BotGrid.key(floor, row, column)] == true
	local goalKey = brain.goalKey
	local goalLost = goalKey ~= nil and (not view.intact[goalKey] or avoid[goalKey] == true)

	if goalKey == nil or goalLost or inDanger or now >= brain.nextGoalAt then
		brain.nextGoalAt = now + random:NextNumber(BotConfig.Brain.GoalMinSeconds, BotConfig.Brain.GoalMaxSeconds)
		if not goalLost and not inDanger and random:NextNumber() < level.IdleChance then
			brain.goalKey = BotGrid.key(floor, row, column)
			moveTo(brain, humanoid, root.Position, now)
			return
		end
		local targetRoot = if brain.target ~= nil then CombatantRegistry.getRoot(brain.target) else nil
		local goalRow, goalColumn = BotGrid.chooseGoal(grid, view.intact, floor, root.Position.X, root.Position.Z, {
			maxDistance = BotConfig.Brain.MoveRadius,
			avoid = avoid,
			random = function()
				return random:NextNumber()
			end,
			prefer = if targetRoot ~= nil then { x = targetRoot.Position.X, z = targetRoot.Position.Z } else nil,
			preferWeight = level.ChaseWeight,
		})
		if goalRow ~= nil and goalColumn ~= nil then
			local x, z = BotGrid.center(grid, goalRow, goalColumn)
			brain.goalKey = BotGrid.key(floor, goalRow, goalColumn)
			moveTo(brain, humanoid, Vector3.new(x, view.floorTops[floor] + ROOT_HEIGHT, z), now)
		end
		return
	end

	local goalPosition = brain.goalPosition
	if goalPosition ~= nil and now - brain.lastMoveAt >= MOVE_REFRESH then
		moveTo(brain, humanoid, goalPosition, now)
	end
	-- Buraco logo à frente com chão depois dele: pula.
	local moving = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	if moving.Magnitude > 0.1 then
		local ahead = root.Position + (moving.Unit * LOOKAHEAD)
		local beyond = root.Position + (moving.Unit * LOOKAHEAD * 2)
		local aheadRow, aheadColumn = BotGrid.cellOf(grid, ahead.X, ahead.Z)
		local beyondRow, beyondColumn = BotGrid.cellOf(grid, beyond.X, beyond.Z)
		if not view.intact[BotGrid.key(floor, aheadRow, aheadColumn)] and view.intact[BotGrid.key(floor, beyondRow, beyondColumn)] then
			humanoid.Jump = true
		end
	end
end

-- Armadilha pronta, longe o bastante do bot e com alguém perto dela.
local function pickTrap(brain: Brain, from: Vector3, combatants: { Combatant }): BasePart?
	for _, part in ipairs(CollectionService:GetTagged(TrapConstants.Tag)) do
		if part:IsA("BasePart") and part:GetAttribute(TrapConstants.StateAttribute) == TrapConstants.Ready then
			local kind = part:GetAttribute(TrapConstants.KindAttribute)
			local rules = if kind == TrapConstants.Window then TrapConfig.Window elseif kind == TrapConstants.Rug then TrapConfig.Rug else nil
			if rules ~= nil and (part.Position - from).Magnitude >= rules.MinDistance then
				for _, other in ipairs(combatants) do
					local root = if other ~= brain.bot then CombatantRegistry.getRoot(other) else nil
					if root ~= nil then
						local flat = Vector3.new(root.Position.X - part.Position.X, 0, root.Position.Z - part.Position.Z)
						if flat.Magnitude <= BotConfig.Brain.TrapVictimRadius then
							return part
						end
					end
				end
			end
		end
	end
	return nil
end

-- Onde mirar: numa armadilha, no chão embaixo do alvo ou no corpo dele.
local function aimPoint(brain: Brain, from: Vector3, target: Combatant, view: View, combatants: { Combatant }): Vector3?
	local level = brain.level
	if level.TrapChance > 0 and random:NextNumber() < level.TrapChance then
		local trap = pickTrap(brain, from, combatants)
		if trap ~= nil then
			return trap.Position
		end
	end
	local root = CombatantRegistry.getRoot(target)
	if root == nil then
		return nil
	end
	local floor = BotArenaView.floorAt(view, root.Position.Y)
	if floor ~= nil and random:NextNumber() < level.FloorShotChance then
		return Vector3.new(root.Position.X, view.floorTops[floor] - FLOOR_AIM_DEPTH, root.Position.Z)
	end
	return root.Position + (root.AssemblyLinearVelocity * LEAD_TIME)
end

-- Desvia a direção num cone de `degrees` graus.
local function withAimError(from: Vector3, point: Vector3, degrees: number): Vector3
	local distance = (point - from).Magnitude
	if distance < 1e-3 then
		return point
	end
	local spread = math.rad(degrees)
	local aim = CFrame.lookAt(from, point) * CFrame.Angles(random:NextNumber(-spread, spread), random:NextNumber(-spread, spread), 0)
	return from + (aim.LookVector * distance)
end

local function shoot(brain: Brain, root: BasePart, view: View, combatants: { Combatant }, now: number)
	local level = brain.level
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	local target = brain.target
	local targetLost = target == nil
		or not KnockbackService.isActiveParticipant(target)
		or now - brain.targetSince > BotConfig.Brain.RetargetSeconds
	if targetLost then
		local chosen = pickTarget(brain, eye, combatants)
		if chosen ~= brain.target then
			-- Alvo novo: o tempo de reação começa agora.
			brain.nextShotAt = math.max(brain.nextShotAt, now + level.ReactionTime)
		end
		brain.target = chosen
		brain.targetSince = now
		target = chosen
	end
	if target == nil or now < brain.nextShotAt then
		return
	end
	local point = aimPoint(brain, eye, target, view, combatants)
	if point == nil then
		return
	end
	local flatLook = Vector3.new(point.X, root.Position.Y, point.Z)
	if (flatLook - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flatLook)
	end
	if PuffadorService.fireAsBot(brain.bot, withAimError(eye, point, level.AimErrorDegrees)) then
		local cooldown = GameConfig.Puffador.FireCooldown * level.FireCooldownFactor
		brain.nextShotAt = now + (cooldown * random:NextNumber(0.85, 1.2))
	end
end

local function tick()
	local view = BotArenaView.capture()
	if view == nil then
		return
	end
	local combatants = activeCombatants()
	local now = os.clock()
	for _, brain in ipairs(brains) do
		if KnockbackService.isActiveParticipant(brain.bot) then
			local root, humanoid = aliveRoot(brain.bot)
			if root ~= nil and humanoid ~= nil then
				local ok, failure = pcall(function()
					steer(brain, root, humanoid, view, now)
					shoot(brain, root, view, combatants, now)
				end)
				if not ok then
					warn(`[BlocoPuff] RoboPuff {brain.bot.name} brain failed: {failure}`)
				end
			end
		end
	end
end

-- Nível e experiência dos humanos da partida (perfil carregado).
local function humanInfo(players: { Player }): { BotLevelRules.HumanInfo }
	local list: { BotLevelRules.HumanInfo } = {}
	for _, player in ipairs(players) do
		local snapshot = PlayerDataService.getSnapshot(player)
		if snapshot ~= nil then
			table.insert(list, { matches = snapshot.stats.matches, level = snapshot.level })
		end
	end
	return list
end

-- Começo da partida: um cérebro por bot, com o nível escolhido pelos humanos.
function BotBrainService.beginRound(bots: { Combatant }, humans: { Player })
	BotBrainService.endRound()
	if #bots == 0 then
		return
	end
	local levels = BotLevelRules.choose(#bots, humanInfo(humans), BotConfig.LevelRules)
	local now = os.clock()
	for index, bot in ipairs(bots) do
		local levelName: BotConfig.LevelName = levelOverride or levels[index] or "Easy"
		local level = BotConfig.Levels[levelName]
		local _, humanoid = aliveRoot(bot)
		if humanoid ~= nil then
			humanoid.WalkSpeed = level.WalkSpeed
		end
		local model = bot.model
		if model ~= nil then
			model:SetAttribute("BotLevel", levelName)
		end
		table.insert(brains, {
			bot = bot,
			level = level,
			-- Começa a andar e a atirar com um pequeno atraso, cada um no seu tempo.
			nextGoalAt = now + random:NextNumber(0.3, 1),
			goalKey = nil,
			goalPosition = nil,
			lastMoveAt = now,
			target = nil,
			targetSince = now,
			nextShotAt = now + level.ReactionTime + random:NextNumber(0.5, 1.5),
		})
	end
	running = true
	generation += 1
	local current = generation
	task.spawn(function()
		while running and generation == current do
			tick()
			task.wait(BotConfig.Brain.TickSeconds)
		end
	end)
end

-- Comando de teste: nível fixo para os próximos bots (nil volta ao normal).
function BotBrainService.setLevelOverride(level: BotConfig.LevelName?)
	levelOverride = level
end

function BotBrainService.endRound()
	running = false
	table.clear(brains)
end

return table.freeze(BotBrainService)
