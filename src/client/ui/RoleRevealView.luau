--!strict

-- Papel no Assassinato no Casarão (Fase 5E): a roleta em tela cheia da
-- abertura (os papéis giram e param no do jogador, com cor própria e o
-- objetivo em uma frase), o selo fixo no alto da tela durante a partida e o
-- painel do fim, que revela quem era quem.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local UiTheme = require(script.Parent.UiTheme)
local ResponsiveScale = require(script.Parent.ResponsiveScale)

local T = Lang.t
local GUI_NAME = "BlocoPuffRoleReveal"
local DISPLAY_ORDER = 30
local CARD_SIZE = Vector2.new(520, 300)
local BADGE_SIZE = Vector2.new(300, 56)
-- Faixa no topo: a tela de resultado ocupa o centro.
local REVEAL_SIZE = Vector2.new(640, 96)
local SPIN_ORDER = { "Innocent", "Sheriff", "Murderer" }
-- Intervalo entre trocas da roleta: começa rápido e vai desacelerando.
local SPIN_FIRST_STEP = 0.06
local SPIN_GROWTH = 1.18
local REVEAL_SECONDS = 7
local TICK_SOUND = "rbxasset://sounds/clickfast.wav"
local LAND_SOUND = "rbxasset://sounds/electronicpingshort.wav"

export type RoleInfo = {
	icon: string,
	title: string,
	goal: string,
	color: Color3,
}

export type RevealData = {
	murderer: string,
	sheriff: string,
	hero: string,
	-- "Murderer", "Innocents" ou "".
	winner: string,
}

export type RoleRevealHandle = {
	spin: (role: string, seconds: number) -> (),
	setBadge: (role: string?) -> (),
	showReveal: (data: RevealData) -> (),
	hide: () -> (),
}

local RoleRevealView = {}

function RoleRevealView.info(role: string): RoleInfo
	if role == "Murderer" then
		return { icon = "🔪", title = T("ASSASSINO"), goal = T("Elimine todos sem ser pego pelo Xerife"), color = Color3.fromRGB(255, 82, 96) }
	elseif role == "Sheriff" then
		return { icon = "🔫", title = T("XERIFE"), goal = T("Descubra o Assassino e acerte-o · errar elimina você"), color = Color3.fromRGB(92, 170, 255) }
	elseif role == "Hero" then
		return { icon = "🦸", title = T("HERÓI"), goal = T("Você pegou a arma · acerte o Assassino"), color = UiTheme.Colors.Gold }
	end
	return { icon = "😇", title = T("INOCENTE"), goal = T("Fuja, colete moedas e pegue a arma se ela cair"), color = UiTheme.Colors.Green }
end

