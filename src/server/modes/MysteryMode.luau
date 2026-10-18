--!strict

-- Modo Assassinato no Casarão (Fase 5E, docs/FASE_5E_ASSASSINATO_NO_CASARAO.md),
-- fiel ao Murder Mystery 2. O id continua "Mystery" (rotação, voto e
-- telemetria já usam esse nome):
--   * o Assassino (sempre humano) tem a faca: saca, golpeia de perto e
--     arremessa (MurderKnife);
--   * o Xerife tem a arma: o Puffador com um tiro e recarga longa. Acertar o
--     Assassino dá a vitória aos Inocentes; acertar um Inocente elimina o
--     alvo e o próprio Xerife, e a arma cai;
--   * a arma caída vira de qualquer Inocente humano vivo, que vira o Herói;
--   * Inocentes (humanos e bots) coletam moedas e fogem.
-- Os Inocentes vencem eliminando o Assassino ou sobrevivendo até o fim; o
-- Assassino vence eliminando todos. Quem é eliminado vira fumaça e confete
-- (sem corpo no chão).
--
-- Cada jogador só fica sabendo do próprio papel (o remote manda só para
-- ele); nenhum atributo replicado revela quem é quem. A faca sacada todos
-- veem, porque está na mão do Assassino.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local EliminationTypes = require(ReplicatedStorage.Shared.types.EliminationTypes)
local RoundModeTypes = require(script.Parent.RoundModeTypes)
local MurderRules = require(script.Parent.Parent.data.MurderRules)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local services = script.Parent.Parent.services
local CombatantRegistry = require(services.CombatantRegistry)
local KnockbackService = require(services.KnockbackService)
local PuffadorService = require(services.PuffadorService)
local ProjectileService = require(services.ProjectileService)
local PlayerDataService = require(services.PlayerDataService)
local TelemetryService = require(services.TelemetryService)
local MurderMansionBuilder = require(services.MurderMansionBuilder)
local MysteryCoins = require(services.MysteryCoins)
local MysteryBots = require(services.MysteryBots)
local MurderKnife = require(services.MurderKnife)

type BeginContext = RoundModeTypes.BeginContext
type TickContext = RoundModeTypes.TickContext
type Outcome = RoundModeTypes.Outcome
type Combatant = CombatantRegistry.Combatant
type Role = MurderRules.Role
type WingLayout = MurderMansionBuilder.WingLayout

local REMOTE_NAME = "MysteryMode"
local HIT_HANDLER_KEY = "Mystery"
local COINS_ATTRIBUTE = "MysteryCoins"
local PICKUP_CHECK_SECONDS = 0.2
-- Sacar e guardar a faca no máximo a cada tanto (remote do cliente).
local EQUIP_MIN_INTERVAL = 0.15
local GUN_COLOR = Color3.fromRGB(110, 170, 255)
local POOF_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 214, 90),
	Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(190, 140, 255),
}

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
local alive: { [Combatant]: boolean } = {}
local coins: { [Combatant]: number } = {}
-- Ações que contam como "jogou" para o XP (golpes, arremessos, moedas, pegar
-- a arma). Só sobreviver não conta: quem fica parado não ganha XP.
local actions: { [Combatant]: number } = {}
local murderer: Combatant? = nil
local sheriff: Combatant? = nil
local hero: Combatant? = nil
local gunHolder: Combatant? = nil
-- Última posição conhecida da arma (se o portador sumir, cai aqui).
local lastGunPosition: Vector3? = nil
local droppedGun: Model? = nil
-- Quem acertou o Assassino.
local murdererDownBy: Combatant? = nil
local winnerSide: MurderRules.Winner? = nil
local lastStabAt: number? = nil
local lastThrowAt: number? = nil
local lastEquipAt = 0

-- Entre partidas (no mesmo servidor): quem já foi o quê.
local history: { [number]: MurderRules.RoleHistory } = {}
local lastMurdererId: number? = nil
local studioSoloRounds = 0

local function requireWing(): WingLayout
	local current = wing
	if current == nil then
		current = MurderMansionBuilder.build()
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

local function isAlive(combatant: Combatant): boolean
	return alive[combatant] == true and CombatantRegistry.isPresent(combatant)
end

local function elapsed(): number
	return os.clock() - startedAt
end

-- Todos os vivos menos o Assassino (alvos da faca e quem vence com o tempo).
local function aliveOthers(): { Combatant }
	local list: { Combatant } = {}
	for _, combatant in ipairs(order) do
		if combatant ~= murderer and isAlive(combatant) then
			table.insert(list, combatant)
		end
	end
	return list
