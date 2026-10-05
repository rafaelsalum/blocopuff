--!strict

-- Carrossel da Puff Machine: uma fita de mini cartões de Puffs (bolinha com
-- as cores do rastro, olhinhos e a raridade) passando atrás de uma moldura
-- dourada. Parado, ela anda devagar; no giro, acelera; quando o servidor
-- responde, desacelera e para exatamente no Puff sorteado, com um "tique" a
-- cada cartão que cruza o centro. Os cartões de enchimento são só enfeite
-- (sorteados aqui pelas chances da tabela); quem decide o prêmio é o servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lang = require(ReplicatedStorage.Shared.i18n.Lang)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffTypes = require(ReplicatedStorage.Shared.types.PuffTypes)
local RewardConfig = require(ReplicatedStorage.Shared.config.RewardConfig)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type PuffDefinition = PuffTypes.PuffDefinition
type PuffRarity = PuffTypes.PuffRarity

export type CarouselHandle = {
	setActive: (active: boolean) -> (),
	spin: () -> (),
	land: (definition: PuffDefinition, onLanded: () -> ()) -> (),
	finish: () -> (),
	stop: () -> (),
	destroy: () -> (),
}

type Slot = {
	frame: Frame,
	scale: UIScale,
	stroke: UIStroke,
	gradient: UIGradient,
	orbGradient: UIGradient,
	rarity: TextLabel,
	index: number?,
}

type Phase = "Idle" | "Spin" | "Land"

local CARD_WIDTH = 88
local CARD_HEIGHT = 106
local PITCH = 98
local SLOTS = 5
local ORB_SIZE = 52
local IDLE_SPEED = 0.6
local SPIN_SPEED = 14
local SPIN_ACCEL = 30
-- Duração aproximada da freada (curva "quint": começa rápida, termina suave).
local LAND_SECONDS = 2.4
local MIN_TICK_GAP = 0.05
local CARD_BACK = Color3.fromRGB(32, 26, 58)

local PuffMachineCarousel = {}

type ByRarity = { [PuffRarity]: { PuffDefinition } }

local function groupByRarity(pool: { PuffDefinition }): ByRarity
	local byRarity: ByRarity = {}
	for _, entry in ipairs(pool) do
		local list = byRarity[entry.rarity] or {}
		table.insert(list, entry)
		byRarity[entry.rarity] = list
	end
	return byRarity
end

