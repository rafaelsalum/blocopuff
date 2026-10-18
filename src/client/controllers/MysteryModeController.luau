--!strict

-- Assassinato no Casarão no cliente (Fase 5E): a roleta e o selo do papel
-- (só o próprio jogador sabe o seu), a primeira pessoa com a mão e o item
-- na tela (MurderFirstPerson), a faca do Assassino (clique ou toque rápido
-- golpeia; segurar e soltar arremessa para onde a mira aponta; no celular,
-- um botão só, no lugar do botão de tiro), o contador de moedas, os avisos
-- da arma caída e do Herói e a revelação de quem era quem no fim.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
local FireButtonView = require(script.Parent.Parent.ui.FireButtonView)
local MurderFirstPerson = require(script.Parent.MurderFirstPerson)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)

local T = Lang.t
local WAIT_TIMEOUT = 15
local REMOTE_NAME = "MysteryMode"
local GUI_NAME = "BlocoPuffMysteryHud"
local DISPLAY_ORDER = 6
local CATEGORY = "Mystery"
local COINS_ATTRIBUTE = "MysteryCoins"
local KNIFE_TOOL_NAME = "Faca"
-- A carga do arremesso enche nesse tempo depois de virar arremesso (s).
local CHARGE_FILL_SECONDS = 0.35
-- Segurando a carga, avisa o servidor de novo (senão ele guarda a faca).
local DRAW_REPEAT_SECONDS = 2
local CROSSHAIR_SIZE = 6
local GUN_RETRY_SECONDS = 0.2

local MysteryModeController = {}

local started = false

type Hud = {
	gui: ScreenGui,
	aimGui: ScreenGui,
	coinsLabel: TextLabel,
	crosshair: Frame,
	hint: TextLabel,
}

local function createHud(playerGui: PlayerGui): Hud
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

	-- Mira: um ponto no centro exato da tela (a primeira pessoa esconde o
	-- cursor). Fica numa tela própria que ignora a barra do topo, como a mira
	-- do Puffador; senão os dois centros não batem.
	local aimGui = UiTheme.createScreenGui(GUI_NAME .. "Aim", playerGui, DISPLAY_ORDER)
	aimGui.IgnoreGuiInset = true
	aimGui.Enabled = false
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(CROSSHAIR_SIZE, CROSSHAIR_SIZE)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BackgroundTransparency = 0.1
	crosshair.BorderSizePixel = 0
	crosshair.Parent = aimGui
	UiTheme.addCorner(crosshair, 999)
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(0, 0, 0)
	ring.Thickness = 1.5
	ring.Transparency = 0.3
	ring.Parent = crosshair

	-- Dica curta logo abaixo da mira (faca liberada em tantos segundos).
	local hint = UiTheme.createLabel(aimGui, "Hint", "", Enum.Font.GothamBold, 16)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.5, 18)
	hint.Size = UDim2.fromOffset(240, 24)
	hint.Visible = false
	UiTheme.addTextOutline(hint, 1.5)

	return { gui = gui, aimGui = aimGui, coinsLabel = coinsLabel, crosshair = crosshair, hint = hint }
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

local function heldTool(player: Player): Tool?
	local character = player.Character
	return if character ~= nil then character:FindFirstChildOfClass("Tool") else nil
end

