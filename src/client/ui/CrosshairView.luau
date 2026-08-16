--!strict

-- Retículo simples e nativo (sem assets externos), mostrado no centro da
-- tela enquanto o jogador empunha o Puffador. Sem essa referência visual, a
-- direção do disparo (calculada pela câmera) não tem nenhuma indicação na
-- tela, o que torna a mira essencialmente um "chute". Não decide nada: só
-- aparece/desaparece conforme mandado pelo controller.

local CROSSHAIR_NAME = "BlocoPuffCrosshair"
local DOT_SIZE = 6
local RING_SIZE = 22

export type CrosshairViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
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
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0.5, 0, 0.5, 0)
	ring.Size = UDim2.new(0, RING_SIZE, 0, RING_SIZE)
	ring.BackgroundTransparency = 1
	ring.Parent = screenGui

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
	dot.Parent = screenGui

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	screenGui.Parent = playerGui

	local handle = {} :: CrosshairViewHandle
	handle.screenGui = screenGui

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(CrosshairView)
