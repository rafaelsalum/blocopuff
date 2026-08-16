--!strict

-- Botão de disparo nativo (sem assets externos), mostrado no canto inferior
-- direito enquanto o jogador empunha o Puffador. O Tool.Activated padrão já
-- cobre clique/toque/gatilho ao tocar o mundo 3D, mas em toque isso disputa
-- espaço com o gesto de arrastar para olhar ao redor; um botão dedicado dá
-- um alvo claro e sem ambiguidade para disparar, como a maioria dos jogos
-- de tiro em celular faz. Não decide nada: só aparece, desaparece e repassa
-- o toque/clique para o controller.

local FIRE_BUTTON_NAME = "BlocoPuffFireButton"
local BUTTON_SIZE = 76
local ICON_SIZE = 30

export type FireButtonViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local FireButtonView = {}

function FireButtonView.new(playerGui: PlayerGui, onFire: () -> ()): FireButtonViewHandle
	local existing = playerGui:FindFirstChild(FIRE_BUTTON_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = FIRE_BUTTON_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false

	local button = Instance.new("TextButton")
	button.Name = "Button"
	-- Perto do canto onde o botão de pulo padrão do Roblox normalmente fica
	-- em toque, mas deslocado para cima para não sobrepor.
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -30, 1, -170)
	button.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
	button.BackgroundColor3 = Color3.fromRGB(255, 230, 148)
	button.BackgroundTransparency = 0.15
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = screenGui

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(1, 0)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Color3.fromRGB(194, 168, 255)
	buttonStroke.Thickness = 3
	buttonStroke.Transparency = 0.1
	buttonStroke.Parent = button

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	icon.BackgroundColor3 = Color3.new(1, 1, 1)
	icon.BackgroundTransparency = 0.05
	icon.Parent = button

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = icon

	-- GuiButton.Activated unifica clique de mouse, toque e seleção de
	-- gamepad, do mesmo jeito que Tool.Activated: um único caminho de
	-- disparo, sem lógica separada por dispositivo.
	button.Activated:Connect(function()
		onFire()
	end)

	screenGui.Parent = playerGui

	local handle = {} :: FireButtonViewHandle
	handle.screenGui = screenGui

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(FireButtonView)
