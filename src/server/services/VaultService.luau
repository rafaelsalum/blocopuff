--!strict

-- O Cofre do Barão Puff, atrás da porta da parede oeste do andar de baixo
-- (separado dos corredores secretos). Ele destranca no instante em que o
-- Barão acorda: todos recebem o aviso e um brilho dourado escapa por baixo
-- da porta. Quem segurar o prompt e abrir primeiro dispara o alarme para a
-- partida inteira e deixa o Barão bravo por um tempo.
--
-- Lá dentro está o Puffador do Cofre (um por rodada): quebra dois blocos por
-- disparo, empurra mais forte, tem o modo Construir e deixa quem o carrega
-- brilhando em dourado, visível para todos. A disputa é no empurrão; não há
-- eliminação especial no cofre. Para ninguém acampar lá dentro, cada
-- jogador tem um tempo total limitado no cofre por rodada; depois disso o
-- Barão o põe para fora.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildingLayout = require(ReplicatedStorage.Shared.modules.BuildingLayout)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local PuffadorService = require(script.Parent.PuffadorService)
local TelemetryService = require(script.Parent.TelemetryService)
local VaultProps = require(script.Parent.VaultProps)
local MatchAudience = require(script.Parent.MatchAudience)

type DoorProps = VaultProps.DoorProps
type OpenedListener = (player: Player) -> ()
type PrizeListener = (player: Player) -> ()

local FOLDER_NAME = "Vaults"
local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "VaultService"
local LOCKED_FEEDBACK_COOLDOWN = 1.5
local HOLDER_GLOW = Color3.fromRGB(255, 200, 70)
local SOUND_LOCKED = "rbxasset://sounds/clickfast.wav"
local SOUND_OPEN = "rbxasset://sounds/swoosh.wav"
local SPIN_SPEED = 1.6

local VaultService = {}

local folder: Folder? = nil
local vaultRemote: RemoteEvent? = nil
local doors: { DoorProps } = {}
local openedListener: OpenedListener? = nil
local prizeListener: PrizeListener? = nil
local connections: { RBXScriptConnection } = {}
local random = Random.new()

-- Estado da rodada atual. `roundToken` muda a cada rodada para invalidar
-- tarefas agendadas (destravar) de rodadas anteriores.
local roundToken = 0
local roundActive = false
local roundId = 0
local chosen: DoorProps? = nil
local unlocked = false
local opened = false
local prize: Model? = nil
local prizeHandle: Part? = nil
local prizePrompt: ProximityPrompt? = nil
local prizeBase: CFrame? = nil
local holder: Player? = nil
local holderHighlight: Highlight? = nil
local stayTime: { [Player]: number } = {}
local warned: { [Player]: boolean } = {}
local lastLockedFeedback: { [Player]: number } = {}

local function fireAll(kind: string, ...: any)
	local remote = vaultRemote
	if remote ~= nil then
		MatchAudience.fire(remote, kind, ...)
	end
end

local function fireTo(player: Player, kind: string, ...: any)
	local remote = vaultRemote
	if remote ~= nil and player.Parent ~= nil then
		remote:FireClient(player, kind, ...)
	end
end

local function isActiveParticipant(player: Player): boolean
	return roundActive
		and player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true
		and player:GetAttribute(StateAttributeNames.PlayerParticipatingRoundId) == roundId
		and player:GetAttribute(StateAttributeNames.PlayerIsEliminated) == false
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isInsideOpenVault(player: Player): boolean
	local door = chosen
	local root = getRoot(player)
	if door == nil or not opened or root == nil then
		return false
	end
	return BuildingLayout.isInsideSecretRoom(door.door, GameConfig.Building, root.Position)
end

local function clearHolder()
	if holderHighlight ~= nil then
		holderHighlight:Destroy()
		holderHighlight = nil
	end
	holder = nil
end

local function markHolder(player: Player)
	clearHolder()
	holder = player
	local character = player.Character
	if character == nil then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "SuperPuffadorGlow"
	highlight.FillColor = HOLDER_GLOW
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = HOLDER_GLOW
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	holderHighlight = highlight
end

local function destroyPrize()
	if prize ~= nil then
		prize:Destroy()
	end
	prize = nil
	prizeHandle = nil
	prizePrompt = nil
	prizeBase = nil
end

local function onPrizeTriggered(player: Player)
	if not isActiveParticipant(player) or prize == nil or not isInsideOpenVault(player) then
		return
	end
	if not PuffadorService.upgradeToSuper(player, GameConfig.SecretRoom.SuperCharges, GameConfig.SecretRoom.BuildCharges) then
		return
	end
	destroyPrize()
	markHolder(player)
	fireAll("SuperTaken", player.DisplayName, player.UserId)
	TelemetryService.vaultPrizeTaken(player)
	local listener = prizeListener
	if listener ~= nil then
		task.spawn(listener, player)
	end
end

local function spawnPrize(door: DoorProps)
	destroyPrize()
	local model, prompt, handle = VaultProps.createPrize(door.model, door.door, GameConfig.Building)
	prize = model
	prizeHandle = handle
	prizePrompt = prompt
	prizeBase = handle.CFrame
	prompt.Triggered:Connect(onPrizeTriggered)
end

local function openVault(door: DoorProps, player: Player)
	opened = true
	door.prompt.Enabled = false
	VaultProps.setOpen(door, true, true)
	VaultProps.setGlow(door, false)
	VaultProps.playSound(door, SOUND_OPEN, 0.8, 0.8)
	local token = roundToken
	VaultProps.startAlarm(door, function()
		return roundToken == token and roundActive
	end)
	if prizePrompt ~= nil then
		prizePrompt.Enabled = true
	end
	fireAll("Opened", player.DisplayName, player.UserId)
	TelemetryService.vaultOpened(player)
	local listener = openedListener
	if listener ~= nil then
		task.spawn(listener, player)
	end
