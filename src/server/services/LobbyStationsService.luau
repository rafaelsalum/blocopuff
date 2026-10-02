--!strict

-- Estações do lobby, espalhadas pelas salas do Casarão (MansionLayout). Cada
-- uma tem um ProximityPrompt que abre a tela correspondente no cliente (o
-- atributo "LobbyStation" diz qual):
--   Salão da Coleção → vitrine com todos os Puffs, púlpito do Puffdex e a
--                      Puff Machine;
--   Jardim do Barão  → o Barão amigável dormindo na caminha (dá para fazer
--                      carinho) e a loja "em breve" (nada é vendido);
--   Ponto de Encontro → quadro de desafios e o canto da Party.
-- O treino (ala sul) é do TrainingService.
--
-- Pensado para celular: poucas peças, nenhuma luz extra, placas com
-- distância máxima e nada animado continuamente pelo servidor.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local PuffEffects = require(ReplicatedStorage.Shared.modules.PuffEffects)
local BaraoModel = require(ReplicatedStorage.Shared.modules.BaraoModel)
local TelemetryService = require(script.Parent.TelemetryService)

type PuffDefinition = PuffCatalog.PuffDefinition

local FOLDER_NAME = "LobbyStations"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "LobbyStationsService"
local STATION_ATTRIBUTE = "LobbyStation"
local SIGN_DISTANCE = 45
local PROMPT_DISTANCE = 9
local PET_COOLDOWN = 2
-- Barão do Jardim: tamanho, caminha e quanto tempo fica feliz no carinho.
local FRIENDLY_BARAO_SCALE = 1.15
local FRIENDLY_BED_SIZE = 6.5
local FRIENDLY_PROMPT_GAP = 1.5
local FRIENDLY_PROMPT_HEIGHT = 1
local FRIENDLY_BARAO_TAG = "BaraoFriendly"
local PET_ATTRIBUTE = "BaraoPet"
-- Vitrine: Puffs por fileira e distância entre pedestais.
local SHOWCASE_PER_ROW = 11
local SHOWCASE_SPACING = 9.4
-- Fração da quantidade de partículas do disparo usada na vitrine.
local SHOWCASE_EFFECT_RATE = 0.25

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

-- Puff Machine: gabinete com cúpula de cápsulas; `facing` (±1) diz para
-- que lado de X fica a abertura.
local function buildMachine(parent: Instance, base: Vector3, facing: number)
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
	local slot = part(model, "Slot", Vector3.new(0.2, 0.8, 1.6), CFrame.new(base + Vector3.new(facing * 1.55, 1.6, 0)), Color3.fromRGB(26, 21, 48))
	slot.CanCollide = false
	sign(cabinet, "🎰 PUFF MACHINE", "Tickets viram Puffs", 6.2)
	prompt(cabinet, "PuffMachine", "Girar", "Puff Machine")
	model.PrimaryPart = cabinet
end

-- Barão amigável: dorme numa caminha; carinho faz ele acordar, pular e
-- abanar o rabo. Quem anima é o cliente (BaraoVisualController, tag
-- BaraoFriendly); aqui só o contador "BaraoPet" avisa do carinho.
local function buildFriendlyBarao(parent: Instance, base: Vector3)
	-- Cilindro com o eixo (X) em pé: um disco baixo.
	local bed = part(parent, "BaraoBed", Vector3.new(0.6, FRIENDLY_BED_SIZE, FRIENDLY_BED_SIZE), CFrame.new(base + Vector3.new(0, 0.3, 0)), Color3.fromRGB(64, 40, 70), Enum.Material.Fabric, Enum.PartType.Cylinder)
	bed.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local barao = BaraoModel.build(FRIENDLY_BARAO_SCALE)
	barao.Name = "BaraoLobby"
	-- De frente para o arco do Salão Principal (−X); o modelo olha para −Z.
	local restCFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.pi / 2, 0)
	barao:PivotTo(restCFrame)
	barao:SetAttribute(PET_ATTRIBUTE, 0)
	barao:SetAttribute(BaraoModel.RestAttribute, restCFrame)
	barao.Parent = parent
	CollectionService:AddTag(barao, FRIENDLY_BARAO_TAG)
	local body = barao:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") then
		return
	end
	sign(body, "🐶 BARÃO", "Aqui ele é bonzinho", 4.2 * FRIENDLY_BARAO_SCALE)
	local sleep = Instance.new("BillboardGui")
	sleep.Name = "Sleep"
	sleep.Size = UDim2.new(2, 0, 1.2, 0)
	sleep.StudsOffset = Vector3.new(1.2, 2.6, 0) * FRIENDLY_BARAO_SCALE
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

	-- O aviso de carinho fica na frente da caminha, baixo, para não tapar
	-- o Barão (ele olha para −X).
	local anchor = part(
		parent,
		"BaraoPromptAnchor",
		Vector3.new(1, 1, 1),
		CFrame.new(base + Vector3.new(-((FRIENDLY_BED_SIZE / 2) + FRIENDLY_PROMPT_GAP), FRIENDLY_PROMPT_HEIGHT, 0)),
		Color3.new(1, 1, 1)
	)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	local proximity = prompt(anchor, "Barao", "Fazer carinho", "Barão")
	local happy = false
	proximity.Triggered:Connect(function(player: Player)
		local clock = os.clock()
		local last = lastPet[player]
		if happy or (last ~= nil and clock - last < PET_COOLDOWN) then
			return
		end
		lastPet[player] = clock
		happy = true
		zzz.Text = "💜"
		TelemetryService.lobbyEvent(player, "BaraoPet", 1)
		barao:SetAttribute(PET_ATTRIBUTE, ((barao:GetAttribute(PET_ATTRIBUTE) :: number?) or 0) + 1)
		task.delay(BaraoModel.FriendlyHappySeconds, function()
			zzz.Text = "Zzz"
			happy = false
		end)
	end)
