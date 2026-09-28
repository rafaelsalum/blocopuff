--!strict

-- Lobby expandido (Fase 4.5): estações físicas na galeria, cada uma com um
-- ProximityPrompt que abre a tela correspondente no cliente (o atributo
-- "LobbyStation" diz qual). Ao norte, a Puff Machine e o Barão amigável
-- dormindo na caminha (dá para fazer carinho); do lado do vidro, a vitrine
-- de Puffs (abre o Puffdex), o quadro de desafios e a loja "em breve" (só
-- preparação: nada é vendido). O centro e os sofás ficam livres.
--
-- Pensado para celular: poucas peças, nenhuma luz extra, placas com
-- distância máxima e nada animado continuamente pelo servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local BaraoModel = require(script.Parent.BaraoModel)
local LobbyService = require(script.Parent.LobbyService)
local TelemetryService = require(script.Parent.TelemetryService)

type ReservedArea = LobbyService.ReservedArea

local FOLDER_NAME = "LobbyStations"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "LobbyStationsService"
local STATION_ATTRIBUTE = "LobbyStation"
local SIGN_DISTANCE = 45
local PROMPT_DISTANCE = 9
local PET_COOLDOWN = 2
-- Um Puff de cada raridade na vitrine.
local SHOWCASE_IDS = { "menta", "gelo", "galaxia", "barao" }

local LobbyStationsService = {}

local started = false
local lastPet: { [Player]: number } = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Anchored = true
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = color
	instance.Material = material or Enum.Material.SmoothPlastic
	if shape ~= nil then
		instance.Shape = shape
	end
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Parent = parent
	return instance
end

local function sign(adornee: BasePart, title: string, subtitle: string, offsetY: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.new(8, 0, 2.2, 0)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = SIGN_DISTANCE
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 0.6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 209, 102)
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = gui
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Position = UDim2.fromScale(0, 0.6)
	subtitleLabel.Size = UDim2.fromScale(1, 0.4)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(255, 248, 238)
	subtitleLabel.TextScaled = true
	subtitleLabel.TextStrokeTransparency = 0.3
	subtitleLabel.Parent = gui
	return gui
end

local function prompt(parent: BasePart, station: string, action: string, object: string): ProximityPrompt
	local proximity = Instance.new("ProximityPrompt")
	proximity.Name = "StationPrompt"
	proximity.ActionText = action
	proximity.ObjectText = object
	proximity.MaxActivationDistance = PROMPT_DISTANCE
	proximity.RequiresLineOfSight = false
	proximity.HoldDuration = 0
	proximity:SetAttribute(STATION_ATTRIBUTE, station)
	proximity.Parent = parent
	return proximity
end

