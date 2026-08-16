--!strict

-- Retículo simples e nativo (sem assets externos), mostrado enquanto o
-- jogador empunha o Puffador. Acompanha o ponto real de mira: a posição do
-- mouse em telas com mouse, ou o centro da tela em toque/gamepad (onde a
-- mira já é sempre pelo centro da câmera, sem cursor). Sem essa referência
-- visual acompanhando o ponto certo, a mira parece "fixa" e não bate com
-- para onde o tiro realmente vai. Não decide nada: só aparece, desaparece e
-- se move conforme mandado pelo controller.

local CROSSHAIR_NAME = "BlocoPuffCrosshair"
local DOT_SIZE = 6
local RING_SIZE = 22

export type CrosshairViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
	setPosition: (x: number, y: number) -> (),
	setCenteredOnScreen: () -> (),
	destroy: () -> (),
}

local CrosshairView = {}

function CrosshairView.new(playerGui: PlayerGui): CrosshairViewHandle
	local existing = playerGui:FindFirstChild(CROSSHAIR_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = CROSSHAIR_NAME
	screenGui.ResetOnSpawn = false
	-- Mesmo espaço de coordenadas do UserInputService:GetMouseLocation() e do
	-- Camera.ViewportSize (ambos já descontam a barra superior do Roblox),
	-- para a mira bater exatamente com o raycast real do disparo.
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.Size = UDim2.new(0, 0, 0, 0)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0.5, 0, 0.5, 0)
	ring.Size = UDim2.new(0, RING_SIZE, 0, RING_SIZE)
	ring.BackgroundTransparency = 1
	ring.Parent = root

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Color3.new(1, 1, 1)
	ringStroke.Thickness = 2
	ringStroke.Transparency = 0.2
	ringStroke.Parent = ring

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(0.5, 0, 0.5, 0)
	dot.Size = UDim2.new(0, DOT_SIZE, 0, DOT_SIZE)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BackgroundTransparency = 0.1
	dot.Parent = root

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	screenGui.Parent = playerGui

	local handle = {} :: CrosshairViewHandle
	handle.screenGui = screenGui

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.setPosition = function(x: number, y: number)
		root.Position = UDim2.new(0, x, 0, y)
	end

	handle.setCenteredOnScreen = function()
		root.Position = UDim2.new(0.5, 0, 0.5, 0)
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(CrosshairView)
