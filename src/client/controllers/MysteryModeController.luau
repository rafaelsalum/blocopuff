--!strict

-- Assassinato no Casarão no cliente (Fase 5E): a roleta e o selo do papel
-- (só o próprio jogador sabe o seu), os controles da faca do Assassino
-- (sacar e guardar com Q, golpear com o clique, arremessar com E, e botões
-- no celular), o contador de moedas, os avisos da arma caída e do Herói e a
-- revelação de quem era quem no fim.

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
local RoleRevealView = require(script.Parent.Parent.ui.RoleRevealView)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local T = Lang.t
local WAIT_TIMEOUT = 15
local REMOTE_NAME = "MysteryMode"
local GUI_NAME = "BlocoPuffMysteryHud"
local DISPLAY_ORDER = 6
local CATEGORY = "Mystery"
local COINS_ATTRIBUTE = "MysteryCoins"
local KNIFE_TOOL_NAME = "Faca"
local EQUIP_KEY = Enum.KeyCode.Q
local THROW_KEY = Enum.KeyCode.E

local MysteryModeController = {}

local started = false

type Hud = {
	gui: ScreenGui,
	coinsLabel: TextLabel,
	knifeButtons: Frame,
	equip: UiKit.ButtonHandle,
	stab: UiKit.ButtonHandle,
	throw: UiKit.ButtonHandle,
}

type Actions = {
	toggleEquip: () -> (),
	stab: () -> (),
	throw: () -> (),
}

local function createHud(playerGui: PlayerGui, actions: Actions): Hud
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

	local knifeButtons = Instance.new("Frame")
	knifeButtons.Name = "KnifeButtons"
	knifeButtons.AnchorPoint = Vector2.new(1, 1)
	knifeButtons.Position = UDim2.new(1, -18, 1, -150)
	knifeButtons.Size = UDim2.fromOffset(170, 184)
	knifeButtons.BackgroundTransparency = 1
	knifeButtons.Visible = false
	knifeButtons.Parent = gui
	ResponsiveScale.attach(knifeButtons, Vector2.new(1280, 720), 0.75, 1.1)
	local equip = UiKit.createButton(knifeButtons, {
		name = "Equip",
		text = T("🔪 SACAR (Q)"),
		variant = "Neutral",
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.fromOffset(0, 0),
	})
	equip.button.Activated:Connect(actions.toggleEquip)
	local stab = UiKit.createButton(knifeButtons, {
		name = "Stab",
		text = T("🔪 GOLPEAR"),
		variant = "Danger",
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.fromOffset(0, 64),
	})
	stab.button.Activated:Connect(actions.stab)
	local throw = UiKit.createButton(knifeButtons, {
		name = "Throw",
		text = T("🎯 ARREMESSAR (E)"),
		variant = "Warning",
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.fromOffset(0, 128),
	})
	throw.button.Activated:Connect(actions.throw)

	return { gui = gui, coinsLabel = coinsLabel, knifeButtons = knifeButtons, equip = equip, stab = stab, throw = throw }
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

local function knifeEquipped(player: Player): boolean
	local character = player.Character
	local tool = if character ~= nil then character:FindFirstChild(KNIFE_TOOL_NAME) else nil
	return tool ~= nil and tool:IsA("Tool")
end