end

-- Todos os vivos, inclusive o Assassino (moedas: se ele não pegasse, o
-- contador dele o denunciaria).
local function aliveEveryone(): { Combatant }
	local list: { Combatant } = {}
	for _, combatant in ipairs(order) do
		if isAlive(combatant) then
			table.insert(list, combatant)
		end
	end
	return list
end

local function remember(combatant: Combatant?, field: "murderer" | "sheriff")
	if combatant == nil or combatant.player == nil then
		return
	end
	local entry = history[combatant.id] or { murderer = 0, sheriff = 0 }
	entry[field] += 1
	history[combatant.id] = entry
end

-- No teste solo do Studio o papel do jogador alterna (começa Xerife, com um
-- bot de Assassino; depois ele é o Assassino). Fora do Studio, os dois
-- papéis são sempre de humanos.
local function pickSoloRoles(human: Combatant, combatants: { Combatant })
	studioSoloRounds += 1
	if studioSoloRounds % 2 == 0 then
		murderer = human
		return
	end
	sheriff = human
	for _, combatant in ipairs(combatants) do
		if combatant.player == nil then
			murderer = combatant
			return
		end
	end
end

local function assignRoles(combatants: { Combatant }, humans: { Player })
	for _, combatant in ipairs(combatants) do
		roles[combatant] = "Innocent"
	end
	local humanCombatants = CombatantRegistry.forPlayers(humans)
	if RunService:IsStudio() and MysteryModeConfig.StudioSoloTest and #humanCombatants == 1 then
		pickSoloRoles(humanCombatants[1], combatants)
	else
		local byId: { [number]: Combatant } = {}
		local candidates: { number } = {}
		for _, combatant in ipairs(humanCombatants) do
			byId[combatant.id] = combatant
			table.insert(candidates, combatant.id)
		end
		local picked = MurderRules.assignRoles(candidates, history, lastMurdererId, function()
			return random:NextNumber()
		end)
		if picked ~= nil then
			murderer = byId[picked.murderer]
			sheriff = byId[picked.sheriff]
		end
	end
	local currentMurderer = murderer
	if currentMurderer ~= nil then
		roles[currentMurderer] = "Murderer"
		lastMurdererId = currentMurderer.id
	end
	if sheriff ~= nil then
		roles[sheriff :: Combatant] = "Sheriff"
	end
	gunHolder = sheriff
	remember(murderer, "murderer")
	remember(sheriff, "sheriff")
end

-- Fumaça e confete onde o eliminado estava, e o corpo some (sem corpo no
-- chão). Roda antes de o RoundService zerar a vida do personagem.
local function poof(combatant: Combatant)
	local character = CombatantRegistry.getCharacter(combatant)
	local root = CombatantRegistry.getRoot(combatant)
	local layout = wing
	if character == nil or root == nil or layout == nil then
		return
	end
	local burst = Instance.new("Part")
	burst.Name = "Poof"
	burst.Size = Vector3.one
	burst.Transparency = 1
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.CFrame = root.CFrame
	burst.Parent = layout.folder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 245))
	smoke.Size = NumberSequence.new(2.5, 5)
	smoke.Transparency = NumberSequence.new(0.2, 1)
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Speed = NumberRange.new(4, 8)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Enabled = false
	smoke.Parent = burst
	smoke:Emit(16)
	for _, color in ipairs(POOF_COLORS) do
		local confetti = Instance.new("ParticleEmitter")
		confetti.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		confetti.Color = ColorSequence.new(color)
		confetti.Size = NumberSequence.new(0.5)
		confetti.Lifetime = NumberRange.new(0.8, 1.4)
		confetti.Speed = NumberRange.new(10, 18)
		confetti.SpreadAngle = Vector2.new(180, 180)
		confetti.Acceleration = Vector3.new(0, -25, 0)
		confetti.Enabled = false
		confetti.Parent = burst
		confetti:Emit(10)
	end
	Debris:AddItem(burst, 2)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.Transparency = 1
		elseif descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end
end

local function removeDroppedGun()
	local gun = droppedGun
	if gun ~= nil then
		gun:Destroy()
		droppedGun = nil
	end
end

