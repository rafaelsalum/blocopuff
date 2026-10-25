--!strict

-- Cartas do Barão no Assassinato no Casarão (Fase 5E; eram moedas até a
-- 5I): espalhadas pela Ala, dão aos Inocentes um motivo para andar em vez
-- de ficar parados num canto. Quem passa perto pega (conferido no servidor
-- pela distância), até o limite por rodada (o saco do Assassinato). Os nomes
-- internos (módulo, atributo, config e telemetria) seguem "coins".
--
-- Metade cai no miolo dos cômodos; a outra metade atrás das coberturas e
-- junto das portas (WingLayout.coinSpots), onde pegar é um risco. Cada
-- carta é um envelope lacrado (BaronLetterModel) que flutua no cliente.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local MurderRules = require(script.Parent.Parent.data.MurderRules)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local CombatantRegistry = require(script.Parent.CombatantRegistry)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local MurderMansionBuilder = require(script.Parent.MurderMansionBuilder)
local BaronLetterModel = require(script.Parent.BaronLetterModel)

type Combatant = CombatantRegistry.Combatant
type WingLayout = MurderMansionBuilder.WingLayout

-- Quem pode pegar agora e o que acontece ao pegar (devolve se aceitou).
export type Collector = {
	eligible: () -> { Combatant },
	collect: (combatant: Combatant) -> boolean,
}

-- Centro da carta acima do chão (o cliente faz ela subir e descer).
local LETTER_HEIGHT = 2.1
-- Inclinação da carta para trás (graus), como se apoiada no ar.
local LETTER_TILT = 12
-- Fração das cartas nos pontos de risco (atrás das coberturas, portas).
local RISKY_SHARE = 0.5
-- Espalha um pouco cada carta em volta do ponto de risco.
local SPOT_JITTER = 1
local CHECK_INTERVAL = 0.15

local MysteryCoins = {}

local random = Random.new()
local coins: { Model } = {}
local connection: RBXScriptConnection? = nil

local function spawnLetter(layout: WingLayout, at: Vector3): Model
	-- Virada para um lado qualquer, um pouco inclinada.
	local cframe = CFrame.new(at + Vector3.new(0, LETTER_HEIGHT, 0))
		* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		* CFrame.Angles(math.rad(-LETTER_TILT), 0, 0)
	return BaronLetterModel.create(cframe, layout.folder)
end

-- Onde cai cada carta da rodada: parte nos pontos de risco (sem repetir),
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
		table.insert(coins, spawnLetter(layout, position))
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
				if root ~= nil and (root.Position - coin:GetPivot().Position).Magnitude <= radius and collector.collect(combatant) then
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

-- Cartas viram tickets (com teto) para os humanos que terminaram a partida.
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
