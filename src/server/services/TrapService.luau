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
--     atirador nunca é afetado pela própria armadilha).
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
local RugTrap = require(script.Parent.traps.RugTrap)
local WindowTrap = require(script.Parent.traps.WindowTrap)

type TrapState = TrapConstants.TrapState

-- O que cada tipo de armadilha precisa oferecer.
type Behavior = {
	rules: TrapConfig.TrapRules,
	-- Efeito ao fim do aviso; devolve quantos jogadores atingiu.
	-- `isCurrent()` diz se a armadilha continua neste acionamento (a rodada
	-- não acabou), para efeitos com atraso.
	trigger: (part: BasePart, shooter: Player, isCurrent: () -> boolean) -> number,
	-- Volta a aparência de pronta.
	restore: (part: BasePart) -> (),
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
	-- Identificador da armadilha no cenário (telemetria).
	id: string,
}

local HANDLER_KEY = "CasaraoTraps"
local FOLDER_NAME = "CasaraoTraps"
local CRACK_INTERVAL = 0.2
local BEHAVIORS: { [string]: Behavior } = {
	[TrapConstants.Window] = WindowTrap,
	[TrapConstants.Rug] = RugTrap,
}

local TrapService = {}

local traps: { [BasePart]: Trap } = {}
local active = false
local started = false
local connections: { RBXScriptConnection } = {}
local trapsFolder: Folder? = nil

local function setState(trap: Trap, state: TrapState, by: Player?)
	trap.state = state
	local part = trap.part
	part:SetAttribute(TrapConstants.StateAttribute, state)
	part:SetAttribute(TrapConstants.StateAtAttribute, Workspace:GetServerTimeNow())
	part:SetAttribute(TrapConstants.ByAttribute, if by ~= nil then by.UserId else 0)
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
		makeReady(trap)
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

local function fire(trap: Trap, shooter: Player, token: number)
	if trap.token ~= token or not active then
		return
	end
	if shooter.Parent == nil then
		-- Quem atirou saiu do jogo durante o aviso: a armadilha não dispara
		-- e não gasta o uso.
		makeReady(trap)
		return
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
	TelemetryService.event(shooter, "TrapAffected", if ok then result else 0, trap.kind, trap.id)
	task.delay(trap.behavior.rules.RechargeTime, finishRecharge, trap, token)
end

local function onSurfaceHit(shooter: Player, instance: Instance, _position: Vector3, distance: number)
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
	trap.token += 1
	local token = trap.token
	setState(trap, TrapConstants.Warning, shooter)
	TelemetryService.event(shooter, "TrapTriggered", math.floor(distance), trap.kind, trap.id)
	task.delay(trap.behavior.rules.WarningTime, fire, trap, shooter, token)
end

function TrapService.beginRound()
	active = true
	resetAll()
end

function TrapService.endRound()
	active = false
	resetAll()
end

-- Monta as armadilhas que não fazem parte do prédio (tapetes, depois da
-- arena) e registra todas as que têm a tag CasaraoTrap (as janelas vêm do
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
	if trapsFolder ~= nil then
		trapsFolder:Destroy()
		trapsFolder = nil
	end
	started = false
end

return table.freeze(TrapService)