local function run(remote: RemoteEvent, container: Instance, playerGui: PlayerGui)
	local localPlayer = Players.LocalPlayer
	local role = ""
	local isHero = false
	local graceEndsAt = 0
	local throwReadyAt = 0
	local stabReadyAt = 0
	-- Ataque em andamento: quando começou (nil: solto).
	local pressedAt: number? = nil
	local drawSentAt: number? = nil
	local view = RoleRevealView.create(playerGui)
	local hud = createHud(playerGui)

	local function inMatch(): boolean
		return container:GetAttribute(StateAttributeNames.RoundState) == "Active"
			and container:GetAttribute(StateAttributeNames.RoundMode) == "Mystery"
			and localPlayer:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
	end

	local function canAttack(): boolean
		return role == "Murderer" and inMatch() and os.clock() >= graceEndsAt
	end

	-- Para onde a mira (centro da tela) aponta.
	local function aimDirection(): Vector3
		local camera = Workspace.CurrentCamera
		return if camera ~= nil then camera.CFrame.LookVector else Vector3.zAxis
	end

	local function holdStarted()
		if not canAttack() then
			return
		end
		pressedAt = os.clock()
		drawSentAt = nil
	end

	-- Soltou: rápido é golpe; segurado (com o arremesso pronto) é arremesso.
	local function holdEnded()
		local startedAt = pressedAt
		pressedAt = nil
		MurderFirstPerson.setCharge(0)
		if startedAt == nil or not canAttack() then
			return
		end
		local now = os.clock()
		local held = now - startedAt
		if held >= MysteryModeConfig.ThrowHoldSeconds and now >= throwReadyAt then
			throwReadyAt = now + MysteryModeConfig.ThrowCooldown
			stabReadyAt = now + MysteryModeConfig.StabCooldown
			remote:FireServer("Throw", aimDirection())
			MurderFirstPerson.pulse("Throw")
			return
		end
		if now >= stabReadyAt then
			stabReadyAt = now + MysteryModeConfig.StabCooldown
			remote:FireServer("Stab")
			MurderFirstPerson.pulse("Stab")
		end
	end

	-- Botão da faca no celular (no lugar do botão de tiro, ao lado do pulo).
	local knifeButton = if UserInputService.TouchEnabled then FireButtonView.new(playerGui, holdStarted, holdEnded) else nil
	if knifeButton ~= nil then
		knifeButton.setLabel("🔪", T("FACA"))
	end

	-- Carga do arremesso enquanto segura (mostra a faca para todos).
	RunService.RenderStepped:Connect(function()
		local startedAt = pressedAt
		if startedAt == nil then
			return
		end
		local now = os.clock()
		local over = now - startedAt - MysteryModeConfig.ThrowHoldSeconds
		if over < 0 or now < throwReadyAt then
			return
		end
		local sentAt = drawSentAt
		if sentAt == nil or now - sentAt >= DRAW_REPEAT_SECONDS then
			drawSentAt = now
			remote:FireServer("Draw")
		end
		MurderFirstPerson.setCharge(over / CHARGE_FILL_SECONDS)
	end)

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
		local playing = inMatch() and alive and role ~= ""
		hud.gui.Enabled = playing
		hud.aimGui.Enabled = playing
		if playing then
			MurderFirstPerson.enable()
		else
			MurderFirstPerson.disable()
			pressedAt = nil
		end
		if knifeButton ~= nil then
			knifeButton.setVisible(playing and role == "Murderer")
		end
		-- Item na mão: a faca sempre com o Assassino (erguida quando à vista
		-- de todos); a arma quando o Xerife ou o Herói a segura.
		local tool = heldTool(localPlayer)
		local holdingGun = tool ~= nil and tool.Name == PuffadorConstants.ToolName
		-- Com a arma na mão vale a mira do Puffador.
		hud.crosshair.Visible = not holdingGun
		if role == "Murderer" then
			MurderFirstPerson.setItem("Knife")
			MurderFirstPerson.setRaised(tool ~= nil and tool.Name == KNIFE_TOOL_NAME)
		elseif tool ~= nil and holdingGun and tool:FindFirstChild("Handle") ~= nil then
			MurderFirstPerson.setItem("Gun", tool)
		elseif tool ~= nil and holdingGun then
			-- O Puffador ainda está chegando no cliente: tenta de novo já já.
			MurderFirstPerson.setItem(nil)
			task.delay(GUN_RETRY_SECONDS, refresh)
			MurderFirstPerson.setRaised(true)
		else
			MurderFirstPerson.setItem(nil)
		end
		if not playing and role ~= "" and not alive then
			view.setBadge(nil)
		end
		local coins = localPlayer:GetAttribute(COINS_ATTRIBUTE)
		hud.coinsLabel.Text = T("💰 %d/%d", if typeof(coins) == "number" then coins else 0, MysteryModeConfig.MaxCoinsPerPlayer)
	end

	-- Faca liberada em tantos segundos (só o Assassino vê).
	task.spawn(function()
		while true do
			local remaining = math.ceil(graceEndsAt - os.clock())
			local showing = role == "Murderer" and remaining > 0 and hud.aimGui.Enabled
			hud.hint.Visible = showing
			if showing then
				hud.hint.Text = T("🔪 faca liberada em %ds", remaining)
			end
			task.wait(0.2)
		end
	end)

	remote.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown, c: unknown, d: unknown)
		if kind == "Role" and typeof(a) == "string" then
			role = a
			isHero = false
			graceEndsAt = os.clock() + (if typeof(b) == "number" then b else 0)
			throwReadyAt = 0
			stabReadyAt = 0
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
			if knifeButton ~= nil then
				knifeButton.startCooldown(a)
			end
		elseif kind == "Reveal" and typeof(a) == "string" and typeof(b) == "string" and typeof(c) == "string" and typeof(d) == "string" then
			view.setBadge(nil)
			view.showReveal({ murderer = a, sheriff = b, hero = c, winner = d })
		end
	end)

	-- No PC o ataque é o clique (ou o gatilho do controle); o toque usa o
	-- botão da faca.
	local function isAttackInput(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
	end
	-- Coice da arma na tela (no ritmo da recarga do Xerife).
	local shotReadyAt = 0
	local function gunKick()
		local tool = heldTool(localPlayer)
		local now = os.clock()
		if tool ~= nil and tool.Name == PuffadorConstants.ToolName and now >= shotReadyAt then
			shotReadyAt = now + MysteryModeConfig.SheriffReload
			MurderFirstPerson.pulse("Shot")
		end
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not isAttackInput(input) then
			return
		end
		if role == "Murderer" then
			holdStarted()
		elseif inMatch() then
			gunKick()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if isAttackInput(input) and pressedAt ~= nil then
			holdEnded()
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
