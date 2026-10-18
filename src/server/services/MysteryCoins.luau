--!strict

-- Moedas do Barão no Assassinato no Casarão (Fase 5E): espalhadas pela Ala,
-- dão aos Inocentes um motivo para andar em vez de ficar parados num canto.
-- Quem passa perto pega (conferido no servidor pela distância), até o
-- limite por rodada (o saco do Assassinato, Fase 5E).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local MysteryWingBuilder = require(script.Parent.MysteryWingBuilder)

type Combatant = CombatantRegistry.Combatant
type WingLayout = MysteryWingBuilder.WingLayout

-- Quem pode pegar agora e o que acontece ao pegar (devolve se aceitou).
export type Collector = {
	eligible: () -> { Combatant },
	collect: (combatant: Combatant) -> boolean,
}

local COIN_COLOR = Color3.fromRGB(255, 200, 60)
local COIN_HEIGHT = 2
local CHECK_INTERVAL = 0.15
local SPIN_SPEED = 2

local MysteryCoins = {}

local random = Random.new()
local coins: { Part } = {}
local connection: RBXScriptConnection? = nil

local function spawnCoin(layout: WingLayout): Part
	local coin = Instance.new("Part")
	coin.Name = "BaronCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2, 2)
	coin.Color = COIN_COLOR
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin.CFrame = CFrame.new(layout.randomPoint(random) + Vector3.new(0, COIN_HEIGHT, 0))
	coin.Parent = layout.folder
	return coin
end

function MysteryCoins.start(layout: WingLayout, collector: Collector)
	MysteryCoins.stop()
	for _ = 1, MysteryModeConfig.CoinsPerRound do
		table.insert(coins, spawnCoin(layout))
	end
	local elapsed = 0
	local angle = 0
	connection = RunService.Heartbeat:Connect(function(dt: number)
		angle += dt * SPIN_SPEED
		elapsed += dt
		if elapsed < CHECK_INTERVAL then
			return
		end
		elapsed = 0
		local radius = MysteryModeConfig.CoinPickupRadius
		local candidates = collector.eligible()
		for index = #coins, 1, -1 do
			local coin = coins[index]
			coin.CFrame = CFrame.new(coin.Position) * CFrame.Angles(0, angle, 0)
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

return table.freeze(MysteryCoins)
