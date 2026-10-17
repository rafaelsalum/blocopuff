--!strict

-- Mistério no Casarão no cliente (Fase 5D.3): o cartão do papel (só o
-- próprio jogador sabe o seu), os botões do Fantasma (Assustar e Lençol
-- Voador, também nas teclas Q e E), o contador de moedas e os avisos do
-- Puffador caído, do Herói, do erro do Detetive e da revelação no fim.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local UiTheme = require(script.Parent.Parent.ui.UiTheme)
local UiKit = require(script.Parent.Parent.ui.UiKit)
local ResponsiveScale = require(script.Parent.Parent.ui.ResponsiveScale)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local T = Lang.t
local WAIT_TIMEOUT = 15
local REMOTE_NAME = "MysteryMode"
local GUI_NAME = "BlocoPuffMysteryHud"
local DISPLAY_ORDER = 6
local CATEGORY = "Mystery"
local COINS_ATTRIBUTE = "MysteryCoins"
local SCARE_KEY = Enum.KeyCode.Q
local SHEET_KEY = Enum.KeyCode.E

type RoleText = {
	icon: string,
	title: string,
	goal: string,
}

local function roleText(role: string): RoleText
	if role == "Ghost" then
		return { icon = "👻", title = T("VOCÊ É O FANTASMA"), goal = T("Assuste todos sem ser descoberto · Q assusta, E joga o lençol") }
	elseif role == "Detective" then
		return { icon = "🔦", title = T("VOCÊ É O DETETIVE"), goal = T("Descubra o Fantasma e capture com um Puff · errar derruba o Puffador") }
	end
	return { icon = "🏠", title = T("VOCÊ É MORADOR"), goal = T("Pegue moedas, fuja do Fantasma e descubra quem ele é") }
end

local MysteryModeController = {}

local started = false

type Hud = {
	gui: ScreenGui,
	coinsLabel: TextLabel,
	ghostButtons: Frame,
}

local function createHud(playerGui: PlayerGui, onScare: () -> (), onSheet: () -> ()): Hud
	local gui = UiTheme.createScreenGui(GUI_NAME, playerGui, DISPLAY_ORDER)
	gui.Enabled = false

	local coinsRoot = Instance.new("Frame")
	coinsRoot.Name = "Coins"
	coinsRoot.Position = UDim2.fromOffset(18, 16)
	coinsRoot.Size = UDim2.fromOffset(150, 44)
	coinsRoot.Parent = gui
	UiTheme.stylePanel(coinsRoot, { accent = UiTheme.Colors.Gold, radius = 14 })
	ResponsiveScale.attach(coinsRoot, Vector2.new(1280, 720), 0.7, 1.05)
	local coinsLabel = UiTheme.createLabel(coinsRoot, "Value", "", Enum.Font.GothamBold, 18)
	coinsLabel.Size = UDim2.fromScale(1, 1)
	UiTheme.addTextOutline(coinsLabel, 1.5)

	local ghostButtons = Instance.new("Frame")
	ghostButtons.Name = "GhostButtons"
	ghostButtons.AnchorPoint = Vector2.new(1, 1)
	ghostButtons.Position = UDim2.new(1, -18, 1, -170)
	ghostButtons.Size = UDim2.fromOffset(150, 120)
	ghostButtons.BackgroundTransparency = 1
	ghostButtons.Visible = false
	ghostButtons.Parent = gui
	ResponsiveScale.attach(ghostButtons, Vector2.new(1280, 720), 0.75, 1.1)
	local scare = UiKit.createButton(ghostButtons, {
		name = "Scare",
		text = T("👻 ASSUSTAR"),
		variant = "Danger",
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.fromOffset(0, 0),
	})
	scare.button.Activated:Connect(onScare)
	local sheet = UiKit.createButton(ghostButtons, {
		name = "Sheet",
		text = T("💨 LENÇOL"),
		variant = "Neutral",
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.fromOffset(0, 64),
	})
	sheet.button.Activated:Connect(onSheet)

	return { gui = gui, coinsLabel = coinsLabel, ghostButtons = ghostButtons }
end

