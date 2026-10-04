--!strict

-- Fila da partida no cliente. Quem está na fila é decidido no servidor
-- (MatchQueueService, atributo "InMatchQueue"); aqui só o retorno:
--   * avisos da Ficha da Partida (Fase 5C.1): ao entrar na fila, ao sair do
--     mirante com a ficha, quando ela volta por ficar parado e o chamado
--     com sino faltando 15 s para quem está passeando;
--   * aviso quando o embarque fecha e bipes no "3, 2, 1" da contagem;
--   * botões JOGAR e SAIR DA FILA do HUD (pedem a ficha / devolvem);
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
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local T = Lang.t

local WAIT_TIMEOUT = 15
local TRAMPOLINE_TAG = "PuffTrampoline"
local JOIN_SOUND = "rbxassetid://103516326607012"
local BEEP_SOUND = "rbxassetid://117751546358455"
local TRAMPOLINE_SOUND = "rbxassetid://127855700916139"
local FINAL_BEEPS = 3
local BELL_SOUND = "rbxassetid://9113421646"
-- O "saiu da fila" logo depois de a ficha expirar já foi dito.
local EXPIRED_QUIET = 2

type QueueStatus = "Out" | "Mirante" | "Ticket" | "Party"

type Priority = NotificationManager.Priority
type Tone = NotificationManager.Tone

local MatchQueueController = {}

local started = false
local remote: RemoteEvent? = nil
local lastBounce = 0
local lastExpired = -math.huge

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

-- Sino do chamado.
local function ringBell()
	playSound(BELL_SOUND, 1, 0.9)
end

local function onMessage(kind: unknown, value: unknown)
	if kind == "TicketCall" then
		local seconds = if typeof(value) == "number" then math.max(1, math.floor(value)) else QueueConfig.TicketCallSeconds
		ringBell()
		banner("queue-call", "⚔️", T("SUA PARTIDA COMEÇA EM %d s!", seconds), T("Você vai para a arena sozinho, pode continuar onde está"), "Gold", "High", 4)
	elseif kind == "TicketExpired" then
		lastExpired = os.clock()
		banner("queue-state", "💤", T("SUA FICHA VOLTOU"), T("Você ficou parado muito tempo. Aperte JOGAR para voltar à fila"), "Info", "Normal", 4)
	elseif kind == "StillInParty" then
		banner("queue-state", "👥", T("SUA PARTY AINDA ESTÁ NA FILA"), T("Você joga junto com ela. Para sair, saia da Party"), "Info", "Normal", 4)
	elseif kind == "Lonely" then
		banner("queue-lonely", "👥", T("CHAME UM AMIGO"), T("A partida começa com 2 na fila. Convide pela Party!"), "Info", "Low", 5)
	elseif kind == "BotsArriving" then
		banner("queue-bots", "🤖", T("ROBOPUFFS CHEGANDO!"), T("Eles completam a partida. Chame um amigo para jogar junto!"), "Info", "Normal", 4)
	elseif kind == "GatesClosed" then
		banner("queue-closed", "🔒", T("EMBARQUE ENCERRADO!"), T("Portas fechadas: a partida vai começar"), "Gold", "High", 3)
	elseif kind == "BoardingClosed" then
		banner("queue-closed", "🔒", T("EMBARQUE ENCERRADO"), T("Essa partida já vai começar. Entre na fila da próxima!"), "Info", "Normal", 3)
	end
end

local function readStatus(player: Player): QueueStatus
	if player:GetAttribute(StateAttributeNames.PlayerInMatchQueue) ~= true then
		return "Out"
	end
	local place = player:GetAttribute(StateAttributeNames.PlayerQueuePlace)
	if place == "Ticket" or place == "Party" then
		return place
	end
	return "Mirante"
end

local function announce(previous: QueueStatus, status: QueueStatus)
	local seconds = QueueConfig.TicketCallSeconds
	if status == "Out" then
		if os.clock() - lastExpired > EXPIRED_QUIET then
			banner("queue-state", "🚪", T("VOCÊ SAIU DA FILA"), T("Aperte JOGAR quando quiser jogar"), "Info", "Normal", 2.5)
		end
	elseif previous == "Out" then
		playSound(JOIN_SOUND, 1, 0.6)
		if status == "Ticket" then
			banner("queue-state", "🎟", T("VOCÊ PEGOU A FICHA!"), T("Explore o Casarão: avisamos %d s antes da partida", seconds), "Gold", "Normal", 4)
		elseif status == "Party" then
			banner("queue-state", "👥", T("NA FILA COM A PARTY!"), T("Sua Party guardou a vaga. Explore à vontade"), "Gold", "Normal", 4)
		else
			banner("queue-state", "✅", T("VOCÊ ESTÁ NA FILA!"), T("Pode explorar o Casarão: a ficha guarda sua vaga"), "Gold", "Normal", 4)
		end
	elseif previous == "Mirante" and status == "Ticket" then
		banner("queue-state", "🎟", T("FICHA GUARDADA"), T("Explore à vontade: avisamos %d s antes da partida", seconds), "Info", "Normal", 3)
	end
end

-- Entrar e sair da fila. Quem está numa partida (inclusive eliminado) não
-- recebe esses avisos: a entrada e a saída da fila ali são automáticas. Os
-- dois atributos mudam juntos; a leitura fica para o fim do quadro.
local function watchQueue(player: Player)
	local previous = readStatus(player)
	local pending = false
	local function evaluate()
		pending = false
		local status = readStatus(player)
		if status == previous then
			return
		end
		local before = previous
		previous = status
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			return
		end
		announce(before, status)
	end
	local function schedule()
		if not pending then
			pending = true
			task.defer(evaluate)
		end
	end
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerInMatchQueue):Connect(schedule)
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerQueuePlace):Connect(schedule)
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
		playSound(TRAMPOLINE_SOUND, 1, 0.4)
	end)
end

-- Botão JOGAR: o servidor valida (fora da partida, vivo, embarque aberto)
-- e entrega a Ficha da Partida ali mesmo.
function MatchQueueController.join()
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireServer("Join")
	end
end

-- Botão SAIR DA FILA: devolve a ficha.
function MatchQueueController.leave()
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireServer("Leave")
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
