--!strict

-- Empurrão do Puffador. Quando um projétil acerta outro participante, o
-- servidor valida o acerto, calcula a velocidade do empurrão e manda o
-- cliente dono do personagem aplicá-la (a física do personagem pertence a
-- ele; uma velocidade escrita pelo servidor seria sobrescrita). Bots
-- RoboPuff não têm cliente: neles o servidor aplica o empurrão. Também
-- lembra quem empurrou cada jogador por último, para creditar a derrubada
-- quando ele cair, e mantém a imunidade curta após a Segunda Chance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local CharacterImpulse = require(ReplicatedStorage.Shared.modules.CharacterImpulse)
local ProjectileService = require(script.Parent.ProjectileService)
local TelemetryService = require(script.Parent.TelemetryService)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

type LastHit = {
	attacker: Combatant,
	clock: number,
}

export type HitSender = (player: Player, kind: string, value: any) -> ()

local HANDLER_KEY = "Knockback"

local KnockbackService = {}

local roundId = 0
local active = false
local lastHits: { [Combatant]: LastHit } = {}
local protectedUntil: { [Combatant]: number } = {}
local sendToPlayer: HitSender? = nil

local function isActiveParticipant(combatant: Combatant): boolean
	return active
		and CombatantRegistry.isPresent(combatant)
		and CombatantRegistry.getAttribute(combatant, StateAttributeNames.PlayerIsParticipant) == true
		and CombatantRegistry.getAttribute(combatant, StateAttributeNames.PlayerParticipatingRoundId) == roundId
		and CombatantRegistry.getAttribute(combatant, StateAttributeNames.PlayerIsEliminated) == false
end

-- O bot RoboPuff é simulado pelo servidor: o empurrão é aplicado aqui,
-- com a mesma física que o cliente aplica no jogador.
local function applyToBot(bot: Combatant, kind: string, value: any)
	local root = CombatantRegistry.getRoot(bot)
	local humanoid = CombatantRegistry.getHumanoid(bot)
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if kind == "Knockback" and typeof(value) == "Vector3" then
		CharacterImpulse.knockback(root, humanoid, value)
	elseif kind == "Slide" and typeof(value) == "table" then
		CharacterImpulse.slide(root, value.velocity, value.duration)
	end
end

-- Avisa o jogador (o cliente dele aplica o empurrão) ou empurra o bot.
local function notify(combatant: Combatant, kind: string, value: any)
	local send = sendToPlayer
	local player = combatant.player
	if player == nil then
		applyToBot(combatant, kind, value)
	elseif send ~= nil then
		send(player, kind, value)
	end
end

local function computeVelocity(direction: Vector3, power: number): Vector3
	local config = GameConfig.Knockback
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local horizontal = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
	local multiplier = if power > 1 then config.SuperMultiplier else 1
	return (horizontal * config.HorizontalSpeed * multiplier) + Vector3.new(0, config.VerticalSpeed * multiplier, 0)
end

local function onCharacterHit(shooter: Combatant, victim: Combatant, _position: Vector3, direction: Vector3, power: number)
	if sendToPlayer == nil or not isActiveParticipant(shooter) or not isActiveParticipant(victim) then
		return
	end

	-- Acerto confirmado para quem atirou (marcador na mira), mesmo se o
	-- alvo estiver imune.
	notify(shooter, "PlayerHit", victim.id)
	local shooterPlayer = shooter.player
	if shooterPlayer ~= nil then
		TelemetryService.playerHit(shooterPlayer)
	end

	local now = os.clock()
	local immuneUntil = protectedUntil[victim]
	if immuneUntil ~= nil and now < immuneUntil then
		return
	end

	lastHits[victim] = { attacker = shooter, clock = now }
	notify(victim, "Knockback", computeVelocity(direction, power))
end

-- Participante vivo da rodada em andamento.
function KnockbackService.isActiveParticipant(combatant: Combatant): boolean
	return isActiveParticipant(combatant)
end

-- Empurrão vindo de outra fonte (armadilhas do Casarão), com as mesmas
-- regras do disparo: só participantes vivos, respeita a proteção da Segunda
-- Chance e credita a derrubada a `attacker` (nil: ninguém leva o crédito).
-- Devolve se o empurrão foi aplicado.
local function deliver(attacker: Combatant?, victim: Combatant, kind: string, value: any): boolean
	if sendToPlayer == nil or not isActiveParticipant(victim) then
		return false
	end
	local now = os.clock()
	local immuneUntil = protectedUntil[victim]
	if immuneUntil ~= nil and now < immuneUntil then
		return false
	end
	if attacker ~= nil and attacker ~= victim then
		lastHits[victim] = { attacker = attacker, clock = now }
	end
	notify(victim, kind, value)
	return true
end

function KnockbackService.push(attacker: Combatant?, victim: Combatant, velocity: Vector3): boolean
	return deliver(attacker, victim, "Knockback", velocity)
end

-- Escorregão (Tapete Puxado): só na horizontal, por `duration` segundos, sem
-- tirar o jogador do chão (a gravidade continua valendo). Mesmas regras de
-- `push`.
function KnockbackService.slide(attacker: Combatant?, victim: Combatant, velocity: Vector3, duration: number): boolean
	return deliver(attacker, victim, "Slide", { velocity = Vector3.new(velocity.X, 0, velocity.Z), duration = duration })
end

-- Credita uma queda de `victim` a `attacker` sem empurrar (ex.: o chão
-- caiu debaixo dele por causa de uma armadilha).
function KnockbackService.markAttacker(victim: Combatant, attacker: Combatant)
	if attacker == victim or not isActiveParticipant(victim) then
		return
	end
	local now = os.clock()
	local immuneUntil = protectedUntil[victim]
	if immuneUntil ~= nil and now < immuneUntil then
		return
	end
	lastHits[victim] = { attacker = attacker, clock = now }
end

-- Quem empurrou `victim` por último, se foi há pouco tempo.
function KnockbackService.getRecentAttacker(victim: Combatant): Combatant?
	local hit = lastHits[victim]
	if hit == nil then
		return nil
	end
	if os.clock() - hit.clock > GameConfig.Knockback.CreditWindow then
		return nil
	end
	return hit.attacker
end

function KnockbackService.protect(combatant: Combatant, seconds: number)
	protectedUntil[combatant] = os.clock() + seconds
	lastHits[combatant] = nil
end

function KnockbackService.forget(combatant: Combatant)
	lastHits[combatant] = nil
	protectedUntil[combatant] = nil
end

function KnockbackService.beginRound(newRoundId: number)
	roundId = newRoundId
	active = true
	table.clear(lastHits)
	table.clear(protectedUntil)
end

function KnockbackService.endRound()
	active = false
	table.clear(lastHits)
	table.clear(protectedUntil)
end

function KnockbackService.start(sender: HitSender)
	sendToPlayer = sender
	ProjectileService.setCharacterHitHandler(HANDLER_KEY, onCharacterHit)
end

function KnockbackService.stop()
	KnockbackService.endRound()
	ProjectileService.setCharacterHitHandler(HANDLER_KEY, nil)
	sendToPlayer = nil
end

return table.freeze(KnockbackService)