local function notify(channel: "Center" | "Banner", key: string, icon: string, title: string, subtitle: string, tone: NotificationManager.Tone, duration: number)
	NotificationManager.notify({
		channel = channel,
		category = CATEGORY,
		priority = if channel == "Center" then "High" else "Normal",
		key = key,
		icon = icon,
		title = title,
		subtitle = subtitle,
		tone = tone,
		duration = duration,
	})
end

local function run(remote: RemoteEvent, container: Instance, playerGui: PlayerGui)
	local localPlayer = Players.LocalPlayer
	local role = ""

	local function lookDirection(): Vector3
		local camera = Workspace.CurrentCamera
		return if camera ~= nil then camera.CFrame.LookVector else Vector3.zAxis
	end
	local function scare()
		if role == "Ghost" then
			remote:FireServer("Scare")
		end
	end
	local function sheet()
		if role == "Ghost" then
			remote:FireServer("Sheet", lookDirection())
		end
	end

	local hud = createHud(playerGui, scare, sheet)

	local function refresh()
		-- O papel vale até a partida acabar (o aviso do papel pode chegar
		-- antes de o estado virar Active).
		local state = container:GetAttribute(StateAttributeNames.RoundState)
		if state == "Ending" or state == "WaitingForPlayers" then
			role = ""
		end
		local inMystery = state == "Active"
			and container:GetAttribute(StateAttributeNames.RoundMode) == "Mystery"
			and localPlayer:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		local awake = localPlayer:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
		hud.gui.Enabled = inMystery and awake
		hud.ghostButtons.Visible = role == "Ghost"
		local coins = localPlayer:GetAttribute(COINS_ATTRIBUTE)
		hud.coinsLabel.Text = T("💰 %d/%d", if typeof(coins) == "number" then coins else 0, MysteryModeConfig.MaxCoinsPerPlayer)
	end

	remote.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown, c: unknown)
		if kind == "Role" and typeof(a) == "string" then
			role = a
			local text = roleText(a)
			notify("Center", "mystery-role", text.icon, text.title, text.goal, if a == "Ghost" then "Danger" else "Gold", 4)
			refresh()
		elseif kind == "GunDropped" then
			notify("Banner", "mystery-gun", "🔦", T("O PUFFADOR CAIU!"), T("Qualquer Morador pode pegar e virar o Herói"), "Warning", 3)
		elseif kind == "GunTaken" then
			notify("Banner", "mystery-gun", "🦸", T("ALGUÉM PEGOU O PUFFADOR"), T("Há um Herói no Casarão"), "Info", 3)
		elseif kind == "Hero" then
			notify("Center", "mystery-hero", "🦸", T("VOCÊ É O HERÓI!"), T("Capture o Fantasma com um Puff"), "Gold", 3)
		elseif kind == "Misfire" then
			notify("Center", "mystery-misfire", "😵", T("ERA UM MORADOR!"), T("Você ficou tonto e derrubou o Puffador"), "Danger", 3)
		elseif kind == "Reveal" and typeof(a) == "string" and typeof(b) == "string" then
			local winners = if c == "Ghost" then T("O Fantasma venceu!") elseif c == "Residents" then T("Os Moradores venceram!") else ""
			local subtitle = if a ~= "" then T("O Fantasma era %s", a) else ""
			notify("Center", "mystery-reveal", "👻", winners, subtitle, "Winner", 4)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or role ~= "Ghost" then
			return
		end
		if input.KeyCode == SCARE_KEY then
			scare()
		elseif input.KeyCode == SHEET_KEY then
			sheet()
		end
	end)

	container.AttributeChanged:Connect(refresh)
	localPlayer.AttributeChanged:Connect(refresh)
	refresh()
end

function MysteryModeController.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local localPlayer = Players.LocalPlayer
		local playerGui = localPlayer:WaitForChild("PlayerGui", WAIT_TIMEOUT)
		local container = ReplicatedStorage:WaitForChild(StateAttributeNames.ContainerName, WAIT_TIMEOUT)
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local remote = if remotes ~= nil then remotes:WaitForChild(REMOTE_NAME, WAIT_TIMEOUT) else nil
		if playerGui == nil or not playerGui:IsA("PlayerGui") or container == nil or remote == nil or not remote:IsA("RemoteEvent") then
			warn("[BlocoPuff] MysteryModeController: remote, state container or PlayerGui not found")
			return
		end
		run(remote, container, playerGui)
	end)
end

return table.freeze(MysteryModeController)
