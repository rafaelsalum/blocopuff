--!strict

-- Modo Mistério no Casarão (Fase 5D.3), inspirado no Murder Mystery 2 e sem
-- violência: um Fantasma disfarçado assusta os Moradores (eles desmaiam e
-- assistem ao resto); o Detetive tem o único Puffador e captura o Fantasma
-- com um Puff. Se o Detetive acertar um Morador, fica parado e derruba o
-- Puffador, que qualquer Morador pode pegar e virar o Herói. Os Moradores
-- vencem capturando o Fantasma ou sobrevivendo até o fim; o Fantasma vence
-- se assustar todos.
--
-- Cada jogador só fica sabendo do próprio papel (o remote manda só para
-- ele); nenhum atributo replicado revela quem é quem.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local EliminationTypes = require(ReplicatedStorage.Shared.types.EliminationTypes)
local RoundModeTypes = require(script.Parent.RoundModeTypes)
local MysteryModeRules = require(script.Parent.Parent.data.MysteryModeRules)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local services = script.Parent.Parent.services
local CombatantRegistry = require(services.CombatantRegistry)
local KnockbackService = require(services.KnockbackService)
local PuffadorService = require(services.PuffadorService)
local ProjectileService = require(services.ProjectileService)
local PlayerDataService = require(services.PlayerDataService)
local TelemetryService = require(services.TelemetryService)
local MysteryWingBuilder = require(services.MysteryWingBuilder)
local MysteryCoins = require(services.MysteryCoins)
local MysteryBots = require(services.MysteryBots)
local MysterySheet = require(services.MysterySheet)

type BeginContext = RoundModeTypes.BeginContext
type TickContext = RoundModeTypes.TickContext
type Outcome = RoundModeTypes.Outcome
type Combatant = CombatantRegistry.Combatant
type Role = MysteryModeRules.Role
type WingLayout = MysteryWingBuilder.WingLayout

local REMOTE_NAME = "MysteryMode"
local HIT_HANDLER_KEY = "Mystery"
local COINS_ATTRIBUTE = "MysteryCoins"
local PICKUP_CHECK_SECONDS = 0.2
local GUN_COLOR = Color3.fromRGB(255, 214, 90)

local random = Random.new()
local remote: RemoteEvent? = nil
local wing: WingLayout? = nil

-- Estado da partida em andamento.
local running = false
local generation = 0
local startedAt = 0
local eliminate: ((Combatant, EliminationTypes.EliminationReason) -> ())? = nil
local roles: { [Combatant]: Role } = {}
local order: { Combatant } = {}
local awake: { [Combatant]: boolean } = {}
local coins: { [Combatant]: number } = {}
-- Quem derrubou o Puffador por errar o tiro não pega de novo.
local disarmed: { [Combatant]: boolean } = {}
local ghost: Combatant? = nil
local detective: Combatant? = nil
local gunHolder: Combatant? = nil
-- Última posição conhecida do Puffador (se o portador sumir, cai aqui).
local lastGunPosition: Vector3? = nil
local droppedGun: Part? = nil
local capturedBy: Combatant? = nil
local winnerSide: MysteryModeRules.Winner? = nil
local lastScareAt: number? = nil
local lastSheetAt: number? = nil

-- Entre partidas (no mesmo servidor): quem já foi o quê.
local history: { [number]: MysteryModeRules.RoleHistory } = {}
local lastGhostId: number? = nil
local studioSoloRounds = 0

local function requireWing(): WingLayout
	local current = wing
	if current == nil then
		current = MysteryWingBuilder.build()
		wing = current
	end
	return current
end

local function send(player: Player, kind: string, ...: any)
	local current = remote
	if current ~= nil and player.Parent ~= nil then
		current:FireClient(player, kind, ...)
	end
end

local function sendToAll(kind: string, ...: any)
	for _, combatant in ipairs(order) do
		local player = combatant.player
		if player ~= nil then
			send(player, kind, ...)
		end
	end
end

local function isFiniteVector(vector: Vector3): boolean
	return vector == vector and math.abs(vector.X) < math.huge and math.abs(vector.Y) < math.huge and math.abs(vector.Z) < math.huge
end

local function isAwake(combatant: Combatant): boolean
	return awake[combatant] == true and CombatantRegistry.isPresent(combatant)
end

-- Quem o Fantasma ainda pode assustar (todos acordados, menos ele).
local function awakeResidents(): { Combatant }
	local list: { Combatant } = {}
	for _, combatant in ipairs(order) do
		if combatant ~= ghost and isAwake(combatant) then
			table.insert(list, combatant)
		end
	end
	return list
