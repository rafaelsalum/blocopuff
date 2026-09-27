--!strict

-- Empurrão do Puffador. Quando um projétil acerta outro participante, o
-- servidor valida o acerto, calcula a velocidade do empurrão e manda o
-- cliente dono do personagem aplicá-la (a física do personagem pertence a
-- ele; uma velocidade escrita pelo servidor seria sobrescrita). Também
-- lembra quem empurrou cada jogador por último, para creditar a derrubada
-- quando ele cair, e mantém a imunidade curta após a Segunda Chance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ProjectileService = require(script.Parent.ProjectileService)
local TelemetryService = require(script.Parent.TelemetryService)

type LastHit = {
	attacker: Player,
	clock: number,
}

export type HitSender = (player: Player, kind: string, value: any) -> ()

local HANDLER_KEY = "Knockback"

local KnockbackService = {}

local roundId = 0
local active = false
local lastHits: { [Player]: LastHit } = {}
local protectedUntil: { [Player]: number } = {}
local sendToPlayer: HitSender? = nil

local function isActiveParticipant(player: Player): boolean
	return active
		and player.Parent ~= nil
		and player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) == roundId
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == false
end

local function computeVelocity(direction: Vector3, power: number): Vector3
	local config = GameConfig.Knockback
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local horizontal = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
	local multiplier = if power > 1 then config.SuperMultiplier else 1
	return (horizontal * config.HorizontalSpeed * multiplier) + Vector3.new(0, config.VerticalSpeed * multiplier, 0)
end

local function onCharacterHit(shooter: Player, victim: Player, _position: Vector3, direction: Vector3, power: number)
	if not isActiveParticipant(shooter) or not isActiveParticipant(victim) then
		return
	end
	local send = sendToPlayer
	if send == nil then
		return
	end

	-- Acerto confirmado para quem atirou (marcador na mira), mesmo se o
	-- alvo estiver imune.
	send(shooter, "PlayerHit", victim.UserId)
	TelemetryService.playerHit(shooter)

	local now = os.clock()
	local immuneUntil = protectedUntil[victim]
	if immuneUntil ~= nil and now < immuneUntil then
		return
	end

	lastHits[victim] = { attacker = shooter, clock = now }
	send(victim, "Knockback", computeVelocity(direction, power))
end

-- Quem empurrou `victim` por último, se foi há pouco tempo.
function KnockbackService.getRecentAttacker(victim: Player): Player?
	local hit = lastHits[victim]
	if hit == nil then
		return nil
	end
	if os.clock() - hit.clock > GameConfig.Knockback.CreditWindow then
		return nil
	end
	return hit.attacker
end

function KnockbackService.protect(player: Player, seconds: number)
	protectedUntil[player] = os.clock() + seconds
	lastHits[player] = nil
end

function KnockbackService.forget(player: Player)
	lastHits[player] = nil
	protectedUntil[player] = nil
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
