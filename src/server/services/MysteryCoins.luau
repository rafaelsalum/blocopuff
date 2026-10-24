--!strict

-- Moedas do Barão no Assassinato no Casarão (Fase 5E): espalhadas pela Ala,
-- dão aos Inocentes um motivo para andar em vez de ficar parados num canto.
-- Quem passa perto pega (conferido no servidor pela distância), até o
-- limite por rodada (o saco do Assassinato, Fase 5E).
--
-- Metade cai no miolo dos cômodos; a outra metade atrás das coberturas e
-- junto das portas (WingLayout.coinSpots), onde pegar é um risco. Cada
-- moeda é de ouro (metal, sem Neon) em pé, com um miolo em relevo e um
-- brilho discreto de partículas para ser achada sem estourar a luz.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local MurderRules = require(script.Parent.Parent.data.MurderRules)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local MurderMansionBuilder = require(script.Parent.MurderMansionBuilder)

type Combatant = CombatantRegistry.Combatant
type WingLayout = MurderMansionBuilder.WingLayout

-- Quem pode pegar agora e o que acontece ao pegar (devolve se aceitou).
export type Collector = {
	eligible: () -> { Combatant },
	collect: (combatant: Combatant) -> boolean,
}

local COIN_COLOR = Color3.fromRGB(232, 180, 64)
local EMBLEM_COLOR = Color3.fromRGB(196, 140, 40)
local COIN_DIAMETER = 1.6
local COIN_THICKNESS = 0.3
local EMBLEM_DIAMETER = 1.05
-- Centro da moeda acima do chão.
local COIN_HEIGHT = 1.4
-- Fração das moedas nos pontos de risco (atrás das coberturas, portas).
local RISKY_SHARE = 0.5
-- Espalha um pouco cada moeda em volta do ponto de risco.
local SPOT_JITTER = 1
local CHECK_INTERVAL = 0.15
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local MysteryCoins = {}

local random = Random.new()
local coins: { Part } = {}
local connection: RBXScriptConnection? = nil

local function disk(name: string, diameter: number, thickness: number, color: Color3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, diameter, diameter)
	part.Color = color
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = cframe
	return part
end

local function sparkle(parent: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 140))
	emitter.LightEmission = 0.5
	emitter.Rate = 1.5
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(0.3, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = parent
end

local function spawnCoin(layout: WingLayout, at: Vector3): Part
	-- Em pé (o eixo do cilindro é o X da peça), virada para um lado qualquer.
	local cframe = CFrame.new(at + Vector3.new(0, COIN_HEIGHT, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	local coin = disk("BaronCoin", COIN_DIAMETER, COIN_THICKNESS, COIN_COLOR, cframe)
	disk("Emblem", EMBLEM_DIAMETER, COIN_THICKNESS + 0.06, EMBLEM_COLOR, cframe).Parent = coin
	sparkle(coin)
	coin.Parent = layout.folder
	return coin
end

-- Onde cai cada moeda da rodada: parte nos pontos de risco (sem repetir),
-- o resto no miolo dos cômodos.
local function coinPositions(layout: WingLayout, count: number): { Vector3 }
	local pool = table.clone(layout.coinSpots)
	local positions: { Vector3 } = {}
	local risky = math.min(#pool, math.floor(count * RISKY_SHARE))
	for _ = 1, risky do
		local spot = table.remove(pool, random:NextInteger(1, #pool)) :: Vector3
		local jitter = Vector3.new(random:NextNumber(-SPOT_JITTER, SPOT_JITTER), 0, random:NextNumber(-SPOT_JITTER, SPOT_JITTER))
		table.insert(positions, spot + jitter)
	end
	for _ = risky + 1, count do
		table.insert(positions, layout.randomPoint(random))
	end
	return positions
end

function MysteryCoins.start(layout: WingLayout, collector: Collector)
	MysteryCoins.stop()
	for _, position in ipairs(coinPositions(layout, MysteryModeConfig.CoinsPerRound)) do
		table.insert(coins, spawnCoin(layout, position))
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < CHECK_INTERVAL then
			return
		end
		elapsed = 0
		local radius = MysteryModeConfig.CoinPickupRadius
		local candidates = collector.eligible()
		for index = #coins, 1, -1 do
			local coin = coins[index]
			for _, combatant in ipairs(candidates) do
				local root = CombatantRegistry.getRoot(combatant)
				if root ~= nil and (root.Position - coin.Position).Magnitude <= radius and collector.collect(combatant) then
					coin:Destroy()
					table.remove(coins, index)
					break
				end
			end
		end
	end)
end

function MysteryCoins.stop()
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	for _, coin in ipairs(coins) do
		coin:Destroy()
	end
	table.clear(coins)
end

-- Moedas viram tickets (com teto) para os humanos que terminaram a partida.
function MysteryCoins.pay(order: { Combatant }, collected: { [Combatant]: number })
	for _, combatant in ipairs(order) do
		local player = combatant.player
		local tickets = MurderRules.coinTickets(collected[combatant] or 0, MysteryModeConfig.CoinsPerTicket, MysteryModeConfig.MaxCoinTickets)
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

return table.freeze(MysteryCoins)
