--!strict

-- Serviço autoritativo do Puffador: constrói a ferramenta, controla quando
-- cada participante a possui, recebe o RemoteEvent de disparo, valida tudo
-- no servidor e delega a simulação do projétil ao ProjectileService.
-- O cliente informa somente o ponto que deseja mirar; nunca escolhe origem,
-- alcance, cadência, resultado do impacto ou destruição.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ProjectileService = require(script.Parent.ProjectileService)

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

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function isFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteVector3(vector: Vector3): boolean
	return isFiniteNumber(vector.X) and isFiniteNumber(vector.Y) and isFiniteNumber(vector.Z)
end

local function buildPuffadorTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = PuffadorConstants.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Puffador"
	tool:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)

	local handle = Instance.new("Part")
	handle.Name = PuffadorConstants.HandleName
	handle.Size = Vector3.new(0.6, 2, 0.6)
	handle.Color = PuffadorConstants.PuffadorAccentColor
	handle.Material = Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	local shotSound = Instance.new("Sound")
	shotSound.Name = PuffadorConstants.ShotSoundName
	shotSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	shotSound.Volume = 0.55
	shotSound.PlaybackSpeed = 0.82
	shotSound.RollOffMaxDistance = 70
	shotSound.Parent = handle

	local hitSound = Instance.new("Sound")
	hitSound.Name = PuffadorConstants.HitSoundName
	hitSound.SoundId = "rbxasset://sounds/button.wav"
	hitSound.Volume = 0.5
	hitSound.PlaybackSpeed = 1.25
	hitSound.RollOffMaxDistance = 45
	hitSound.Parent = handle

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(1.6, 0.9, 0.9)
	barrel.Color = PuffadorConstants.PuffadorPrimaryColor
	barrel.Material = Enum.Material.SmoothPlastic
	barrel.CanCollide = false
	barrel.CanTouch = false
	barrel.CanQuery = false
	barrel.Massless = true
	barrel.CFrame = CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(90), 0)
	barrel.Parent = tool

	local barrelWeld = Instance.new("WeldConstraint")
	barrelWeld.Part0 = handle
	barrelWeld.Part1 = barrel
	barrelWeld.Parent = handle

	local bell = Instance.new("Part")
	bell.Name = "Bell"
	bell.Shape = Enum.PartType.Ball
	bell.Size = Vector3.new(1.0, 1.0, 1.0)
	bell.Color = PuffadorConstants.PuffadorAccentColor
	bell.Material = Enum.Material.SmoothPlastic
	bell.CanCollide = false
	bell.CanTouch = false
	bell.CanQuery = false
	bell.Massless = true
	bell.CFrame = CFrame.new(0, 0, -2.1)
	bell.Parent = tool

	local bellWeld = Instance.new("WeldConstraint")
	bellWeld.Part0 = handle
	bellWeld.Part1 = bell
	bellWeld.Parent = handle

	local muzzle = Instance.new("Attachment")
	muzzle.Name = PuffadorConstants.MuzzleAttachmentName
	muzzle.CFrame = CFrame.new(0, 0, -2.6)
	muzzle.Parent = handle

	-- Um Puffador largado no chão não deve permanecer ali: em vez de depender
	-- de uma API específica para impedir o descarte, removemos qualquer cópia
	-- que acabe diretamente sob o Workspace (fora de Backpack/Character).
	tool.AncestryChanged:Connect(function(descendant, newParent)
		if descendant == tool and newParent == Workspace then
			tool:Destroy()
		end
	end)

	return tool
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

local function grantToolToPlayer(player: Player)
	removeExistingToolCopies(player)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		warn(string.format("[BlocoPuff] Cannot grant Puffador to %s: Backpack not found", player.Name))
		return
	end

	local tool = buildPuffadorTool()
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
	ProjectileService.clearForPlayer(player)
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

local function onRequestPuff(player: Player, rawAimTarget: unknown)
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

	local aimDelta = rawAimTarget - origin
	if not isFiniteVector3(aimDelta) or aimDelta.Magnitude < GameConfig.Puffador.MinimumAimDistance then
		return
	end

	lastFireClock[player] = now

	local direction = aimDelta.Unit
	ProjectileService.spawn(player, origin, direction, currentRoundId, function()
		local remote = feedbackRemote
		if remote ~= nil and player.Parent ~= nil then
			remote:FireClient(player, "Hit")
		end
	end)
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

function PuffadorService.stop()
	if requestConnection ~= nil then
		requestConnection:Disconnect()
		requestConnection = nil
	end

	acceptingRequests = false
	revokeAllTracked()
	table.clear(lastFireClock)
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
