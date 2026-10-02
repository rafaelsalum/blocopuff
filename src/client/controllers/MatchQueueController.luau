--!strict

-- Fila da partida no cliente. Quem está na fila é decidido no servidor
-- (MatchQueueService, atributo "InMatchQueue"); aqui só o retorno:
--   * aviso ao entrar ("✅ Você está na fila!") e ao sair do mirante;
--   * aviso quando o embarque fecha e bipes no "3, 2, 1" da contagem;
--   * botão JOGAR do HUD (pede ao servidor para ir ao mirante);
--   * "sozinho na fila" vira uma faixa sugerindo chamar amigos;
--   * impulso dos trampolins do aquecimento (tag "PuffTrampoline"): a
--     física do personagem é do cliente, então o impulso é aplicado aqui.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local QueueConfig = require(ReplicatedStorage.Shared.config.QueueConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local RoundTypes = require(ReplicatedStorage.Shared.types.RoundTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local WAIT_TIMEOUT = 15
local TRAMPOLINE_TAG = "PuffTrampoline"
local JOIN_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local BEEP_SOUND = "rbxasset://sounds/button.wav"
local FINAL_BEEPS = 3

type Priority = NotificationManager.Priority
type Tone = NotificationManager.Tone

local MatchQueueController = {}

local started = false
local remote: RemoteEvent? = nil
local lastBounce = 0

local function banner(key: string, icon: string, title: string, subtitle: string, tone: Tone, priority: Priority, duration: number)
	NotificationManager.notify({
		channel = "Banner",
		category = "Queue",
		priority = priority,
		key = key,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = tone,
		duration = duration,
		maxWait = 3,
	})
end

local function playSound(soundId: string, speed: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 3)
	sound:Play()
end

local function onMessage(kind: unknown)
	if kind == "Lonely" then
		banner("queue-lonely", "👥", "CHAME UM AMIGO", "A partida começa com 2 no mirante. Convide pela Party!", "Info", "Low", 5)
	elseif kind == "BotsArriving" then
		banner("queue-bots", "🤖", "ROBOPUFFS CHEGANDO!", "Eles completam a partida. Chame um amigo para jogar junto!", "Info", "Normal", 4)
	elseif kind == "GatesClosed" then
		banner("queue-closed", "🔒", "EMBARQUE ENCERRADO!", "Portas fechadas: a partida vai começar", "Gold", "High", 3)
	elseif kind == "BoardingClosed" then
		banner("queue-closed", "🔒", "EMBARQUE ENCERRADO", "Essa partida já vai começar. Entre na fila da próxima!", "Info", "Normal", 3)
	end
end

-- Entrar e sair do mirante. Quem está numa partida (inclusive eliminado)
-- não recebe esses avisos: a entrada e a saída da fila ali são automáticas.
local function watchQueue(player: Player)
	local wasQueued = player:GetAttribute(StateAttributeNames.PlayerInMatchQueue) == true
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerInMatchQueue):Connect(function()
		local queued = player:GetAttribute(StateAttributeNames.PlayerInMatchQueue) == true
		if queued == wasQueued then
			return
		end
		wasQueued = queued
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			return
		end
		if queued then
			playSound(JOIN_SOUND, 1.5, 0.6)
			banner("queue-state", "✅", "VOCÊ ESTÁ NA FILA!", "Fique no mirante. Para sair, é só voltar pela porta", "Gold", "Normal", 3)
		else
			banner("queue-state", "🚪", "VOCÊ SAIU DA FILA", "Volte ao mirante quando quiser jogar", "Info", "Normal", 2.5)
		end
	end)
end

-- Bipes no "3, 2, 1" para quem está na fila.
local function watchCountdown(player: Player)
	task.spawn(function()
		local container = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, WAIT_TIMEOUT)
		if container == nil then
			return
		end
		container:GetAttributeChangedSignal(StateAttributeNames.TimeRemaining):Connect(function()
			if container:GetAttribute(StateAttributeNames.RoundState) ~= RoundTypes.Countdown then
				return
			end
			if player:GetAttribute(StateAttributeNames.PlayerInMatchQueue) ~= true then
				return
			end
			local remaining = container:GetAttribute(StateAttributeNames.TimeRemaining)
			if typeof(remaining) == "number" and remaining >= 1 and remaining <= FINAL_BEEPS then
				playSound(BEEP_SOUND, 1 + (FINAL_BEEPS - remaining) * 0.15, 0.7)
			end
		end)
	end)
end

local function connectTrampoline(player: Player, pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	pad.Touched:Connect(function(hit: BasePart)
		local character = player.Character
		if character == nil or not hit:IsDescendantOf(character) then
			return
		end
		local clock = os.clock()
		if clock - lastBounce < QueueConfig.TrampolineCooldown then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return
		end
		lastBounce = clock
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, QueueConfig.TrampolineVelocity, velocity.Z)
		playSound(JOIN_SOUND, 0.8, 0.4)
	end)
end

-- Botão JOGAR: o servidor valida (fora da partida, vivo, embarque aberto)
-- e leva ao mirante.
function MatchQueueController.join()
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireServer("Join")
	end
end

function MatchQueueController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if playerGui ~= nil and playerGui:IsA("PlayerGui") then
		NotificationManager.init(playerGui)
	end
	watchQueue(player)
	watchCountdown(player)
	for _, pad in ipairs(CollectionService:GetTagged(TRAMPOLINE_TAG)) do
		connectTrampoline(player, pad)
	end
	CollectionService:GetInstanceAddedSignal(TRAMPOLINE_TAG):Connect(function(pad: Instance)
		connectTrampoline(player, pad)
	end)
	-- Espera o remote sem travar o início dos outros controllers.
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.MatchQueueRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Match queue remote not found")
			return
		end
		remote = instance
		instance.OnClientEvent:Connect(onMessage)
	end)
end

return table.freeze(MatchQueueController)
