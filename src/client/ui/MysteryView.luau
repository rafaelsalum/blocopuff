--!strict

-- Tela dos Mistérios do Barão (Fase 5C.3, parte 2): abre no lugar de cada
-- mistério e manda a tentativa ao servidor (que confere).
--   * Relógio: ◀ ▶ nas horas e nos minutos e ACERTAR;
--   * Velas: tocar nas quatro velas na ordem (cada uma acende); errou,
--     todas apagam;
--   * Cofrinho: três rodinhas ▲ ▼ e ABRIR.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClockFace = require(ReplicatedStorage.Shared.modules.ClockFace)
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local MysteryConfig = require(ReplicatedStorage.Shared.config.MysteryConfig)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

export type MysteryViewHandle = {
	-- `candles`: índices das cores das velas, da esquerda para a direita.
	open: (id: string, solved: boolean, candles: { number }?) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	showWrong: () -> (),
	showLocked: (seconds: number) -> (),
	destroy: () -> (),
}

type CandleButton = { flame: Frame, button: TextButton, cup: Frame }

local GUI_NAME = "BlocoPuffMystery"
local PANEL_SIZE = Vector2.new(560, 400)
local CONTENT_Y = 108
local CONTENT_HEIGHT = 210
local FLAME = Color3.fromRGB(255, 170, 60)

local MysteryView = {}

local function stepper(parent: Instance, name: string, position: UDim2, onStep: (delta: number) -> ()): TextLabel
	local row = Instance.new("Frame")
	row.Name = name
	row.Position = position
	row.Size = UDim2.fromOffset(200, 48)
	row.BackgroundTransparency = 1
	row.ZIndex = 4
	row.Parent = parent
	for _, side in ipairs({ -1, 1 }) do
		local button = UiKit.createButton(row, {
			name = if side < 0 then "Less" else "More",
			text = if side < 0 then "◀" else "▶",
			variant = "Neutral",
			size = UDim2.fromOffset(52, 46),
			position = if side < 0 then UDim2.fromOffset(0, 0) else UDim2.new(1, 0, 0, 0),
			anchorPoint = if side < 0 then Vector2.new(0, 0) else Vector2.new(1, 0),
			textSize = 20,
			zIndex = 5,
		})
		button.button.Activated:Connect(function()
			UiKit.playClick(1.1)
			onStep(side)
		end)
	end
	local value = UiTheme.createLabel(row, "Value", "", UiTheme.Fonts.Display, 28, UiTheme.Colors.Ink)
	value.Position = UDim2.fromOffset(52, 0)
	value.Size = UDim2.new(1, -104, 1, 0)
	value.ZIndex = 5
	return value
end

