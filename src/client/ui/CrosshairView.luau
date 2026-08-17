--!strict

-- Retículo central de alto contraste. Expande ao disparar e mostra uma
-- confirmação colorida somente quando o servidor confirma a destruição de
-- um bloco válido.

local TweenService = game:GetService("TweenService")

local CROSSHAIR_NAME = "BlocoPuffCrosshair"
local DEFAULT_RING_SIZE = 26
local SHOT_RING_SIZE = 38
local DEFAULT_DOT_SIZE = 6
local HIT_COLOR = Color3.fromRGB(255, 230, 96)
local DEFAULT_COLOR = Color3.new(1, 1, 1)

export type CrosshairViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
	setPosition: (x: number, y: number) -> (),
	setCenteredOnScreen: () -> (),
	playShot: () -> (),
	playHit: () -> (),
	destroy: () -> (),
}

local CrosshairView = {}

local function addCorner(instance: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = instance
end

local function createHitLine(parent: Instance, position: UDim2, rotation: number): Frame
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = position
	line.Size = UDim2.fromOffset(10, 3)
	line.Rotation = rotation
	line.BackgroundColor3 = HIT_COLOR
	line.BorderSizePixel = 0
	line.Visible = false
	line.Parent = parent
	addCorner(line)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(44, 35, 52)
	stroke.Thickness = 1
	stroke.Parent = line

	return line
end

function CrosshairView.new(playerGui: PlayerGui): CrosshairViewHandle
	local existing = playerGui:FindFirstChild(CROSSHAIR_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = CROSSHAIR_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 20
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(64, 64)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	local shadowRing = Instance.new("Frame")
	shadowRing.Name = "ShadowRing"
	shadowRing.AnchorPoint = Vector2.new(0.5, 0.5)
	shadowRing.Position = UDim2.fromScale(0.5, 0.5)
	shadowRing.Size = UDim2.fromOffset(DEFAULT_RING_SIZE + 3, DEFAULT_RING_SIZE + 3)
	shadowRing.BackgroundTransparency = 1
	shadowRing.Parent = root
	addCorner(shadowRing)

	local shadowStroke = Instance.new("UIStroke")
	shadowStroke.Color = Color3.fromRGB(44, 35, 52)
	shadowStroke.Thickness = 4
	shadowStroke.Transparency = 0.15
	shadowStroke.Parent = shadowRing

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(DEFAULT_RING_SIZE, DEFAULT_RING_SIZE)
	ring.BackgroundTransparency = 1
	ring.Parent = root
	addCorner(ring)

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = DEFAULT_COLOR
	ringStroke.Thickness = 2
	ringStroke.Parent = ring

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(DEFAULT_DOT_SIZE, DEFAULT_DOT_SIZE)
	dot.BackgroundColor3 = DEFAULT_COLOR
	dot.BorderSizePixel = 0
	dot.Parent = root
	addCorner(dot)

	local dotStroke = Instance.new("UIStroke")
	dotStroke.Color = Color3.fromRGB(44, 35, 52)
	dotStroke.Thickness = 2
	dotStroke.Parent = dot

	local hitLines = {
		createHitLine(root, UDim2.new(0.5, -10, 0.5, -10), 45),
		createHitLine(root, UDim2.new(0.5, 10, 0.5, -10), -45),
		createHitLine(root, UDim2.new(0.5, -10, 0.5, 10), -45),
		createHitLine(root, UDim2.new(0.5, 10, 0.5, 10), 45),
	}

	screenGui.Parent = playerGui

	local handle = {} :: CrosshairViewHandle
	handle.screenGui = screenGui

	handle.setVisible = function(visible: boolean)
		screenGui.Enabled = visible
	end

	handle.setPosition = function(x: number, y: number)
		root.Position = UDim2.fromOffset(x, y)
	end

	handle.setCenteredOnScreen = function()
		root.Position = UDim2.fromScale(0.5, 0.5)
	end

	handle.playShot = function()
		ring.Size = UDim2.fromOffset(SHOT_RING_SIZE, SHOT_RING_SIZE)
		shadowRing.Size = UDim2.fromOffset(SHOT_RING_SIZE + 3, SHOT_RING_SIZE + 3)
		dot.Size = UDim2.fromOffset(4, 4)

		TweenService:Create(ring, TweenInfo.new(0.16, Enum.EasingStyle.Back), {
			Size = UDim2.fromOffset(DEFAULT_RING_SIZE, DEFAULT_RING_SIZE),
		}):Play()
		TweenService:Create(shadowRing, TweenInfo.new(0.16, Enum.EasingStyle.Back), {
			Size = UDim2.fromOffset(DEFAULT_RING_SIZE + 3, DEFAULT_RING_SIZE + 3),
		}):Play()
		TweenService:Create(dot, TweenInfo.new(0.12), {
			Size = UDim2.fromOffset(DEFAULT_DOT_SIZE, DEFAULT_DOT_SIZE),
		}):Play()
	end

	handle.playHit = function()
		ringStroke.Color = HIT_COLOR
		dot.BackgroundColor3 = HIT_COLOR

		for _, line in ipairs(hitLines) do
			line.Visible = true
			line.BackgroundTransparency = 0
			TweenService:Create(line, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1,
			}):Play()
		end

		task.delay(0.3, function()
			if screenGui.Parent == nil then
				return
			end
			ringStroke.Color = DEFAULT_COLOR
			dot.BackgroundColor3 = DEFAULT_COLOR
			for _, line in ipairs(hitLines) do
				line.Visible = false
			end
		end)
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(CrosshairView)