end

local function onDoorTriggered(door: DoorProps, player: Player)
	if not isActiveParticipant(player) or opened then
		return
	end
	if door == chosen and unlocked then
		openVault(door, player)
		return
	end

	local now = os.clock()
	local last = lastLockedFeedback[player]
	if last ~= nil and now - last < LOCKED_FEEDBACK_COOLDOWN then
		return
	end
	lastLockedFeedback[player] = now
	VaultProps.playSound(door, SOUND_LOCKED, 0.7, 0.9)
	fireTo(player, "Locked", unlocked)
end

local function unlockChosen(token: number)
	local door = chosen
	if token ~= roundToken or not roundActive or door == nil then
		return
	end
	unlocked = true
	VaultProps.setGlow(door, true)
	fireAll("Unlocked")
end

local function expel(player: Player, door: DoorProps)
	local root = getRoot(player)
	if root == nil then
		return
	end
	local outside = door.door.center + (door.door.inward * 4) + Vector3.new(0, 3, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(outside, outside + door.door.inward)
	fireTo(player, "Expelled")
	TelemetryService.event(player, "VaultExpelled")
end

local function updateStays(deltaTime: number)
	local door = chosen
	if door == nil or not opened then
		return
	end
	local config = GameConfig.SecretRoom
	for _, player in ipairs(Players:GetPlayers()) do
		if isActiveParticipant(player) and isInsideOpenVault(player) then
			local total = (stayTime[player] or 0) + deltaTime
			stayTime[player] = total
			if total >= config.MaxStaySeconds then
				expel(player, door)
			elseif total >= config.StayWarningSeconds and not warned[player] then
				warned[player] = true
				fireTo(player, "StayWarning", math.ceil(config.MaxStaySeconds - total))
			end
		end
	end
end

local function onHeartbeat(deltaTime: number)
	if not roundActive then
		return
	end

	local handle = prizeHandle
	local base = prizeBase
	if handle ~= nil and base ~= nil then
		local t = os.clock()
		handle.CFrame = base * CFrame.new(0, math.sin(t * 2) * 0.25, 0) * CFrame.Angles(0, t * SPIN_SPEED, math.rad(-10))
	end

	-- O brilho some quando o Super acaba, o portador é eliminado ou sai.
	local current = holder
	if current ~= nil and (not PuffadorService.hasSuper(current) or not isActiveParticipant(current)) then
		clearHolder()
	end

	updateStays(deltaTime)
end

local function resetDoors()
	for _, door in ipairs(doors) do
		door.prompt.Enabled = false
		VaultProps.setOpen(door, false, false)
		VaultProps.setGlow(door, false)
	end
end

local function resetRoundState()
	roundToken += 1
	roundActive = false
	chosen = nil
	unlocked = false
	opened = false
	destroyPrize()
	clearHolder()
	table.clear(stayTime)
	table.clear(warned)
	table.clear(lastLockedFeedback)
	resetDoors()
end

-- `unlockDelay`: segundos até destrancar, o mesmo instante em que o Barão acorda.
function VaultService.beginRound(newRoundId: number, unlockDelay: number)
	resetRoundState()
	if not GameConfig.SecretRoom.Enabled or #doors == 0 then
		return
	end
	roundActive = true
	roundId = newRoundId

	local door = doors[random:NextInteger(1, #doors)]
	chosen = door
	spawnPrize(door)
	for _, candidate in ipairs(doors) do
		candidate.prompt.Enabled = true
	end

	task.delay(math.max(0, unlockDelay), unlockChosen, roundToken)
end

function VaultService.endRound()
	resetRoundState()
end

-- Avisado quando alguém abre o cofre (o Barão fica bravo).
function VaultService.setOpenedListener(listener: OpenedListener?)
	openedListener = listener
end

-- Avisado quando alguém pega o Puffador do Cofre (Momento Puff).
function VaultService.setPrizeListener(listener: PrizeListener?)
	prizeListener = listener
end

function VaultService.start(worldRoot: Model)
	if folder ~= nil then
		return
	end

	local existing = worldRoot:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_BY_ATTRIBUTE) ~= SERVICE_NAME then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	newFolder:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	newFolder.Parent = worldRoot
	folder = newFolder

	for _, door in ipairs(BuildingLayout.getSecretDoors(GameConfig.Arena, GameConfig.Building)) do
		local props = VaultProps.create(newFolder, door, GameConfig.Building)
		table.insert(doors, props)
		table.insert(connections, props.prompt.Triggered:Connect(function(player)
			onDoorTriggered(props, player)
		end))
	end

	local remotes = PuffadorService.getRemotesFolder()
	if remotes ~= nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = PuffadorConstants.VaultEventRemoteName
		remote.Parent = remotes
		vaultRemote = remote
	else
		warn("[BlocoPuff] VaultService: remotes folder not found; vault announcements disabled")
	end

	table.insert(connections, RunService.Heartbeat:Connect(onHeartbeat))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		stayTime[player] = nil
		warned[player] = nil
		lastLockedFeedback[player] = nil
		if holder == player then
			clearHolder()
		end
	end))
end

function VaultService.stop()
	resetRoundState()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(doors)
	if vaultRemote ~= nil then
		vaultRemote:Destroy()
		vaultRemote = nil
	end
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
	openedListener = nil
	prizeListener = nil
end

return table.freeze(VaultService)