local function run(remote: RemoteEvent, container: Instance, playerGui: PlayerGui)
	local localPlayer = Players.LocalPlayer
	local role = ""
	local isHero = false
	local throwReadyAt = 0
	local view = RoleRevealView.create(playerGui)

	-- Direção do arremesso: para onde o mouse aponta; no toque, para onde a
	-- câmera olha.
	local function aimDirection(): Vector3
		local character = localPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if not UserInputService.TouchEnabled and root ~= nil and root:IsA("BasePart") then
			local target = localPlayer:GetMouse().Hit.Position
			local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
			if flat.Magnitude > 1 then
				return flat
			end
		end
		local camera = Workspace.CurrentCamera
		return if camera ~= nil then camera.CFrame.LookVector else Vector3.zAxis
	end

	local actions: Actions = {
		toggleEquip = function()
			if role == "Murderer" then
				remote:FireServer("Equip", not knifeEquipped(localPlayer))
			end
		end,
		stab = function()
			if role == "Murderer" and knifeEquipped(localPlayer) then
				remote:FireServer("Stab")
			end
		end,
		throw = function()
			if role == "Murderer" and knifeEquipped(localPlayer) and os.clock() >= throwReadyAt then
				remote:FireServer("Throw", aimDirection())
			end
		end,
	}
	local hud = createHud(playerGui, actions)

	local function inMatch(): boolean
		return container:GetAttribute(StateAttributeNames.RoundState) == "Active"
			and container:GetAttribute(StateAttributeNames.RoundMode) == "Mystery"
			and localPlayer:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
	end

	local function refresh()
		-- O papel vale até a partida acabar (o aviso do papel pode chegar
		-- antes de o estado virar Active).
		local state = container:GetAttribute(StateAttributeNames.RoundState)
		if state == "Ending" or state == "WaitingForPlayers" then
			if role ~= "" then
				view.hide()
			end
			role = ""
			isHero = false
		end
		local alive = localPlayer:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= true
		local playing = inMatch() and alive
		hud.gui.Enabled = playing
		hud.knifeButtons.Visible = role == "Murderer"
		-- O botão de golpear é para o toque; no PC o golpe é o clique.
		hud.stab.root.Visible = UserInputService.TouchEnabled
		local equipped = knifeEquipped(localPlayer)
		hud.equip.setText(if equipped then T("✋ GUARDAR (Q)") else T("🔪 SACAR (Q)"))
		hud.stab.setEnabled(equipped)
		hud.throw.setEnabled(equipped)
		if not playing and role ~= "" and not alive then
			view.setBadge(nil)
		end
		local coins = localPlayer:GetAttribute(COINS_ATTRIBUTE)
		hud.coinsLabel.Text = T("💰 %d/%d", if typeof(coins) == "number" then coins else 0, MysteryModeConfig.MaxCoinsPerPlayer)
	end

	remote.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown, c: unknown, d: unknown)
		if kind == "Role" and typeof(a) == "string" then
			role = a
			isHero = false
			view.spin(a, MysteryModeConfig.RoleRevealSeconds)
			refresh()
		elseif kind == "GunDropped" then
			notify("Banner", "mystery-gun", "🔫", T("A ARMA DO XERIFE CAIU!"), T("Qualquer Inocente pode pegar e virar o Herói"), "Warning", 3)
		elseif kind == "GunTaken" then
			if not isHero then
				notify("Banner", "mystery-gun", "🦸", T("ALGUÉM PEGOU A ARMA"), T("Há um Herói no Casarão"), "Info", 3)
			end
		elseif kind == "Hero" then
			isHero = true
			view.setBadge("Hero")
			notify("Center", "mystery-hero", "🦸", T("VOCÊ É O HERÓI!"), T("Acerte o Assassino · errar elimina você"), "Gold", 3)
		elseif kind == "ThrowCooldown" and typeof(a) == "number" then
			throwReadyAt = os.clock() + a
		elseif kind == "Reveal" and typeof(a) == "string" and typeof(b) == "string" and typeof(c) == "string" and typeof(d) == "string" then
			view.setBadge(nil)
			view.showReveal({ murderer = a, sheriff = b, hero = c, winner = d })
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or role ~= "Murderer" or not inMatch() then
			return
		end
		if input.KeyCode == EQUIP_KEY then
			actions.toggleEquip()
		elseif input.KeyCode == THROW_KEY then
			actions.throw()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			actions.stab()
		end
	end)

	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(refresh)
		character.ChildRemoved:Connect(refresh)
		refresh()
	end
	localPlayer.CharacterAdded:Connect(watchCharacter)
	if localPlayer.Character ~= nil then
		watchCharacter(localPlayer.Character)
	end
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