end

-- Todos os acordados, inclusive o Fantasma (moedas: se ele não pegasse,
-- o contador dele denunciaria quem é).
local function awakeEveryone(): { Combatant }
	local list: { Combatant } = {}
	for _, combatant in ipairs(order) do
		if isAwake(combatant) then
			table.insert(list, combatant)
		end
	end
	return list
end

local function remember(combatant: Combatant?, field: "ghost" | "detective")
	if combatant == nil or combatant.player == nil then
		return
	end
	local entry = history[combatant.id] or { ghost = 0, detective = 0 }
	entry[field] += 1
	history[combatant.id] = entry
end

-- Sorteia os papéis entre os humanos. No teste solo do Studio, o papel do
-- jogador alterna (começa Detetive) e um bot faz o Fantasma quando ele é o
-- Detetive.
local function assignRoles(combatants: { Combatant }, humans: { Player })
	for _, combatant in ipairs(combatants) do
		roles[combatant] = "Resident"
	end
	local humanCombatants = CombatantRegistry.forPlayers(humans)
	local soloTest = RunService:IsStudio() and MysteryModeConfig.StudioSoloTest and #humanCombatants == 1
	if soloTest then
		studioSoloRounds += 1
		local human = humanCombatants[1]
		if studioSoloRounds % 2 == 0 then
			ghost = human
		else
			detective = human
			for _, combatant in ipairs(combatants) do
				if combatant.player == nil then
					ghost = combatant
					break
				end
			end
		end
	else
		local byId: { [number]: Combatant } = {}
		local candidates: { number } = {}
		for _, combatant in ipairs(humanCombatants) do
			byId[combatant.id] = combatant
			table.insert(candidates, combatant.id)
		end
		local picked = MysteryModeRules.assignRoles(candidates, history, lastGhostId, function()
			return random:NextNumber()
		end)
		if picked ~= nil then
			ghost = byId[picked.ghost]
			detective = byId[picked.detective]
		end
	end
	if ghost ~= nil then
		roles[ghost :: Combatant] = "Ghost"
		lastGhostId = (ghost :: Combatant).id
	end
	if detective ~= nil then
		roles[detective :: Combatant] = "Detective"
	end
	gunHolder = detective
	remember(ghost, "ghost")
	remember(detective, "detective")
end

local function removeDroppedGun()
	local gun = droppedGun
	if gun ~= nil then
		gun:Destroy()
		droppedGun = nil
	end
end

-- O Puffador cai no chão onde o portador estava (ou onde foi visto por
-- último, ou no meio da Ala); qualquer Morador pega.
local function dropGun(at: Vector3?)
	local layout = wing
	if layout == nil then
		return
	end
	local position = at or lastGunPosition or layout.center
	removeDroppedGun()
	gunHolder = nil
	local gun = Instance.new("Part")
	gun.Name = "DroppedPuffador"
	gun.Size = Vector3.new(1.2, 1.2, 3)
	gun.Color = GUN_COLOR
	gun.Material = Enum.Material.Neon
	gun.Anchored = true
	gun.CanCollide = false
	gun.CanQuery = false
	gun.CastShadow = false
	gun.CFrame = CFrame.new(Vector3.new(position.X, layout.floorY + 1, position.Z))
	local light = Instance.new("PointLight")
	light.Color = GUN_COLOR
	light.Range = 10
	light.Brightness = 2
	light.Parent = gun
	gun.Parent = layout.folder
	droppedGun = gun
	sendToAll("GunDropped")
end

local function stun(combatant: Combatant)
	local humanoid = CombatantRegistry.getHumanoid(combatant)
	if humanoid == nil then
		return
	end
	local speed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	task.delay(MysteryModeConfig.MisfireStun, function()
		if humanoid.Parent ~= nil and humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = speed
		end
	end)
end

local function knockOut(victim: Combatant, reason: EliminationTypes.EliminationReason)
	local remove = eliminate
	if remove ~= nil and isAwake(victim) then
		remove(victim, reason)
	end
end

