--!strict

-- Armadilhas do Casarão (Fase 5, entrega 5.1): objetos do cenário que um
-- disparo aciona. Regras comuns a todas:
--   * só participantes vivos acionam, e só durante a rodada;
--   * efeito completo só com tiro a partir de `MinDistance`; mais perto, a
--     armadilha só trinca (atributo TrapCracks, sem consequência);
--   * aviso de `WarningTime` antes do efeito (estado Warning), para quem
--     está perto poder reagir;
--   * depois, recarga de `RechargeTime` e no máximo `UsesPerRound` usos por
--     rodada (sem usos, fica gasta até a próxima rodada);
--   * o empurrão e o crédito da derrubada passam pelo KnockbackService (o
--     atirador nunca é afetado pela própria armadilha);
--   * uma armadilha presa a um bloco (lustre) também dispara, com o mesmo
--     aviso, quando esse bloco cai: o crédito vai para quem derrubou o
--     bloco (ninguém, se foi o próprio jogo).
-- Cada tipo (traps/*) faz o próprio efeito e a própria aparência. O estado
-- vai em atributos da peça-alvo (TrapConstants) para os clientes desenharem.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local KnockbackService = require(script.Parent.KnockbackService)
local ProjectileService = require(script.Parent.ProjectileService)
local TelemetryService = require(script.Parent.TelemetryService)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local ArenaService = require(script.Parent.ArenaService)
local ChandelierTrap = require(script.Parent.traps.ChandelierTrap)
local FireplaceTrap = require(script.Parent.traps.FireplaceTrap)
local RugTrap = require(script.Parent.traps.RugTrap)
local WindowTrap = require(script.Parent.traps.WindowTrap)

type TrapState = TrapConstants.TrapState
type Combatant = CombatantRegistry.Combatant

-- O que cada tipo de armadilha precisa oferecer.
type Behavior = {
	rules: TrapConfig.TrapRules,
	-- Efeito ao fim do aviso; devolve quantos jogadores atingiu. `shooter`
	-- é nil quando ninguém acionou (bloco derrubado pelo próprio jogo).
	-- `isCurrent()` diz se a armadilha continua neste acionamento (a rodada
	-- não acabou), para efeitos com atraso.
	trigger: (part: BasePart, shooter: Combatant?, isCurrent: () -> boolean) -> number,
	-- Volta a aparência de pronta.
	restore: (part: BasePart) -> (),
	-- A peça-alvo da armadilha presa a `block`, se houver (ela dispara
	-- quando o bloco cai).
	dependentOn: ((block: Part) -> BasePart?)?,
	-- Limpa o que o tipo guarda por rodada (rostos sujos da lareira).
	roundReset: (() -> ())?,
}

type Trap = {
	part: BasePart,
	kind: string,
	behavior: Behavior,
	state: TrapState,
	uses: number,
	-- Muda a cada acionamento e a cada rodada: tarefas atrasadas de um
	-- acionamento antigo param sozinhas.
	token: number,
	lastCrack: number,
	-- O bloco que segura a armadilha caiu durante um aviso de tiro: ela tem
	-- de cair mesmo que o atirador saia (não dá para pendurar de novo).
	supportLost: boolean,
	-- Identificador da armadilha no cenário (telemetria).
	id: string,
}

local HANDLER_KEY = "CasaraoTraps"
local FOLDER_NAME = "CasaraoTraps"
local CRACK_INTERVAL = 0.2
local BEHAVIORS: { [string]: Behavior } = {
	[TrapConstants.Window] = WindowTrap,
	[TrapConstants.Rug] = RugTrap,
	[TrapConstants.Chandelier] = ChandelierTrap,
	[TrapConstants.Fireplace] = FireplaceTrap,
}

local TrapService = {}

local traps: { [BasePart]: Trap } = {}
local active = false
local started = false
local connections: { RBXScriptConnection } = {}
local trapsFolder: Folder? = nil
local listeningToBlocks = false

local function setState(trap: Trap, state: TrapState, by: Combatant?)
	trap.state = state
	local part = trap.part
	part:SetAttribute(TrapConstants.StateAttribute, state)
	part:SetAttribute(TrapConstants.StateAtAttribute, Workspace:GetServerTimeNow())
	part:SetAttribute(TrapConstants.ByAttribute, if by ~= nil then by.id else 0)
	part:SetAttribute(TrapConstants.UsesAttribute, trap.uses)
end

local function makeReady(trap: Trap)
	local ok, failure = pcall(trap.behavior.restore, trap.part)
	if not ok then
		warn(`[BlocoPuff] Trap {trap.kind} restore failed: {failure}`)
	end
	setState(trap, TrapConstants.Ready, nil)
end

-- Começo (ou fim) de rodada: todas prontas, com os usos completos.
local function resetAll()
	for _, trap in pairs(traps) do
		trap.token += 1
		trap.uses = trap.behavior.rules.UsesPerRound
		trap.supportLost = false
		makeReady(trap)
	end
	for kind, behavior in pairs(BEHAVIORS) do
		local reset = behavior.roundReset
		if reset ~= nil then
			local ok, failure = pcall(reset)
			if not ok then
				warn(`[BlocoPuff] Trap {kind} round reset failed: {failure}`)
			end
		end
	end
end

local function register(instance: Instance)
	if not instance:IsA("BasePart") or traps[instance] ~= nil then
		return
	end
	local kind = instance:GetAttribute(TrapConstants.KindAttribute)
	local behavior = if typeof(kind) == "string" then BEHAVIORS[kind] else nil
	if behavior == nil or typeof(kind) ~= "string" then
		warn(`[BlocoPuff] Unknown trap kind on {instance:GetFullName()}`)
		return
	end
	local trap: Trap = {
		part = instance,
		kind = kind,
		behavior = behavior,
		state = TrapConstants.Ready,
		uses = behavior.rules.UsesPerRound,
		token = 0,
		lastCrack = 0,
		supportLost = false,
		id = tostring(instance:GetAttribute(TrapConstants.IdAttribute) or instance.Name),
	}
	traps[instance] = trap
	makeReady(trap)
end

local function unregister(instance: Instance)
	if instance:IsA("BasePart") then
		traps[instance] = nil
	end
end

-- Trinca (tiro de perto): só aparência, no máximo uma a cada
-- CRACK_INTERVAL por armadilha.
local function crack(trap: Trap)
	local now = os.clock()
	if now - trap.lastCrack < CRACK_INTERVAL then
		return
	end
	trap.lastCrack = now
	local current = trap.part:GetAttribute(TrapConstants.CracksAttribute)
	trap.part:SetAttribute(TrapConstants.CracksAttribute, (if typeof(current) == "number" then current else 0) + 1)
end

local function finishRecharge(trap: Trap, token: number)
	if trap.token ~= token then
		return
	end
	if trap.uses > 0 then
		makeReady(trap)
	else
		setState(trap, TrapConstants.Spent, nil)
	end
end

-- Telemetria só existe para jogadores.
local function logEvent(shooter: Combatant?, name: string, value: number, kind: string, id: string)
	local player = if shooter ~= nil then shooter.player else nil
	if player ~= nil then
		TelemetryService.event(player, name, value, kind, id)
	end
end

-- `forced`: disparada pela queda do bloco que a segura (não dá para voltar
-- atrás, mesmo que quem derrubou tenha saído).
local function fire(trap: Trap, shooter: Combatant?, token: number, forced: boolean)
	if trap.token ~= token or not active then
		return
	end
	if shooter ~= nil and not CombatantRegistry.isPresent(shooter) then
		if not forced and not trap.supportLost then
			-- Quem atirou saiu do jogo durante o aviso: a armadilha não
			-- dispara e não gasta o uso.
			makeReady(trap)
			return
		end
		shooter = nil
	end
	trap.uses -= 1
	setState(trap, TrapConstants.Recharging, shooter)
	local function isCurrent(): boolean
		return active and trap.token == token
	end
	local ok, result = pcall(trap.behavior.trigger, trap.part, shooter, isCurrent)
	if not ok then
		warn(`[BlocoPuff] Trap {trap.kind} failed: {result}`)
	end
	logEvent(shooter, "TrapAffected", if ok then result else 0, trap.kind, trap.id)
	task.delay(trap.behavior.rules.RechargeTime, finishRecharge, trap, token)
end

local function arm(trap: Trap, shooter: Combatant?, forced: boolean)
	trap.supportLost = false
	trap.token += 1
	local token = trap.token
	setState(trap, TrapConstants.Warning, shooter)
	task.delay(trap.behavior.rules.WarningTime, fire, trap, shooter, token, forced)
end

local function onSurfaceHit(shooter: Combatant, instance: Instance, _position: Vector3, distance: number)
	if not active or not instance:IsA("BasePart") then
		return
	end
	local trap = traps[instance]
	if trap == nil or trap.state ~= TrapConstants.Ready or not KnockbackService.isActiveParticipant(shooter) then
		return
	end
	if distance < trap.behavior.rules.MinDistance then
		crack(trap)
		return
	end
	logEvent(shooter, "TrapTriggered", math.floor(distance), trap.kind, trap.id)
	arm(trap, shooter, false)
end

-- Um bloco caiu: dispara a armadilha presa a ele (o lustre), se estiver
-- pendurada.
local function onBlockDestroyed(block: Part, by: Combatant?)
	if not active then
		return
	end
	for _, behavior in pairs(BEHAVIORS) do
		local find = behavior.dependentOn
		local part = if find ~= nil then find(block) else nil
		local trap = if part ~= nil then traps[part] else nil
		if trap ~= nil and trap.state == TrapConstants.Ready then
			logEvent(by, "TrapSupportLost", 1, trap.kind, trap.id)
			arm(trap, by, true)
		elseif trap ~= nil and trap.state == TrapConstants.Warning then
			-- Já está caindo por um tiro: o crédito continua com quem atirou.
			trap.supportLost = true
		end
	end
end

function TrapService.beginRound()
	active = true
	resetAll()
end

function TrapService.endRound()
	active = false
	resetAll()
end

-- Depois que a arena restaura os blocos fora da rodada (fim do intervalo,
-- modo foto): as armadilhas presas a um bloco voltam a aparecer.
function TrapService.refresh()
	if active then
		return
	end
	for _, trap in pairs(traps) do
		if trap.state == TrapConstants.Ready then
			local ok, failure = pcall(trap.behavior.restore, trap.part)
			if not ok then
				warn(`[BlocoPuff] Trap {trap.kind} restore failed: {failure}`)
			end
		end
	end
end

-- Monta as armadilhas que não fazem parte do prédio (tapetes, lustres e
-- lareira, depois da arena) e registra todas as que têm a tag CasaraoTrap (as janelas vêm do
-- BuildingDecor).
function TrapService.start(worldRoot: Instance)
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = worldRoot
	trapsFolder = folder
	RugTrap.build(folder)
	ChandelierTrap.build(folder)
	FireplaceTrap.build(folder)
	if not listeningToBlocks then
		-- A arena não tem como remover o aviso; ele confere `active`.
		listeningToBlocks = true
		ArenaService.addDestroyedListener(onBlockDestroyed)
	end
	for _, instance in ipairs(CollectionService:GetTagged(TrapConstants.Tag)) do
		register(instance)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(TrapConstants.Tag):Connect(register))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(TrapConstants.Tag):Connect(unregister))
	ProjectileService.setSurfaceHitHandler(HANDLER_KEY, onSurfaceHit)
end

function TrapService.stop()
	active = false
	resetAll()
	ProjectileService.setSurfaceHitHandler(HANDLER_KEY, nil)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(traps)
	RugTrap.clear()
	ChandelierTrap.clear()
	FireplaceTrap.clear()
	if trapsFolder ~= nil then
		trapsFolder:Destroy()
		trapsFolder = nil
	end
	started = false
end

return table.freeze(TrapService)
