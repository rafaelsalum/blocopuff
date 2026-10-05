--!strict

-- Cenário dos Mistérios do Barão (Fase 5C.3, parte 2), montado com os
-- modelos da Creator Store (MysteryAssets) e as respostas deste servidor:
--   * Salão Principal: quatro candelabros de ferro à esquerda da porta norte
--     (velas coloridas), quatro vitrais à direita dela (a ordem certa) e o
--     quadro com a hora certa na parede oeste;
--   * Sótão: o relógio de pêndulo (parado nas 12h) e a estante com a
--     partitura da Vovó;
--   * Biblioteca, Sala de Música e Sótão: quadros com os dígitos do código;
--   * Porão: o cofre;
--   * Piano de cauda: o nome de cada nota acima das teclas.
-- Sem os modelos, vale o cenário simples (MysteryPropsBasic).
-- Os nomes começam com "Mystery" (não confundem as âncoras das relíquias).
-- Tudo de enfeite: quem confere as respostas é o MysteryService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MysteryConfig = require(ReplicatedStorage.Shared.config.MysteryConfig)
local MysteryAssets = require(script.Parent.MysteryAssets)
local MysteryPropsBasic = require(script.Parent.MysteryPropsBasic)
local MysteryRules = require(script.Parent.Parent.data.MysteryRules)

type Answers = MysteryRules.Answers
export type Built = MysteryPropsBasic.Built

local MODELS = { "Candelabra", "StainedWindow", "GrandfatherClock", "Safe", "Frame", "MusicStand" }

-- Tamanhos (o modelo original é 1).
local CANDELABRA_SCALE = 0.8
local WINDOW_SCALE = 0.52
local FRAME_SCALE = 0.8
local CLOCK_SCALE = 1.2
local STAND_SCALE = 1
local SAFE_SCALE = 1

-- Base dos quadros: acima do friso de madeira das paredes (4,3 a 4,7).
local PAINTING_BOTTOM = 5
local WINDOW_BOTTOM = 9
-- Folga entre o fundo do modelo e a parede.
local WALL_GAP = 0.75

local SAFE_COLOR = Color3.fromRGB(64, 104, 84)
local LAMP_COLOR = Color3.fromRGB(255, 205, 140)
-- Velas mais grossas que as do modelo (a cor precisa ser vista de longe).
local CANDLE_THICKNESS = 1.8
local FLAME_COLOR = Color3.fromRGB(255, 180, 70)
local FLAME_SIZE = Vector3.new(0.22, 0.38, 0.22)
local FLAME_PARTICLE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })

local MysteryProps = {}

local function setParts(root: Instance, apply: (BasePart) -> ())
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			apply(descendant)
		end
	end
end