-- Puff do Detetive (ou do Herói) acertou alguém.
local function resolveHit(shooter: Combatant, victim: Combatant)
	if not running or shooter ~= gunHolder or not isAwake(shooter) or not isAwake(victim) then
		return
	end
	local player = shooter.player
	if victim == ghost then
		capturedBy = shooter
		knockOut(victim, EliminationTypes.Captured)
		if player ~= nil then
			TelemetryService.event(player, "MysteryCapture", math.floor(os.clock() - startedAt))
		end
		return
	end
	-- Erro: o Morador desmaia, e quem atirou fica parado e derruba o Puffador.
	knockOut(victim, EliminationTypes.Scared)
	local root = CombatantRegistry.getRoot(shooter)
	disarmed[shooter] = true
	if player ~= nil then
		PuffadorService.revokeFrom(player)
		TelemetryService.event(player, "MysteryMisfire", math.floor(os.clock() - startedAt))
		send(player, "Misfire", MysteryModeConfig.MisfireStun)
	end
	stun(shooter)
	dropGun(if root ~= nil then root.Position else nil)
end

-- Fora do laço dos projéteis: eliminar tira o Puffador e apaga projéteis, o
-- que não pode acontecer no meio da atualização deles.
local function onCharacterHit(shooter: Combatant, victim: Combatant, _position: Vector3, _direction: Vector3, _power: number)
	task.defer(resolveHit, shooter, victim)
end

local function elapsed(): number
	return os.clock() - startedAt
end

-- Susto: o Fantasma assusta o Morador acordado mais perto, ao alcance.
local function tryScare(): boolean
	local currentGhost = ghost
	if not running or currentGhost == nil or not isAwake(currentGhost) then
		return false
	end
	local now = os.clock()
	if not MysteryModeRules.actionReady(elapsed(), MysteryModeConfig.StartGrace, lastScareAt, MysteryModeConfig.ScareCooldown, now) then
		return false
	end
	local root = CombatantRegistry.getRoot(currentGhost)
	if root == nil then
		return false
	end
	local nearest: Combatant? = nil
	local nearestDistance = MysteryModeConfig.ScareRange
	for _, target in ipairs(awakeResidents()) do
		local targetRoot = CombatantRegistry.getRoot(target)
		if targetRoot ~= nil then
			local distance = (targetRoot.Position - root.Position).Magnitude
			if distance <= nearestDistance then
				nearest = target
				nearestDistance = distance
			end
		end
	end
	if nearest == nil then
		return false
	end
	lastScareAt = now
	knockOut(nearest, EliminationTypes.Scared)
	return true
end

local function trySheet(direction: Vector3)
	local currentGhost = ghost
	local layout = wing
	if not running or currentGhost == nil or layout == nil or not isAwake(currentGhost) then
		return
	end
	local now = os.clock()
	if not MysteryModeRules.actionReady(elapsed(), MysteryModeConfig.StartGrace, lastSheetAt, MysteryModeConfig.SheetCooldown, now) then
		return
	end
	local root = CombatantRegistry.getRoot(currentGhost)
	if root == nil then
		return
	end
	lastSheetAt = now
	local flat = Vector3.new(direction.X, 0, direction.Z)
	MysterySheet.throw({
		origin = root.Position,
		direction = flat,
		obstacles = layout.folder,
		targets = awakeResidents,
		onHit = function(victim: Combatant)
			knockOut(victim, EliminationTypes.Scared)
		end,
	})
end

local function onRemote(player: Player, action: unknown, value: unknown)
	local currentGhost = ghost
	if currentGhost == nil or currentGhost.player ~= player then
		return
	end
	if action == "Scare" then
		tryScare()
	elseif action == "Sheet" and typeof(value) == "Vector3" and isFiniteVector(value) and Vector3.new(value.X, 0, value.Z).Magnitude > 1e-3 then
		trySheet(value)
	end
end

local function collectCoin(combatant: Combatant): boolean
	local count = coins[combatant] or 0
	if count >= MysteryModeConfig.MaxCoinsPerPlayer then
		return false
	end
	coins[combatant] = count + 1
	CombatantRegistry.setAttribute(combatant, COINS_ATTRIBUTE, count + 1)
	return true
end

-- Moradores humanos acordados (bots e o Fantasma não pegam o Puffador).
local function checkGunPickup()
	local holder = gunHolder
	if holder ~= nil then
		local holderRoot = CombatantRegistry.getRoot(holder)
		if CombatantRegistry.isPresent(holder) and holderRoot ~= nil then
			lastGunPosition = holderRoot.Position
		elseif not CombatantRegistry.isPresent(holder) then
			-- O portador saiu do servidor: o Puffador cai onde foi visto.
			dropGun(nil)
		end
	end
	local gun = droppedGun
	if gun == nil then
		return
	end
	for _, combatant in ipairs(order) do
		local role = roles[combatant] or "Resident"
		local player = combatant.player
		local root = CombatantRegistry.getRoot(combatant)
		if player ~= nil and root ~= nil and MysteryModeRules.canPickUp(role, false, isAwake(combatant), disarmed[combatant] == true) and (root.Position - gun.Position).Magnitude <= MysteryModeConfig.PickupRadius then
			removeDroppedGun()
			gunHolder = combatant
			lastGunPosition = root.Position
			PuffadorService.grantTo({ player })
			send(player, "Hero")
			sendToAll("GunTaken")
			TelemetryService.event(player, "MysteryGunPickup", math.floor(elapsed()))
			return
		end
	end