-- Arma caída: brilho e feixe de luz visíveis de longe.
local function buildDroppedGun(layout: WingLayout, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "DroppedSheriffGun"
	local body = Instance.new("Part")
	body.Name = "Gun"
	body.Size = Vector3.new(1.2, 1.2, 3)
	body.Color = GUN_COLOR
	body.Material = Enum.Material.Neon
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CastShadow = false
	-- No chão do andar em que caiu (a Ala tem dois andares).
	local floorY = layout.floorAt(position)
	body.CFrame = CFrame.new(Vector3.new(position.X, floorY + 1.2, position.Z))
	body.Parent = model
	local light = Instance.new("PointLight")
	light.Color = GUN_COLOR
	light.Range = 14
	light.Brightness = 3
	light.Parent = body
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Color = GUN_COLOR
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.55
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Size = Vector3.new(0.6, 13, 0.6)
	beam.CFrame = CFrame.new(Vector3.new(position.X, floorY + 7.5, position.Z))
	beam.Parent = model
	model.PrimaryPart = body
	model.Parent = layout.folder
	return model
end

-- A arma cai onde o portador estava (ou onde foi vista por último, ou no
-- meio da Ala); qualquer Inocente humano vivo pega.
local function dropGun(at: Vector3?)
	local layout = wing
	if layout == nil then
		return
	end
	removeDroppedGun()
	gunHolder = nil
	droppedGun = buildDroppedGun(layout, at or lastGunPosition or layout.randomPoint(random))
	sendToAll("GunDropped")
end

local function countAction(combatant: Combatant)
	actions[combatant] = (actions[combatant] or 0) + 1
end

local function knockOut(victim: Combatant, reason: EliminationTypes.EliminationReason)
	local remove = eliminate
	-- Um acerto adiado (task.defer) pode chegar depois do fim da partida.
	if running and remove ~= nil and isAlive(victim) then
		remove(victim, reason)
	end
end

-- Tiro da arma (Xerife ou Herói) acertou alguém.
local function resolveHit(shooter: Combatant, victim: Combatant)
	if not running or shooter ~= gunHolder or not isAlive(shooter) or not isAlive(victim) then
		return
	end
	if elapsed() < MysteryModeConfig.StartGrace then
		return
	end
	local player = shooter.player
	if MurderRules.shotResult(roles[victim] or "Innocent") == "MurdererDown" then
		murdererDownBy = shooter
		knockOut(victim, EliminationTypes.Shot)
		if player ~= nil then
			TelemetryService.event(player, "MurderSheriffShot", math.floor(elapsed()), "Murderer")
		end
		return
	end
	-- Erro: o Inocente sai, e quem atirou sai junto (a arma cai onde ele estava).
	if player ~= nil then
		TelemetryService.event(player, "MurderSheriffShot", math.floor(elapsed()), "Innocent")
	end
	knockOut(victim, EliminationTypes.Shot)
	knockOut(shooter, EliminationTypes.Misfire)
end

-- Fora do laço dos projéteis: eliminar tira o Puffador e apaga projéteis, o
-- que não pode acontecer no meio da atualização deles.
local function onCharacterHit(shooter: Combatant, victim: Combatant, _position: Vector3, _direction: Vector3, _power: number)
	task.defer(resolveHit, shooter, victim)
end

local function murdererReady(): Combatant?
	local current = murderer
	if not running or current == nil or not isAlive(current) or not MurderKnife.isEquipped(current) then
		return nil
	end
	return current
end

-- Golpe de perto: o primeiro alvo à frente, ao alcance e sem parede no meio.
local function tryStab(): boolean
	local current = murdererReady()
	local layout = wing
	if current == nil or layout == nil then
		return false
	end
	local now = os.clock()
	if not MurderRules.actionReady(elapsed(), MysteryModeConfig.StartGrace, lastStabAt, MysteryModeConfig.StabCooldown, now) then
		return false
	end
	lastStabAt = now
	local target = MurderKnife.stabTarget(current, aliveOthers(), layout.folder)
	if target == nil then
		return false
	end
	countAction(current)
	local player = current.player
	if player ~= nil then
		TelemetryService.event(player, "MurderStab", math.floor(elapsed()))
	end
	knockOut(target, EliminationTypes.Knifed)
	return true
end

local function tryThrow(direction: Vector3)
	local current = murdererReady()
	local layout = wing
	if current == nil or layout == nil then
		return
	end
	local now = os.clock()
	if not MurderRules.actionReady(elapsed(), MysteryModeConfig.StartGrace, lastThrowAt, MysteryModeConfig.ThrowCooldown, now) then
		return
	end
	local root = CombatantRegistry.getRoot(current)
	if root == nil then
		return
	end
	lastThrowAt = now
	countAction(current)
	-- Logo depois do arremesso também não dá para golpear.
	lastStabAt = now
	local player = current.player
	if player ~= nil then
		TelemetryService.event(player, "MurderThrow", math.floor(elapsed()))
		send(player, "ThrowCooldown", MysteryModeConfig.ThrowCooldown)
	end
	MurderKnife.throw({
		origin = root.Position + Vector3.new(0, 0.5, 0),
		direction = direction,
		obstacles = layout.folder,
		targets = aliveOthers,
		onHit = function(victim: Combatant)
			if player ~= nil then
				TelemetryService.event(player, "MurderThrowHit", math.floor(elapsed()))
			end
			task.defer(knockOut, victim, EliminationTypes.Knifed)
		end,
	})
end

local function onRemote(player: Player, action: unknown, value: unknown)
	local current = murderer
	if current == nil or current.player ~= player then
		return
	end
	if action == "Equip" and typeof(value) == "boolean" then
		local now = os.clock()
		if now - lastEquipAt >= EQUIP_MIN_INTERVAL then
			lastEquipAt = now
			MurderKnife.setEquipped(current, value)
		end
	elseif action == "Stab" then
		tryStab()
	elseif action == "Throw" and typeof(value) == "Vector3" and isFiniteVector(value) and Vector3.new(value.X, 0, value.Z).Magnitude > 1e-3 then
		tryThrow(value)
	end
end

local function collectCoin(combatant: Combatant): boolean
	local nextCount = MurderRules.collect(coins[combatant] or 0, MysteryModeConfig.MaxCoinsPerPlayer)
	if nextCount == nil then
		return false
	end
	coins[combatant] = nextCount
	countAction(combatant)
	CombatantRegistry.setAttribute(combatant, COINS_ATTRIBUTE, nextCount)
	return true
end

-- Inocentes humanos vivos pegam a arma caída e viram o Herói.
local function checkGunPickup()
	local holder = gunHolder
	if holder ~= nil then
		local holderRoot = CombatantRegistry.getRoot(holder)
		if CombatantRegistry.isPresent(holder) and holderRoot ~= nil then
			lastGunPosition = holderRoot.Position
		elseif not CombatantRegistry.isPresent(holder) then
			-- O portador saiu do servidor: a arma cai onde foi vista.
			dropGun(nil)
		end
	end
	local gun = droppedGun
	local gunPart = if gun ~= nil then gun.PrimaryPart else nil
	if gunPart == nil then
		return
	end
	for _, combatant in ipairs(order) do
		local player = combatant.player
		local root = CombatantRegistry.getRoot(combatant)
		local role = roles[combatant] or "Innocent"
		if player ~= nil and root ~= nil and MurderRules.canPickUp(role, false, isAlive(combatant)) and (root.Position - gunPart.Position).Magnitude <= MysteryModeConfig.PickupRadius then
			removeDroppedGun()
			gunHolder = combatant
			hero = combatant
			countAction(combatant)
			lastGunPosition = root.Position
			PuffadorService.grantTo({ player })
			send(player, "Hero")
			sendToAll("GunTaken")
			TelemetryService.event(player, "MurderHero", math.floor(elapsed()))
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
	table.clear(alive)
	table.clear(coins)
	table.clear(actions)
	murderer = nil
	sheriff = nil
	hero = nil
	gunHolder = nil
	lastGunPosition = nil
	murdererDownBy = nil
	winnerSide = nil
	lastStabAt = nil
	lastThrowAt = nil
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
		alive[combatant] = true
		coins[combatant] = 0
		CombatantRegistry.setAttribute(combatant, COINS_ATTRIBUTE, 0)
	end
	assignRoles(context.combatants, context.humans)
	-- A arma do Xerife não empurra ninguém: só elimina, com recarga longa.
	KnockbackService.setShotForce(0)
	PuffadorService.setFireCooldown(MysteryModeConfig.SheriffReload)
	ProjectileService.setCharacterHitHandler(HIT_HANDLER_KEY, onCharacterHit)
	local currentMurderer = murderer
	if currentMurderer ~= nil then
		MurderKnife.give(currentMurderer)
	end
	MysteryCoins.start(layout, {
		eligible = aliveEveryone,
		collect = collectCoin,
	})
	for _, combatant in ipairs(order) do
		local player = combatant.player
		if player ~= nil then
			send(player, "Role", roles[combatant], MysteryModeConfig.StartGrace)
			TelemetryService.event(player, "MurderRoleAssigned", 1, roles[combatant])
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
	local holder = sheriff
	if holder ~= nil and holder.player ~= nil then
		return { holder.player :: Player }
	end
	return {}
end

local function onEliminated(combatant: Combatant)
	if not running then
		return
	end
	alive[combatant] = false
	poof(combatant)
	if combatant == murderer then
		MurderKnife.take(combatant)
	end
	-- A arma do Xerife (ou do Herói) cai onde ele foi eliminado.
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
	local currentMurderer = murderer
	local side: MurderRules.Winner? = nil
	if currentMurderer == nil then
		side = if timeUp then "Innocents" else nil
	else
		side = MurderRules.outcome({
			murdererAlive = isAlive(currentMurderer),
			othersAlive = #aliveOthers(),
			timeUp = timeUp,
		})
	end
	if side == nil then
		return nil
	end
	winnerSide = side
	if side == "Murderer" then
		return { winner = currentMurderer }
	end
	-- Quem aparece como vencedor: quem acertou o Assassino; senão quem segura
	-- a arma ou o primeiro vivo (a vitória é de todos eles).
	local shooter = murdererDownBy
	if shooter ~= nil and CombatantRegistry.isPresent(shooter) then
		return { winner = shooter }
	end
	local holder = gunHolder
	if holder ~= nil and isAlive(holder) then
		return { winner = holder }
	end
	return { winner = aliveOthers()[1] }
end

-- Assassino vencedor sozinho; ou todos os vivos no fim (com quem acertou o
-- Assassino, mesmo que não esteja mais vivo).
local function getWinners(): { [Combatant]: boolean }?
	local winners: { [Combatant]: boolean } = {}
	local currentMurderer = murderer
	if winnerSide == "Murderer" and currentMurderer ~= nil then
		winners[currentMurderer] = true
	elseif winnerSide == "Innocents" then
		for _, combatant in ipairs(aliveOthers()) do
			winners[combatant] = true
		end
		local shooter = murdererDownBy
		if shooter ~= nil and CombatantRegistry.isPresent(shooter) then
			winners[shooter] = true
		end
	end
	return winners
end

local function getRanking(): { [Combatant]: number }?
	local winners = getWinners() or {}
	local positions: { [Combatant]: number } = {}
	for _, combatant in ipairs(order) do
		if CombatantRegistry.isPresent(combatant) then
			positions[combatant] = if winners[combatant] then 1 elseif isAlive(combatant) then 2 else 3
		end
	end
	return positions
end

local function getActions(combatant: Combatant): number
	return actions[combatant] or 0
end

local function beginBots(bots: { Combatant }, _humans: { Player })
	local currentMurderer = murderer
	local driver = if currentMurderer ~= nil and currentMurderer.player == nil
		then {
			murderer = currentMurderer,
			targets = aliveOthers,
			attack = function()
				tryStab()
			end,
		}
		else nil
	MysteryBots.begin(requireWing(), bots, {
		murderer = function(): Combatant?
			local current = murderer
			return if current ~= nil and isAlive(current) then current else nil
		end,
		droppedGun = function(): Vector3?
			local gun = droppedGun
			local gunPart = if gun ~= nil then gun.PrimaryPart else nil
			return if gunPart ~= nil then gunPart.Position else nil
		end,
		driver = driver,
	})
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
		local tickets = MurderRules.coinTickets(coins[combatant] or 0, MysteryModeConfig.CoinsPerTicket, MysteryModeConfig.MaxCoinTickets)
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

local function nameOf(combatant: Combatant?): string
	return if combatant ~= nil then combatant.name else ""
end

-- No fim, todos ficam sabendo quem era quem.
local function reveal()
	sendToAll("Reveal", nameOf(murderer), nameOf(sheriff), nameOf(hero), winnerSide or "")
	for _, combatant in ipairs(order) do
		local player = combatant.player
		if player ~= nil then
			TelemetryService.event(player, "MurderResult", math.floor(elapsed()), winnerSide or "", roles[combatant])
		end
	end
end

local function stopRound()
	running = false
	generation += 1
	ProjectileService.setCharacterHitHandler(HIT_HANDLER_KEY, nil)
	PuffadorService.setFireCooldown(nil)
	MysteryCoins.stop()
	MurderKnife.clear()
	removeDroppedGun()
end

local function finish()
	if not running then
		return
	end
	stopRound()
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
	stopRound()
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
	getActions = getActions,
	beginBots = beginBots,
	endBots = endBots,
	getRespawnCFrame = getRespawnCFrame,
	getRemainingFloorRatio = getRemainingFloorRatio,
	finish = finish,
	cleanup = cleanup,
	stop = stop,
}

return table.freeze(MysteryMode)
