--!strict

-- Serviço autoritativo do Puffador: constrói a ferramenta, controla quando
-- cada participante a possui, recebe o RemoteEvent de disparo, valida tudo
-- no servidor e delega a simulação do projétil ao ProjectileService.
-- O cliente informa o ponto mirado e a origem do raio da câmera; o servidor
-- só aceita essa origem perto da cabeça e com linha livre até ela, e segue
-- decidindo alcance, cadência, resultado do impacto e destruição.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ProjectileService = require(script.Parent.ProjectileService)
local PuffadorModel = require(script.Parent.PuffadorModel)
local TelemetryService = require(script.Parent.TelemetryService)
local OnboardingService = require(script.Parent.OnboardingService)
local RoundStatsService = require(script.Parent.RoundStatsService)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Variant = PuffadorModel.Variant

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "PuffadorService"

local PuffadorService = {}

local remotesFolder: Folder? = nil
local requestPuffRemote: RemoteEvent? = nil
local feedbackRemote: RemoteEvent? = nil
local requestConnection: RBXScriptConnection? = nil

local acceptingRequests = false
local currentRoundId = 0

local grantedTools: { [Player]: Tool } = {}
-- Jogadores na área de treino do lobby (Puffador de treino, 4.5).
local trainees: { [Player]: boolean } = {}
local lastFireClock: { [Player]: number } = {}
-- Tiros restantes do Puffador do Cofre de cada jogador; ao zerar, volta ao
-- comum (e as construções que sobraram se perdem).
local superCharges: { [Player]: number } = {}
-- Construções restantes do modo Construir do Puffador do Cofre.
local buildCharges: { [Player]: number } = {}
-- Último disparo de cada bot RoboPuff (cadência mínima, como o jogador).
local botLastFire: { [CombatantRegistry.Combatant]: number } = {}

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function isFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteVector3(vector: Vector3): boolean
	return isFiniteNumber(vector.X) and isFiniteNumber(vector.Y) and isFiniteNumber(vector.Z)
end

local function buildPuffadorTool(variant: Variant): Tool
	return PuffadorModel.build(variant, SERVICE_NAME)
end

local function clearCooldown(player: Player)
	lastFireClock[player] = nil
end

local function removeExistingToolCopies(player: Player)
	local character = player.Character
	if character ~= nil then
		local existingInCharacter = character:FindFirstChild(PuffadorConstants.ToolName)
		if existingInCharacter ~= nil and existingInCharacter:IsA("Tool") and isOwned(existingInCharacter) then
			existingInCharacter:Destroy()
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack ~= nil then
		local existingInBackpack = backpack:FindFirstChild(PuffadorConstants.ToolName)
		if existingInBackpack ~= nil and existingInBackpack:IsA("Tool") and isOwned(existingInBackpack) then
			existingInBackpack:Destroy()
		end
	end
end

local function sendFeedback(player: Player, kind: string, value: any)
	local remote = feedbackRemote
	if remote ~= nil and player.Parent ~= nil then
		remote:FireClient(player, kind, value)
	end
end

local function grantToolToPlayer(player: Player, variant: Variant?)
	removeExistingToolCopies(player)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		warn(string.format("[BlocoPuff] Cannot grant Puffador to %s: Backpack not found", player.Name))
		return
	end

	local tool = buildPuffadorTool(variant or "Standard")
	tool.Parent = backpack
	grantedTools[player] = tool

	-- Em um jogo infantil, exigir abrir o inventário e clicar no Puffador
	-- antes de poder jogar é um passo extra desnecessário: equipamos
	-- automaticamente assim que a ferramenta é concedida. Se o personagem
	-- ainda não estiver pronto, a ferramenta apenas fica no Backpack (o
	-- jogador ainda consegue equipá-la manualmente).
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		humanoid:EquipTool(tool)
	end
end

function PuffadorService.grantTo(players: { Player })
	for _, player in ipairs(players) do
		grantToolToPlayer(player)
	end
end

function PuffadorService.revokeFrom(player: Player)
	local tool = grantedTools[player]
	if tool ~= nil then
		grantedTools[player] = nil
		if tool.Parent ~= nil then
			tool:Destroy()
		end
	end

	removeExistingToolCopies(player)
	clearCooldown(player)
	-- Zera o modo Construir no cliente (o aviso de "esgotado" é só para
	-- quando os Puffs acabam de verdade).
	if superCharges[player] ~= nil then
		sendFeedback(player, "Builds", 0)
	end
	superCharges[player] = nil
	buildCharges[player] = nil
	ProjectileService.clearFor(CombatantRegistry.forPlayer(player))
end

