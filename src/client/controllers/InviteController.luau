--!strict

-- Convite com recompensa no cliente (Fase 5B): o botão 💌 do cartão de
-- perfil abre o convite do Roblox (amigos escolhidos pelo próprio Roblox,
-- sem texto livre) e os avisos de prêmio chegam do ReferralService. O
-- cliente não decide nenhum prêmio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ReferralConfig = require(ReplicatedStorage.Shared.config.ReferralConfig)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local WAIT_TIMEOUT = 15
local MAX_TICKETS_SHOWN = 999

local InviteController = {}

local started = false
local remote: RemoteEvent? = nil
local lastInviteAt = -math.huge

local function banner(key: string, icon: string, title: string, subtitle: string, tone: NotificationManager.Tone, duration: number)
	NotificationManager.notify({
		channel = "Banner",
		category = "Referral",
		priority = "High",
		key = key,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = tone,
		duration = duration,
		maxWait = 20,
	})
end

local function report(action: string)
	local current = remote
	if current ~= nil then
		current:FireServer(action)
	end
end

local function canInvite(player: Player): boolean
	local ok, result = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	return ok and result == true
end

-- Abre o convite do Roblox (botão 💌).
function InviteController.invite()
	local player = Players.LocalPlayer
	local clock = os.clock()
	if player == nil or clock - lastInviteAt < ReferralConfig.InviteCooldown then
		return
	end
	lastInviteAt = clock
	task.spawn(function()
		if not canInvite(player) then
			banner("InviteUnavailable", "💌", "CONVITE INDISPONÍVEL", "Sua conta não pode enviar convites agora.", "Info", 3)
			report("Unavailable")
			return
		end
		local ok, failure = pcall(function()
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = ReferralConfig.PromptMessage
			options.LaunchData = `\{"inviter":{player.UserId}\}`
			SocialService:PromptGameInvite(player, options)
		end)
		if ok then
			report("Sent")
			banner(
				"InviteHint",
				"💌",
				"CONVIDE E GANHE",
				`{ReferralConfig.InviterTickets} 🎟️ por amigo novo que jogar uma partida`,
				"Gold",
				4
			)
		else
			warn(string.format("[BlocoPuff] Invite prompt failed: %s", tostring(failure)))
		end
	end)
end

local function readCount(value: unknown): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_TICKETS_SHOWN)
end

local function onReward(raw: unknown)
	if typeof(raw) ~= "table" then
		return
	end
	local data = raw :: { [string]: unknown }
	local tickets = readCount(data.tickets)
	if tickets <= 0 then
		return
	end
	if data.kind == "Invitee" then
		banner("InviteeReward", "💌", `+{tickets} 🎟️ BOAS-VINDAS!`, "Prêmio por chegar a convite de um amigo", "Gold", 4)
	elseif data.kind == "Inviter" then
		local friends = readCount(data.friends)
		local subtitle = if friends == 1 then "Um amigo seu jogou a primeira partida" else `{friends} amigos seus jogaram a primeira partida`
		banner("InviterReward", "💌", `+{tickets} 🎟️ CONVITE!`, subtitle, "Gold", 4)
	end
end

function InviteController.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local instance = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.ReferralRemoteName, WAIT_TIMEOUT) else nil
		if instance == nil or not instance:IsA("RemoteEvent") then
			warn("[BlocoPuff] Invite rewards unavailable: remote not found")
			return
		end
		remote = instance
		instance.OnClientEvent:Connect(onReward)
	end)
end

return table.freeze(InviteController)
