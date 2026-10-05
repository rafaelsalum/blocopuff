--!strict

-- Mistérios do Barão (Fase 5C.3, parte 2). Sorteia as respostas deste
-- servidor, monta o cenário com as pistas (MysteryProps) e confere as
-- tentativas. Remote "Mystery":
--   cliente → ("Solve", id, resposta): relógio { hora, minuto }, velas
--     { posições na ordem acesa }, cofrinho { d1, d2, d3 };
--   servidor → ("Solved", id, tickets, todos) ou ("Wrong", id).
-- O piano não tem tela: o servidor ouve as notas (PianoService) e resolve
-- quando as últimas notas de alguém são a música da Vovó.
-- Só no lobby, perto do lugar do mistério e com intervalo entre tentativas.
-- Cada mistério paga uma vez por jogador (perfil `mysteries`).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryConfig = require(ReplicatedStorage.Shared.config.MysteryConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local LobbyService = require(script.Parent.LobbyService)
local MysteryProps = require(script.Parent.MysteryProps)
local PianoService = require(script.Parent.PianoService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local MysteryRules = require(script.Parent.Parent.data.MysteryRules)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)

type Profile = ProfileSchema.Profile
type Answers = MysteryRules.Answers

local MELODY_MEMORY = 12

local MysteryService = {}

local started = false
local answers: Answers? = nil
local anchors: { [string]: Vector3 } = {}
local remote: RemoteEvent? = nil
local lastTry: { [Player]: number } = {}
local notes: { [Player]: { number } } = {}
local lastNote: { [Player]: number } = {}
-- Erros seguidos e trava por jogador e mistério.
type WrongState = { count: number, lockedUntil: number }
local wrongs: { [Player]: { [string]: WrongState } } = {}

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

local function isNear(player: Player, id: string): boolean
	local anchor = anchors[id]
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if anchor == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - anchor).Magnitude <= MysteryConfig.ServerDistance
end

local function grant(player: Player, id: string)
	local outcome: MysteryRules.Outcome? = nil
	local saved = false
	local before = 0
	local balance = 0
	PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, PlayerDataService.Events?)
		local solved, result = MysteryRules.solve(profile.mysteries, id, MysteryConfig.Ids, MysteryConfig.Tickets, MysteryConfig.AllTickets, os.time())
		if solved == nil or result == nil then
			return nil, nil
		end
		local updated = ProfileSchema.withTickets(profile, result.tickets)
		updated.mysteries = solved
		outcome = result
		saved = canSave
		before = profile.tickets
		balance = updated.tickets
		return updated, nil
	end, true)
	local result = outcome
	local currentRemote = remote
	if result == nil then
		return
	end
	-- Comemora mesmo sem perfil salvo (o jogador vê o que fez agora).
	if currentRemote ~= nil then
		currentRemote:FireClient(player, "Solved", id, balance - before, result.allSolved)
	end
	if saved then
		TelemetryService.lobbyEvent(player, "PuzzleSolved", result.solvedCount, id, if result.allSolved then "All" else nil)
		TelemetryService.ticketsEarned(player, before, balance, "Mystery")
	end
end

local function check(id: string, answer: unknown): boolean
	local current = answers
	if current == nil or typeof(answer) ~= "table" then
		return false
	end
	local data = answer :: { any }
	if id == "Clock" then
		return MysteryRules.checkClock(current, data[1], data[2])
	elseif id == "Candles" then
		return MysteryRules.checkCandles(current, data)
	elseif id == "Safe" then
		return MysteryRules.checkCode(current, data)
	end
	return false
end

local function onSolve(player: Player, id: unknown, answer: unknown)
	if typeof(id) ~= "string" or id == "Piano" or table.find(MysteryConfig.Ids, id :: any) == nil then
		return
	end
	local clock = os.clock()
	local last = lastTry[player]
	if last ~= nil and clock - last < MysteryConfig.SolveCooldown then
		return
	end
	lastTry[player] = clock
	if isCompeting(player) or not isNear(player, id) then
		return
	end
	local mysteryId = id :: string
	local byId = wrongs[player] or {}
	wrongs[player] = byId
	local state = byId[mysteryId] or { count = 0, lockedUntil = 0 }
	local currentRemote = remote
	if clock < state.lockedUntil then
		if currentRemote ~= nil then
			currentRemote:FireClient(player, "Locked", mysteryId, math.ceil(state.lockedUntil - clock))
		end
		return
	end
	if check(mysteryId, answer) then
		byId[mysteryId] = nil
		grant(player, mysteryId)
		return
	end
	local count = state.count + 1
	local lock = MysteryRules.wrongLock(count, MysteryConfig.WrongLimit, MysteryConfig.WrongLockSeconds)
	byId[mysteryId] = { count = count, lockedUntil = if lock > 0 then clock + lock else 0 }
	if currentRemote ~= nil then
		if lock > 0 then
			currentRemote:FireClient(player, "Locked", mysteryId, lock)
		else
			currentRemote:FireClient(player, "Wrong", mysteryId)
		end
	end
end

local function onNote(player: Player, semitone: number)
	local current = answers
	if current == nil or isCompeting(player) or not isNear(player, "Piano") then
		notes[player] = nil
		return
	end
	-- Pausa longa recomeça a música.
	local clock = os.clock()
	local previous = lastNote[player]
	lastNote[player] = clock
	local start = if previous ~= nil and clock - previous <= MysteryConfig.MelodyGap then notes[player] or {} else {}
	local history = MysteryRules.pushNote(start, semitone, MELODY_MEMORY)
	notes[player] = history
	if MysteryRules.melodyPlayed(current, history) then
		notes[player] = {}
		grant(player, "Piano")
	end
end

-- Semente do servidor (cada servidor tem as suas respostas).
local function serverSeed(): number
	local guid = HttpService:GenerateGUID(false)
	local value = os.time()
	for index = 1, #guid do
		value = (value * 31 + string.byte(guid, index)) % 2147483647
	end
	return value
end

-- `world`: o mundo com o Casarão (as pistas vão numa pasta dentro dele).
function MysteryService.start(world: Instance, remotesFolder: Folder)
	if started then
		return
	end
	started = true
	local generated = MysteryRules.generate(serverSeed(), {
		colorCount = #MysteryConfig.CandleColors,
		whiteKeys = MysteryConfig.WhiteKeys,
		melodyLength = MysteryConfig.MelodyLength,
		minuteStep = MysteryConfig.MinuteStep,
	})
	answers = generated

	local folder = Instance.new("Folder")
	folder.Name = "Mysteries"
	local mansionRoot = world:FindFirstChild("Mansion") or world
	local built = MysteryProps.build(folder, mansionRoot, generated)
	anchors = built.anchors
	LobbyService.addReservedAreas(built.reserved)
	folder.Parent = mansionRoot

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = PuffadorConstants.MysteryRemoteName
	newRemote.Parent = remotesFolder
	remote = newRemote
	newRemote.OnServerEvent:Connect(function(player: Player, action: unknown, id: unknown, answer: unknown)
		if action == "Solve" then
			onSolve(player, id, answer)
		end
	end)
	PianoService.onNote(onNote)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTry[player] = nil
		notes[player] = nil
		lastNote[player] = nil
		wrongs[player] = nil
	end)
end

return table.freeze(MysteryService)
