--!strict

-- Painel PUFF MACHINE (Fase 4.2): saldo de tickets, botão GIRAR, tabela de
-- chances sempre visível, contador da garantia de Épico e a revelação
-- animada do Puff sorteado. Só visual: o sorteio é do servidor; aqui a
-- cápsula gira até a resposta chegar (com um tempo mínimo de suspense).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local RewardConfig = require(ReplicatedStorage.Shared.config.RewardConfig)
local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileSnapshot = ProfileTypes.ProfileSnapshot
type PuffDefinition = PuffTypes.PuffDefinition
type PuffRarity = PuffTypes.PuffRarity

export type MachineReveal = {
	puffId: string,
	duplicate: boolean,
	refund: number,
}

export type PuffMachineViewHandle = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setProfile: (snapshot: ProfileSnapshot) -> (),
	showResult: (reveal: MachineReveal) -> (),
	showFailure: (message: string) -> (),
	destroy: () -> (),
}

type OddsRow = {
	rarity: PuffRarity,
	owned: TextLabel,
}

local GUI_NAME = "BlocoPuffPuffMachine"
local PANEL_SIZE = Vector2.new(780, 450)
local CABINET_WIDTH = 310
local ODDS_ROW = 36
local MIN_SPIN_TIME = RewardConfig.MachineRevealTime
local SPIN_STEP = 0.08
local SPIN_TIMEOUT = 8
local IDLE_COLOR = Color3.fromRGB(60, 48, 100)

local PuffMachineView = {}

local function machinePuffs(): { PuffDefinition }
	local list: { PuffDefinition } = {}
	for _, entry in ipairs(PuffCatalog.all()) do
		if entry.unlock.kind == "Machine" then
			table.insert(list, entry)
		end
	end
	return list
end

