--!strict

-- Acabamento dos cartões do Puffdex por raridade:
--   Comum    → borda simples;
--   Raro     → borda com brilho suave girando;
--   Épico    → borda animada mais forte;
--   Lendário → borda dourada girando e um reflexo holográfico passando
--              pelo cartão (só quando o jogador já tem o Puff).
-- E a comemoração de desbloqueio (clarão + pulo do cartão). Quem anima é o
-- PuffdexView (chama `step` a cada quadro só com o painel aberto).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type PuffRarity = PuffTypes.PuffRarity

export type CardFxHandle = {
	setOwned: (owned: boolean) -> (),
	step: (deltaTime: number) -> (),
	celebrate: () -> (),
}

-- Voltas por segundo do brilho da borda.
local SPIN: { [PuffRarity]: number } = {
	Common = 0,
	Rare = 0.12,
	Epic = 0.35,
	Legendary = 0.25,
}
local HOLO_SECONDS = 2.6

local PuffCardFx = {}

function PuffCardFx.decorate(button: GuiObject, stroke: UIStroke, rarity: PuffRarity, rarityColor: Color3, zIndex: number): CardFxHandle
	local spin = SPIN[rarity] or 0
	local strokeGradient: UIGradient? = nil
	if spin > 0 then
		stroke.Color = UiTheme.Colors.White
		local gradient = Instance.new("UIGradient")
		local highlight = if rarity == "Legendary" then UiTheme.Colors.White else rarityColor:Lerp(UiTheme.Colors.White, 0.7)
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor),
			ColorSequenceKeypoint.new(0.45, rarityColor),
			ColorSequenceKeypoint.new(0.5, highlight),
			ColorSequenceKeypoint.new(0.55, rarityColor),
			ColorSequenceKeypoint.new(1, rarityColor),
		})
		gradient.Parent = stroke
		strokeGradient = gradient
	end

	-- Reflexo holográfico: faixa clara inclinada atravessando o cartão.
	local holo: Frame? = nil
	local holoGradient: UIGradient? = nil
	if rarity == "Legendary" then
		local frame = Instance.new("Frame")
		frame.Name = "Holo"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = UiTheme.Colors.White
		frame.BackgroundTransparency = 0
		frame.ZIndex = zIndex
		frame.Visible = false
		frame.Parent = button
		UiTheme.addCorner(frame, 12)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 25
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.72),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		holo = frame
		holoGradient = gradient
	end

	local flash = Instance.new("Frame")
	flash.Name = "UnlockFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = rarityColor:Lerp(UiTheme.Colors.White, 0.5)
	flash.BackgroundTransparency = 1
	flash.ZIndex = zIndex + 1
	flash.Parent = button
	UiTheme.addCorner(flash, 12)

	local angle = math.random() * 360
	local holoPhase = math.random()
	local handle = {} :: CardFxHandle

	handle.setOwned = function(owned: boolean)
		local frame = holo
		if frame ~= nil then
			frame.Visible = owned
		end
	end

	handle.step = function(deltaTime: number)
		local gradient = strokeGradient
		if gradient ~= nil then
			angle = (angle + (spin * 360 * deltaTime)) % 360
			gradient.Rotation = angle
		end
		local sweep = holoGradient
		local frame = holo
		if sweep ~= nil and frame ~= nil and frame.Visible then
			holoPhase = (holoPhase + (deltaTime / HOLO_SECONDS)) % 1
			sweep.Offset = Vector2.new((holoPhase * 1.3) - 0.65, 0)
		end
	end

	handle.celebrate = function()
		flash.BackgroundTransparency = 0.15
		TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		UiKit.pop(button, 0.35)
	end

	return handle
end

return table.freeze(PuffCardFx)
