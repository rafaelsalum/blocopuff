--!strict

-- Puff Machine do cliente (Fase 4.2): abre o painel pelo botão 🎰 do cartão
-- de perfil, pede o giro ao servidor e mostra a revelação com a resposta.
-- Saldo e coleção vêm do perfil (ProfileController); o cliente não decide
-- nada do sorteio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PuffMachineView = require(script.Parent.Parent.ui.PuffMachineView)
local ProfileController = require(script.Parent.ProfileController)
local PuffdexController = require(script.Parent.PuffdexController)

type PuffMachineViewHandle = PuffMachineView.PuffMachineViewHandle
type MachineReveal = PuffMachineView.MachineReveal

local WAIT_TIMEOUT = 15

local FAILURE_MESSAGES: { [string]: string } = {
	NoTickets = "Tickets insuficientes. Jogue mais partidas!",
	NotSaved = "Seu progresso não está sendo salvo agora. Tente mais tarde.",
	NotLoaded = "Carregando seu perfil…",
	Competing = "A máquina funciona só no lobby.",
	Empty = "A máquina está vazia agora.",
	Cooldown = "Calma! A máquina está recarregando.",
}

local PuffMachineController = {}

local started = false
local view: PuffMachineViewHandle? = nil
local remote: RemoteEvent? = nil
-- Número do giro pedido por último: respostas de giros antigos (que
-- chegaram atrasadas) são ignoradas.
local lastRequestId = 0

local function parseReveal(raw: unknown): MachineReveal?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: any }
	local definition = PuffCatalog.get(data.puffId)
	if definition == nil then
		return nil
	end
	local refund = if typeof(data.refund) == "number" and data.refund == data.refund then math.clamp(math.floor(data.refund), 0, 99) else 0
	return { puffId = definition.id, duplicate = data.duplicate == true, refund = refund }
end

local function send(action: string, requestId: number?)
	local currentRemote = remote
	if currentRemote ~= nil then
		currentRemote:FireServer(action, requestId)
	end
end

function PuffMachineController.open()
	local current = view
	if current == nil then
		return
	end
	if current.isOpen() then
		current.close()
	else
		current.open()
	end
end

-- Abre (sem alternar): usado pelas estações do lobby.
function PuffMachineController.show()
	local current = view
	if current ~= nil and not current.isOpen() then
		current.open()
	end
end

function PuffMachineController.start()
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
		warn("[BlocoPuff] Puff Machine controller not started: PlayerGui unavailable")
		return
	end
	local newView = PuffMachineView.new(playerGui, function()
		if remote == nil then
			local currentView = view
			if currentView ~= nil then
				currentView.showFailure("A máquina ainda está ligando…")
			end
			return
		end
		lastRequestId += 1
		send("Pull", lastRequestId)
	end, function()
		send("Opened")
	end, function()
		local currentView = view
		if currentView ~= nil then
			currentView.close()
		end
		PuffdexController.show()
	end)
	view = newView

	-- Fecha quando o jogador entra na partida.
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			newView.close()
		end
	end)

	ProfileController.Changed:Connect(newView.setProfile)
	local current = ProfileController.get()
	if current ~= nil then
		newView.setProfile(current)
	end

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.PuffMachineRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Puff Machine controller: remote not found")
			return
		end
		remote = instance
		instance.OnClientEvent:Connect(function(kind: unknown, payload: unknown, requestId: unknown)
			if requestId ~= lastRequestId then
				return
			end
			if kind == "Result" then
				local reveal = parseReveal(payload)
				if reveal == nil then
					newView.showFailure("A máquina engasgou. Tente de novo!")
					return
				end
				newView.showResult(reveal)
				if not reveal.duplicate then
					PuffdexController.markNew({ reveal.puffId })
				end
			elseif kind == "Failed" then
				local message = if typeof(payload) == "string" then FAILURE_MESSAGES[payload] else nil
				newView.showFailure(message or "A máquina engasgou. Tente de novo!")
			end
		end)
	end)
end

return table.freeze(PuffMachineController)