function PuffMachineView.new(
	playerGui: PlayerGui,
	onPull: () -> (),
	onOpened: () -> (),
	onShowPuffdex: () -> ()
): PuffMachineViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 27)
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
	UiTheme.stylePanel(card, { accent = UiTheme.Colors.Gold, radius = 20 })

	local title = UiTheme.createLabel(card, "Title", "🎰 PUFF MACHINE", UiTheme.Fonts.Display, 32, UiTheme.Colors.Gold)
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -100, 0, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	UiTheme.addTextOutline(title, 2.5)

	local closeButton = UiKit.createButton(card, {
		name = "Close",
		text = "✕",
		variant = "Neutral",
		size = UDim2.fromOffset(56, 48),
		position = UDim2.new(1, -14, 0, 10),
		anchorPoint = Vector2.new(1, 0),
		textSize = 24,
		zIndex = 4,
	})

	-- Máquina (esquerda).
	local cabinet = Instance.new("Frame")
	cabinet.Name = "Cabinet"
	cabinet.Position = UDim2.fromOffset(20, 64)
	cabinet.Size = UDim2.new(0, CABINET_WIDTH, 1, -104)
	cabinet.BackgroundColor3 = UiTheme.Colors.White
	cabinet.ZIndex = 3
	cabinet.Parent = card
	UiTheme.addCorner(cabinet, 16)
	UiTheme.addGradient(cabinet, UiTheme.Colors.BrandDeep, UiTheme.Colors.Panel, 90)
	UiTheme.addStroke(cabinet, UiTheme.Colors.Gold, 2.5)

	local capsule = Instance.new("Frame")
	capsule.Name = "Capsule"
	capsule.AnchorPoint = Vector2.new(0.5, 0)
	capsule.Position = UDim2.new(0.5, 0, 0, 14)
	capsule.Size = UDim2.fromOffset(116, 116)
	capsule.BackgroundColor3 = UiTheme.Colors.White
	capsule.ZIndex = 4
	capsule.Parent = cabinet
	UiTheme.addCorner(capsule, 999)
	UiTheme.addStroke(capsule, UiTheme.Colors.Outline, 3)
	local capsuleGradient = UiTheme.addGradient(capsule, IDLE_COLOR, IDLE_COLOR, 45)
	local capsuleScale = Instance.new("UIScale")
	capsuleScale.Parent = capsule
	local capsuleMark = UiTheme.createLabel(capsule, "Mark", "?", UiTheme.Fonts.Display, 50, UiTheme.Colors.InkSoft)
	capsuleMark.Size = UDim2.fromScale(1, 1)
	capsuleMark.ZIndex = 5

	local resultName = UiTheme.createLabel(cabinet, "ResultName", "Gire para ganhar um Puff!", UiTheme.Fonts.Display, 22, UiTheme.Colors.Ink)
	resultName.Position = UDim2.fromOffset(10, 136)
	resultName.Size = UDim2.new(1, -20, 0, 28)
	resultName.TextScaled = true
	resultName.ZIndex = 4
	UiTheme.addTextConstraint(resultName, 15, 22)
	UiTheme.addTextOutline(resultName, 1.5)

	local resultInfo = UiTheme.createLabel(cabinet, "ResultInfo", "", UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.InkSoft)
	resultInfo.Position = UDim2.fromOffset(10, 164)
	resultInfo.Size = UDim2.new(1, -20, 0, 22)
	resultInfo.ZIndex = 4

	local balance = UiTheme.createLabel(cabinet, "Balance", "🎟 0", UiTheme.Fonts.Display, 26, UiTheme.Colors.Gold)
	balance.Position = UDim2.fromOffset(10, 188)
	balance.Size = UDim2.new(1, -20, 0, 32)
	balance.ZIndex = 4
	UiTheme.addTextOutline(balance, 2)

	local pullButton = UiKit.createButton(cabinet, {
		name = "Pull",
		text = string.format("GIRAR  ·  %d 🎟", RewardConfig.MachineCost),
		variant = "Gold",
		size = UDim2.new(1, -28, 0, 52),
		position = UDim2.new(0.5, 0, 1, -12),
		anchorPoint = Vector2.new(0.5, 1),
		textSize = 21,
		zIndex = 5,
	})

	local puffdexButton = UiKit.createButton(cabinet, {
		name = "ShowPuffdex",
		text = "VER NO PUFFDEX",
		variant = "Neutral",
		size = UDim2.new(1, -28, 0, 40),
		position = UDim2.new(0.5, 0, 1, -70),
		anchorPoint = Vector2.new(0.5, 1),
		textSize = 17,
		zIndex = 5,
	})
	puffdexButton.root.Visible = false

	-- Chances e regras (direita).
	local info = Instance.new("Frame")
	info.Name = "Info"
	info.AnchorPoint = Vector2.new(1, 0)
	info.Position = UDim2.new(1, -20, 0, 64)
	info.Size = UDim2.new(1, -(CABINET_WIDTH + 60), 1, -104)
	info.BackgroundColor3 = UiTheme.Colors.Outline
	info.BackgroundTransparency = 0.35
	info.ZIndex = 3
	info.Parent = card
	UiTheme.addCorner(info, 14)

	local oddsTitle = UiTheme.createLabel(info, "OddsTitle", "CHANCES", UiTheme.Fonts.Display, 20, UiTheme.Colors.Ink)
	oddsTitle.Position = UDim2.fromOffset(16, 10)
	oddsTitle.Size = UDim2.new(1, -32, 0, 24)
	oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
	oddsTitle.ZIndex = 4

	local rows: { OddsRow } = {}
	for index, weight in ipairs(RewardConfig.MachineOdds) do
		local rarityInfo = PuffCatalog.rarity(weight.rarity)
		local y = 40 + (index - 1) * ODDS_ROW
		local dot = Instance.new("Frame")
		dot.Position = UDim2.fromOffset(16, y + 8)
		dot.Size = UDim2.fromOffset(16, 16)
		dot.BackgroundColor3 = rarityInfo.color
		dot.ZIndex = 4
		dot.Parent = info
		UiTheme.addCorner(dot, 999)
		local name = UiTheme.createLabel(info, `Odds{weight.rarity}`, rarityInfo.label, UiTheme.Fonts.BodyBold, 18, rarityInfo.color)
		name.Position = UDim2.fromOffset(40, y)
		name.Size = UDim2.new(0.45, -40, 0, 32)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 4
		local percent = UiTheme.createLabel(info, `Percent{weight.rarity}`, `{weight.percent}%`, UiTheme.Fonts.Display, 19, UiTheme.Colors.Ink)
		percent.Position = UDim2.new(0.45, 0, 0, y)
		percent.Size = UDim2.new(0.25, 0, 0, 32)
		percent.ZIndex = 4
		local owned = UiTheme.createLabel(info, `Owned{weight.rarity}`, "", UiTheme.Fonts.Body, 15, UiTheme.Colors.InkSoft)
		owned.Position = UDim2.new(0.7, 0, 0, y)
		owned.Size = UDim2.new(0.3, -16, 0, 32)
		owned.TextXAlignment = Enum.TextXAlignment.Right
		owned.ZIndex = 4
		table.insert(rows, { rarity = weight.rarity, owned = owned })
	end

	local rulesTop = 40 + #RewardConfig.MachineOdds * ODDS_ROW + 6
	local pityLabel = UiTheme.createLabel(info, "Pity", "", UiTheme.Fonts.BodyBold, 16, UiTheme.Colors.Gold)
	pityLabel.Position = UDim2.fromOffset(16, rulesTop)
	pityLabel.Size = UDim2.new(1, -32, 0, 42)
	pityLabel.TextXAlignment = Enum.TextXAlignment.Left
	pityLabel.ZIndex = 4

	local rules = UiTheme.createLabel(
		info,
		"Rules",
		string.format(
			"Repetido devolve %d 🎟.\nTickets saem jogando: partida, Top 3, vitória e subir de nível.",
			RewardConfig.DuplicateRefund
		),
		UiTheme.Fonts.Body,
		15,
		UiTheme.Colors.InkSoft
	)
	rules.Position = UDim2.fromOffset(16, rulesTop + 46)
	rules.Size = UDim2.new(1, -32, 0, 70)
	rules.TextXAlignment = Enum.TextXAlignment.Left
	rules.TextYAlignment = Enum.TextYAlignment.Top
	rules.ZIndex = 4

	local footer = UiTheme.createLabel(card, "Footer", "Sem compras: tickets só saem jogando. Puffs não dão vantagem.", UiTheme.Fonts.Body, 15, UiTheme.Colors.InkSoft)
	footer.Position = UDim2.new(0, 20, 1, -34)
	footer.Size = UDim2.new(1, -40, 0, 22)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.ZIndex = 3

	local pool = machinePuffs()
	local tickets = 0
	local ownedIds: { [string]: boolean } = {}
	local spinning = false
	local spinToken = 0
	local spinStartedAt = 0

	local function setCapsule(definition: PuffDefinition?)
		if definition == nil then
			capsuleGradient.Color = ColorSequence.new(IDLE_COLOR, IDLE_COLOR)
			capsuleMark.Visible = true
		else
			capsuleGradient.Color = ColorSequence.new(definition.style.trailStart, definition.style.trailEnd)
			capsuleMark.Visible = false
		end
	end

	local function refreshButton()
		if spinning then
			pullButton.setEnabled(false)
			pullButton.setText("GIRANDO…")
		elseif tickets < RewardConfig.MachineCost then
			pullButton.setEnabled(false)
			pullButton.setText(string.format("FALTAM %d 🎟", RewardConfig.MachineCost - tickets))
		else
			pullButton.setEnabled(true)
			pullButton.setText(string.format("GIRAR  ·  %d 🎟", RewardConfig.MachineCost))
		end
	end

	local function refreshInfo(pity: number)
		balance.Text = string.format("🎟 %d", tickets)
		for _, row in ipairs(rows) do
			local have, total = 0, 0
			for _, entry in ipairs(pool) do
				if entry.rarity == row.rarity then
					total += 1
					if ownedIds[entry.id] then
						have += 1
					end
				end
			end
			row.owned.Text = string.format("%d/%d", have, total)
		end
		local left = math.max(1, RewardConfig.PityThreshold - pity)
		pityLabel.Text = if left <= 1
			then "O próximo giro é Épico ou melhor!"
			else string.format("Épico ou melhor garantido em até %d giros", left)
		refreshButton()
	end

	local function stopSpin()
		spinning = false
		spinToken += 1
		capsule.Rotation = 0
		refreshButton()
	end

	local function startSpin()
		spinning = true
		spinToken += 1
		local token = spinToken
		spinStartedAt = os.clock()
		puffdexButton.root.Visible = false
		resultName.Text = "Girando…"
		resultName.TextColor3 = UiTheme.Colors.Ink
		resultInfo.Text = ""
		refreshButton()
		task.spawn(function()
			local step = 0
			while spinning and spinToken == token do
				step += 1
				setCapsule(pool[(step % #pool) + 1])
				capsule.Rotation = if step % 2 == 0 then 6 else -6
				if step % 3 == 0 then
					UiKit.playClick(1 + (step % 5) * 0.08)
				end
				if os.clock() - spinStartedAt > SPIN_TIMEOUT then
					stopSpin()
					setCapsule(nil)
					resultName.Text = "A máquina engasgou. Tente de novo!"
					return
				end
				task.wait(SPIN_STEP)
			end
		end)
	end

	local handle = {} :: PuffMachineViewHandle

	handle.showResult = function(reveal: MachineReveal)
		local definition = PuffCatalog.get(reveal.puffId)
		if definition == nil then
			stopSpin()
			return
		end
		local token = spinToken
		local wait = math.max(0, MIN_SPIN_TIME - (os.clock() - spinStartedAt))
		task.delay(wait, function()
			if token ~= spinToken then
				return
			end
			stopSpin()
			local rarityInfo = PuffCatalog.rarity(definition.rarity)
			setCapsule(definition)
			capsuleScale.Scale = 1.35
			TweenService:Create(capsuleScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			UiKit.playClick(if definition.rarity == "Legendary" then 2 else 1.5)
			resultName.Text = definition.name
			resultName.TextColor3 = rarityInfo.color
			resultInfo.Text = if reveal.duplicate
				then string.format("%s · repetido, +%d 🎟", rarityInfo.label, reveal.refund)
				else string.format("%s · NOVO!", rarityInfo.label)
			puffdexButton.root.Visible = true
		end)
	end

	handle.showFailure = function(message: string)
		stopSpin()
		setCapsule(nil)
		resultName.Text = message
		resultName.TextColor3 = UiTheme.Colors.Ink
		resultInfo.Text = ""
	end

	handle.open = function()
		screenGui.Enabled = true
		responsive.pop(0.9, 0.25)
		onOpened()
	end

	handle.close = function()
		screenGui.Enabled = false
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.setProfile = function(snapshot: ProfileSnapshot)
		tickets = snapshot.tickets
		local nextOwned: { [string]: boolean } = {}
		for _, item in ipairs(snapshot.puffs) do
			nextOwned[item.id] = true
		end
		ownedIds = nextOwned
		refreshInfo(snapshot.machinePity)
	end

	handle.destroy = function()
		spinToken += 1
		responsive.destroy()
		screenGui:Destroy()
	end

	pullButton.button.Activated:Connect(function()
		if spinning or tickets < RewardConfig.MachineCost then
			return
		end
		UiKit.playClick(1.3)
		startSpin()
		onPull()
	end)

	puffdexButton.button.Activated:Connect(function()
		UiKit.playClick()
		onShowPuffdex()
	end)

	closeButton.button.Activated:Connect(function()
		UiKit.playClick()
		handle.close()
	end)

	refreshInfo(0)
	return handle
end

return table.freeze(PuffMachineView)
