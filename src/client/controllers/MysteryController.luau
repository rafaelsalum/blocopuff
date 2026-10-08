--!strict

-- Mistérios do Barão do cliente (Fase 5C.3, parte 2): os prompts do
-- cenário (atributo MysteryConfig.PromptAttribute) abrem a tela do
-- quebra-cabeça, a tentativa vai ao servidor e a resposta comemora (ou
-- avisa que errou). Para quem já resolveu, o cenário muda só na tela dele:
-- velas acesas, cofrinho aberto e o relógio da torre na hora certa, e o
-- prompt daquele mistério some (`MysteryPrompts`), para não convidar a
-- resolver de novo.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local MysteryConfig = require(ReplicatedStorage.Shared.config.MysteryConfig)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local MysteryPrompts = require(ReplicatedStorage.Shared.modules.MysteryPrompts)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local MysteryView = require(script.Parent.Parent.ui.MysteryView)
local ProfileController = require(script.Parent.ProfileController)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot

local WAIT_TIMEOUT = 15
local SOLVED_SOUND = "rbxassetid://138190748214493"
local ALL_SOUND = "rbxassetid://84872960927850"
local FOLDER_NAME = "Mysteries"
local REAPPLY_SECONDS = 3
-- Pêndulo do relógio resolvido: balanço (graus) e tempo de ida e volta.
local SWING_DEGREES = 9
local SWING_PERIOD = 2
local TICK_VOLUME = 0.35

local MysteryController = {}

local started = false
local view: MysteryView.MysteryViewHandle? = nil
local remote: RemoteEvent? = nil
local solved: { [string]: boolean } = {}
local applied: { [string]: boolean } = {}
local swing: RBXScriptConnection? = nil
local swingTarget: Instance? = nil

local function playSound(soundId: string)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.8
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local cachedFolder: Instance? = nil
local function mysteriesFolder(): Instance?
	local folder = cachedFolder
	if folder ~= nil and folder.Parent ~= nil then
		return folder
	end
	local world = Workspace:FindFirstChild("BlocoPuffWorld")
	local mansion = if world ~= nil then world:FindFirstChild("Mansion") else nil
	cachedFolder = if mansion ~= nil then mansion:FindFirstChild(FOLDER_NAME) else nil
	return cachedFolder
end

-- Cores das velas, da esquerda para a direita (do cenário).
local function candleColors(): { number }
	local colors: { number } = {}
	local folder = mysteriesFolder()
	if folder == nil then
		return colors
	end
	for index = 1, #MysteryConfig.CandleColors do
		local model = folder:FindFirstChild(`MysteryCandle{index}`)
		local color = if model ~= nil then model:GetAttribute("CandleColor") else nil
		if typeof(color) ~= "number" or MysteryConfig.CandleColors[color] == nil then
			return {}
		end
		table.insert(colors, color)
	end
	return colors
end

-- Acende as chamas de um candelabro: a chama ("FlameTip", ou a própria
-- "Flame" no cenário simples), o fogo e a luz.
local function lightCandles(model: Instance)
	for _, flame in ipairs(model:GetDescendants()) do
		if flame:IsA("BasePart") and flame.Name == "Flame" then
			local tip = flame:FindFirstChild("FlameTip")
			if tip ~= nil and tip:IsA("BasePart") then
				tip.Transparency = 0
			else
				flame.Transparency = 0
			end
			for _, effect in ipairs(flame:GetChildren()) do
				if effect:IsA("ParticleEmitter") or effect:IsA("Light") then
					effect.Enabled = true
				end
			end
		end
	end
end