local function pickWeighted(pool: { PuffDefinition }, byRarity: ByRarity): PuffDefinition?
	local total = 0
	for _, weight in ipairs(RewardConfig.MachineOdds) do
		if byRarity[weight.rarity] ~= nil then
			total += weight.percent
		end
	end
	if total <= 0 then
		return pool[math.random(1, math.max(1, #pool))]
	end
	local roll = math.random() * total
	for _, weight in ipairs(RewardConfig.MachineOdds) do
		local list = byRarity[weight.rarity]
		if list ~= nil then
			roll -= weight.percent
			if roll <= 0 then
				return list[math.random(1, #list)]
			end
		end
	end
	return pool[1]
end

local function buildSlot(parent: Frame, zIndex: number): Slot
	local frame = Instance.new("Frame")
	frame.Name = "PuffCard"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	frame.BackgroundColor3 = UiTheme.Colors.White
	frame.ZIndex = zIndex
	frame.Parent = parent
	UiTheme.addCorner(frame, 12)
	local gradient = UiTheme.addGradient(frame, CARD_BACK, CARD_BACK, 90)
	local stroke = UiTheme.addStroke(frame, UiTheme.Colors.White, 2.5)
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local orb = Instance.new("Frame")
	orb.Name = "Orb"
	orb.AnchorPoint = Vector2.new(0.5, 0)
	orb.Position = UDim2.new(0.5, 0, 0, 10)
	orb.Size = UDim2.fromOffset(ORB_SIZE, ORB_SIZE)
	orb.BackgroundColor3 = UiTheme.Colors.White
	orb.ZIndex = zIndex + 1
	orb.Parent = frame
	UiTheme.addCorner(orb, 999)
	UiTheme.addStroke(orb, UiTheme.Colors.Outline, 2)
	local orbGradient = UiTheme.addGradient(orb, CARD_BACK, CARD_BACK, 45)
	for _, x in ipairs({ 0.36, 0.64 }) do
		local eye = Instance.new("Frame")
		eye.Name = "Eye"
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(x, 0.45)
		eye.Size = UDim2.fromOffset(8, 12)
		eye.BackgroundColor3 = UiTheme.Colors.Outline
		eye.ZIndex = zIndex + 2
		eye.Parent = orb
		UiTheme.addCorner(eye, 999)
		local shine = Instance.new("Frame")
		shine.Position = UDim2.fromOffset(1, 1)
		shine.Size = UDim2.fromOffset(3, 3)
		shine.BackgroundColor3 = UiTheme.Colors.White
		shine.ZIndex = zIndex + 3
		shine.Parent = eye
		UiTheme.addCorner(shine, 999)
	end

	local rarity = UiTheme.createLabel(frame, "Rarity", "", UiTheme.Fonts.Display, 14, UiTheme.Colors.White)
	rarity.AnchorPoint = Vector2.new(0.5, 1)
	rarity.Position = UDim2.new(0.5, 0, 1, -6)
	rarity.Size = UDim2.new(1, -8, 0, 22)
	rarity.TextScaled = true
	rarity.ZIndex = zIndex + 1
	UiTheme.addTextConstraint(rarity, 9, 14)
	UiTheme.addTextOutline(rarity, 1.5)

	return { frame = frame, scale = scale, stroke = stroke, gradient = gradient, orbGradient = orbGradient, rarity = rarity, index = nil }
end

local function paintSlot(slot: Slot, definition: PuffDefinition?)
	if definition == nil then
		return
	end
	local rarityInfo = PuffCatalog.rarity(definition.rarity)
	slot.gradient.Color = ColorSequence.new(rarityInfo.color:Lerp(CARD_BACK, 0.55), CARD_BACK)
	slot.stroke.Color = rarityInfo.color
	slot.orbGradient.Color = ColorSequence.new(definition.style.trailStart, definition.style.trailEnd)
	slot.rarity.Text = Lang.t(rarityInfo.label)
	slot.rarity.TextColor3 = rarityInfo.color
end

local function easeOutQuint(t: number): number
	return 1 - (1 - t) ^ 5
end

function PuffMachineCarousel.new(parent: GuiObject, zIndex: number, pool: { PuffDefinition }): CarouselHandle
	local window = Instance.new("Frame")
	window.Name = "Carousel"
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, 12)
	window.Size = UDim2.new(1, -28, 0, CARD_HEIGHT + 22)
	window.BackgroundColor3 = UiTheme.Colors.Outline
	window.BackgroundTransparency = 0.15
	window.ClipsDescendants = true
	window.ZIndex = zIndex
	window.Parent = parent
	UiTheme.addCorner(window, 14)
	UiTheme.addStroke(window, UiTheme.Colors.GoldDeep, 2)

	local slots: { Slot } = {}
	for _ = 1, SLOTS do
		table.insert(slots, buildSlot(window, zIndex + 1))
	end

	-- Esmaecido nas laterais: os cartões "somem" ao sair do centro.
	for _, side in ipairs({ 0, 1 }) do
		local fade = Instance.new("Frame")
		fade.Name = "Fade"
		fade.AnchorPoint = Vector2.new(side, 0)
		fade.Position = UDim2.fromScale(side, 0)
		fade.Size = UDim2.new(0, 56, 1, 0)
		fade.BackgroundColor3 = UiTheme.Colors.Outline
		fade.BorderSizePixel = 0
		fade.ZIndex = zIndex + 6
		fade.Parent = window
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = if side == 0
			then NumberSequence.new(0, 1)
			else NumberSequence.new(1, 0)
		gradient.Parent = fade
	end

	-- Moldura dourada do centro, com setinhas em cima e embaixo.
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.Size = UDim2.fromOffset(CARD_WIDTH + 10, CARD_HEIGHT + 10)
	marker.BackgroundTransparency = 1
	marker.ZIndex = zIndex + 7
	marker.Parent = window
	UiTheme.addCorner(marker, 14)
	local markerStroke = UiTheme.addStroke(marker, UiTheme.Colors.Gold, 3)
	for _, top in ipairs({ true, false }) do
		local arrow = Instance.new("Frame")
		arrow.Name = "Arrow"
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = UDim2.new(0.5, 0, if top then 0 else 1, 0)
		arrow.Size = UDim2.fromOffset(12, 12)
		arrow.Rotation = 45
		arrow.BackgroundColor3 = UiTheme.Colors.Gold
		arrow.BorderSizePixel = 0
		arrow.ZIndex = zIndex + 8
		arrow.Parent = marker
	end

	local byRarity = groupByRarity(pool)
	local data: { [number]: PuffDefinition } = {}
	local position = 0
	local speed = IDLE_SPEED
	local phase: Phase = "Idle"
	local landFrom = 0
	local landTo = 0
	local landDuration = LAND_SECONDS
	local landClock = 0
	local landToken = 0
	local onLandedCallback: (() -> ())? = nil
	local lastTick = math.floor(position + 0.5)
	local lastTickAt = 0
	local connection: RBXScriptConnection? = nil

	-- Esquece cartões que já passaram (a fita é infinita).
	local function trim()
		for index in pairs(data) do
			if index < position - SLOTS then
				data[index] = nil
			end
		end
	end

	local function dataAt(index: number): PuffDefinition?
		local existing = data[index]
		if existing == nil then
			local picked = pickWeighted(pool, byRarity)
			if picked ~= nil then
				trim()
				data[index] = picked
			end
			return picked
		end
		return existing
	end

	local function render()
		local first = math.floor(position) - 2
		for offset = 0, SLOTS - 1 do
			local index = first + offset
			local slot = slots[(index % SLOTS) + 1]
			if slot.index ~= index then
				slot.index = index
				paintSlot(slot, dataAt(index))
			end
			local distance = index - position
			-- Relativo ao meio (fromScale): o UIScale do painel não desalinha.
			slot.frame.Position = UDim2.new(0.5, distance * PITCH, 0.5, 0)
			slot.scale.Scale = 1 - 0.16 * math.min(1, math.abs(distance))
		end
	end

	local function tickPass()
		local nearest = math.floor(position + 0.5)
		if nearest ~= lastTick then
			lastTick = nearest
			local now = os.clock()
			if phase ~= "Idle" and now - lastTickAt >= MIN_TICK_GAP then
				lastTickAt = now
				local pitch = if phase == "Land" then 1 + 0.6 * math.clamp(landClock / landDuration, 0, 1) else 1.1
				UiKit.playClick(pitch)
			end
		end
	end

	local function finishLanding()
		phase = "Idle"
		speed = 0
		position = landTo
		markerStroke.Thickness = 4
		local slot = slots[(landTo % SLOTS) + 1]
		UiKit.pop(slot.frame, 0.3)
		local callback = onLandedCallback
		onLandedCallback = nil
		if callback ~= nil then
			callback()
		end
	end

	local function step(dt: number)
		if phase == "Spin" then
			speed = math.min(SPIN_SPEED, speed + SPIN_ACCEL * dt)
			position += speed * dt
		elseif phase == "Land" then
			landClock += dt
			local t = math.clamp(landClock / landDuration, 0, 1)
			position = landFrom + (landTo - landFrom) * easeOutQuint(t)
			if t >= 1 then
				render()
				finishLanding()
				return
			end
		elseif speed > 0 then
			position += speed * dt
		end
		tickPass()
		render()
	end

	local handle = {} :: CarouselHandle

	handle.setActive = function(active: boolean)
		if active and connection == nil then
			connection = RunService.Heartbeat:Connect(step)
			render()
		elseif not active and connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end

	handle.spin = function()
		landToken += 1
		onLandedCallback = nil
		phase = "Spin"
		markerStroke.Thickness = 3
		speed = math.max(speed, IDLE_SPEED)
	end

	-- Freia até o cartão sorteado. A distância sai da velocidade atual para a
	-- freada começar no mesmo ritmo do giro (sem tranco).
	handle.land = function(definition: PuffDefinition, onLanded: () -> ())
		landToken += 1
		local token = landToken
		local currentSpeed = math.max(speed, IDLE_SPEED)
		landFrom = position
		landTo = math.floor(position + currentSpeed * LAND_SECONDS / 5) + 1
		landDuration = math.max(0.8, 5 * (landTo - landFrom) / currentSpeed)
		landClock = 0
		data[landTo] = definition
		local slot = slots[(landTo % SLOTS) + 1]
		if slot.index == landTo then
			paintSlot(slot, definition)
		end
		phase = "Land"
		onLandedCallback = function()
			if token == landToken then
				onLanded()
			end
		end
		if connection == nil then
			-- Painel fechado no meio do giro: chega direto ao resultado.
			position = landTo
			render()
			finishLanding()
		end
	end

	-- Termina uma freada em andamento na hora (painel fechado).
	handle.finish = function()
		if phase == "Land" then
			position = landTo
			render()
			finishLanding()
		end
	end

	handle.stop = function()
		landToken += 1
		onLandedCallback = nil
		phase = "Idle"
		speed = IDLE_SPEED
		markerStroke.Thickness = 3
	end

	handle.destroy = function()
		handle.setActive(false)
		window:Destroy()
	end

	render()
	return handle
end

return table.freeze(PuffMachineCarousel)