-- Troca o Puffador do jogador pelo Puffador do Cofre, com `charges` tiros
-- de poder dobrado e `builds` construções.
function PuffadorService.upgradeToSuper(player: Player, charges: number, builds: number): boolean
	if not acceptingRequests or grantedTools[player] == nil then
		return false
	end
	superCharges[player] = charges
	buildCharges[player] = builds
	grantToolToPlayer(player, "Super")
	sendFeedback(player, "Super", charges)
	sendFeedback(player, "Builds", builds)
	return true
end

function PuffadorService.hasSuper(player: Player): boolean
	return superCharges[player] ~= nil
end

-- Verdadeiro se o jogador está participando e com o Puffador na mão.
function PuffadorService.isHoldingPuffador(player: Player): boolean
	local tool = grantedTools[player]
	local character = player.Character
	return acceptingRequests
		and tool ~= nil
		and character ~= nil
		and tool.Parent == character
		and player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) == currentRoundId
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == false
end

function PuffadorService.getBuildCharges(player: Player): number
	return if superCharges[player] ~= nil then buildCharges[player] or 0 else 0
end

-- Gasta uma construção; devolve quantas sobraram.
function PuffadorService.consumeBuildCharge(player: Player): number
	local remaining = math.max(0, PuffadorService.getBuildCharges(player) - 1)
	buildCharges[player] = remaining
	sendFeedback(player, "Builds", remaining)
	return remaining
end

function PuffadorService.getRoundId(): number
	return currentRoundId
end

local function consumeSuperCharge(player: Player)
	local remaining = superCharges[player]
	if remaining == nil then
		return
	end
	remaining -= 1
	if remaining > 0 then
		superCharges[player] = remaining
		sendFeedback(player, "Super", remaining)
		return
	end
	superCharges[player] = nil
	buildCharges[player] = nil
	sendFeedback(player, "Super", 0)
	sendFeedback(player, "Builds", 0)
	-- Espera o tiro sair antes de trocar a arma na mão do jogador.
	task.delay(0.15, function()
		if acceptingRequests and grantedTools[player] ~= nil and superCharges[player] == nil then
			grantToolToPlayer(player, "Standard")
		end
	end)
end

local function revokeAllTracked()
	local playersToRevoke: { Player } = {}
	for player in pairs(grantedTools) do
		table.insert(playersToRevoke, player)
	end

	for _, player in ipairs(playersToRevoke) do
		PuffadorService.revokeFrom(player)
	end
end

-- Área de treino do lobby (4.5): dá ou tira um Puffador de treino. Quem
-- está com o Puffador da partida não vira treinando.
function PuffadorService.setTraining(player: Player, enabled: boolean)
	if enabled then
		if trainees[player] or grantedTools[player] ~= nil then
			return
		end
		trainees[player] = true
		grantToolToPlayer(player, "Standard")
	elseif trainees[player] then
		trainees[player] = nil
		PuffadorService.revokeFrom(player)
	end
end

function PuffadorService.isTraining(player: Player): boolean
	return trainees[player] == true
end

function PuffadorService.beginRound(players: { Player }, roundId: number)
	-- Quem foi escalado deixa de treinar e recebe o Puffador da partida.
	for _, player in ipairs(players) do
		trainees[player] = nil
	end
	ProjectileService.clearAll()
	currentRoundId = roundId
	acceptingRequests = true
	PuffadorService.grantTo(players)
end

function PuffadorService.endRound()
	acceptingRequests = false
	revokeAllTracked()
	-- A área de treino devolve o Puffador de treino a quem continuar nela.
	table.clear(trainees)
	table.clear(superCharges)
	table.clear(buildCharges)
	table.clear(botLastFire)
	ProjectileService.clearAll()
	currentRoundId = 0
end

local function computeOrigin(rootPart: BasePart, tool: Tool): Vector3
	local config = GameConfig.Puffador
	local handle = tool:FindFirstChild(PuffadorConstants.HandleName)
	if handle ~= nil and handle:IsA("BasePart") then
		local muzzle = handle:FindFirstChild(PuffadorConstants.MuzzleAttachmentName)
		if muzzle ~= nil and muzzle:IsA("Attachment") then
			local muzzlePosition = muzzle.WorldPosition
			if (muzzlePosition - rootPart.Position).Magnitude <= config.MaximumOriginDistance then
				return muzzlePosition
			end
		end
	end

	local rootCFrame = rootPart.CFrame
	return rootCFrame.Position
		+ (rootCFrame.LookVector * config.MuzzleForwardOffset)
		+ Vector3.new(0, config.MuzzleUpOffset, 0)
end