-- Abre a porta do cofre pela dobradiça e mostra o dinheiro.
local function openSafe(safe: Instance)
	local door = safe:FindFirstChild("Door", true)
	local closed = if door ~= nil then door:GetAttribute("ClosedCFrame") else nil
	local hinge = if door ~= nil then door:GetAttribute("HingeCFrame") else nil
	local angle = if door ~= nil then door:GetAttribute("OpenAngle") else nil
	if door ~= nil and door:IsA("BasePart") and typeof(closed) == "CFrame" and typeof(hinge) == "CFrame" and typeof(angle) == "number" then
		door.CFrame = hinge * CFrame.Angles(0, math.rad(angle), 0) * hinge:ToObjectSpace(closed)
	end
	local coins = safe:FindFirstChild("Coins", true)
	if coins ~= nil and coins:IsA("BasePart") then
		coins.Transparency = 0
	elseif coins ~= nil then
		for _, note in ipairs(coins:GetDescendants()) do
			if note:IsA("BasePart") then
				note.Transparency = 0
			end
		end
	end
end

-- Pêndulo balançando e tique-taque (só neste cliente).
local function startSwing(clock: Instance)
	local frame = clock:GetAttribute("SwingFrame")
	local pendulum = clock:FindFirstChild("Pendulum", true)
	local rest = if pendulum ~= nil then pendulum:GetAttribute("RestOffset") else nil
	if typeof(frame) ~= "CFrame" or pendulum == nil or not pendulum:IsA("BasePart") or typeof(rest) ~= "CFrame" then
		return
	end
	-- Já balançando este pêndulo (a reaplicação a cada 3s não recomeça).
	if swing ~= nil and swingTarget == pendulum then
		return
	end
	swingTarget = pendulum
	local current = swing
	if current ~= nil then
		current:Disconnect()
	end
	swing = RunService.Heartbeat:Connect(function()
		if pendulum.Parent == nil then
			local connection = swing
			if connection ~= nil then
				connection:Disconnect()
				swing = nil
				swingTarget = nil
			end
			return
		end
		local angle = math.sin(os.clock() * 2 * math.pi / SWING_PERIOD) * math.rad(SWING_DEGREES)
		pendulum.CFrame = frame * CFrame.Angles(0, 0, angle) * rest
	end)
	local tick = clock:FindFirstChild("TickSound", true)
	if tick ~= nil and tick:IsA("Sound") and not tick.IsPlaying then
		tick.Looped = true
		tick.Volume = TICK_VOLUME
		tick:Play()
	end
end

-- Acerta o relógio da torre na hora do quadro do Salão: ponteiros 3D (o
-- relógio de pêndulo) ou o mostrador desenhado (cenário simples).
local function setTowerClock(folder: Instance): boolean
	local painting = folder:FindFirstChild("MysteryClockPainting")
	local clock = folder:FindFirstChild("MysteryTowerClock")
	local paintingFace = if painting ~= nil then painting:FindFirstChild("ClockFace", true) else nil
	if paintingFace == nil or clock == nil then
		return false
	end
	local handFrame = clock:GetAttribute("HandFrame")
	for _, name in ipairs({ "HourHand", "MinuteHand" }) do
		local from = paintingFace:FindFirstChild(name)
		local to = clock:FindFirstChild(name, true)
		if from ~= nil and from:IsA("GuiObject") and to ~= nil then
			local rest = to:GetAttribute("RestOffset")
			if to:IsA("BasePart") and typeof(handFrame) == "CFrame" and typeof(rest) == "CFrame" then
				to.CFrame = handFrame * CFrame.Angles(0, 0, math.rad(from.Rotation)) * rest
			elseif to:IsA("GuiObject") then
				to.Rotation = from.Rotation
			end
		end
	end
	startSwing(clock)
	return true
end