end

local function start(remotes: Folder?)
	if remotes == nil or remote ~= nil then
		return
	end
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = REMOTE_NAME
	newRemote.Parent = remotes
	newRemote.OnServerEvent:Connect(onRemote)
	remote = newRemote
end

local function canRun(humans: number): boolean
	if RunService:IsStudio() and MysteryModeConfig.StudioSoloTest then
		return humans >= 1
	end
	return humans >= MysteryModeConfig.MinHumans
end

local function resetState()
	table.clear(roles)
	table.clear(order)
	table.clear(awake)
	table.clear(coins)
	table.clear(disarmed)
	ghost = nil
	detective = nil
	gunHolder = nil
	lastGunPosition = nil
	capturedBy = nil
	winnerSide = nil
	lastScareAt = nil
	lastSheetAt = nil
	removeDroppedGun()
end

local function prepare(_roundId: number)
	requireWing()
	resetState()
end

local function getSpawnCFrames(count: number): { CFrame }
	local layout = requireWing()
	local cframes: { CFrame } = {}
	for _ = 1, count do
		local point = layout.randomPoint(random) + Vector3.new(0, 3, 0)
		table.insert(cframes, CFrame.new(point) * CFrame.Angles(0, random:NextNumber(0, 2 * math.pi), 0))
	end
	return cframes
end

local function getRoundDuration(default: number): number
	return math.min(default, MysteryModeConfig.Duration)
end

local function begin(context: BeginContext)
	local layout = requireWing()
	eliminate = context.eliminate
	for _, combatant in ipairs(context.combatants) do
		table.insert(order, combatant)
		awake[combatant] = true
		coins[combatant] = 0
		CombatantRegistry.setAttribute(combatant, COINS_ATTRIBUTE, 0)
	end
	assignRoles(context.combatants, context.humans)
	-- O Puff do Detetive não empurra ninguém: só captura ou erra.
	KnockbackService.setShotForce(0)
	ProjectileService.setCharacterHitHandler(HIT_HANDLER_KEY, onCharacterHit)
	MysteryCoins.start(layout, {
		eligible = awakeEveryone,
		collect = collectCoin,
	})
	for _, combatant in ipairs(order) do
		local player = combatant.player
		if player ~= nil then
			send(player, "Role", roles[combatant], MysteryModeConfig.StartGrace)
			TelemetryService.event(player, "MysteryRoleAssigned", 1, roles[combatant])
		end
	end

	running = true
	generation += 1
	startedAt = os.clock()
	local current = generation
	task.spawn(function()
		while running and generation == current do
			checkGunPickup()
			task.wait(PICKUP_CHECK_SECONDS)
		end
	end)
end

local function getPuffadorHolders(_humans: { Player }): { Player }
	local holder = detective
	if holder ~= nil and holder.player ~= nil then
		return { holder.player :: Player }
	end
	return {}
end

local function onEliminated(combatant: Combatant)
	if not running then
		return
	end
	awake[combatant] = false
	-- O Puffador do Detetive (ou do Herói) cai onde ele desmaiou.
	if combatant == gunHolder then
		local root = CombatantRegistry.getRoot(combatant)
		dropGun(if root ~= nil then root.Position else nil)
	end
end

local function getClimaxDuration(_roundDuration: number): number
	return 0
end

local function isInClimax(): boolean
	return false
end

local function tick(_context: TickContext) end

local function evaluate(timeUp: boolean): Outcome?
	local currentGhost = ghost
	local side: MysteryModeRules.Winner? = nil
	if currentGhost == nil then
		side = if timeUp then "Residents" else nil
	else
		side = MysteryModeRules.outcome({
			ghostAwake = isAwake(currentGhost),
			awakeResidents = #awakeResidents(),
			timeUp = timeUp,
		})
	end
	if side == nil then
		return nil
	end
	winnerSide = side
	if side == "Ghost" then
		return { winner = currentGhost }
	end
	-- Quem aparece como vencedor: quem capturou; sem captura, quem segura o
	-- Puffador ou o primeiro Morador acordado (a vitória é de todos eles).
	local capturer = capturedBy
	if capturer ~= nil and CombatantRegistry.isPresent(capturer) then
		return { winner = capturer }
	end
	local holder = gunHolder
	if holder ~= nil and isAwake(holder) then
		return { winner = holder }
	end
	return { winner = awakeResidents()[1] }
