--!strict

-- Cartão de convite para Party (Fase 4.4): aparece na lateral esquerda
-- (fora do centro da tela), com ENTRAR / AGORA NÃO e uma barra do tempo que
-- falta para o convite expirar. Um convite por vez; o mais novo substitui.

local TweenService = game:GetService("TweenService")

local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

export type PartyInviteViewHandle = {
	show: (fromUserId: number, fromName: string, lifetime: number) -> (),
	hide: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffPartyInvite"

local PartyInviteView = {}

function PartyInviteView.new(
	playerGui: PlayerGui,
	onAccept: (fromUserId: number) -> (),
	onDecline: (fromUserId: number) -> ()
): PartyInviteViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 35)
	screenGui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0, 0.5)
	-- Abaixo dos cartões de aviso (AnnouncementView e BannerView), à esquerda.
	root.Position = UDim2.new(0, 18, 0.72, 0)
	root.Size = UDim2.fromOffset(300, 104)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	local responsive = ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.7, 1.05)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 2
	card.Parent = root
	UiTheme.stylePanel(card, { accent = UiTheme.Colors.Blue, radius = 16 })

	local text = UiTheme.createLabel(card, "Text", "", UiTheme.Fonts.Display, 16, UiTheme.Colors.Ink)
	text.Position = UDim2.fromOffset(14, 10)
	text.Size = UDim2.new(1, -28, 0, 40)
	text.TextScaled = true
	text.ZIndex = 3
	UiTheme.addTextConstraint(text, 11, 16)
	UiTheme.addTextOutline(text, 1.5)

	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(14, 52)
	track.Size = UDim2.new(1, -28, 0, 5)
	track.BackgroundColor3 = UiTheme.Colors.Track
	track.ZIndex = 3
	track.Parent = card
	UiTheme.addCorner(track, 999)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = UiTheme.Colors.Blue
	fill.ZIndex = 4
	fill.Parent = track
	UiTheme.addCorner(fill, 999)

	local acceptButton = UiKit.createButton(card, {
		name = "Accept",
		text = "ENTRAR",
		variant = "Success",
		size = UDim2.new(0.5, -18, 0, 32),
		position = UDim2.new(0, 14, 1, -10),
		anchorPoint = Vector2.new(0, 1),
		textSize = 14,
		zIndex = 4,
	})
	local declineButton = UiKit.createButton(card, {
		name = "Decline",
		text = "AGORA NÃO",
		variant = "Neutral",
		size = UDim2.new(0.5, -18, 0, 32),
		position = UDim2.new(1, -14, 1, -10),
		anchorPoint = Vector2.new(1, 1),
		textSize = 13,
		zIndex = 4,
	})

	local currentFrom = 0
	local generation = 0

	local handle = {} :: PartyInviteViewHandle

	handle.hide = function()
		generation += 1
		screenGui.Enabled = false
	end

	handle.show = function(fromUserId: number, fromName: string, lifetime: number)
		generation += 1
		local current = generation
		currentFrom = fromUserId
		text.Text = `{fromName} te chamou para a Party!`
		fill.Size = UDim2.fromScale(1, 1)
		TweenService:Create(fill, TweenInfo.new(lifetime, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
		screenGui.Enabled = true
		UiKit.pop(card, 0.12)
		UiKit.playClick(1.4)
		task.delay(lifetime, function()
			if generation == current then
				handle.hide()
			end
		end)
	end

	handle.destroy = function()
		generation += 1
		responsive.destroy()
		screenGui:Destroy()
	end

	acceptButton.button.Activated:Connect(function()
		UiKit.playClick()
		local from = currentFrom
		handle.hide()
		onAccept(from)
	end)
	declineButton.button.Activated:Connect(function()
		UiKit.playClick()
		local from = currentFrom
		handle.hide()
		onDecline(from)
	end)

	return handle
end

return table.freeze(PartyInviteView)