end

-- Um Puff exposto: nuvem de três bolinhas foscas nas cores do rastro, sobre
-- um pedestal com faixa metálica da cor da raridade. Sem neon: as cores
-- ficam legíveis de perto e de longe (o neon estourava a luz da sala).
local function buildPedestal(parent: Instance, index: number, definition: PuffDefinition, position: Vector3)
	local rarity = PuffCatalog.rarity(definition.rarity)
	local style = definition.style
	part(parent, `Pedestal{index}`, Vector3.new(1.8, 2.6, 1.8), CFrame.new(position + Vector3.new(0, 1.3, 0)), Color3.fromRGB(232, 226, 214), Enum.Material.Marble)
	part(parent, `Band{index}`, Vector3.new(1.95, 0.3, 1.95), CFrame.new(position + Vector3.new(0, 2.45, 0)), rarity.color, Enum.Material.Metal)
	local center = position + Vector3.new(0, 3.55, 0)
	local cloud = part(parent, `Puff{index}`, Vector3.new(1.3, 1.3, 1.3), CFrame.new(center), style.trailStart, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cloud.CanCollide = false
	-- O efeito do Puff de verdade (partículas), bem mais calmo que no disparo.
	PuffEffects.attach(cloud, style, SHOWCASE_EFFECT_RATE)
	for side, offset in ipairs({ Vector3.new(-0.55, -0.25, 0.1), Vector3.new(0.55, -0.2, -0.1) }) do
		local puffball = part(parent, `Puff{index}Side{side}`, Vector3.new(0.85, 0.85, 0.85), CFrame.new(center + offset), style.trailEnd, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		puffball.CanCollide = false
	end
	-- Aro de vidro fino da cor do brilho, só como moldura.
	local ring = part(parent, `Ring{index}`, Vector3.new(0.12, 2.2, 2.2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), style.glow, Enum.Material.Glass, Enum.PartType.Cylinder)
	ring.Transparency = 0.7
	ring.CanCollide = false
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.new(4.4, 0, 1.1, 0)
	label.StudsOffset = Vector3.new(0, 1.7, 0)
	label.MaxDistance = 30
	label.LightInfluence = 0
	label.Parent = cloud
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.Text = `{PuffEffects.info(style.effect).icon} {definition.name} · {rarity.label}`
	text.TextColor3 = rarity.color
	text.TextScaled = true
	text.TextStrokeTransparency = 0.2
	text.Parent = label
end

-- Vitrine com todos os Puffs do catálogo, em fileiras ao longo do Salão da
-- Coleção (`rowZ` de cada fileira, começando em `startX`).
local function buildShowcase(parent: Instance, floorY: number, startX: number, rowZ: { number })
	local model = Instance.new("Model")
	model.Name = "PuffShowcase"
	model.Parent = parent
	for index, definition in ipairs(PuffCatalog.all()) do
		local row = math.floor((index - 1) / SHOWCASE_PER_ROW) + 1
		local z = rowZ[row]
		if z == nil then
			break
		end
		local column = (index - 1) % SHOWCASE_PER_ROW
		-- Fileiras alternadas ficam defasadas, para não esconder uma a outra.
		local x = startX + (column * SHOWCASE_SPACING) + (if row % 2 == 0 then SHOWCASE_SPACING / 2 else 0)
		buildPedestal(model, index, definition, Vector3.new(x, floorY, z))
	end
end

-- Púlpito com o livro do Puffdex, virado para os arcos (+Z).
local function buildPuffdexLectern(parent: Instance, base: Vector3)
	local stand = part(parent, "PuffdexLectern", Vector3.new(2.4, 3, 1.6), CFrame.new(base + Vector3.new(0, 1.5, 0)), Color3.fromRGB(86, 56, 38), Enum.Material.Wood)
	local book = part(parent, "PuffdexBook", Vector3.new(2.6, 0.3, 1.9), CFrame.new(base + Vector3.new(0, 3.2, 0.1)) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(104, 76, 204), Enum.Material.Fabric)
	book.CanCollide = false
	sign(stand, "✨ PUFFDEX", "Colecione Puffs jogando", 5)
	prompt(stand, "Puffdex", "Abrir", "Puffdex")
end

-- Quadro de desafios, de frente para o salão (+X).
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

-- Loja: só a banca, fechada ("em breve"). Preparação para a Fase 6.
-- `facing` (±1) diz para que lado de X fica o balcão.
local function buildShop(parent: Instance, base: Vector3, facing: number)
	local counter = part(parent, "ShopCounter", Vector3.new(2.4, 2.6, 5.6), CFrame.new(base + Vector3.new(0, 1.3, 0)), Color3.fromRGB(150, 108, 66), Enum.Material.Wood)
	local stripes = { Color3.fromRGB(255, 122, 186), Color3.fromRGB(255, 248, 238) }
	for index = 1, 4 do
		part(parent, `Awning{index}`, Vector3.new(3, 0.3, 1.4), CFrame.new(base + Vector3.new(facing * 0.3, 5.6, -2.1 + (index - 1) * 1.4)), stripes[(index % 2) + 1], Enum.Material.Fabric)
	end
	part(parent, "ShopPostA", Vector3.new(0.3, 3, 0.3), CFrame.new(base + Vector3.new(-facing * 0.9, 4.1, -2.6)), Color3.fromRGB(86, 56, 38), Enum.Material.Wood)
	part(parent, "ShopPostB", Vector3.new(0.3, 3, 0.3), CFrame.new(base + Vector3.new(-facing * 0.9, 4.1, 2.6)), Color3.fromRGB(86, 56, 38), Enum.Material.Wood)
	sign(counter, "🛍 LOJA", "Em breve", 5.8)
	prompt(counter, "Shop", "Espiar", "Loja")
end

-- Canto da Party: placa em pé entre os sofás do Ponto de Encontro.
local function buildPartyPost(parent: Instance, base: Vector3)
	local post = part(parent, "PartyPost", Vector3.new(0.5, 3.6, 0.5), CFrame.new(base + Vector3.new(0, 1.8, 0)), Color3.fromRGB(86, 56, 38), Enum.Material.Wood)
	local board = part(parent, "PartyBoard", Vector3.new(3.6, 1.8, 0.3), CFrame.new(base + Vector3.new(0, 4.2, 0)), Color3.fromRGB(64, 92, 140), Enum.Material.WoodPlanks)
	board.CanCollide = false
	sign(post, "👥 PARTY", "Chame amigos para jogar juntos", 6.2)
	prompt(post, "Party", "Abrir", "Party")
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

	local mansion = MansionLayout.get()
	local floorY = mansion.floorY
	local half = MansionConfig.PartitionThickness / 2
	local collection = MansionLayout.room("Collection")
	local garden = MansionLayout.room("Garden")
	local meeting = MansionLayout.roomCenter("Meeting")
	local function at(x: number, z: number): Vector3
		return Vector3.new(x, floorY, z)
	end

	buildShowcase(folder, floorY, collection.minX + 8, { collection.minZ + 5, collection.minZ + 15 })
	buildPuffdexLectern(folder, at((collection.minX + collection.maxX) / 2, collection.maxZ - half - 6))
	buildMachine(folder, at(collection.maxX - 4.5, collection.maxZ - half - 9), -1)
	buildFriendlyBarao(folder, MansionLayout.roomCenter("Garden"))
	buildShop(folder, at(garden.maxX - 3.5, (garden.minZ + garden.maxZ) / 2 + 12), -1)
	buildChallengeBoard(folder, at(MansionLayout.room("Meeting").minX + 1.5, meeting.Z - 5))
	buildPartyPost(folder, meeting + Vector3.new(0, 0, 13))

	Players.PlayerRemoving:Connect(function(player: Player)
		lastPet[player] = nil
	end)
end

return table.freeze(LobbyStationsService)
