--!strict

-- Feedbacks customizados de jogo, no estilo dos jogos de tiro mais polidos:
-- um "+1" pequeno que escorrega para a direita da mira a cada bloco
-- derrubado (sem cobrir o alvo), e, no lado direito da tela, a faixa de
-- sequência (combo "x5" e chamadas como "TRIPLO!", "EM CHAMAS!") acima das
-- notificações curtas (toasts). O centro da tela fica livre para jogar.
-- Puramente visual: só reage a confirmações que o servidor já enviou.

local TweenService = game:GetService("TweenService")

local Lang = require(game:GetService("ReplicatedStorage").Shared.i18n.Lang)
local T = Lang.t
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

export type ToastTone = "Info" | "Success" | "Warning" | "Danger"

export type FeedbackViewHandle = {
	playBlockHit: () -> (),
	resetCombo: () -> (),
	showToast: (text: string, tone: ToastTone?, duration: number?) -> (),
	destroy: () -> (),
}

type Callout = {
	count: number,
	text: string,
	color: Color3,
}

local GUI_NAME = "BlocoPuffFeedback"
local COMBO_WINDOW = 1.6
-- "+1": nasce à direita da mira e escorrega para fora dela.
local POPUP_START = Vector2.new(30, 4)
local POPUP_DRIFT = Vector2.new(26, -10)
local POPUP_DURATION = 0.55
-- Faixa de sequência no lado direito, entre o HUD superior e os toasts.
local STREAK_Y = 96
local CALLOUT_HOLD = 1.2
local TOAST_DURATION = 3
local MAX_TOASTS = 4
local CALLOUTS: { Callout } = {
	{ count = 3, text = T("TRIPLO!"), color = UiTheme.Colors.Gold },
	{ count = 5, text = T("EM CHAMAS!"), color = UiTheme.Colors.Orange },
	{ count = 8, text = T("IMPARÁVEL!"), color = UiTheme.Colors.Pink },
	{ count = 12, text = T("LENDÁRIO!"), color = UiTheme.Colors.Brand },
}

local FeedbackView = {}

local function getToneColor(tone: ToastTone): Color3
	if tone == "Success" then
		return UiTheme.Colors.Green
	elseif tone == "Warning" then
		return UiTheme.Colors.Orange
	elseif tone == "Danger" then
		return UiTheme.Colors.Danger
	end
	return UiTheme.Colors.Brand
end

local function findCallout(count: number): Callout?
	for _, callout in ipairs(CALLOUTS) do
		if callout.count == count then
			return callout
		end
	end
	return nil
end