local function playSound(id: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	SoundService:PlayLocalSound(sound)
	task.delay(2, function()
		sound:Destroy()
	end)
end

local function panel(parent: Instance, name: string, size: Vector2, anchor: Vector2, position: UDim2): (Frame, UIStroke)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.Visible = false
	frame.Parent = parent
	local stroke = UiTheme.stylePanel(frame, { accent = UiTheme.Colors.Gold, radius = 18 })
	stroke.Thickness = 4
	ResponsiveScale.attach(frame, Vector2.new(1280, 720), 0.6, 1.1)
	return frame, stroke
end

local function textLabel(parent: Instance, name: string, font: Enum.Font, size: number, position: UDim2, height: UDim2): TextLabel
	local label = UiTheme.createLabel(parent, name, "", font, size)
	label.Position = position
	label.Size = height
	label.TextScaled = true
	UiTheme.addTextOutline(label, 2)
	return label
end

function RoleRevealView.create(playerGui: PlayerGui): RoleRevealHandle
	local gui = UiTheme.createScreenGui(GUI_NAME, playerGui, DISPLAY_ORDER)
	gui.IgnoreGuiInset = true

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.35
	dim.Visible = false
	dim.Parent = gui

	local card, cardStroke = panel(gui, "RoleCard", CARD_SIZE, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	local header = textLabel(card, "Header", Enum.Font.GothamBold, 22, UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.12))
	header.Text = T("VOCÊ É...")
	local icon = textLabel(card, "Icon", Enum.Font.FredokaOne, 60, UDim2.fromScale(0.05, 0.2), UDim2.fromScale(0.9, 0.3))
	local title = textLabel(card, "Title", Enum.Font.FredokaOne, 54, UDim2.fromScale(0.05, 0.5), UDim2.fromScale(0.9, 0.2))
	local goal = textLabel(card, "Goal", Enum.Font.GothamBold, 22, UDim2.fromScale(0.07, 0.74), UDim2.fromScale(0.86, 0.18))

	local badge, badgeStroke = panel(gui, "RoleBadge", BADGE_SIZE, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 64))
	local badgeLabel = textLabel(badge, "Label", Enum.Font.FredokaOne, 26, UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.8))

	local reveal, revealStroke = panel(gui, "Reveal", REVEAL_SIZE, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8))
	local revealTitle = textLabel(reveal, "Winner", Enum.Font.FredokaOne, 34, UDim2.fromScale(0.04, 0.06), UDim2.fromScale(0.92, 0.5))
	local revealLines = textLabel(reveal, "Lines", Enum.Font.GothamBold, 22, UDim2.fromScale(0.04, 0.58), UDim2.fromScale(0.92, 0.34))

	local spinToken = 0
	local revealToken = 0
	local badgeRole: string? = nil

	local function paint(role: string)
		local info = RoleRevealView.info(role)
		icon.Text = info.icon
		title.Text = info.title
		title.TextColor3 = info.color
		cardStroke.Color = info.color
	end

	local handle = {} :: RoleRevealHandle

	handle.setBadge = function(role: string?)
		badgeRole = role
		if role == nil then
			badge.Visible = false
			return
		end
		local info = RoleRevealView.info(role)
		badgeLabel.Text = `{info.icon} {info.title}`
		badgeLabel.TextColor3 = info.color
		badgeStroke.Color = info.color
		badge.Visible = not card.Visible
	end

	handle.spin = function(role: string, seconds: number)
		spinToken += 1
		local token = spinToken
		dim.Visible = true
		card.Visible = true
		badge.Visible = false
		goal.Text = ""
		header.Text = T("VOCÊ É...")
		task.spawn(function()
			-- Gira desacelerando até o tempo da roleta e para no papel.
			local spinTime = math.max(1, seconds - 1)
			local step = SPIN_FIRST_STEP
			local index = 1
			local spent = 0
			while spent < spinTime and token == spinToken do
				paint(SPIN_ORDER[index])
				playSound(TICK_SOUND, 0.35)
				task.wait(step)
				spent += step
				step *= SPIN_GROWTH
				index = (index % #SPIN_ORDER) + 1
			end
			if token ~= spinToken then
				return
			end
			paint(role)
			local info = RoleRevealView.info(role)
			goal.Text = info.goal
			playSound(LAND_SOUND, 0.8)
			card.Size = UDim2.fromOffset(CARD_SIZE.X * 0.8, CARD_SIZE.Y * 0.8)
			TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y) }):Play()
			task.wait(2.2)
			if token ~= spinToken then
				return
			end
			card.Visible = false
			dim.Visible = false
			handle.setBadge(badgeRole or role)
		end)
	end

	handle.showReveal = function(data: RevealData)
		revealToken += 1
		local token = revealToken
		local murdererWon = data.winner == "Murderer"
		revealTitle.Text = if murdererWon then T("🔪 O ASSASSINO VENCEU!") elseif data.winner == "Innocents" then T("😇 OS INOCENTES VENCERAM!") else T("FIM DA PARTIDA")
		local color = if murdererWon then RoleRevealView.info("Murderer").color else UiTheme.Colors.Green
		revealTitle.TextColor3 = color
		revealStroke.Color = color
		local lines = { T("🔪 Assassino: %s", if data.murderer ~= "" then data.murderer else "—") }
		if data.sheriff ~= "" then
			table.insert(lines, T("🔫 Xerife: %s", data.sheriff))
		end
		if data.hero ~= "" then
			table.insert(lines, T("🦸 Herói: %s", data.hero))
		end
		revealLines.Text = table.concat(lines, "   ·   ")
		reveal.Visible = true
		task.delay(REVEAL_SECONDS, function()
			if token == revealToken then
				reveal.Visible = false
			end
		end)
	end

	handle.hide = function()
		spinToken += 1
		dim.Visible = false
		card.Visible = false
		badgeRole = nil
		badge.Visible = false
	end

	return handle
end

return table.freeze(RoleRevealView)
