--!strict

-- Revelação da Puff Machine, por cima do painel: a tela escurece, uma
-- cápsula na cor da raridade aparece e treme cada vez mais forte, estoura
-- (clarão + confete) e mostra o cartão do Puff com a prévia animada, o nome,
-- a raridade e se é NOVO ou repetido. Épico e Lendário ganham raios girando,
-- fundo mais escuro e fanfarra própria. "CONTINUAR" fecha.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)
local PuffCardFx = require(script.Parent.PuffCardFx)
local PuffPreview = require(script.Parent.PuffPreview)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type PuffDefinition = PuffTypes.PuffDefinition
type PuffRarity = PuffTypes.PuffRarity
type CardFxHandle = PuffCardFx.CardFxHandle
type PuffPreviewHandle = PuffPreview.PuffPreviewHandle

export type RevealHandle = {
	play: (definition: PuffDefinition, duplicate: boolean, refund: number) -> (),
	hide: () -> (),
	isShowing: () -> boolean,
	destroy: () -> (),
}

type Confetti = {
	frame: Frame,
	position: Vector2,
	velocity: Vector2,
	spin: number,
	age: number,
	life: number,
}

type Stage = "Hidden" | "Shake" | "Card"

local POP_SOUND = "rbxassetid://9113263649"
local FANFARE: { [PuffRarity]: { id: string, speed: number, volume: number } } = {
	Common = { id = "rbxassetid://123582256549202", speed = 1, volume = 0.6 },
	Rare = { id = "rbxassetid://123582256549202", speed = 1.15, volume = 0.7 },
	Epic = { id = "rbxassetid://138190748214493", speed = 1, volume = 0.8 },
	Legendary = { id = "rbxassetid://84872960927850", speed = 1, volume = 0.9 },
}
local SHAKE_SECONDS: { [PuffRarity]: number } = { Common = 1, Rare = 1.1, Epic = 1.4, Legendary = 1.8 }
local CONFETTI_COUNT: { [PuffRarity]: number } = { Common = 18, Rare = 26, Epic = 40, Legendary = 56 }
local DIM: { [PuffRarity]: number } = { Common = 0.3, Rare = 0.3, Epic = 0.12, Legendary = 0.05 }
local CAPSULE_SIZE = 150
local CARD_SIZE = Vector2.new(320, 360)
local RAY_COUNT = 12
local RAY_SPEED = 25
local GRAVITY = 520

local PuffMachineReveal = {}