-- Puff Machine: gabinete com cúpula de cápsulas, virado para o salão (+X).
local function buildMachine(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "PuffMachine"
	model.Parent = parent
	local purple = Color3.fromRGB(104, 76, 204)
	local gold = Color3.fromRGB(255, 209, 102)
	local cabinet = part(model, "Cabinet", Vector3.new(3, 4.4, 3.4), CFrame.new(base + Vector3.new(0, 2.2, 0)), purple)
	part(model, "Trim", Vector3.new(3.2, 0.4, 3.6), CFrame.new(base + Vector3.new(0, 4.5, 0)), gold, Enum.Material.Metal)
	local dome = part(model, "Dome", Vector3.new(3, 3, 3), CFrame.new(base + Vector3.new(0, 6, 0)), Color3.fromRGB(200, 230, 255), Enum.Material.Glass, Enum.PartType.Ball)
	dome.Transparency = 0.45
	dome.CanCollide = false
	local capsuleColors = { Color3.fromRGB(255, 160, 200), Color3.fromRGB(120, 240, 255), Color3.fromRGB(196, 120, 255), gold }
	for index, color in ipairs(capsuleColors) do
		local angle = (index / #capsuleColors) * math.pi * 2
		local capsule = part(model, `Capsule{index}`, Vector3.new(0.8, 0.8, 0.8), CFrame.new(base + Vector3.new(math.cos(angle) * 0.6, 5.4, math.sin(angle) * 0.6)), color, Enum.Material.Neon, Enum.PartType.Ball)
		capsule.CanCollide = false
	end
	local slot = part(model, "Slot", Vector3.new(0.2, 0.8, 1.6), CFrame.new(base + Vector3.new(1.55, 1.6, 0)), Color3.fromRGB(26, 21, 48))
	slot.CanCollide = false
	sign(cabinet, "🎰 PUFF MACHINE", "Tickets viram Puffs", 6.2)
	prompt(cabinet, "PuffMachine", "Girar", "Puff Machine")
	model.PrimaryPart = cabinet
end

-- Barão amigável: dorme numa caminha; carinho faz ele pular de alegria.
local function buildFriendlyBarao(parent: Instance, base: Vector3)
	-- Cilindro com o eixo (X) em pé: um disco baixo de 5 studs.
	local bed = part(parent, "BaraoBed", Vector3.new(0.6, 5, 5), CFrame.new(base + Vector3.new(0, 0.3, 0)), Color3.fromRGB(64, 40, 70), Enum.Material.Fabric, Enum.PartType.Cylinder)
	bed.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local barao = BaraoModel.build()
	barao.Name = "BaraoLobby"
	-- De frente para o salão (+Z); o modelo olha para −Z.
	local restCFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.pi, 0)
	barao:PivotTo(restCFrame)
	barao.Parent = parent
	local body = barao:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") then
		return
	end
	sign(body, "🐶 BARÃO", "Aqui ele é bonzinho", 4.2)
	local sleep = Instance.new("BillboardGui")
	sleep.Name = "Sleep"
	sleep.Size = UDim2.new(2, 0, 1.2, 0)
	sleep.StudsOffset = Vector3.new(1.2, 2.6, 0)
	sleep.MaxDistance = SIGN_DISTANCE
	sleep.Parent = body
	local zzz = Instance.new("TextLabel")
	zzz.Size = UDim2.fromScale(1, 1)
	zzz.BackgroundTransparency = 1
	zzz.Font = Enum.Font.FredokaOne
	zzz.Text = "Zzz"
	zzz.TextColor3 = Color3.fromRGB(190, 180, 220)
	zzz.TextScaled = true
	zzz.Parent = sleep

	local proximity = prompt(body, "Barao", "Fazer carinho", "Barão")
	local hopping = false
	proximity.Triggered:Connect(function(player: Player)
		local clock = os.clock()
		local last = lastPet[player]
		if hopping or (last ~= nil and clock - last < PET_COOLDOWN) then
			return
		end
		lastPet[player] = clock
		hopping = true
		zzz.Text = "💜"
		TelemetryService.lobbyEvent(player, "BaraoPet", 1)
		local hop = Instance.new("CFrameValue")
		hop.Value = restCFrame
		local connection = hop.Changed:Connect(function(value: CFrame)
			barao:PivotTo(value)
		end)
		local up = TweenService:Create(hop, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = restCFrame + Vector3.new(0, 1.2, 0) })
		local down = TweenService:Create(hop, TweenInfo.new(0.22, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Value = restCFrame })
		up.Completed:Once(function()
			down:Play()
		end)
		down.Completed:Once(function()
			connection:Disconnect()
			hop:Destroy()
			barao:PivotTo(restCFrame)
			task.delay(1.2, function()
				zzz.Text = "Zzz"
				hopping = false
			end)
		end)
		up:Play()
	end)
end

