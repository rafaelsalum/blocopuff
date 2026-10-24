--!strict

-- Anuncia os Momentos Puff enviados pelo servidor (fuga do Barão, Volta por
-- Cima e as derrubadas por armadilha da Fase 5.8) numa faixa curta. Cofre conquistado e passagem secreta já têm faixa
-- própria nos seus controllers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local T = Lang.t
local WAIT_TIMEOUT = 15

local PuffMomentController = {}

local started = false

-- Derrubada por armadilha: título, ícone e as legendas (para quem acionou
-- e para os outros, com o nome).
local TRAP_MOMENTS: { [string]: { title: string, icon: string, mine: string, other: string } } = {
	TrapWindow = { title = "VIDRAÇA!", icon = "💨", mine = "Sua janela derrubou alguém", other = "%s derrubou alguém com uma janela" },
	TrapRug = { title = "PUXOU O TAPETE!", icon = "🧶", mine = "Você puxou o tapete e derrubou alguém", other = "%s puxou o tapete e derrubou alguém" },
	TrapChandelier = { title = "LUSTRE!", icon = "💡", mine = "Seu lustre derrubou alguém", other = "%s derrubou alguém com um lustre" },
	TrapFireplace = { title = "ATCHIM!", icon = "🤧", mine = "A fuligem da lareira derrubou alguém", other = "%s derrubou alguém com a fuligem da lareira" },
}

local function describe(kind: unknown, detail: unknown, isMe: boolean, name: string): (string?, string, string)
	if kind == "BaraoEscape" then
		local jumped = detail == "Jump"
		if isMe then
			return T("ESCAPOU DO BARÃO!"), "🐶", if jumped then T("Você pulou por cima dele") else T("Você fugiu da perseguição")
		end
		return T("ESCAPOU DO BARÃO!"), "🐶", if jumped then T("%s pulou por cima do Barão", name) else T("%s fugiu do Barão", name)
	elseif kind == "Comeback" then
		local won = detail == "Win"
		if isMe then
			return T("VOLTA POR CIMA!"), "🔥", if won then T("Você venceu depois da Segunda Chance") else T("Você voltou da Segunda Chance e derrubou alguém")
		end
		return T("VOLTA POR CIMA!"), "🔥", if won then T("%s venceu depois da Segunda Chance", name) else T("%s voltou da Segunda Chance e derrubou alguém", name)
	end
	local trap = if typeof(kind) == "string" then TRAP_MOMENTS[kind] else nil
	if trap ~= nil then
		return T(trap.title), trap.icon, if isMe then T(trap.mine) else T(trap.other, name)
	end
	return nil, "", ""
end

local function onMoment(kind: unknown, name: unknown, userId: unknown, detail: unknown)
	local localPlayer = Players.LocalPlayer
	local isMe = localPlayer ~= nil and userId == localPlayer.UserId
	local displayName = if typeof(name) == "string" and #name <= 60 then name else T("Alguém")
	local title, icon, subtitle = describe(kind, detail, isMe, displayName)
	if title == nil then
		return
	end
	NotificationManager.notify({
		channel = "Banner",
		category = "Moment",
		priority = "Normal",
		key = `moment-{tostring(kind)}-{tostring(userId)}`,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = "Winner",
		duration = 3,
		maxWait = 4,
	})
end

function PuffMomentController.start()
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

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local remote = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.PuffMomentRemoteName, WAIT_TIMEOUT) else nil
		if remote ~= nil and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(onMoment)
		else
			warn("[BlocoPuff] Puff moment controller: remote not found")
		end
	end)
end

return table.freeze(PuffMomentController)
