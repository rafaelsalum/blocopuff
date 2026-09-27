--!strict

-- Retículo central pequeno e de alto contraste, no estilo dos jogos de tiro
-- mobile. Fica verde sobre um bloco válido, expande ao disparar e mostra um
-- marcador quando o servidor confirma o acerto: amarelo em bloco, rosa em
-- jogador (empurrão).

local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent.UiTheme)

local CROSSHAIR_NAME = "BlocoPuffCrosshair"
local DEFAULT_RING_SIZE = 18
local SHOT_RING_SIZE = 28
local DEFAULT_DOT_SIZE = 4
local HIT_COLOR = UiTheme.Colors.Yellow
local PLAYER_HIT_COLOR = UiTheme.Colors.Pink
local TARGET_COLOR = UiTheme.Colors.Green
local DEFAULT_COLOR = UiTheme.Colors.White

export type CrosshairViewHandle = {
	screenGui: ScreenGui,
	setVisible: (visible: boolean) -> (),
	setPosition: (x: number, y: number) -> (),
	setCenteredOnScreen: () -> (),
	setTargeting: (targeting: boolean) -> (),
	playShot: () -> (),
	playHit: () -> (),
	playPlayerHit: () -> (),
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
	line.Size = UDim2.fromOffset(8, 2)
	line.Rotation = rotation
	line.BackgroundColor3 = HIT_COLOR
	line.BorderSizePixel = 0
	line.Visible = false
	line.Parent = parent
	addCorner(line)

	local stroke = Instance.new("UIStroke")
	stroke.Color = UiTheme.Colors.Ink
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
	-- O disparo usa Camera:ViewportPointToRay no centro do viewport. A mira
	-- precisa ignorar o inset da barra superior para ocupar exatamente o mesmo
	-- ponto; caso contrário, ela aparece alguns pixels abaixo da trajetória.
	screenGui.IgnoreGuiInset = true
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
	shadowStroke.Color = UiTheme.Colors.Ink
	shadowStroke.Thickness = 3
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
	ringStroke.Thickness = 1.5
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
	dotStroke.Color = UiTheme.Colors.Ink
	dotStroke.Thickness = 1
	dotStroke.Parent = dot

	local hitLines = {
		createHitLine(root, UDim2.new(0.5, -8, 0.5, -8), 45),
		createHitLine(root, UDim2.new(0.5, 8, 0.5, -8), -45),
		createHitLine(root, UDim2.new(0.5, -8, 0.5, 8), -45),
		createHitLine(root, UDim2.new(0.5, 8, 0.5, 8), 45),
	}

	screenGui.Parent = playerGui
	local isTargeting = false
	local isShowingHit = false
	local hitFeedbackSequence = 0

	local function getRestingRingSize(): number
		return if isTargeting then DEFAULT_RING_SIZE - 3 else DEFAULT_RING_SIZE
	end

	local function applyRestingStyle()
		if isShowingHit then
			return
		end

		local color = if isTargeting then TARGET_COLOR else DEFAULT_COLOR
		ringStroke.Color = color
		dot.BackgroundColor3 = color
	end

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

	handle.setTargeting = function(targeting: boolean)
		if targeting == isTargeting then
			return
		end

		isTargeting = targeting
		applyRestingStyle()
		local restingSize = getRestingRingSize()
		TweenService:Create(ring, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(restingSize, restingSize),
		}):Play()
		TweenService:Create(shadowRing, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(restingSize + 3, restingSize + 3),
		}):Play()
	end

	handle.playShot = function()
		local restingSize = getRestingRingSize()
		ring.Size = UDim2.fromOffset(SHOT_RING_SIZE, SHOT_RING_SIZE)
		shadowRing.Size = UDim2.fromOffset(SHOT_RING_SIZE + 3, SHOT_RING_SIZE + 3)
		dot.Size = UDim2.fromOffset(4, 4)

		TweenService:Create(ring, TweenInfo.new(0.16, Enum.EasingStyle.Back), {
			Size = UDim2.fromOffset(restingSize, restingSize),
		}):Play()
		TweenService:Create(shadowRing, TweenInfo.new(0.16, Enum.EasingStyle.Back), {
			Size = UDim2.fromOffset(restingSize + 3, restingSize + 3),
		}):Play()
		TweenService:Create(dot, TweenInfo.new(0.12), {
			Size = UDim2.fromOffset(DEFAULT_DOT_SIZE, DEFAULT_DOT_SIZE),
		}):Play()
	end

	local function showHitMarker(color: Color3)
		hitFeedbackSequence += 1
		local sequence = hitFeedbackSequence
		isShowingHit = true
		ringStroke.Color = color
		dot.BackgroundColor3 = color

		for _, line in ipairs(hitLines) do
			line.Visible = true
			line.BackgroundColor3 = color
			line.BackgroundTransparency = 0
			TweenService:Create(line, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1,
			}):Play()
		end

		task.delay(0.3, function()
			if screenGui.Parent == nil or sequence ~= hitFeedbackSequence then
				return
			end
			isShowingHit = false
			applyRestingStyle()
			for _, line in ipairs(hitLines) do
				line.Visible = false
			end
		end)
	end

	handle.playHit = function()
		showHitMarker(HIT_COLOR)
	end

	handle.playPlayerHit = function()
		showHitMarker(PLAYER_HIT_COLOR)
	end

	handle.destroy = function()
		screenGui:Destroy()
	end

	return handle
end

return table.freeze(CrosshairView)