function FeedbackView.new(playerGui: PlayerGui): FeedbackViewHandle
	-- Alinhado ao centro exato do viewport, igual à mira.
	local centerGui = Instance.new("ScreenGui")
	centerGui.Name = GUI_NAME
	centerGui.ResetOnSpawn = false
	centerGui.IgnoreGuiInset = true
	centerGui.DisplayOrder = 21
	centerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	centerGui.Parent = playerGui

	local center = Instance.new("Frame")
	center.Name = "Center"
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(1, 1)
	center.BackgroundTransparency = 1
	center.Parent = centerGui

	-- Toasts e a faixa de sequência ficam na área segura, abaixo do HUD
	-- superior direito, longe da mira.
	local toastGui = UiTheme.createScreenGui(`{GUI_NAME}Toasts`, playerGui, 40)

	local streak = Instance.new("Frame")
	streak.Name = "Streak"
	streak.AnchorPoint = Vector2.new(1, 0)
	streak.Position = UDim2.new(1, -18, 0, STREAK_Y)
	streak.Size = UDim2.fromOffset(300, 44)
	streak.BackgroundTransparency = 1
	streak.Parent = toastGui
	ResponsiveScale.attach(streak, Vector2.new(1280, 720), 0.7, 1.05)

	local comboLabel = UiTheme.createLabel(streak, "Combo", "", UiTheme.Fonts.Display, 30, UiTheme.Colors.White)
	comboLabel.AnchorPoint = Vector2.new(1, 0.5)
	comboLabel.Position = UDim2.new(1, 0, 0.5, 0)
	comboLabel.Size = UDim2.fromOffset(80, 40)
	comboLabel.TextXAlignment = Enum.TextXAlignment.Right
	comboLabel.TextTransparency = 1
	local comboGradient = UiTheme.addGradient(comboLabel, UiTheme.Colors.White, UiTheme.Colors.Gold)
	local comboOutline = UiTheme.addTextOutline(comboLabel, 3)
	comboOutline.Transparency = 1

	local calloutLabel = UiTheme.createLabel(streak, "Callout", "", UiTheme.Fonts.Display, 30, UiTheme.Colors.White)
	calloutLabel.AnchorPoint = Vector2.new(1, 0.5)
	calloutLabel.Position = UDim2.new(1, -86, 0.5, 0)
	calloutLabel.Size = UDim2.fromOffset(214, 40)
	calloutLabel.TextXAlignment = Enum.TextXAlignment.Right
	calloutLabel.TextScaled = true
	calloutLabel.TextWrapped = false
	UiTheme.addTextConstraint(calloutLabel, 18, 30)
	calloutLabel.TextTransparency = 1
	local calloutGradient = UiTheme.addGradient(calloutLabel, UiTheme.Colors.White, UiTheme.Colors.Gold)
	local calloutOutline = UiTheme.addTextOutline(calloutLabel, 3.5)
	calloutOutline.Transparency = 1

	local toastStack = Instance.new("Frame")
	toastStack.Name = "ToastStack"
	toastStack.AnchorPoint = Vector2.new(1, 0)
	toastStack.Position = UDim2.new(1, -18, 0, 150)
	toastStack.Size = UDim2.fromOffset(280, 300)
	toastStack.BackgroundTransparency = 1
	toastStack.Parent = toastGui

	local toastLayout = Instance.new("UIListLayout")
	toastLayout.FillDirection = Enum.FillDirection.Vertical
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Padding = UDim.new(0, 8)
	toastLayout.Parent = toastStack

	local comboCount = 0
	local lastHitClock = 0
	local comboGeneration = 0
	local toastSequence = 0

	local function fadeCombo(generation: number)
		task.delay(COMBO_WINDOW, function()
			if generation ~= comboGeneration then
				return
			end
			comboCount = 0
			TweenService:Create(comboLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			TweenService:Create(comboOutline, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end)
	end

	local function spawnPopup()
		local popup = UiTheme.createLabel(center, "HitPopup", "+1", UiTheme.Fonts.Display, 20, UiTheme.Colors.White)
		popup.AnchorPoint = Vector2.new(0, 0.5)
		local jitter = math.random(-6, 6)
		popup.Position = UDim2.fromOffset(POPUP_START.X, POPUP_START.Y + jitter)
		popup.Size = UDim2.fromOffset(44, 24)
		popup.TextXAlignment = Enum.TextXAlignment.Left
		UiTheme.addGradient(popup, UiTheme.Colors.White, UiTheme.Colors.Gold)
		local outline = UiTheme.addTextOutline(popup, 2.5)
		UiKit.pop(popup, 0.45)

		local info = TweenInfo.new(POPUP_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(popup, info, {
			Position = UDim2.fromOffset(POPUP_START.X + POPUP_DRIFT.X, POPUP_START.Y + jitter + POPUP_DRIFT.Y),
			TextTransparency = 1,
		}):Play()
		TweenService:Create(outline, info, { Transparency = 1 }):Play()
		task.delay(POPUP_DURATION + 0.05, function()
			popup:Destroy()
		end)
	end

	local function playCallout(callout: Callout)
		calloutLabel.Text = callout.text
		calloutGradient.Color = ColorSequence.new(UiTheme.Colors.White, callout.color)
		calloutLabel.TextTransparency = 0
		calloutOutline.Transparency = 0
		UiKit.pop(calloutLabel, 0.4)
		UiKit.playClick(1.6)
		task.delay(CALLOUT_HOLD, function()
			if calloutLabel.Text ~= callout.text then
				return
			end
			TweenService:Create(calloutLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(calloutOutline, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end)
	end

	local handle = {} :: FeedbackViewHandle

	handle.playBlockHit = function()
		local now = os.clock()
		comboCount = if now - lastHitClock <= COMBO_WINDOW then comboCount + 1 else 1
		lastHitClock = now
		comboGeneration += 1

		spawnPopup()
		if comboCount >= 2 then
			comboLabel.Text = string.format("x%d", comboCount)
			local heat = math.clamp((comboCount - 2) / 8, 0, 1)
			comboGradient.Color = ColorSequence.new(UiTheme.Colors.White, UiTheme.Colors.Gold:Lerp(UiTheme.Colors.Danger, heat))
			comboLabel.TextTransparency = 0
			comboOutline.Transparency = 0
			UiKit.pop(comboLabel, 0.35)
		end

		local callout = findCallout(comboCount)
		if callout ~= nil then
			playCallout(callout)
		end
		fadeCombo(comboGeneration)
	end

	handle.resetCombo = function()
		comboGeneration += 1
		comboCount = 0
		comboLabel.TextTransparency = 1
		comboOutline.Transparency = 1
	end

	handle.showToast = function(text: string, tone: ToastTone?, duration: number?)
		local accent = getToneColor(tone or "Info")
		toastSequence += 1

		local existing: { Frame } = {}
		for _, child in ipairs(toastStack:GetChildren()) do
			if child:IsA("Frame") then
				table.insert(existing, child)
			end
		end
		if #existing >= MAX_TOASTS then
			table.sort(existing, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			existing[1]:Destroy()
		end

		local toast = Instance.new("Frame")
		toast.Name = "Toast"
		toast.Size = UDim2.fromOffset(280, 44)
		toast.LayoutOrder = toastSequence
		toast.Parent = toastStack
		UiTheme.stylePanel(toast, { accent = accent, radius = 12, transparency = 0.06 })

		local bar = Instance.new("Frame")
		bar.Name = "ToneBar"
		bar.Position = UDim2.fromOffset(8, 10)
		bar.Size = UDim2.new(0, 5, 1, -20)
		bar.BackgroundColor3 = accent
		bar.BorderSizePixel = 0
		bar.Parent = toast
		UiTheme.addCorner(bar, 3)

		local label = UiTheme.createLabel(toast, "Text", text, UiTheme.Fonts.BodyBold, 13, UiTheme.Colors.Ink)
		label.Position = UDim2.fromOffset(22, 0)
		label.Size = UDim2.new(1, -30, 1, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd

		local slide = Instance.new("UIScale")
		slide.Scale = 0.8
		slide.Parent = toast
		TweenService:Create(slide, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

		task.delay(duration or TOAST_DURATION, function()
			if toast.Parent == nil then
				return
			end
			local fade = TweenService:Create(slide, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0,
			})
			fade:Play()
			fade.Completed:Connect(function()
				toast:Destroy()
			end)
		end)
	end

	handle.destroy = function()
		comboGeneration += 1
		centerGui:Destroy()
		toastGui:Destroy()
	end

	return handle
end

return table.freeze(FeedbackView)