function MysteryView.new(playerGui: PlayerGui, onSubmit: (id: string, answer: { number }) -> ()): MysteryViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 28)
	screenGui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	local responsive = ResponsiveScale.fit(root, PANEL_SIZE, ResponsiveScale.Modal)

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 20)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 2
	card.Parent = root
	UiTheme.stylePanel(card, { accent = UiTheme.Colors.Purple, radius = 20 })
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local title = UiTheme.createLabel(card, "Title", "", UiTheme.Fonts.Display, 28, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -100, 0, 38)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	UiTheme.addTextOutline(title, 2)
	local hint = UiTheme.createLabel(card, "Hint", "", UiTheme.Fonts.BodyBold, 15, UiTheme.Colors.InkSoft)
	hint.Position = UDim2.fromOffset(20, 54)
	hint.Size = UDim2.new(1, -40, 0, 44)
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.ZIndex = 3

	local closeButton = UiKit.createButton(card, {
		name = "Close",
		text = "X",
		variant = "Neutral",
		size = UDim2.fromOffset(52, 46),
		position = UDim2.new(1, -14, 0, 10),
		anchorPoint = Vector2.new(1, 0),
		textSize = 22,
		zIndex = 4,
	})
	local submit = UiKit.createButton(card, {
		name = "Submit",
		text = "",
		variant = "Gold",
		size = UDim2.fromOffset(240, 50),
		position = UDim2.new(0.5, 0, 1, -16),
		anchorPoint = Vector2.new(0.5, 1),
		textSize = 20,
		zIndex = 4,
	})
	local status = UiTheme.createLabel(card, "Status", "", UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.Danger)
	status.Position = UDim2.new(0, 20, 1, -96)
	status.Size = UDim2.new(1, -40, 0, 24)
	status.ZIndex = 4

	local function page(name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Position = UDim2.fromOffset(20, CONTENT_Y)
		frame.Size = UDim2.new(1, -40, 0, CONTENT_HEIGHT)
		frame.BackgroundTransparency = 1
		frame.Visible = false
		frame.ZIndex = 3
		frame.Parent = card
		return frame
	end

	-- Relógio.
	local clockPage = page("Clock")
	local clockHolder = Instance.new("Frame")
	clockHolder.Position = UDim2.fromOffset(20, 0)
	clockHolder.Size = UDim2.fromOffset(180, 180)
	clockHolder.BackgroundTransparency = 1
	clockHolder.ZIndex = 4
	clockHolder.Parent = clockPage
	local clockFace = ClockFace.draw(clockHolder, 5)
	local hour, minute = 12, 0
	local hourValue: TextLabel
	local minuteValue: TextLabel
	local function renderClock()
		ClockFace.set(clockFace, hour, minute)
		hourValue.Text = tostring(hour)
		minuteValue.Text = string.format("%02d", minute)
	end
	local hoursLabel = UiTheme.createLabel(clockPage, "HoursLabel", Lang.t("Horas"), UiTheme.Fonts.BodyBold, 15, UiTheme.Colors.InkSoft)
	hoursLabel.Position = UDim2.fromOffset(260, 6)
	hoursLabel.Size = UDim2.fromOffset(200, 20)
	hoursLabel.ZIndex = 4
	hourValue = stepper(clockPage, "Hours", UDim2.fromOffset(260, 28), function(delta: number)
		hour = ((hour - 1 + delta) % 12) + 1
		renderClock()
	end)
	local minutesLabel = UiTheme.createLabel(clockPage, "MinutesLabel", Lang.t("Minutos"), UiTheme.Fonts.BodyBold, 15, UiTheme.Colors.InkSoft)
	minutesLabel.Position = UDim2.fromOffset(260, 96)
	minutesLabel.Size = UDim2.fromOffset(200, 20)
	minutesLabel.ZIndex = 4
	minuteValue = stepper(clockPage, "Minutes", UDim2.fromOffset(260, 118), function(delta: number)
		minute = (minute + delta * MysteryConfig.MinuteStep) % 60
		renderClock()
	end)

	-- Velas.
	local candlePage = page("Candles")
	local candleButtons: { CandleButton } = {}
	local lit: { number } = {}
	for index = 1, #MysteryConfig.CandleColors do
		local button = Instance.new("TextButton")
		button.Name = `Candle{index}`
		button.Position = UDim2.new((index - 1) / #MysteryConfig.CandleColors, 12, 0, 0)
		button.Size = UDim2.new(1 / #MysteryConfig.CandleColors, -24, 1, -10)
		button.BackgroundColor3 = UiTheme.Colors.Surface
		button.Text = ""
		button.AutoButtonColor = true
		button.ZIndex = 4
		button.Parent = candlePage
		UiTheme.addCorner(button, 14)
		UiTheme.addStroke(button, UiTheme.Colors.Border, 1.5)
		local flame = Instance.new("Frame")
		flame.Name = "Flame"
		flame.AnchorPoint = Vector2.new(0.5, 0)
		flame.Position = UDim2.new(0.5, 0, 0, 14)
		flame.Size = UDim2.fromOffset(22, 32)
		flame.BackgroundColor3 = FLAME
		flame.Visible = false
		flame.ZIndex = 6
		flame.Parent = button
		UiTheme.addCorner(flame, 999)
		local wax = Instance.new("Frame")
		wax.Name = "Wax"
		wax.AnchorPoint = Vector2.new(0.5, 0)
		wax.Position = UDim2.new(0.5, 0, 0, 48)
		wax.Size = UDim2.fromOffset(26, 70)
		wax.BackgroundColor3 = Color3.fromRGB(250, 246, 232)
		wax.ZIndex = 5
		wax.Parent = button
		UiTheme.addCorner(wax, 6)
		local cup = Instance.new("Frame")
		cup.Name = "Cup"
		cup.AnchorPoint = Vector2.new(0.5, 0)
		cup.Position = UDim2.new(0.5, 0, 0, 112)
		cup.Size = UDim2.fromOffset(64, 40)
		cup.ZIndex = 6
		cup.Parent = button
		UiTheme.addCorner(cup, 999)
		UiTheme.addStroke(cup, UiTheme.Colors.Outline, 2)
		table.insert(candleButtons, { flame = flame, button = button, cup = cup })
	end

	-- Cofrinho.
	local safePage = page("Safe")
	local digits = { 0, 0, 0 }
	local digitLabels: { TextLabel } = {}
	for index = 1, 3 do
		local column = Instance.new("Frame")
		column.Name = `Wheel{index}`
		column.AnchorPoint = Vector2.new(0.5, 0)
		column.Position = UDim2.new(0.5, (index - 2) * 120, 0, 0)
		column.Size = UDim2.fromOffset(96, 200)
		column.BackgroundTransparency = 1
		column.ZIndex = 4
		column.Parent = safePage
		local value = UiTheme.createLabel(column, "Digit", "0", UiTheme.Fonts.Display, 56, UiTheme.Colors.Gold)
		value.Position = UDim2.fromOffset(0, 54)
		value.Size = UDim2.new(1, 0, 0, 90)
		value.BackgroundTransparency = 0
		value.BackgroundColor3 = UiTheme.Colors.Outline
		value.ZIndex = 5
		UiTheme.addCorner(value, 12)
		table.insert(digitLabels, value)
		for _, side in ipairs({ 1, -1 }) do
			local button = UiKit.createButton(column, {
				name = if side > 0 then "Up" else "Down",
				text = if side > 0 then "▲" else "▼",
				variant = "Neutral",
				size = UDim2.new(1, 0, 0, 46),
				position = if side > 0 then UDim2.fromOffset(0, 0) else UDim2.new(0, 0, 1, 0),
				anchorPoint = if side > 0 then Vector2.new(0, 0) else Vector2.new(0, 1),
				textSize = 20,
				zIndex = 5,
			})
			button.button.Activated:Connect(function()
				UiKit.playClick(1.2)
				digits[index] = (digits[index] + side) % 10
				value.Text = tostring(digits[index])
			end)
		end
	end

	local currentId = ""
	local candleColors: { number } = {}
	local alreadySolved = false

	local function renderCandles()
		for index, item in ipairs(candleButtons) do
			local colorIndex = candleColors[index]
			local info = if colorIndex ~= nil then MysteryConfig.CandleColors[colorIndex] else nil
			item.button.Visible = info ~= nil
			if info ~= nil then
				item.cup.BackgroundColor3 = info.color
			end
			item.flame.Visible = alreadySolved or table.find(lit, index) ~= nil
		end
	end

	local handle = {} :: MysteryViewHandle

	local function send()
		if currentId == "Clock" then
			onSubmit("Clock", { hour, minute })
		elseif currentId == "Candles" then
			onSubmit("Candles", table.clone(lit))
		elseif currentId == "Safe" then
			onSubmit("Safe", table.clone(digits))
		end
	end

	for index, item in ipairs(candleButtons) do
		item.button.Activated:Connect(function()
			if currentId ~= "Candles" or alreadySolved or table.find(lit, index) ~= nil then
				return
			end
			UiKit.playClick(1 + #lit * 0.15)
			table.insert(lit, index)
			status.Text = ""
			renderCandles()
			if #lit == #candleColors then
				send()
			end
		end)
	end

	handle.open = function(id: string, solved: boolean, candles: { number }?)
		local info = (MysteryConfig.Info :: any)[id]
		if info == nil or id == "Piano" then
			return
		end
		currentId = id
		alreadySolved = solved
		title.Text = `{info.icon} {Lang.t(info.name)}`
		hint.Text = if solved then Lang.t("✓ Você já resolveu este mistério!") else Lang.t(info.hint)
		hint.TextColor3 = if solved then UiTheme.Colors.Green else UiTheme.Colors.InkSoft
		status.Text = ""
		-- Resolvido: sem controles (relógio e cofre); as velas aparecem acesas.
		clockPage.Visible = id == "Clock" and not solved
		candlePage.Visible = id == "Candles"
		safePage.Visible = id == "Safe" and not solved
		table.clear(lit)
		candleColors = if candles ~= nil then table.clone(candles) else {}
		renderCandles()
		renderClock()
		submit.root.Visible = not solved and id ~= "Candles"
		submit.setText(if id == "Clock" then Lang.t("ACERTAR") else Lang.t("ABRIR"))
		screenGui.Enabled = true
		responsive.pop(0.9, 0.25)
	end

	handle.close = function()
		screenGui.Enabled = false
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.showWrong = function()
		UiKit.playClick(0.6)
		status.Text = Lang.t("Não foi dessa vez… tente de novo!")
		table.clear(lit)
		renderCandles()
		cardScale.Scale = 0.96
		TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	end

	handle.showLocked = function(seconds: number)
		handle.showWrong()
		status.Text = Lang.t("Muitas tentativas! Pense nas pistas e tente de novo em %d s.", math.max(1, math.floor(seconds)))
	end

	handle.destroy = function()
		responsive.destroy()
		screenGui:Destroy()
	end

	submit.button.Activated:Connect(function()
		UiKit.playClick(1.3)
		send()
	end)
	closeButton.button.Activated:Connect(function()
		UiKit.playClick()
		handle.close()
	end)

	return handle
end

return table.freeze(MysteryView)
