--!strict

-- Conquistas secretas (Fase 4.3), todas detectadas no servidor:
--   passagem_oculta: entrar num corredor pela passagem de um andar ainda
--                    não revelado (avisado pelo CorridorTelemetryService);
--   pula_barao:      pular o Barão 3 vezes na mesma partida (fuga "Jump");
--   mestre_quadros:  revelar as passagens de todos os andares na mesma
--                    partida;
--   por_um_fio:      vencer com até 15% da arena de pé;
--   puff_perdido:    tocar o Puff escondido num canto do lobby.
-- Cada uma vale uma vez só (o perfil guarda pelo id) e dá tickets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local SecretCatalog = require(ReplicatedStorage.Shared.config.SecretCatalog)
local MansionConfig = require(ReplicatedStorage.Shared.config.MansionConfig)
local MansionLayout = require(ReplicatedStorage.Shared.modules.MansionLayout)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)

type Profile = ProfileSchema.Profile

local FOLDER_NAME = "SecretLobbyPuff"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "SecretAchievementService"
local BARAO_JUMPS_NEEDED = 3
local NEAR_EMPTY_ARENA = 0.15
-- Canto do lobby: distância das paredes.
local CORNER_INSET = 1.6
local PUFF_COLOR = Color3.fromRGB(255, 225, 140)
local TOUCH_COOLDOWN = 2

local SecretAchievementService = {}

local started = false
local baraoJumps: { [Player]: number } = {}
local revealedFloors: { [Player]: { [number]: boolean } } = {}

local function grant(player: Player, secretId: string)
	local definition = SecretCatalog.get(secretId)
	if definition == nil or player.Parent == nil then
		return
	end
	local owned = 0
	local saved = false
	local granted = PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, PlayerDataService.Events?)
		if profile.secrets[secretId] ~= nil then
			return nil, nil
		end
		local updated = ProfileSchema.withTickets(profile, definition.tickets)
		local secrets = table.clone(profile.secrets)
		secrets[secretId] = os.time()
		updated.secrets = secrets
		for _, candidate in ipairs(SecretCatalog.all()) do
			if secrets[candidate.id] ~= nil then
				owned += 1
			end
		end
		-- Sem perfil salvo não comemora nem conta na telemetria: voltaria
		-- como nova na próxima sessão.
		saved = canSave
		return updated, { newSecrets = if canSave then { secretId } else nil }
	end, true)
	if granted and saved then
		TelemetryService.lobbyEvent(player, "SecretAchievement", owned, secretId)
		TelemetryService.lobbyEvent(player, "TicketsEarned", definition.tickets, "Secret")
	end
end

-- O CorridorTelemetryService avisa a entrada; `revealed` diz se as
-- passagens daquele andar já estavam abertas.
function SecretAchievementService.corridorEntered(player: Player, revealed: boolean)
	if not revealed then
		grant(player, "passagem_oculta")
	end
end

function SecretAchievementService.baraoEvent(kind: string, player: Player, detail: string?)
	if kind ~= "Escape" or detail ~= "Jump" then
		return
	end
	local jumps = (baraoJumps[player] or 0) + 1
	baraoJumps[player] = jumps
	if jumps >= BARAO_JUMPS_NEEDED then
		grant(player, "pula_barao")
	end
end

function SecretAchievementService.passageRevealed(player: Player, floor: number)
	local floors = revealedFloors[player] or {}
	revealedFloors[player] = floors
	floors[floor] = true
	for index = 1, GameConfig.Arena.FloorCount do
		if not floors[index] then
			return
		end
	end
	grant(player, "mestre_quadros")
end

-- Fim da rodada: `remainingRatio` = parte da arena ainda de pé (0 a 1).
function SecretAchievementService.roundFinished(winner: Player?, remainingRatio: number)
	if winner ~= nil and remainingRatio <= NEAR_EMPTY_ARENA then
		grant(winner, "por_um_fio")
	end
	table.clear(baraoJumps)
	table.clear(revealedFloors)
end

function SecretAchievementService.beginRound()
	table.clear(baraoJumps)
	table.clear(revealedFloors)
end

-- O Puff escondido: pequeno, com brilho fraco, atrás de um caixote num
-- canto do Casarão.
local function createLobbyPuff(worldRoot: Model)
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

	-- Canto nordeste do Jardim do Barão.
	local garden = MansionLayout.room("Garden")
	local x = garden.maxX - CORNER_INSET
	local z = garden.minZ + (MansionConfig.PartitionThickness / 2) + CORNER_INSET
	local floorY = MansionLayout.get().floorY

	local crate = Instance.new("Part")
	crate.Name = "Crate"
	crate.Anchored = true
	crate.Size = Vector3.new(2.6, 2.2, 2.6)
	crate.Position = Vector3.new(x - 2.4, floorY + 1.1, z + 2.4)
	crate.Color = Color3.fromRGB(150, 105, 70)
	crate.Material = Enum.Material.WoodPlanks
	crate.Parent = folder

	local puff = Instance.new("Part")
	puff.Name = "LostPuff"
	puff.Shape = Enum.PartType.Ball
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanQuery = false
	puff.CanTouch = false
	puff.Size = Vector3.new(0.9, 0.9, 0.9)
	puff.Position = Vector3.new(x, floorY + 0.7, z)
	puff.Color = PUFF_COLOR
	puff.Material = Enum.Material.Neon
	puff.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = PUFF_COLOR
	light.Brightness = 0.6
	light.Range = 5
	light.Parent = puff
	TweenService:Create(puff, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = puff.Position + Vector3.new(0, 0.35, 0),
	}):Play()

	local trigger = Instance.new("Part")
	trigger.Name = "LostPuffTrigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.Transparency = 1
	trigger.Size = Vector3.new(3, 4, 3)
	trigger.Position = Vector3.new(x, floorY + 2, z)
	trigger.Parent = folder
	-- O Touched dispara muitas vezes; o perfil garante que vale uma vez só.
	local lastTouch: { [Player]: number } = {}
	trigger.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = if character ~= nil then Players:GetPlayerFromCharacter(character) else nil
		if player == nil then
			return
		end
		local clock = os.clock()
		local last = lastTouch[player]
		if last ~= nil and clock - last < TOUCH_COOLDOWN then
			return
		end
		lastTouch[player] = clock
		grant(player, "puff_perdido")
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTouch[player] = nil
	end)
end

function SecretAchievementService.start(worldRoot: Model)
	if started then
		return
	end
	started = true
	createLobbyPuff(worldRoot)
	Players.PlayerRemoving:Connect(function(player: Player)
		baraoJumps[player] = nil
		revealedFloors[player] = nil
	end)
end

return table.freeze(SecretAchievementService)