-- Origem do raio da mira. Usar a câmera (e não o cano) faz o tiro acertar
-- exatamente o que está sob a mira, como em jogos de tiro em terceira pessoa.
-- Se a origem enviada for inválida, distante ou atrás de uma parede, cai
-- para o cano, que é sempre autoritativo.
local function resolveAimOrigin(character: Model, rootPart: BasePart, rawAimOrigin: unknown, fallback: Vector3): Vector3
	if typeof(rawAimOrigin) ~= "Vector3" or not isFiniteVector3(rawAimOrigin) then
		return fallback
	end

	local head = character:FindFirstChild("Head")
	local headPosition = if head ~= nil and head:IsA("BasePart")
		then head.Position
		else rootPart.Position + Vector3.new(0, 1.5, 0)
	local toOrigin = rawAimOrigin - headPosition
	if toOrigin.Magnitude > GameConfig.Puffador.MaximumAimOriginDistance then
		return fallback
	end
	if toOrigin.Magnitude < 1e-3 then
		return rawAimOrigin
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	if Workspace:Raycast(headPosition, toOrigin, params) ~= nil then
		return fallback
	end

	return rawAimOrigin
end

local function incrementRoundBlocksDestroyed(player: Player)
	local attributeName = StateAttributeNames.PlayerRoundBlocksDestroyed
	local currentValue = player:GetAttribute(attributeName)
	local currentScore = if typeof(currentValue) == "number" then math.max(0, math.floor(currentValue)) else 0
	player:SetAttribute(attributeName, currentScore + 1)
end

local function onRequestPuff(player: Player, rawAimTarget: unknown, rawAimOrigin: unknown)
	if player.Parent == nil then
		return
	end

	-- Área de treino (4.5): vale fora da partida, sem regras de rodada.
	local isTrainee = trainees[player] == true
	if not isTrainee and not acceptingRequests then
		return
	end

	if typeof(rawAimTarget) ~= "Vector3" then
		return
	end
	if not isFiniteVector3(rawAimTarget) then
		return
	end

	if not isTrainee then
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) ~= true then
			return
		end
		if player:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) ~= currentRoundId then
			return
		end
		if player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= false then
			return
		end
	end

	local character = player.Character
	if character == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end

	local tool = grantedTools[player]
	if tool == nil or tool.Parent ~= character then
		return
	end
	if not isOwned(tool) then
		return
	end

	local now = os.clock()
	local lastFire = lastFireClock[player]
	local cooldown = GameConfig.Puffador.FireCooldown
	if lastFire ~= nil and now - lastFire < cooldown then
		return
	end

	local origin = computeOrigin(rootPart, tool)
	if (origin - rootPart.Position).Magnitude > GameConfig.Puffador.MaximumOriginDistance then
		return
	end

	local aimOrigin = resolveAimOrigin(character, rootPart, rawAimOrigin, origin)
	local aimDelta = rawAimTarget - aimOrigin
	if not isFiniteVector3(aimDelta) or aimDelta.Magnitude < GameConfig.Puffador.MinimumAimDistance then
		return
	end

	lastFireClock[player] = now
	-- Funil da primeira sessão: o primeiro tiro vale em qualquer lugar.
	OnboardingService.shot(player)

	local direction = aimDelta.Unit
	local equippedPuff = player:GetAttribute(StateAttributeNames.PlayerEquippedPuff)
	local puffId = if typeof(equippedPuff) == "string" then equippedPuff else nil
	if isTrainee then
		-- Só alvos de treino: nada de bloco, empurrão, estatística ou telemetria de tiro.
		ProjectileService.spawn(CombatantRegistry.forPlayer(player), origin, aimOrigin, direction, 0, nil, 1, PuffadorModel.getProjectileColor("Standard"), puffId, true)
		return
	end
	local isSuper = superCharges[player] ~= nil
	local variant: Variant = if isSuper then "Super" else "Standard"
	local power = if isSuper then GameConfig.SecretRoom.SuperPower else 1
	TelemetryService.shot(player, isSuper)
	local shooter = CombatantRegistry.forPlayer(player)
	RoundStatsService.shot(shooter)
	local hitSomeBlock = false
	ProjectileService.spawn(shooter, origin, aimOrigin, direction, currentRoundId, function()
		incrementRoundBlocksDestroyed(player)
		sendFeedback(player, "Hit")
		TelemetryService.blocksDestroyed(player, 1, not hitSomeBlock)
		if not hitSomeBlock then
			OnboardingService.blockDown(player)
		end
		hitSomeBlock = true
	end, power, PuffadorModel.getProjectileColor(variant), puffId)
	if isSuper then
		consumeSuperCharge(player)
	end
end