-- Vitrine: um Puff de cada raridade em pedestais (abre o Puffdex).
local function buildShowcase(parent: Instance, base: Vector3, spacing: number)
	local model = Instance.new("Model")
	model.Name = "PuffShowcase"
	model.Parent = parent
	local middle: BasePart? = nil
	for index, id in ipairs(SHOWCASE_IDS) do
		local definition = PuffCatalog.get(id)
		if definition ~= nil then
			local position = base + Vector3.new(0, 0, (index - (#SHOWCASE_IDS + 1) / 2) * spacing)
			local rarity = PuffCatalog.rarity(definition.rarity)
			local pedestal = part(model, `Pedestal{index}`, Vector3.new(1.8, 2.6, 1.8), CFrame.new(position + Vector3.new(0, 1.3, 0)), Color3.fromRGB(42, 34, 71), Enum.Material.Marble)
			part(model, `Band{index}`, Vector3.new(1.9, 0.3, 1.9), CFrame.new(position + Vector3.new(0, 2.5, 0)), rarity.color, Enum.Material.Neon)
			local orb = part(model, `Orb{index}`, Vector3.new(1.2, 1.2, 1.2), CFrame.new(position + Vector3.new(0, 3.4, 0)), definition.style.trailStart, Enum.Material.Neon, Enum.PartType.Ball)
			orb.CanCollide = false
			local ring = part(model, `Ring{index}`, Vector3.new(0.2, 1.8, 1.8), CFrame.new(position + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), definition.style.trailEnd, Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.Transparency = 0.5
			ring.CanCollide = false
			local label = Instance.new("BillboardGui")
			label.Size = UDim2.new(4, 0, 1, 0)
			label.StudsOffset = Vector3.new(0, 1.4, 0)
			label.MaxDistance = 25
			label.LightInfluence = 0
			label.Parent = orb
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamBold
			text.Text = `{definition.name} · {rarity.label}`
			text.TextColor3 = rarity.color
			text.TextScaled = true
			text.TextStrokeTransparency = 0.3
			text.Parent = label
			if index == 2 then
				middle = pedestal
			end
		end
	end
	local anchor = middle
	if anchor ~= nil then
		sign(anchor, "✨ PUFFDEX", "Colecione Puffs jogando", 5.4)
		prompt(anchor, "Puffdex", "Abrir", "Puffdex")
	end
end

-- Quadro de desafios, de frente para o salão.
local function buildChallengeBoard(parent: Instance, base: Vector3)
	local board = part(parent, "ChallengeBoard", Vector3.new(0.4, 3.2, 4.4), CFrame.new(base + Vector3.new(0, 3.4, 0)), Color3.fromRGB(150, 105, 70), Enum.Material.WoodPlanks)
	part(parent, "ChallengeBoardPostA", Vector3.new(0.4, 2, 0.4), CFrame.new(base + Vector3.new(0, 1, -1.8)), Color3.fromRGB(86, 56, 38), Enum.Material.Wood)
	part(parent, "ChallengeBoardPostB", Vector3.new(0.4, 2, 0.4), CFrame.new(base + Vector3.new(0, 1, 1.8)), Color3.fromRGB(86, 56, 38), Enum.Material.Wood)
	for index = 1, 3 do
		local note = part(parent, `Note{index}`, Vector3.new(0.1, 0.8, 1), CFrame.new(base + Vector3.new(0.25, 3.8 - (index % 2) * 0.6, -1.4 + (index - 1) * 1.4)), Color3.fromRGB(255, 248, 200))
		note.CanCollide = false
	end
	sign(board, "📋 DESAFIOS", "Novos todo dia", 3.4)
	prompt(board, "Challenges", "Ver", "Desafios")
end

-- Loja: só a banca, fechada ("em breve"). Preparação para a Fase 5.
local function buildShop(parent: Instance, base: Vector3)
	local counter = part(parent, "ShopCounter", Vector3.new(2.4, 2.6, 5.6), CFrame.new(base + Vector3.new(0, 1.3, 0)), Color3.fromRGB(150, 108, 66), Enum.Material.Wood)
	local stripes = { Color3.fromRGB(255, 122, 186), Color3.fromRGB(255, 248, 238) }
	for index = 1, 4 do
		part(parent, `Awning{index}`, Vector3.new(3, 0.3, 1.4), CFrame.new(base + Vector3.new(0.3, 5.6, -2.1 + (index - 1) * 1.4)), stripes[(index % 2) + 1], Enum.Material.Fabric)
	end
	part(parent, "ShopPostA", Vector3.new(0.3, 3, 0.3), CFrame.new(base + Vector3.new(-0.9, 4.1, -2.6)), Color3.fromRGB(86, 56, 38), Enum.Material.Wood)
	part(parent, "ShopPostB", Vector3.new(0.3, 3, 0.3), CFrame.new(base + Vector3.new(-0.9, 4.1, 2.6)), Color3.fromRGB(86, 56, 38), Enum.Material.Wood)
	sign(counter, "🛍 LOJA", "Em breve", 5.8)
	prompt(counter, "Shop", "Espiar", "Loja")
end

function LobbyStationsService.start(worldRoot: Model)
	if started then
		return
	end
	started = true
	local existing = worldRoot:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	folder.Parent = worldRoot

	local gallery = BuildingLayout.getGallery(GameConfig.Arena, GameConfig.Building)
	local floorY = gallery.floorY
	local zMin = gallery.center.Z - gallery.size.Z / 2
	local westX = gallery.innerX + 3.4
	local function at(x: number, z: number): Vector3
		return Vector3.new(x, floorY, z)
	end

	local machineAt = at(gallery.innerX + 3.8, zMin + 6)
	local baraoAt = at(gallery.center.X, zMin + 6.5)
	local showcaseAt = at(westX, zMin + 22)
	local boardAt = at(westX, zMin + 37)
	local shopAt = at(gallery.innerX + 3.6, zMin + 55)
	buildMachine(folder, machineAt)
	buildFriendlyBarao(folder, baraoAt)
	buildShowcase(folder, showcaseAt, 3.5)
	buildChallengeBoard(folder, boardAt)
	buildShop(folder, shopAt)

	local reserved: { ReservedArea } = {
		{ center = machineAt, size = Vector3.new(7, 0, 7) },
		{ center = baraoAt, size = Vector3.new(8, 0, 8) },
		{ center = showcaseAt, size = Vector3.new(6, 0, 17) },
		{ center = boardAt, size = Vector3.new(6, 0, 7) },
		{ center = shopAt, size = Vector3.new(7, 0, 9) },
	}
	LobbyStationsService.reserve(reserved)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastPet[player] = nil
	end)
end

-- Soma áreas às já reservadas (a área de treino também reserva a dela).
-- É aditivo: chame só uma vez por estação, na inicialização.
local allReserved: { ReservedArea } = {}
function LobbyStationsService.reserve(areas: { ReservedArea })
	for _, area in ipairs(areas) do
		table.insert(allReserved, area)
	end
	LobbyService.setReservedAreas(allReserved)
end

return table.freeze(LobbyStationsService)
