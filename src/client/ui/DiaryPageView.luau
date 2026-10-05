--!strict

-- Leitura de uma página do Diário do Barão (Fase 5C.3): folha de
-- pergaminho com o título, o texto em letra de mão e a assinatura do Barão.
-- As setas passam pelas páginas já encontradas. Abre ao pegar uma página
-- no Casarão e ao tocar numa página encontrada no Álbum.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local RelicCatalog = require(ReplicatedStorage.Shared.config.RelicCatalog)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

export type DiaryPageViewHandle = {
	-- Mostra a página `relicId`; `found` diz quais já foram encontradas.
	show: (relicId: string, found: { [string]: any }) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffDiaryPage"
local PANEL_SIZE = Vector2.new(560, 380)
local PAPER = Color3.fromRGB(244, 230, 196)
local PAPER_EDGE = Color3.fromRGB(214, 186, 138)
local INK = Color3.fromRGB(74, 50, 30)
local INK_SOFT = Color3.fromRGB(128, 96, 64)
local HANDWRITING = Enum.Font.Kalam

local DiaryPageView = {}

function DiaryPageView.new(playerGui: PlayerGui): DiaryPageViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 29)
	screenGui.Enabled = false

	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = UiTheme.Colors.Shadow
	dim.BackgroundTransparency = 0.45
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Parent = screenGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	local responsive = ResponsiveScale.fit(root, PANEL_SIZE, ResponsiveScale.Modal)

	UiTheme.createShadow(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 18)
	local paper = Instance.new("Frame")
	paper.Name = "Paper"
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = UiTheme.Colors.White
	paper.ZIndex = 2
	paper.Parent = root
	UiTheme.addCorner(paper, 14)
	UiTheme.addGradient(paper, PAPER, PAPER_EDGE, 90)
	UiTheme.addStroke(paper, Color3.fromRGB(150, 110, 60), 3)

	local header = UiTheme.createLabel(paper, "Header", "", UiTheme.Fonts.BodyBold, 15, INK_SOFT)
	header.Position = UDim2.fromOffset(24, 14)
	header.Size = UDim2.new(1, -110, 0, 22)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.ZIndex = 3

	local title = UiTheme.createLabel(paper, "Title", "", UiTheme.Fonts.Display, 30, INK)
	title.Position = UDim2.fromOffset(24, 38)
	title.Size = UDim2.new(1, -48, 0, 38)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	title.ZIndex = 3
	UiTheme.addTextConstraint(title, 18, 30)

	local line = Instance.new("Frame")
	line.Name = "Line"
	line.Position = UDim2.fromOffset(24, 80)
	line.Size = UDim2.new(1, -48, 0, 2)
	line.BackgroundColor3 = PAPER_EDGE
	line.BorderSizePixel = 0
	line.ZIndex = 3
	line.Parent = paper

	-- Letra de mão grande; páginas longas encolhem para caber.
	local body = UiTheme.createLabel(paper, "Body", "", HANDWRITING, 30, INK)
	body.Position = UDim2.fromOffset(24, 92)
	body.Size = UDim2.new(1, -48, 0, 188)
	body.TextWrapped = true
	body.TextScaled = true
	UiTheme.addTextConstraint(body, 18, 30)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 3

	local signature = UiTheme.createLabel(paper, "Signature", Lang.t("— Barão 🐾"), HANDWRITING, 22, INK_SOFT)
	signature.AnchorPoint = Vector2.new(1, 0)
	signature.Position = UDim2.new(1, -28, 0, 284)
	signature.Size = UDim2.fromOffset(220, 28)
	signature.TextXAlignment = Enum.TextXAlignment.Right
	signature.ZIndex = 3

	local closeButton = UiKit.createButton(paper, {
		name = "Close",
		text = "X",
		variant = "Neutral",
		size = UDim2.fromOffset(48, 42),
		position = UDim2.new(1, -12, 0, 10),
		anchorPoint = Vector2.new(1, 0),
		textSize = 22,
		zIndex = 4,
	})
	local previousButton = UiKit.createButton(paper, {
		name = "Previous",
		text = "◀",
		variant = "Neutral",
		size = UDim2.fromOffset(64, 44),
		position = UDim2.new(0, 24, 1, -14),
		anchorPoint = Vector2.new(0, 1),
		textSize = 20,
		zIndex = 4,
	})
	local nextButton = UiKit.createButton(paper, {
		name = "Next",
		text = "▶",
		variant = "Neutral",
		size = UDim2.fromOffset(64, 44),
		position = UDim2.new(1, -24, 1, -14),
		anchorPoint = Vector2.new(1, 1),
		textSize = 20,
		zIndex = 4,
	})
	local doneButton = UiKit.createButton(paper, {
		name = "Done",
		text = Lang.t("FECHAR"),
		variant = "Gold",
		size = UDim2.fromOffset(180, 44),
		position = UDim2.new(0.5, 0, 1, -14),
		anchorPoint = Vector2.new(0.5, 1),
		textSize = 18,
		zIndex = 4,
	})

	local pages = RelicCatalog.diary().relics
	local foundSet: { [string]: any } = {}
	local current = 0

	-- Próxima página encontrada a partir de `from`, andando `step` (±1).
	local function neighbour(from: number, step: number): number?
		local index = from + step
		while index >= 1 and index <= #pages do
			if foundSet[pages[index].id] ~= nil then
				return index
			end
			index += step
		end
		return nil
	end

	local function render()
		local definition = pages[current]
		if definition == nil then
			return
		end
		header.Text = Lang.t("📖 Diário do Barão · Página %d de %d", current, #pages)
		title.Text = Lang.t(definition.name)
		body.Text = Lang.t(definition.text)
		previousButton.root.Visible = neighbour(current, -1) ~= nil
		nextButton.root.Visible = neighbour(current, 1) ~= nil
	end

	local handle = {} :: DiaryPageViewHandle

	handle.show = function(relicId: string, found: { [string]: any })
		for index, definition in ipairs(pages) do
			if definition.id == relicId then
				current = index
				foundSet = found
				render()
				screenGui.Enabled = true
				responsive.pop(0.9, 0.25)
				return
			end
		end
	end

	handle.close = function()
		screenGui.Enabled = false
	end

	handle.isOpen = function(): boolean
		return screenGui.Enabled
	end

	handle.destroy = function()
		responsive.destroy()
		screenGui:Destroy()
	end

	local function turn(step: number)
		local target = neighbour(current, step)
		if target ~= nil then
			UiKit.playClick(1.05)
			current = target
			render()
		end
	end

	previousButton.button.Activated:Connect(function()
		turn(-1)
	end)
	nextButton.button.Activated:Connect(function()
		turn(1)
	end)
	for _, button in ipairs({ closeButton, doneButton }) do
		button.button.Activated:Connect(function()
			UiKit.playClick()
			handle.close()
		end)
	end
	-- Tocar fora da folha também fecha.
	dim.Activated:Connect(handle.close)

	return handle
end

return table.freeze(DiaryPageView)
