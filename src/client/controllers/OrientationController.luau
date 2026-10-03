--!strict

-- Celular: o Bloco Puff só se joga deitado. Em pé, a arena e os controles
-- ficam apertados demais.
--
--   * Pede LandscapeLeft ao Roblox (também em StarterGui, no projeto) e pede
--     de novo se algo mudar a orientação.
--   * Alguns aparelhos (relatado no fórum do Roblox em iPhones) ignoram o
--     pedido. Por isso, sempre que a tela de um aparelho de toque estiver em
--     pé (mais alta que larga), uma tela cheia "Gire o celular" cobre o jogo
--     e bloqueia os toques até o aparelho ser deitado.
--   * O Output mostra a orientação pedida e a atual (diagnóstico).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UiTheme = require(script.Parent.Parent.ui.UiTheme)

local REQUESTED = Enum.ScreenOrientation.LandscapeLeft
local GUI_NAME = "BlocoPuffRotateDevice"
local WAIT_TIMEOUT = 15

local OrientationController = {}

local started = false

local function report(playerGui: PlayerGui, reason: string)
	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.zero
	print(string.format(
		"[BlocoPuff] Screen orientation (%s): requested=%s current=%s viewport=%dx%d",
		reason,
		playerGui.ScreenOrientation.Name,
		playerGui.CurrentScreenOrientation.Name,
		math.floor(viewport.X),
		math.floor(viewport.Y)
	))
end

local function request(playerGui: PlayerGui)
	if playerGui.ScreenOrientation ~= REQUESTED then
		playerGui.ScreenOrientation = REQUESTED
	end
end

-- Tela cheia que bloqueia o jogo com o aparelho em pé.
local function createBlocker(playerGui: PlayerGui): (ScreenGui, GuiObject)
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 1000)
	screenGui.IgnoreGuiInset = true
	screenGui.ScreenInsets = Enum.ScreenInsets.None
	screenGui.ClipToDeviceSafeArea = false
	screenGui.Enabled = false

	local cover = Instance.new("TextButton")
	cover.Name = "Cover"
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = UiTheme.Colors.Shadow
	cover.BackgroundTransparency = 0
	cover.BorderSizePixel = 0
	cover.AutoButtonColor = false
	cover.Text = ""
	cover.Active = true
	cover.Modal = true
	cover.Parent = screenGui

	local phone = UiTheme.createLabel(cover, "Phone", "📱", UiTheme.Fonts.Display, 72, UiTheme.Colors.Ink)
	phone.AnchorPoint = Vector2.new(0.5, 0.5)
	phone.Position = UDim2.fromScale(0.5, 0.38)
	phone.Size = UDim2.fromOffset(120, 120)

	local title = UiTheme.createLabel(cover, "Title", "GIRE O CELULAR", UiTheme.Fonts.Display, 30, UiTheme.Colors.Ink)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.56)
	title.Size = UDim2.new(1, -40, 0, 40)

	local subtitle = UiTheme.createLabel(cover, "Subtitle", "O Bloco Puff é jogado com a tela deitada", UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.Ink)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.fromScale(0.5, 0.64)
	subtitle.Size = UDim2.new(1, -40, 0, 44)
	subtitle.TextWrapped = true

	-- O celular do ícone vai e volta de em pé para deitado.
	local tilt = TweenService:Create(
		phone,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0.3),
		{ Rotation = -90 }
	)
	tilt:Play()

	return screenGui, cover
end

function OrientationController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local found = player:WaitForChild("PlayerGui", WAIT_TIMEOUT)
	if found == nil or not found:IsA("PlayerGui") then
		warn("[BlocoPuff] Screen orientation not enforced: PlayerGui unavailable")
		return
	end
	local playerGui = found

	request(playerGui)
	report(playerGui, "start")
	playerGui:GetPropertyChangedSignal("ScreenOrientation"):Connect(function()
		if playerGui.ScreenOrientation ~= REQUESTED then
			warn(string.format("[BlocoPuff] Screen orientation changed to %s; requesting %s again", playerGui.ScreenOrientation.Name, REQUESTED.Name))
			request(playerGui)
		end
	end)
	playerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(function()
		report(playerGui, "device rotated")
	end)

	if not UserInputService.TouchEnabled then
		return
	end
	local blocker = createBlocker(playerGui)
	local wasPortrait: boolean? = nil
	local function refresh()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local viewport = camera.ViewportSize
		local portrait = viewport.Y > viewport.X
		blocker.Enabled = portrait
		if portrait ~= wasPortrait then
			wasPortrait = portrait
			if portrait then
				request(playerGui)
				report(playerGui, "portrait blocked")
			end
		end
	end
	local cameraConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if cameraConnection ~= nil then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if camera ~= nil then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end
		refresh()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

return table.freeze(OrientationController)
