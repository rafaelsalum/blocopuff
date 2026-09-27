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
local lastFireClock: { [Player]: number } = {}
-- Tiros restantes do Super Puffador de cada jogador; ao zerar, volta ao comum.
local superCharges: { [Player]: number } = {}

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
	superCharges[player] = nil
	ProjectileService.clearForPlayer(player)
end

-- Troca o Puffador do jogador pelo Super, com `charges` tiros de poder dobrado.
function PuffadorService.upgradeToSuper(player: Player, charges: number): boolean
	if not acceptingRequests or grantedTools[player] == nil then
		return false
	end
	superCharges[player] = charges
	grantToolToPlayer(player, "Super")
	sendFeedback(player, "Super", charges)
	return true
end

function PuffadorService.hasSuper(player: Player): boolean
	return superCharges[player] ~= nil
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
	sendFeedback(player, "Super", 0)
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

function PuffadorService.beginRound(players: { Player }, roundId: number)
	ProjectileService.clearAll()
	currentRoundId = roundId
	acceptingRequests = true
	PuffadorService.grantTo(players)
end

function PuffadorService.endRound()
	acceptingRequests = false
	revokeAllTracked()
	table.clear(superCharges)
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

	if not acceptingRequests then
		return
	end

	if typeof(rawAimTarget) ~= "Vector3" then
		return
	end
	if not isFiniteVector3(rawAimTarget) then
		return
	end

	if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) ~= true then
		return
	end
	if player:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) ~= currentRoundId then
		return
	end
	if player:GetAttribute(StateAttributeNames.PlayerIsEliminated) ~= false then
		return
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

	local direction = aimDelta.Unit
	local isSuper = superCharges[player] ~= nil
	local variant: Variant = if isSuper then "Super" else "Standard"
	local power = if isSuper then GameConfig.SecretRoom.SuperPower else 1
	TelemetryService.shot(player)
	local hitSomeBlock = false
	ProjectileService.spawn(player, origin, aimOrigin, direction, currentRoundId, function()
		incrementRoundBlocksDestroyed(player)
		sendFeedback(player, "Hit")
		TelemetryService.blocksDestroyed(player, 1, not hitSomeBlock)
		hitSomeBlock = true
	end, power, PuffadorModel.getProjectileColor(variant))
	if isSuper then
		consumeSuperCharge(player)
	end
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

	ProjectileService.start(worldRoot)

	local folder = ensureRemotesContainer()
	remotesFolder = folder

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
