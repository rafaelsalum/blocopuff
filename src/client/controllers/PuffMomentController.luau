--!strict

-- Anuncia os Momentos Puff enviados pelo servidor (fuga do Barão e Volta por
-- Cima) numa faixa curta. Cofre conquistado e passagem secreta já têm faixa
-- própria nos seus controllers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local WAIT_TIMEOUT = 15

local PuffMomentController = {}

local started = false

local function describe(kind: unknown, detail: unknown, isMe: boolean, name: string): (string?, string, string)
	if kind == "BaraoEscape" then
		local jumped = detail == "Jump"
		if isMe then
			return "ESCAPOU DO BARÃO!", "🐶", if jumped then "Você pulou por cima dele" else "Você fugiu da perseguição"
		end
		return "ESCAPOU DO BARÃO!", "🐶", if jumped then `{name} pulou por cima do Barão` else `{name} fugiu do Barão`
	elseif kind == "Comeback" then
		local won = detail == "Win"
		if isMe then
			return "VOLTA POR CIMA!", "🔥", if won then "Você venceu depois da Segunda Chance" else "Você voltou da Segunda Chance e derrubou alguém"
		end
		return "VOLTA POR CIMA!", "🔥", if won then `{name} venceu depois da Segunda Chance` else `{name} voltou da Segunda Chance e derrubou alguém`
	end
	return nil, "", ""
end

local function onMoment(kind: unknown, name: unknown, userId: unknown, detail: unknown)
	local localPlayer = Players.LocalPlayer
	local isMe = localPlayer ~= nil and userId == localPlayer.UserId
	local displayName = if typeof(name) == "string" and #name <= 60 then name else "Alguém"
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
