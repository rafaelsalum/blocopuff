--!strict

-- Mostrador de relógio em 2D (Fase 5C.3): fundo creme, marcas das horas,
-- 12/3/6/9 e os dois ponteiros. Serve para o quadro com a pista (Salão), o
-- relógio da torre no Sótão (SurfaceGui) e a tela do quebra-cabeça. Os
-- ponteiros têm nomes fixos: `set` acha e gira os de qualquer mostrador.

local ClockFace = {}

local FACE_COLOR = Color3.fromRGB(246, 236, 210)
local INK = Color3.fromRGB(40, 30, 24)
local HOUR_HAND = "HourHand"
local MINUTE_HAND = "MinuteHand"

-- Ponteiro: barra do centro para fora. O GUI gira em volta do próprio
-- centro, então o ponteiro tem o dobro do comprimento e só a metade de
-- cima aparece.
local function hand(face: Frame, name: string, width: number, length: number, zIndex: number)
	local pivot = Instance.new("Frame")
	pivot.Name = name
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.Position = UDim2.fromScale(0.5, 0.5)
	pivot.Size = UDim2.fromScale(width, length * 2)
	pivot.BackgroundTransparency = 1
	pivot.ZIndex = zIndex
	pivot.Parent = face
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 0.5)
	bar.BackgroundColor3 = INK
	bar.BorderSizePixel = 0
	bar.ZIndex = zIndex
	bar.Parent = pivot
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
end

-- Desenha o mostrador ocupando `parent` (quadrado).
function ClockFace.draw(parent: GuiObject, zIndex: number): Frame
	local face = Instance.new("Frame")
	face.Name = "ClockFace"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = FACE_COLOR
	face.ZIndex = zIndex
	face.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = face
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = face
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = face

	for index = 0, 11 do
		local angle = math.rad(index * 30)
		local big = index % 3 == 0
		local tick = Instance.new("Frame")
		tick.Name = "Tick"
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.43, 0.5 - math.cos(angle) * 0.43)
		tick.Size = UDim2.fromScale(if big then 0.035 else 0.02, if big then 0.08 else 0.05)
		tick.Rotation = index * 30
		tick.BackgroundColor3 = INK
		tick.BorderSizePixel = 0
		tick.ZIndex = zIndex + 1
		tick.Parent = face
		if big then
			local number = Instance.new("TextLabel")
			number.Name = "Number"
			number.AnchorPoint = Vector2.new(0.5, 0.5)
			number.Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.3, 0.5 - math.cos(angle) * 0.3)
			number.Size = UDim2.fromScale(0.18, 0.14)
			number.BackgroundTransparency = 1
			number.Font = Enum.Font.FredokaOne
			number.Text = tostring(if index == 0 then 12 else index)
			number.TextColor3 = INK
			number.TextScaled = true
			number.ZIndex = zIndex + 1
			number.Parent = face
		end
	end
	hand(face, HOUR_HAND, 0.05, 0.24, zIndex + 2)
	hand(face, MINUTE_HAND, 0.03, 0.36, zIndex + 3)
	local pin = Instance.new("Frame")
	pin.Name = "Pin"
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.Position = UDim2.fromScale(0.5, 0.5)
	pin.Size = UDim2.fromScale(0.07, 0.07)
	pin.BackgroundColor3 = INK
	pin.ZIndex = zIndex + 4
	pin.Parent = face
	local pinCorner = Instance.new("UICorner")
	pinCorner.CornerRadius = UDim.new(0.5, 0)
	pinCorner.Parent = pin
	ClockFace.set(face, 12, 0)
	return face
end

-- Gira os ponteiros de um mostrador (o próprio ou um ancestral dele).
function ClockFace.set(root: Instance, hour: number, minute: number)
	local face = if root.Name == "ClockFace" then root else root:FindFirstChild("ClockFace", true)
	if face == nil then
		return
	end
	local hourHand = face:FindFirstChild(HOUR_HAND)
	local minuteHand = face:FindFirstChild(MINUTE_HAND)
	if hourHand ~= nil and hourHand:IsA("GuiObject") then
		hourHand.Rotation = (hour % 12) * 30 + minute * 0.5
	end
	if minuteHand ~= nil and minuteHand:IsA("GuiObject") then
		minuteHand.Rotation = minute * 6
	end
end

return table.freeze(ClockFace)