-- Caixa (no espaço do modelo) de uma peça: mínimo e máximo.
local function localBounds(model: Model, target: BasePart): (Vector3, Vector3)
	local pivot = model:GetPivot()
	local half = target.Size / 2
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				local point = pivot:PointToObjectSpace(target.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
				lo = lo:Min(point)
				hi = hi:Max(point)
			end
		end
	end
	return lo, hi
end

-- Velas na cor da pista (brilhando um pouco, para a cor aparecer com a luz
-- quente do Salão) e uma chama visível em cada uma, apagada: o cliente de
-- quem resolveu acende ("FlameTip", fogo e a luz da vela do meio).
local function dressCandelabra(model: Model, color: Color3)
	local highest: BasePart? = nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "Candle" then
			local cframe = descendant.CFrame
			local size = descendant.Size
			descendant.Size = Vector3.new(size.X * CANDLE_THICKNESS, size.Y, size.Z * CANDLE_THICKNESS)
			descendant.CFrame = cframe
			descendant.Color = color
			descendant.Material = Enum.Material.Neon
			descendant.Transparency = 0.1
		elseif descendant:IsA("BasePart") and descendant.Name == "Flame" then
			local tip = Instance.new("Part")
			tip.Name = "FlameTip"
			tip.Shape = Enum.PartType.Ball
			tip.Size = FLAME_SIZE
			tip.CFrame = descendant.CFrame + Vector3.new(0, FLAME_SIZE.Y / 2, 0)
			tip.Color = FLAME_COLOR
			tip.Material = Enum.Material.Neon
			tip.Transparency = 1
			tip.Anchored = true
			tip.CanCollide = false
			tip.CanTouch = false
			tip.CanQuery = false
			tip.CastShadow = false
			tip.Parent = descendant
			local emitter = descendant:FindFirstChildOfClass("ParticleEmitter")
			if emitter ~= nil then
				emitter.Size = FLAME_PARTICLE
			end
			local current = highest
			if current == nil or descendant.Position.Y > current.Position.Y then
				highest = descendant
			end
		end
	end
	-- Uma luz por candelabro (a da vela do meio, a mais alta).
	for _, light in ipairs(model:GetDescendants()) do
		if light:IsA("PointLight") and light.Parent ~= highest then
			light:Destroy()
		elseif light:IsA("PointLight") then
			light.Range = 10
			light.Brightness = 1.4
		end
	end
end

-- Luz quente presa em `target`, deslocada `offset` (fora do móvel, para
-- não ficar tapada por ele).
local function lamp(target: BasePart, offset: Vector3, range: number, brightness: number)
	local spot = Instance.new("Attachment")
	spot.Name = "LampSpot"
	spot.Position = offset
	spot.Parent = target
	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = range
	light.Brightness = brightness
	light.Parent = spot
end

-- Quatro candelabros encostados na parede norte, a oeste da porta (da
-- esquerda para a direita de quem olha para o norte). Devolve o centro.
local function candelabra(parent: Instance, answers: Answers): Vector3
	local mansion = MansionLayout.get()
	local hall = mansion.rooms.GrandHall
	local wallZ = hall.minZ + MansionConfig.PartitionThickness / 2
	local z = wallZ + 2.6
	local firstX = hall.minX + 5.6
	local spacing = 4.6
	for index, colorIndex in ipairs(answers.candles) do
		local model = MysteryAssets.clone("Candelabra") :: Model
		model.Name = `MysteryCandle{index}`
		model:SetAttribute("CandleIndex", index)
		model:SetAttribute("CandleColor", colorIndex)
		local color = MysteryConfig.CandleColors[colorIndex].color
		MysteryAssets.place(model, Vector3.new(firstX + (index - 1) * spacing, mansion.floorY, z), Vector3.zAxis, CANDELABRA_SCALE, parent)
		dressCandelabra(model, color)
	end
	local center = Vector3.new(firstX + spacing * (#answers.candles - 1) / 2, mansion.floorY, z)
	MysteryAssets.blocker(parent, "MysteryCandlesBlock", Vector3.new(spacing * #answers.candles, 7, 3.4), CFrame.new(center + Vector3.new(0, 3.5, 0)))
	local anchor = MysteryAssets.blocker(parent, "MysteryCandlesPrompt", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 3.5, 2)))
	anchor.CanCollide = false
	MysteryPropsBasic.prompt(anchor, "Candles", "Acender as velas", "Velas do Salão")
	return center
end

-- Vitrais na parede norte, a leste da porta, nas cores da ordem certa.
local function stainedGlass(parent: Instance, answers: Answers)
	local mansion = MansionLayout.get()
	local hall = mansion.rooms.GrandHall
	local wallZ = hall.minZ + MansionConfig.PartitionThickness / 2
	local doorRight = (hall.minX + hall.maxX) / 2 + MansionConfig.ArchWidth / 2
	local template = MysteryAssets.clone("StainedWindow") :: Model
	local width = template:GetExtentsSize().X * WINDOW_SCALE
	template:Destroy()
	local gap = math.max(0, (hall.maxX - doorRight - #answers.windows * width) / (#answers.windows + 1))
	for index, colorIndex in ipairs(answers.windows) do
		local model = MysteryAssets.clone("StainedWindow") :: Model
		model.Name = `MysteryWindow{index}`
		local color = MysteryConfig.CandleColors[colorIndex].color
		local main = model:FindFirstChild("MainGlass", true)
		if main ~= nil then
			setParts(main, function(glass: BasePart)
				glass.Color = color
				glass.Material = Enum.Material.Neon
				glass.Transparency = 0.35
			end)
		end
		local x = doorRight + gap * index + width * (index - 0.5)
		MysteryAssets.place(model, Vector3.new(x, mansion.floorY + WINDOW_BOTTOM, wallZ + 0.25), Vector3.zAxis, WINDOW_SCALE, parent)
	end
end

-- Face da tela pelo nome (atributo CanvasFace); Front se não valer.
local function canvasFace(canvas: BasePart): Enum.NormalId
	local faceName = canvas:GetAttribute("CanvasFace")
	for _, item in ipairs(Enum.NormalId:GetEnumItems()) do
		if item.Name == faceName then
			return item
		end
	end
	return Enum.NormalId.Front
end

-- Quadro emoldurado na parede (`wall`: ponto da parede no piso; `facing`:
-- para dentro do cômodo). Devolve a SurfaceGui da tela (na moldura, se a
-- tela faltar).
local function painting(parent: Instance, name: string, wall: Vector3, facing: Vector3): SurfaceGui
	local model = MysteryAssets.clone("Frame") :: Model
	model.Name = name
	local at = wall + facing.Unit * 0.2 + Vector3.new(0, PAINTING_BOTTOM, 0)
	MysteryAssets.place(model, at, facing, FRAME_SCALE, parent)
	local canvas = model:FindFirstChild("Canvas", true)
	if canvas ~= nil and canvas:IsA("BasePart") then
		return MysteryPropsBasic.surfaceGui(canvas, "Painting", canvasFace(canvas))
	end
	warn(`[BlocoPuff] Mystery: frame without Canvas ({name})`)
	local fallback = MysteryAssets.blocker(model, "Canvas", Vector3.new(4, 4, 0.05), CFrame.lookAt(at, at + facing) * CFrame.new(0, 2.5, -0.1))
	fallback.CanCollide = false
	fallback.Transparency = 0
	return MysteryPropsBasic.surfaceGui(fallback, "Painting")
end

-- Relógio de pêndulo no Sótão, de costas para a parede leste, parado nas
-- 12h. Guarda onde ficam os ponteiros e o pêndulo para o cliente girar.
local function grandfatherClock(parent: Instance): Vector3
	local wing = MansionWingLayout.get()
	local model = MysteryAssets.clone("GrandfatherClock") :: Model
	model.Name = "MysteryTowerClock"
	-- Medidas antes de girar (no espaço do modelo).
	local size = model:GetExtentsSize() * CLOCK_SCALE
	local depth = size.Z
	local base = Vector3.new(wing.maxX - WALL_GAP - depth / 2, wing.atticFloorY, 20)
	MysteryAssets.place(model, base, -Vector3.xAxis, CLOCK_SCALE, parent)
	local center = model:FindFirstChild("HandCenter", true)
	if center ~= nil and center:IsA("BasePart") then
		local handFrame = MysteryAssets.frameAt(model, center.Position)
		model:SetAttribute("HandFrame", handFrame)
		for _, name in ipairs({ "HourHand", "MinuteHand" }) do
			local hand = model:FindFirstChild(name, true)
			if hand ~= nil and hand:IsA("BasePart") then
				hand:SetAttribute("RestOffset", handFrame:ToObjectSpace(hand.CFrame))
			end
		end
	end
	local hinge = model:FindFirstChild("PendulumHinge", true)
	local pendulum = model:FindFirstChild("Pendulum", true)
	if hinge ~= nil and hinge:IsA("BasePart") and pendulum ~= nil and pendulum:IsA("BasePart") then
		local swingFrame = MysteryAssets.frameAt(model, hinge.Position)
		model:SetAttribute("SwingFrame", swingFrame)
		pendulum:SetAttribute("RestOffset", swingFrame:ToObjectSpace(pendulum.CFrame))
	end
	MysteryAssets.blocker(model, "Block", size, model:GetPivot() * CFrame.new(0, size.Y / 2, 0))
	local anchor = MysteryAssets.blocker(model, "Hitbox", Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(-depth / 2 - 1.5, 3, 0)))
	anchor.CanCollide = false
	MysteryPropsBasic.prompt(anchor, "Clock", "Acertar o relógio", "Relógio da Torre")
	return base
end

-- Estante com a partitura da Vovó, no Sótão.
local function sheetStand(parent: Instance, answers: Answers)
	local wing = MansionWingLayout.get()
	local model = MysteryAssets.clone("MusicStand") :: Model
	model.Name = "MysterySheetStand"
	MysteryAssets.place(model, Vector3.new(wing.maxX - 8, wing.atticFloorY, 8), -Vector3.xAxis, STAND_SCALE, parent)
	local sheet = model:FindFirstChild("Sheet", true)
	if sheet ~= nil and sheet:IsA("BasePart") then
		MysteryPropsBasic.paintSheet(MysteryPropsBasic.surfaceGui(sheet, "Sheet"), answers)
		-- O Sótão é escuro: luz suave na frente da folha.
		lamp(sheet, Vector3.new(0, 1, -2), 7, 0.8)
	end
end

-- Cofre no Porão, de costas para a parede leste. A porta guarda a posição
-- fechada e a dobradiça (lado -X do modelo); o dinheiro some até abrir.
local function safe(parent: Instance): Vector3
	local wing = MansionWingLayout.get()
	local model = MysteryAssets.clone("Safe") :: Model
	model.Name = "MysterySafe"
	local size = model:GetExtentsSize() * SAFE_SCALE
	local depth = size.Z
	local base = Vector3.new(wing.maxX - WALL_GAP - depth / 2, wing.cellarFloorY, -6)
	MysteryAssets.place(model, base, -Vector3.xAxis, SAFE_SCALE, parent)
	for _, name in ipairs({ "Body", "Door" }) do
		local metal = model:FindFirstChild(name, true)
		if metal ~= nil and metal:IsA("BasePart") then
			metal.Color = SAFE_COLOR
			metal.Material = Enum.Material.Metal
		end
	end
	local door = model:FindFirstChild("Door", true)
	if door ~= nil and door:IsA("BasePart") then
		local lo, hi = localBounds(model, door)
		local hinge = model:GetPivot() * CFrame.new(lo.X, (lo.Y + hi.Y) / 2, (lo.Z + hi.Z) / 2)
		door:SetAttribute("ClosedCFrame", door.CFrame)
		door:SetAttribute("HingeCFrame", hinge)
		door:SetAttribute("OpenAngle", 100)
	end
	local money = model:FindFirstChild("Money", true)
	if money ~= nil then
		money.Name = "Coins"
		if money:IsA("BasePart") then
			money.Transparency = 1
		end
		setParts(money, function(note: BasePart)
			note.Transparency = 1
		end)
	end
	local box = MysteryAssets.blocker(model, "Block", size, model:GetPivot() * CFrame.new(0, size.Y / 2, 0))
	-- O Porão é escuro: luz quente na frente do cofre, acima dele.
	lamp(box, Vector3.new(0, size.Y / 2 + 1, -size.Z / 2 - 1.5), 12, 1.3)
	MysteryPropsBasic.prompt(box, "Safe", "Abrir o cofrinho", "Cofrinho do Porão")
	return base
end

-- Nome das notas no piano: o de cauda já traz a faixa ("NoteStrip"); o
-- antigo, de armário, ganha a do cenário simples.
local function pianoLabels(root: Instance)
	local piano = root:FindFirstChild("Piano", true)
	local strip = if piano ~= nil then piano:FindFirstChild("NoteStrip", true) else nil
	if strip ~= nil and strip:IsA("BasePart") then
		MysteryPropsBasic.paintNotes(MysteryPropsBasic.surfaceGui(strip, "Notes"))
		return
	end
	MysteryPropsBasic.pianoLabels(root)
end

function MysteryProps.build(parent: Instance, mansionRoot: Instance, answers: Answers): Built
	if not MysteryAssets.has(MODELS) then
		return MysteryPropsBasic.build(parent, mansionRoot, answers)
	end
	local mansion = MansionLayout.get()
	local wing = MansionWingLayout.get()
	local hall = mansion.rooms.GrandHall
	local library = wing.rooms.Library
	local music = wing.rooms.Music
	local reserved: { { center: Vector3, size: Vector3 } } = {}

	stainedGlass(parent, answers)
	local candles = candelabra(parent, answers)
	table.insert(reserved, { center = candles, size = Vector3.new(20, 0, 7) })

	-- Quadro do relógio na parede oeste, entre as portas da galeria.
	local hallWestX = hall.minX + MansionConfig.PartitionThickness / 2
	MysteryPropsBasic.paintClock(painting(parent, "MysteryClockPainting", Vector3.new(hallWestX, mansion.floorY, -11.25), Vector3.xAxis), answers)

	-- Dígitos do cofre: parede sul da Biblioteca, norte da Sala de Música e
	-- oeste do Sótão.
	local digits = {
		{ wall = Vector3.new(library.maxX - 9, wing.floorY, library.maxZ - WALL_GAP), facing = -Vector3.zAxis },
		{ wall = Vector3.new(music.maxX - 9, wing.floorY, music.minZ + WALL_GAP), facing = Vector3.zAxis },
		{ wall = Vector3.new(wing.minX + WALL_GAP, wing.atticFloorY, 44), facing = Vector3.xAxis },
	}
	for index, spot in ipairs(digits) do
		MysteryPropsBasic.paintDigit(painting(parent, `MysteryDigit{index}`, spot.wall, spot.facing), index, answers.code[index])
	end

	local clock = grandfatherClock(parent)
	table.insert(reserved, { center = clock, size = Vector3.new(6, 0, 6) })
	sheetStand(parent, answers)
	table.insert(reserved, { center = Vector3.new(wing.maxX - 8, wing.atticFloorY, 8), size = Vector3.new(4, 0, 4) })
	pianoLabels(mansionRoot)
	local safeAt = safe(parent)

	local piano = mansionRoot:FindFirstChild("Piano", true)
	local pianoAt = if piano ~= nil and piano:IsA("Model") then piano:GetPivot().Position else Vector3.new(music.maxX, wing.floorY, (music.minZ + music.maxZ) / 2)
	return {
		anchors = { Clock = clock, Candles = candles, Safe = safeAt, Piano = pianoAt },
		reserved = reserved,
	}
end

return table.freeze(MysteryProps)
