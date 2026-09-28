--!strict

-- Reações de quem está assistindo (Fase 4.4): uma barra discreta de emojis
-- no canto inferior direito e, acima dela, as reações que chegam ("Ana 👏")
-- subindo e sumindo. Só aparece para quem não está competindo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SocialConfig = require(ReplicatedStorage.Shared.config.SocialConfig)
local ResponsiveScale = require(script.Parent.ResponsiveScale)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

export type ReactionViewHandle = {
	setBarVisible: (visible: boolean) -> (),
	push: (name: string, emoji: string) -> (),
	clear: () -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffReactions"
local BUTTON_SIZE = 40
local MAX_FEED = 5
local FEED_LIFETIME = 3

local ReactionView = {}

function ReactionView.new(playerGui: PlayerGui, onReact: (index: number) -> ()): ReactionViewHandle
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 18)

	local emojis = SocialConfig.Reactions
	local barWidth = #emojis * (BUTTON_SIZE + 6) + 6
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -18, 1, -22)
	root.Size = UDim2.fromOffset(barWidth, 230)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	local responsive = ResponsiveScale.attach(root, Vector2.new(1280, 720), 0.75, 1.05)

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.fromOffset(barWidth, BUTTON_SIZE + 12)
	bar.BackgroundColor3 = UiTheme.Colors.Panel
	bar.BackgroundTransparency = 0.25
	bar.Visible = false
	bar.Parent = root
	UiTheme.addCorner(bar, 14)
	UiTheme.addStroke(bar, UiTheme.Colors.Border, 1.5)
	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.Padding = UDim.new(0, 6)
	barLayout.Parent = bar

	for index, emoji in ipairs(emojis) do
		local button = Instance.new("TextButton")
		button.Name = `React{index}`
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
		button.BackgroundColor3 = UiTheme.Colors.Surface
		button.Text = emoji
		button.TextSize = 22
		button.Font = UiTheme.Fonts.Display
		button.AutoButtonColor = true
		button.Parent = bar
		UiTheme.addCorner(button, 10)
		button.Activated:Connect(function()
			UiKit.pop(button, 0.2)
			onReact(index)
		end)
	end

	local feed = Instance.new("Frame")
	feed.Name = "Feed"
	feed.AnchorPoint = Vector2.new(1, 1)
	feed.Position = UDim2.new(1, 0, 1, -(BUTTON_SIZE + 20))
	feed.Size = UDim2.new(1, 40, 0, 160)
	feed.BackgroundTransparency = 1
	feed.Parent = root
	local feedLayout = Instance.new("UIListLayout")
	feedLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	feedLayout.Padding = UDim.new(0, 4)
	feedLayout.Parent = feed

	local order = 0
	local handle = {} :: ReactionViewHandle

	handle.setBarVisible = function(visible: boolean)
		bar.Visible = visible
	end

	handle.push = function(name: string, emoji: string)
		order += 1
		local item = UiTheme.createLabel(feed, "Reaction", `{name} {emoji}`, UiTheme.Fonts.BodyBold, 14, UiTheme.Colors.Ink)
		item.LayoutOrder = order
		item.Size = UDim2.new(1, 0, 0, 24)
		item.TextXAlignment = Enum.TextXAlignment.Right
		item.TextTruncate = Enum.TextTruncate.AtEnd
		item.TextWrapped = false
		local outline = UiTheme.addTextOutline(item, 2)
		local items: { TextLabel } = {}
		for _, child in ipairs(feed:GetChildren()) do
			if child:IsA("TextLabel") then
				table.insert(items, child)
			end
		end
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for index = 1, #items - MAX_FEED do
			items[index]:Destroy()
		end
		task.delay(FEED_LIFETIME, function()
			if item.Parent == nil then
				return
			end
			local fade = TweenService:Create(item, TweenInfo.new(0.4), { TextTransparency = 1 })
			TweenService:Create(outline, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			fade.Completed:Connect(function()
				item:Destroy()
			end)
			fade:Play()
		end)
	end

	handle.clear = function()
		for _, child in ipairs(feed:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	handle.destroy = function()
		responsive.destroy()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(ReactionView)