-- Disparo de um bot RoboPuff (Fase 5B): mesmas regras de rodada, alcance
-- e cadência mínima do jogador, saindo do cano do Puffador que ele segura.
-- Sem remote, Puff equipado nem telemetria. Devolve se o tiro saiu.
function PuffadorService.fireAsBot(bot: CombatantRegistry.Combatant, aimTarget: Vector3): boolean
	if not acceptingRequests or not CombatantRegistry.isPresent(bot) or not isFiniteVector3(aimTarget) then
		return false
	end
	if CombatantRegistry.getAttribute(bot, StateAttributeNames.PlayerIsParticipant) ~= true then
		return false
	end
	if CombatantRegistry.getAttribute(bot, StateAttributeNames.PlayerParticipatingRoundId) ~= currentRoundId then
		return false
	end
	if CombatantRegistry.getAttribute(bot, StateAttributeNames.PlayerIsEliminated) ~= false then
		return false
	end
	local humanoid = CombatantRegistry.getHumanoid(bot)
	local rootPart = CombatantRegistry.getRoot(bot)
	local character = CombatantRegistry.getCharacter(bot)
	if humanoid == nil or humanoid.Health <= 0 or rootPart == nil or character == nil then
		return false
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool == nil then
		return false
	end

	local now = os.clock()
	local lastFire = botLastFire[bot]
	if lastFire ~= nil and now - lastFire < GameConfig.Puffador.FireCooldown then
		return false
	end
	local origin = computeOrigin(rootPart, tool)
	local aimDelta = aimTarget - origin
	if aimDelta.Magnitude < GameConfig.Puffador.MinimumAimDistance then
		return false
	end
	botLastFire[bot] = now

	RoundStatsService.shot(bot)
	ProjectileService.spawn(bot, origin, origin, aimDelta.Unit, currentRoundId, function()
		CombatantRegistry.setAttribute(bot, StateAttributeNames.PlayerRoundBlocksDestroyed, CombatantRegistry.readCount(bot, StateAttributeNames.PlayerRoundBlocksDestroyed) + 1)
	end, 1, PuffadorModel.getProjectileColor("Standard"))
	return true
end

local function ensureRemotesContainer(): Folder
	local existing = ReplicatedStorage:FindFirstChild(PuffadorConstants.RemotesContainerName)
	if existing ~= nil then
		if not isOwned(existing) then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = PuffadorConstants.RemotesContainerName
	folder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	folder.Parent = ReplicatedStorage

	return folder
end

function PuffadorService.start(worldRoot: Model)
	if requestPuffRemote ~= nil then
		return
	end

	local folder = ensureRemotesContainer()
	remotesFolder = folder
	ProjectileService.start(worldRoot, folder)

	local remote = Instance.new("RemoteEvent")
	remote.Name = PuffadorConstants.RequestPuffRemoteName
	remote.Parent = folder
	local newFeedbackRemote = Instance.new("RemoteEvent")
	newFeedbackRemote.Name = PuffadorConstants.PuffFeedbackRemoteName
	newFeedbackRemote.Parent = folder

	requestPuffRemote = remote
	feedbackRemote = newFeedbackRemote
	requestConnection = remote.OnServerEvent:Connect(onRequestPuff)
end

-- Evento curto para um jogador (acerto, empurrão, Super). Usado também pelo
-- KnockbackService.
function PuffadorService.sendFeedback(player: Player, kind: string, value: any)
	sendFeedback(player, kind, value)
end

-- Origem validada da mira de um jogador (câmera perto da cabeça e com
-- linha livre, senão o cano). Usado também pelo modo Construir.
function PuffadorService.resolveAimOrigin(player: Player, rawAimOrigin: unknown): Vector3?
	local character = player.Character
	local tool = grantedTools[player]
	if character == nil or tool == nil then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end
	return resolveAimOrigin(character, rootPart, rawAimOrigin, computeOrigin(rootPart, tool))
end

function PuffadorService.getRemotesFolder(): Folder?
	return remotesFolder
end

function PuffadorService.stop()
	if requestConnection ~= nil then
		requestConnection:Disconnect()
		requestConnection = nil
	end

	acceptingRequests = false
	revokeAllTracked()
	table.clear(lastFireClock)
	table.clear(superCharges)
	table.clear(buildCharges)
	currentRoundId = 0

	ProjectileService.stop()

	if remotesFolder ~= nil and remotesFolder.Parent ~= nil and isOwned(remotesFolder) then
		remotesFolder:Destroy()
	end
	remotesFolder = nil
	requestPuffRemote = nil
	feedbackRemote = nil
end

return table.freeze(PuffadorService)