-- Desliga, só para este jogador, os prompts de um mistério resolvido.
local function hideSolvedPrompts(folder: Instance, id: string)
	if not MysteryPrompts.hidesWhenSolved(id) then
		return
	end
	for _, prompt in ipairs(folder:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and prompt:GetAttribute(MysteryConfig.PromptAttribute) == id then
			prompt.Enabled = false
		end
	end
end

-- Muda o cenário (só para este jogador) de um mistério resolvido.
local function applySolved(id: string)
	local folder = mysteriesFolder()
	if folder == nil or applied[id] then
		return
	end
	hideSolvedPrompts(folder, id)
	if id == "Candles" then
		for index = 1, #MysteryConfig.CandleColors do
			local model = folder:FindFirstChild(`MysteryCandle{index}`)
			if model ~= nil then
				lightCandles(model)
			end
		end
	elseif id == "Safe" then
		local safe = folder:FindFirstChild("MysterySafe")
		if safe ~= nil then
			openSafe(safe)
		end
	elseif id == "Clock" then
		if not setTowerClock(folder) then
			return
		end
	end
	applied[id] = true
end

local function notify(key: string, icon: string, title: string, subtitle: string, priority: NotificationManager.Priority)
	NotificationManager.notify({
		channel = "Banner",
		category = "Progression",
		priority = priority,
		key = key,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = "Gold",
		duration = 4,
		maxWait = 30,
	})
end

local function onSolved(id: unknown, tickets: unknown, all: unknown)
	local info = if typeof(id) == "string" then (MysteryConfig.Info :: any)[id] else nil
	if info == nil then
		return
	end
	local mysteryId = id :: string
	solved[mysteryId] = true
	local current = view
	if current ~= nil then
		current.close()
	end
	local amount = if typeof(tickets) == "number" then math.clamp(math.floor(tickets), 0, 99) else MysteryConfig.Tickets
	notify(`mystery-{mysteryId}`, info.icon, Lang.t("MISTÉRIO RESOLVIDO!"), Lang.t("%s · +%d 🎟", Lang.t(info.name), amount), "High")
	if all == true then
		notify("mystery-all", "🏅", Lang.t("TODOS OS MISTÉRIOS!"), Lang.t("Título: %s", Lang.t(MysteryConfig.AllTitle)), "High")
	end
	playSound(if all == true then ALL_SOUND else SOLVED_SOUND)
	applySolved(mysteryId)
end

local function onProfile(snapshot: ProfileSnapshot)
	for _, id in ipairs(snapshot.mysteries) do
		solved[id] = true
		applySolved(id)
	end
end

local function isCompeting(player: Player): boolean
	return player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
end

function MysteryController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		warn("[BlocoPuff] Mystery controller not started: PlayerGui unavailable")
		return
	end
	NotificationManager.init(playerGui)
	local newView = MysteryView.new(playerGui, function(id: string, answer: { number })
		local currentRemote = remote
		if currentRemote ~= nil then
			currentRemote:FireServer("Solve", id, answer)
		end
	end)
	view = newView

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeredBy: Player)
		local id = prompt:GetAttribute(MysteryConfig.PromptAttribute)
		if triggeredBy ~= player or typeof(id) ~= "string" or isCompeting(player) then
			return
		end
		if solved[id] and MysteryPrompts.hidesWhenSolved(id) then
			return
		end
		newView.open(id, solved[id] == true, if id == "Candles" then candleColors() else nil)
	end)
	-- Entrou na partida: fecha.
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		if isCompeting(player) then
			newView.close()
		end
	end)

	ProfileController.Changed:Connect(onProfile)
	local current = ProfileController.get()
	if current ~= nil then
		onProfile(current)
	end
	-- O cenário chega depois (o servidor monta) e pode sair e voltar com o
	-- streaming: reaplica o que já resolveu de tempos em tempos.
	task.spawn(function()
		while player.Parent ~= nil do
			task.wait(REAPPLY_SECONDS)
			if next(solved) ~= nil and mysteriesFolder() ~= nil then
				table.clear(applied)
				for id in pairs(solved) do
					applySolved(id)
				end
			end
		end
	end)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.MysteryRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Mystery controller: remote not found")
			return
		end
		remote = instance
		-- `value`: tickets ganhos ("Solved") ou segundos de trava ("Locked").
		instance.OnClientEvent:Connect(function(kind: unknown, id: unknown, value: unknown, all: unknown)
			if kind == "Solved" then
				onSolved(id, value, all)
			elseif kind == "Wrong" then
				newView.showWrong()
			elseif kind == "Locked" then
				newView.showLocked(if typeof(value) == "number" then value else MysteryConfig.WrongLockSeconds)
			end
		end)
	end)
end

return table.freeze(MysteryController)
