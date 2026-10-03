--!strict

-- Botão de impulso para toque, no visual do botão de pulo nativo do Roblox
-- (círculo escuro translúcido com anel branco e ícone branco), logo acima
-- dele. O botão de tiro fica à esquerda do pulo, então os três cabem sob o
-- polegar direito sem se sobrepor. Na recarga o ícone dá lugar aos
-- segundos que faltam.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent.UiTheme)

export type DashButtonViewHandle = {
	startCooldown: (duration: number) -> (),
	destroy: () -> (),
}

local GUI_NAME = "BlocoPuffDashButton"
-- Fração do tamanho do pulo e espaço entre os dois.
local SIZE_FACTOR = 0.8
local JUMP_GAP = 10
local LAYOUT_INTERVAL = 1
local ICON = "»"
local ICON_TRANSPARENCY = 0
local FACE_TRANSPARENCY = 0.5

local DashButtonView = {}

-- Botão de pulo da interface de toque do Roblox, se visível.
local function findJumpButton(playerGui: PlayerGui): GuiObject?
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local frame = if touchGui ~= nil then touchGui:FindFirstChild("TouchControlFrame") else nil
	local jump = if frame ~= nil then frame:FindFirstChild("JumpButton") else nil
	if jump ~= nil and jump:IsA("GuiObject") and jump.Visible and jump.AbsoluteSize.X > 0 then
		return jump
	end
	return nil
end

function DashButtonView.new(playerGui: PlayerGui, onPress: () -> ()): DashButtonViewHandle
	-- Sem área segura própria: a posição sai do botão de pulo, que já a respeita.
	local screenGui = UiTheme.createScreenGui(GUI_NAME, playerGui, 18)
	screenGui.ScreenInsets = Enum.ScreenInsets.None
	screenGui.Enabled = false

	local button = Instance.new("TextButton")
	button.Name = "DashButton"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Color3.new(0, 0, 0)
	button.BackgroundTransparency = FACE_TRANSPARENCY
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Active = true
	button.Parent = screenGui
	UiTheme.addCorner(button, 999)
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = 3
	ring.Transparency = 0.15
	ring.Parent = button

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.46)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.Font = Enum.Font.GothamBlack
	icon.Text = ICON
	icon.TextColor3 = Color3.new(1, 1, 1)
	icon.TextScaled = true
	icon.Parent = button

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local coolingUntil = 0

	local function layout()
		local jump = findJumpButton(playerGui)
		screenGui.Enabled = jump ~= nil
		if jump == nil then
			return
		end
		local size = math.floor(jump.AbsoluteSize.X * SIZE_FACTOR)
		local origin = screenGui.AbsolutePosition
		local jumpCenter = jump.AbsolutePosition + (jump.AbsoluteSize / 2) - origin
		button.Size = UDim2.fromOffset(size, size)
		button.Position = UDim2.fromOffset(jumpCenter.X, jumpCenter.Y - (jump.AbsoluteSize.Y / 2) - JUMP_GAP - (size / 2))
	end
	task.spawn(function()
		while screenGui.Parent ~= nil and Players.LocalPlayer ~= nil do
			layout()
			task.wait(LAYOUT_INTERVAL)
		end
	end)

	button.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onPress()
	end)

	local handle = {} :: DashButtonViewHandle

	-- Recarga: segundos restantes no lugar do ícone; pronto, pulso curto.
	handle.startCooldown = function(duration: number)
		coolingUntil = os.clock() + duration
		local mine = coolingUntil
		ring.Transparency = 0.6
		task.spawn(function()
			while screenGui.Parent ~= nil and coolingUntil == mine do
				local remaining = coolingUntil - os.clock()
				if remaining <= 0 then
					break
				end
				icon.Text = tostring(math.ceil(remaining))
				task.wait(0.1)
			end
			if screenGui.Parent == nil or coolingUntil ~= mine then
				return
			end
			icon.Text = ICON
			icon.TextTransparency = ICON_TRANSPARENCY
			ring.Transparency = 0.15
			scale.Scale = 1.12
			TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(DashButtonView)