end

-- Fantasma vencedor sozinho; ou todos os Moradores acordados no fim.
local function getWinners(): { [Combatant]: boolean }?
	local winners: { [Combatant]: boolean } = {}
	local currentGhost = ghost
	if winnerSide == "Ghost" and currentGhost ~= nil then
		winners[currentGhost] = true
	elseif winnerSide == "Residents" then
		for _, combatant in ipairs(awakeResidents()) do
			winners[combatant] = true
		end
	end
	return winners
end

local function getRanking(): { [Combatant]: number }?
	local winners = getWinners() or {}
	local positions: { [Combatant]: number } = {}
	for _, combatant in ipairs(order) do
		if CombatantRegistry.isPresent(combatant) then
			positions[combatant] = if winners[combatant] then 1 elseif isAwake(combatant) then 2 else 3
		end
	end
	return positions
end

local function beginBots(bots: { Combatant }, _humans: { Player })
	local currentGhost = ghost
	local driver = if currentGhost ~= nil and currentGhost.player == nil
		then {
			ghost = currentGhost,
			targets = awakeResidents,
			scare = function()
				tryScare()
			end,
		}
		else nil
	MysteryBots.begin(requireWing(), bots, driver)
end

local function endBots()
	MysteryBots.stop()
end

local function getRespawnCFrame(): CFrame?
	return nil
end

local function getRemainingFloorRatio(): number
	return 1
end

-- Moedas viram tickets (com teto) para os humanos que terminaram a partida.
local function payCoins()
	for _, combatant in ipairs(order) do
		local player = combatant.player
		local tickets = MysteryModeRules.coinTickets(coins[combatant] or 0, MysteryModeConfig.CoinsPerTicket, MysteryModeConfig.MaxCoinTickets)
		if player ~= nil and player.Parent ~= nil and tickets > 0 then
			local before, balance, saved = 0, 0, false
			PlayerDataService.update(player, function(profile, canSave)
				before = profile.tickets
				local updated = ProfileSchema.withTickets(profile, tickets)
				balance = updated.tickets
				saved = canSave
				return updated, nil
			end)
			if saved then
				TelemetryService.ticketsEarned(player, before, balance, "MysteryCoins")
			end
		end
	end
end

local function reveal()
	local currentGhost = ghost
	local currentDetective = detective
	sendToAll(
		"Reveal",
		if currentGhost ~= nil then currentGhost.name else "",
		if currentDetective ~= nil then currentDetective.name else "",
		winnerSide or ""
	)
end

local function finish()
	if not running then
		return
	end
	running = false
	generation += 1
	ProjectileService.setCharacterHitHandler(HIT_HANDLER_KEY, nil)
	MysteryCoins.stop()
	MysterySheet.clear()
	removeDroppedGun()
	payCoins()
	reveal()
end

local function cleanup()
	for _, combatant in ipairs(order) do
		CombatantRegistry.setAttribute(combatant, COINS_ATTRIBUTE, 0)
	end
	resetState()
	eliminate = nil
end

local function stop()
	running = false
	generation += 1
	ProjectileService.setCharacterHitHandler(HIT_HANDLER_KEY, nil)
	MysteryCoins.stop()
	MysterySheet.clear()
	MysteryBots.stop()
	resetState()
end

-- Jogador saindo do servidor: o histórico de papéis dele não importa mais.
Players.PlayerRemoving:Connect(function(player: Player)
	history[player.UserId] = nil
end)

local MysteryMode: RoundModeTypes.RoundMode = {
	id = "Mystery",
	start = start,
	canRun = canRun,
	prepare = prepare,
	getSpawnCFrames = getSpawnCFrames,
	getRoundDuration = getRoundDuration,
	begin = begin,
	getClimaxDuration = getClimaxDuration,
	isInClimax = isInClimax,
	tick = tick,
	lastStanding = false,
	evaluate = evaluate,
	getRanking = getRanking,
	getPuffadorHolders = getPuffadorHolders,
	onEliminated = onEliminated,
	getWinners = getWinners,
	beginBots = beginBots,
	endBots = endBots,
	getRespawnCFrame = getRespawnCFrame,
	getRemainingFloorRatio = getRemainingFloorRatio,
	finish = finish,
	cleanup = cleanup,
	stop = stop,
}

return table.freeze(MysteryMode)
