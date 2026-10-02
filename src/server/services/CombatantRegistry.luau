--!strict

-- Identidade de quem disputa a rodada (Fase 5B): um jogador ou um bot
-- RoboPuff. Os serviços da partida (rodada, empurrão, projéteis, queda,
-- armadilhas, resultado) indexam e conversam por `Combatant`, sem saber se
-- do outro lado há um Player. O que só existe para humanos (perfil,
-- telemetria, remotes) usa `combatant.player`.
--
-- O estado da rodada (StateAttributeNames.Player*) fica no Player, onde o
-- cliente já o lê; no bot, fica no Model do corpo.

local Players = game:GetService("Players")

export type Combatant = {
	-- UserId do jogador; negativo para bot (nunca 0: 0 é "ninguém" no
	-- resultado e nos atributos).
	id: number,
	-- Nome de exibição (DisplayName no jogador).
	name: string,
	-- nil para bot.
	player: Player?,
	-- Corpo do bot; nil para jogador (o corpo dele é player.Character).
	model: Model?,
}

local CombatantRegistry = {}

-- Uma identidade estável por jogador enquanto ele estiver no servidor. Ao
-- sair, a entrada é apagada depois que os outros serviços trataram a saída
-- (eles ainda procuram o Combatant dele no PlayerRemoving).
local byPlayer: { [Player]: Combatant } = {}
Players.PlayerRemoving:Connect(function(player: Player)
	task.defer(function()
		byPlayer[player] = nil
	end)
end)
local bots: { [number]: Combatant } = {}
local botByModel: { [Model]: Combatant } = {}

function CombatantRegistry.forPlayer(player: Player): Combatant
	local existing = byPlayer[player]
	if existing ~= nil then
		return existing
	end
	local combatant: Combatant = {
		id = player.UserId,
		name = player.DisplayName,
		player = player,
		model = nil,
	}
	byPlayer[player] = combatant
	return combatant
end

function CombatantRegistry.forPlayers(players: { Player }): { Combatant }
	local list: { Combatant } = {}
	for _, player in ipairs(players) do
		table.insert(list, CombatantRegistry.forPlayer(player))
	end
	return list
end

-- Registra o corpo de um bot. `id` precisa ser negativo e único.
function CombatantRegistry.registerBot(id: number, name: string, model: Model): Combatant
	assert(id < 0, "bot ids must be negative")
	assert(bots[id] == nil, "bot id already registered")
	local combatant: Combatant = {
		id = id,
		name = name,
		player = nil,
		model = model,
	}
	bots[id] = combatant
	botByModel[model] = combatant
	return combatant
end

function CombatantRegistry.unregisterBot(combatant: Combatant)
	local model = combatant.model
	if model ~= nil then
		botByModel[model] = nil
	end
	bots[combatant.id] = nil
end

function CombatantRegistry.isBot(combatant: Combatant): boolean
	return combatant.player == nil
end

-- Bots registrados agora.
function CombatantRegistry.getBots(): { Combatant }
	local list: { Combatant } = {}
	for _, combatant in pairs(bots) do
		table.insert(list, combatant)
	end
	table.sort(list, function(a, b)
		return a.id > b.id
	end)
	return list
end

-- Todos os jogadores no servidor e todos os bots registrados (quem filtra
-- os participantes da rodada é quem chama).
function CombatantRegistry.all(): { Combatant }
	local list = CombatantRegistry.forPlayers(Players:GetPlayers())
	for _, bot in ipairs(CombatantRegistry.getBots()) do
		table.insert(list, bot)
	end
	return list
end

-- Quem é o dono deste corpo (jogador ou bot), se for de alguém.
function CombatantRegistry.fromCharacter(model: Model): Combatant?
	local player = Players:GetPlayerFromCharacter(model)
	if player ~= nil then
		return CombatantRegistry.forPlayer(player)
	end
	return botByModel[model]
end

-- Jogador ainda no servidor ou bot ainda registrado.
function CombatantRegistry.isPresent(combatant: Combatant): boolean
	local player = combatant.player
	if player ~= nil then
		return player.Parent ~= nil
	end
	local model = combatant.model
	return model ~= nil and model.Parent ~= nil and bots[combatant.id] == combatant
end

function CombatantRegistry.getCharacter(combatant: Combatant): Model?
	local player = combatant.player
	if player ~= nil then
		return player.Character
	end
	return combatant.model
end

function CombatantRegistry.getRoot(combatant: Combatant): BasePart?
	local character = CombatantRegistry.getCharacter(combatant)
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

function CombatantRegistry.getHumanoid(combatant: Combatant): Humanoid?
	local character = CombatantRegistry.getCharacter(combatant)
	return if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Onde ficam os atributos de estado da rodada deste combatente.
local function attributeHolder(combatant: Combatant): Instance?
	return combatant.player or combatant.model
end

function CombatantRegistry.getAttribute(combatant: Combatant, name: string): any
	local holder = attributeHolder(combatant)
	return if holder ~= nil then holder:GetAttribute(name) else nil
end

function CombatantRegistry.setAttribute(combatant: Combatant, name: string, value: any)
	local holder = attributeHolder(combatant)
	if holder ~= nil then
		holder:SetAttribute(name, value)
	end
end

-- Contador inteiro não negativo guardado em atributo (0 se ausente).
function CombatantRegistry.readCount(combatant: Combatant, name: string): number
	local value = CombatantRegistry.getAttribute(combatant, name)
	return if typeof(value) == "number" then math.max(0, math.floor(value)) else 0
end

-- Jogadores reais de uma lista de combatentes (perfil, telemetria, remotes).
function CombatantRegistry.playersOf(combatants: { Combatant }): { Player }
	local list: { Player } = {}
	for _, combatant in ipairs(combatants) do
		local player = combatant.player
		if player ~= nil then
			table.insert(list, player)
		end
	end
	return list
end

return table.freeze(CombatantRegistry)