local function playSound(soundId: string, speed: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function isSpecial(rarity: PuffRarity): boolean
	return rarity == "Epic" or rarity == "Legendary"
end

function PuffMachineReveal.new(parent: GuiObject, zIndex: number): RevealHandle
	local overlay = Instance.new("TextButton")
	overlay.Name = "Reveal"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shadow
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.ZIndex = zIndex
	overlay.Parent = parent
	UiTheme.addCorner(overlay, 20)

	-- Raios (Épico e Lendário): faixas finas girando atrás do cartão.
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(560, 560)
	rays.BackgroundTransparency = 1
	rays.Visible = false
	rays.ZIndex = zIndex + 1
	rays.Parent = overlay
	local rayFrames: { Frame } = {}
	for index = 1, RAY_COUNT do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(1, 0, 0, 34)
		ray.Rotation = (index - 1) * (180 / RAY_COUNT)
		ray.BackgroundColor3 = UiTheme.Colors.White
		ray.BorderSizePixel = 0
		ray.ZIndex = zIndex + 1
		ray.Parent = rays
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.65, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
		table.insert(rayFrames, ray)
	end

	-- Cápsula (metade cor da raridade, metade branca, com faixa no meio).
	local capsule = Instance.new("Frame")
	capsule.Name = "Capsule"
	capsule.AnchorPoint = Vector2.new(0.5, 0.5)
	capsule.Position = UDim2.fromScale(0.5, 0.5)
	capsule.Size = UDim2.fromOffset(CAPSULE_SIZE, CAPSULE_SIZE)
	capsule.BackgroundColor3 = UiTheme.Colors.White
	capsule.ZIndex = zIndex + 2
	capsule.Parent = overlay
	UiTheme.addCorner(capsule, 999)
	local capsuleStroke = UiTheme.addStroke(capsule, UiTheme.Colors.White, 5)
	local capsuleGradient = Instance.new("UIGradient")
	capsuleGradient.Rotation = 90
	capsuleGradient.Parent = capsule
	local capsuleScale = Instance.new("UIScale")
	capsuleScale.Parent = capsule
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.5)
	band.Size = UDim2.new(1, 0, 0, 12)
	band.BackgroundColor3 = UiTheme.Colors.Outline
	band.BorderSizePixel = 0
	band.ZIndex = zIndex + 3
	band.Parent = capsule
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromScale(0.22, 0.14)
	shine.Size = UDim2.fromScale(0.24, 0.14)
	shine.Rotation = -30
	shine.BackgroundColor3 = UiTheme.Colors.White
	shine.BackgroundTransparency = 0.35
	shine.ZIndex = zIndex + 3
	shine.Parent = capsule
	UiTheme.addCorner(shine, 999)
	local question = UiTheme.createLabel(capsule, "Mark", "?", UiTheme.Fonts.Display, 54, UiTheme.Colors.White)
	question.Size = UDim2.fromScale(1, 1)
	question.ZIndex = zIndex + 4
	UiTheme.addTextOutline(question, 3)

	-- Cartão do Puff.
	local card = Instance.new("Frame")
	card.Name = "PuffCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	card.BackgroundColor3 = UiTheme.Colors.White
	card.Visible = false
	card.ZIndex = zIndex + 3
	card.Parent = overlay
	UiTheme.addCorner(card, 18)
	local cardGradient = UiTheme.addGradient(card, UiTheme.Colors.Surface, UiTheme.Colors.Panel, 90)
	local cardStroke = UiTheme.addStroke(card, UiTheme.Colors.White, 4)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local rarityLabel = UiTheme.createLabel(card, "Rarity", "", UiTheme.Fonts.Display, 22, UiTheme.Colors.White)
	rarityLabel.Position = UDim2.fromOffset(16, 10)
	rarityLabel.Size = UDim2.new(1, -32, 0, 28)
	rarityLabel.ZIndex = zIndex + 5
	UiTheme.addTextOutline(rarityLabel, 2)

	local window = Instance.new("Frame")
	window.Name = "PreviewWindow"
	window.Position = UDim2.fromOffset(20, 44)
	window.Size = UDim2.new(1, -40, 0, 128)
	window.BackgroundTransparency = 1
	window.ZIndex = zIndex + 4
	window.Parent = card

	local nameLabel = UiTheme.createLabel(card, "PuffName", "", UiTheme.Fonts.Display, 30, UiTheme.Colors.White)
	nameLabel.Position = UDim2.fromOffset(16, 180)
	nameLabel.Size = UDim2.new(1, -32, 0, 36)
	nameLabel.TextScaled = true
	nameLabel.ZIndex = zIndex + 5
	UiTheme.addTextConstraint(nameLabel, 18, 30)
	UiTheme.addTextOutline(nameLabel, 2.5)

	local lore = UiTheme.createLabel(card, "Lore", "", UiTheme.Fonts.Body, 14, UiTheme.Colors.InkSoft)
	lore.Position = UDim2.fromOffset(20, 218)
	lore.Size = UDim2.new(1, -40, 0, 36)
	lore.TextWrapped = true
	lore.ZIndex = zIndex + 5

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 258)
	badge.Size = UDim2.fromOffset(200, 30)
	badge.BackgroundColor3 = UiTheme.Colors.Green
	badge.Rotation = -3
	badge.ZIndex = zIndex + 5
	badge.Parent = card
	UiTheme.addCorner(badge, 10)
	UiTheme.addStroke(badge, UiTheme.Colors.Outline, 2)
	local badgeLabel = UiTheme.createLabel(badge, "Text", "", UiTheme.Fonts.Display, 18, UiTheme.Colors.White)
	badgeLabel.Size = UDim2.fromScale(1, 1)
	badgeLabel.ZIndex = zIndex + 6
	UiTheme.addTextOutline(badgeLabel, 2)

	local continueButton = UiKit.createButton(card, {
		name = "Continue",
		text = Lang.t("CONTINUAR"),
		variant = "Gold",
		size = UDim2.new(1, -40, 0, 46),
		position = UDim2.new(0.5, 0, 1, -12),
		anchorPoint = Vector2.new(0.5, 1),
		textSize = 20,
		zIndex = zIndex + 6,
	})

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = UiTheme.Colors.White
	flash.BackgroundTransparency = 1
	flash.ZIndex = zIndex + 9
	flash.Parent = overlay
	UiTheme.addCorner(flash, 20)

	local confettiLayer = Instance.new("Frame")
	confettiLayer.Name = "Confetti"
	confettiLayer.Size = UDim2.fromScale(1, 1)
	confettiLayer.BackgroundTransparency = 1
	confettiLayer.ZIndex = zIndex + 8
	confettiLayer.Parent = overlay

	local stage: Stage = "Hidden"
	local rarity: PuffRarity = "Common"
	local rarityColor = UiTheme.Colors.White
	local clock = 0
	local shakeSeconds = 1
	local lastShakeClick = 0
	local confetti: { Confetti } = {}
	local preview: PuffPreviewHandle? = nil
	local cardFx: CardFxHandle? = nil
	local connection: RBXScriptConnection? = nil
	local pending: { definition: PuffDefinition, duplicate: boolean, refund: number }? = nil

	local function clearConfetti()
		for _, piece in ipairs(confetti) do
			piece.frame:Destroy()
		end
		table.clear(confetti)
	end

	local function burstConfetti()
		local palette = { rarityColor, rarityColor:Lerp(UiTheme.Colors.White, 0.5), UiTheme.Colors.Gold, UiTheme.Colors.White }
		for _ = 1, CONFETTI_COUNT[rarity] or 18 do
			local frame = Instance.new("Frame")
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Size = UDim2.fromOffset(math.random(6, 12), math.random(8, 16))
			frame.BackgroundColor3 = palette[math.random(1, #palette)]
			frame.BorderSizePixel = 0
			frame.ZIndex = zIndex + 8
			frame.Parent = confettiLayer
			local angle = math.random() * math.pi * 2
			local speed = 220 + math.random() * 320
			table.insert(confetti, {
				frame = frame,
				-- Relativa ao meio do painel (o UIScale não desalinha).
				position = Vector2.zero,
				velocity = Vector2.new(math.cos(angle) * speed, math.sin(angle) * speed - 180),
				spin = (math.random() - 0.5) * 720,
				age = 0,
				life = 1.1 + math.random() * 0.8,
			})
		end
	end

	local function stepConfetti(dt: number)
		for index = #confetti, 1, -1 do
			local piece = confetti[index]
			piece.age += dt
			if piece.age >= piece.life then
				piece.frame:Destroy()
				table.remove(confetti, index)
			else
				piece.velocity = Vector2.new(piece.velocity.X * (1 - 0.8 * dt), piece.velocity.Y + GRAVITY * dt)
				piece.position += piece.velocity * dt
				piece.frame.Position = UDim2.new(0.5, piece.position.X, 0.5, piece.position.Y)
				piece.frame.Rotation += piece.spin * dt
				piece.frame.BackgroundTransparency = math.clamp((piece.age / piece.life - 0.6) / 0.4, 0, 1)
			end
		end
	end

	local function showCard()
		local current = pending
		if current == nil then
			return
		end
		local definition = current.definition
		stage = "Card"
		capsule.Visible = false
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		burstConfetti()
		playSound(POP_SOUND, 1, 0.7)
		local fanfare = FANFARE[rarity]
		playSound(fanfare.id, fanfare.speed, fanfare.volume)

		cardGradient.Color = ColorSequence.new(rarityColor:Lerp(UiTheme.Colors.Panel, 0.55), UiTheme.Colors.Panel)
		cardStroke.Color = rarityColor
		local fx: CardFxHandle = cardFx or PuffCardFx.decorate(card, cardStroke, rarity, rarityColor, zIndex + 4)
		cardFx = fx
		fx.setOwned(true)
		local previewHandle = preview
		if previewHandle == nil then
			previewHandle = PuffPreview.new(window, zIndex + 4)
			preview = previewHandle
		end
		previewHandle.setPuff(definition, true)
		rarityLabel.Text = Lang.t(PuffCatalog.rarity(rarity).label)
		rarityLabel.TextColor3 = rarityColor
		nameLabel.Text = Lang.t(definition.name)
		nameLabel.TextColor3 = rarityColor
		lore.Text = Lang.t(definition.lore)
		if current.duplicate then
			badge.BackgroundColor3 = UiTheme.Colors.SurfaceSoft
			badgeLabel.Text = Lang.t("Repetido · +%d 🎟", current.refund)
		else
			badge.BackgroundColor3 = UiTheme.Colors.Green
			badgeLabel.Text = Lang.t("✨ NOVO!")
		end
		card.Visible = true
		cardScale.Scale = 0.2
		TweenService:Create(cardScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(0.35, function()
			if stage == "Card" and cardFx == fx then
				fx.celebrate()
			end
		end)
	end

	local function step(dt: number)
		clock += dt
		if stage == "Shake" then
			local progress = math.clamp(clock / shakeSeconds, 0, 1)
			local amplitude = 2 + 12 * progress * progress
			capsule.Position = UDim2.new(0.5, (math.random() - 0.5) * amplitude, 0.5, (math.random() - 0.5) * amplitude)
			capsule.Rotation = (math.random() - 0.5) * amplitude * 1.2
			capsuleStroke.Thickness = 5 + 5 * progress
			capsuleStroke.Transparency = 0.3 * (1 - progress)
			local gap = 0.28 - 0.2 * progress
			if clock - lastShakeClick >= gap then
				lastShakeClick = clock
				UiKit.playClick(0.9 + 0.8 * progress)
			end
			if progress >= 1 then
				showCard()
			end
		end
		if rays.Visible then
			rays.Rotation = (rays.Rotation + RAY_SPEED * dt) % 360
		end
		local fx = cardFx
		if stage == "Card" and fx ~= nil then
			fx.step(dt)
		end
		local previewHandle = preview
		if stage == "Card" and previewHandle ~= nil then
			previewHandle.step(dt)
		end
		stepConfetti(dt)
	end

	local handle = {} :: RevealHandle

	handle.play = function(definition: PuffDefinition, duplicate: boolean, refund: number)
		pending = { definition = definition, duplicate = duplicate, refund = refund }
		rarity = definition.rarity
		rarityColor = PuffCatalog.rarity(rarity).color
		-- O acabamento do cartão depende da raridade: refeito a cada giro.
		if cardFx ~= nil then
			for _, child in ipairs(card:GetChildren()) do
				if child.Name == "Holo" or child.Name == "UnlockFlash" then
					child:Destroy()
				end
			end
			for _, child in ipairs(cardStroke:GetChildren()) do
				child:Destroy()
			end
			cardFx = nil
		end
		clearConfetti()
		stage = "Shake"
		clock = 0
		lastShakeClick = 0
		shakeSeconds = SHAKE_SECONDS[rarity] or 1
		card.Visible = false
		capsule.Visible = true
		capsule.Position = UDim2.fromScale(0.5, 0.5)
		capsule.Rotation = 0
		capsuleStroke.Color = rarityColor
		capsuleStroke.Thickness = 5
		capsuleGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor),
			ColorSequenceKeypoint.new(0.5, rarityColor),
			ColorSequenceKeypoint.new(0.501, UiTheme.Colors.White),
			ColorSequenceKeypoint.new(1, UiTheme.Colors.White),
		})
		capsuleScale.Scale = 0.3
		TweenService:Create(capsuleScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local special = isSpecial(rarity)
		rays.Visible = special
		for _, ray in ipairs(rayFrames) do
			ray.BackgroundColor3 = rarityColor:Lerp(UiTheme.Colors.White, 0.3)
		end
		overlay.BackgroundTransparency = 1
		overlay.Visible = true
		TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = DIM[rarity] or 0.3 }):Play()
		if connection == nil then
			connection = RunService.Heartbeat:Connect(step)
		end
	end

	handle.hide = function()
		stage = "Hidden"
		pending = nil
		overlay.Visible = false
		rays.Visible = false
		clearConfetti()
		local current = connection
		if current ~= nil then
			current:Disconnect()
			connection = nil
		end
	end

	handle.isShowing = function(): boolean
		return stage ~= "Hidden"
	end

	handle.destroy = function()
		handle.hide()
		local previewHandle = preview
		if previewHandle ~= nil then
			previewHandle.destroy()
		end
		overlay:Destroy()
	end

	continueButton.button.Activated:Connect(function()
		if stage ~= "Card" then
			return
		end
		UiKit.playClick()
		handle.hide()
	end)

	return handle
end

return table.freeze(PuffMachineReveal)
