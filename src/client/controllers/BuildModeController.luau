--!strict

-- Modo Construir do Puffador do Cofre no cliente. Com o Puffador do Cofre na
-- mão e construções sobrando, Q (teclado), Y (controle) ou o botão 🧱 (toque)
-- alternam entre Puff e Construir. No modo Construir o disparo pede uma
-- construção ao servidor (uma por aperto) e um bloco fantasma dourado mostra
-- onde o bloco vai voltar. Quem decide tudo é o BuildModeService.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local BuildTargeting = require(ReplicatedStorage.Shared.modules.BuildTargeting)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local NotificationManager = require(script.Parent.Parent.notifications.NotificationManager)
local BuildToggleView = require(script.Parent.Parent.ui.BuildToggleView)
local FireButtonView = require(script.Parent.Parent.ui.FireButtonView)

type Cell = BuildTargeting.Cell
type CellState = BuildTargeting.CellState
type FireButtonViewHandle = FireButtonView.FireButtonViewHandle
type BuildToggleViewHandle = BuildToggleView.BuildToggleViewHandle

local WAIT_TIMEOUT = 15
local TOGGLE_ACTION = "BlocoPuffBuildToggle"
local GHOST_NAME = "BlocoPuffBuildGhost"
local GHOST_COLOR = Color3.fromRGB(255, 214, 90)

local BuildModeController = {}

local started = false
local buildRemote: RemoteEvent? = nil
local fireButton: FireButtonViewHandle? = nil
local toggleView: BuildToggleViewHandle? = nil
local ghost: Part? = nil
local previewConnection: RBXScriptConnection? = nil

local equipped = false
local hasVaultPuffador = false
local charges = 0
local active = false
local lastSequence = -1
local lastBuildClock = 0

local function isAvailable(): boolean
	return equipped and hasVaultPuffador and charges > 0
end

local function cellKey(floor: number, row: number, column: number): number
	return (floor * 1000000) + (row * 1000) + column
end

-- Estado dos blocos a partir dos atributos replicados pela arena.
local function readCellStates(): { [number]: CellState }
	local states: { [number]: CellState } = {}
	for _, block in ipairs(CollectionService:GetTagged(ArenaConstants.BlockTag)) do
		local floor = block:GetAttribute(ArenaConstants.FloorAttribute)
		local row = block:GetAttribute(ArenaConstants.GridRowAttribute)
		local column = block:GetAttribute(ArenaConstants.GridColumnAttribute)
		if typeof(floor) == "number" and typeof(row) == "number" and typeof(column) == "number" then
			local destroyed = block:GetAttribute(ArenaConstants.IsDestroyedAttribute) == true
			states[cellKey(floor, row, column)] = if destroyed then "Destroyed" else "Intact"
		end
	end
	return states
end

-- Ponto sob a mira e origem do raio (a câmera), como no disparo.
local function getAim(): (Vector3?, Vector3?, number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil, nil, 0
	end
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	if ray.Direction.Magnitude < 1e-4 then
		return nil, nil, 0
	end
	local reach = GameConfig.SecretRoom.BuildRange + GameConfig.Puffador.MaximumAimOriginDistance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	local filter: { Instance } = {}
	if character ~= nil then
		table.insert(filter, character)
	end
	local currentGhost = ghost
	if currentGhost ~= nil then
		table.insert(filter, currentGhost)
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true
	local direction = ray.Direction.Unit * reach
	local hit = Workspace:Raycast(ray.Origin, direction, params)
	local target = if hit ~= nil then hit.Position else ray.Origin + direction
	local stop = if hit ~= nil then (hit.Position - ray.Origin).Magnitude else reach
	return target, ray.Origin, stop
end

local function findPreviewCell(): Cell?
	local target, origin, stop = getAim()
	if target == nil or origin == nil then
		return nil
	end
	local states = readCellStates()
	local reach = GameConfig.SecretRoom.BuildRange + GameConfig.Puffador.MaximumAimOriginDistance
	local cell = BuildTargeting.findTarget(GameConfig.Arena, origin, target - origin, reach, stop, function(floor, row, column)
		return states[cellKey(floor, row, column)]
	end)
	if cell == nil then
		return nil
	end
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or (cell.center - root.Position).Magnitude > GameConfig.SecretRoom.BuildRange then
		return nil
	end
	return cell
end

local function getGhost(): Part
	local existing = ghost
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = GHOST_NAME
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = GHOST_COLOR
	part.Transparency = 0.65
	part.Size = GameConfig.Arena.BlockSize + Vector3.new(0.1, 0.1, 0.1)
	local box = Instance.new("SelectionBox")
	box.Adornee = part
	box.Color3 = GHOST_COLOR
	box.LineThickness = 0.08
	box.Parent = part
	part.Parent = Workspace.CurrentCamera
	ghost = part
	return part
end

local function hideGhost()
	local existing = ghost
	if existing ~= nil then
		existing:Destroy()
		ghost = nil
	end
end

local function stopPreview()
	local connection = previewConnection
	if connection ~= nil then
		connection:Disconnect()
		previewConnection = nil
	end
	hideGhost()
end

local function startPreview()
	stopPreview()
	previewConnection = RunService.RenderStepped:Connect(function()
		local cell = findPreviewCell()
		if cell == nil then
			local existing = ghost
			if existing ~= nil then
				existing.Transparency = 1
				local box = existing:FindFirstChildOfClass("SelectionBox")
				if box ~= nil then
					box.Visible = false
				end
			end
			return
		end
		local part = getGhost()
		part.CFrame = CFrame.new(cell.center)
		part.Transparency = 0.65
		local box = part:FindFirstChildOfClass("SelectionBox")
		if box ~= nil then
			box.Visible = true
		end
	end)
end

local function refresh()
	if active and not isAvailable() then
		active = false
	end
	local button = fireButton
	if button ~= nil then
		if active then
			button.setLabel("BLOCO!", "CONSTRUIR")
		else
			button.setLabel("PUFF!", "ATIRAR")
		end
	end
	local toggle = toggleView
	if toggle ~= nil then
		toggle.setVisible(isAvailable() and UserInputService.TouchEnabled)
		toggle.setMode(active, charges)
	end
	if active then
		if previewConnection == nil then
			startPreview()
		end
	else
		stopPreview()
	end
end

local function setActive(value: boolean)
	local wanted = value and isAvailable()
	if wanted == active then
		return
	end
	active = wanted
	refresh()
	if active then
		NotificationManager.notify({
			channel = "Banner",
			category = "Build",
			priority = "Low",
			key = "build-mode",
			icon = "🧱",
			title = "MODO CONSTRUIR",
			subtitle = string.format("Mire num buraco da arena e dispare (%d restantes)", charges),
			tone = "Gold",
			duration = 2.2,
		})
	end
end

local function toggle()
	setActive(not active)
end

local function bindToggle(bound: boolean)
	if bound then
		ContextActionService:BindAction(TOGGLE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				toggle()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
	else
		ContextActionService:UnbindAction(TOGGLE_ACTION)
	end
end

local function updateAvailability()
	bindToggle(isAvailable())
	refresh()
end

local function blockedMessage(reason: unknown): string
	if reason == "Occupied" then
		return "Tem alguém no lugar do bloco"
	end
	return "Mire num buraco da arena, mais perto"
end

local function onFeedback(kind: unknown, value: unknown)
	if kind == "Super" then
		hasVaultPuffador = typeof(value) == "number" and value > 0
		updateAvailability()
	elseif kind == "Builds" then
		charges = if typeof(value) == "number" and value == value then math.max(0, math.floor(value)) else 0
		updateAvailability()
	elseif kind == "BuildDone" then
		if charges <= 0 then
			NotificationManager.notify({
				channel = "Banner",
				category = "Build",
				priority = "Low",
				key = "build-mode",
				icon = "🧱",
				title = "CONSTRUÇÕES ESGOTADAS",
				subtitle = "Seu Puffador do Cofre volta a só dar Puff",
				tone = "Info",
				duration = 2,
			})
		end
	elseif kind == "BuildBlocked" then
		NotificationManager.notify({
			channel = "Banner",
			category = "Build",
			priority = "Low",
			key = "build-blocked",
			icon = "🚫",
			title = "NÃO DÁ PARA CONSTRUIR AQUI",
			subtitle = blockedMessage(value),
			tone = "Warning",
			duration = 1.6,
		})
	end
end

-- Verdadeiro se o disparo deve virar construção agora.
function BuildModeController.isActive(): boolean
	return active and isAvailable()
end

-- Pede uma construção. `sequence` identifica o aperto do botão: segurar o
-- disparo não gasta várias construções seguidas.
function BuildModeController.tryBuild(sequence: number)
	local remote = buildRemote
	if remote == nil or sequence == lastSequence then
		return
	end
	local now = os.clock()
	if now - lastBuildClock < GameConfig.SecretRoom.BuildCooldown then
		return
	end
	local target, origin = getAim()
	if target == nil or origin == nil then
		return
	end
	lastSequence = sequence
	lastBuildClock = now
	remote:FireServer(target, origin)
	local button = fireButton
	if button ~= nil and UserInputService.TouchEnabled then
		button.startCooldown(GameConfig.SecretRoom.BuildCooldown)
	end
end

-- Chamado pelo PuffadorController ao equipar (tool) ou guardar (nil). Só o
-- Puffador do Cofre (atributo Variant = "Super") tem o modo Construir.
function BuildModeController.setEquipped(tool: Tool?)
	local value = tool ~= nil and tool:GetAttribute("Variant") == "Super"
	equipped = value
	if not value then
		active = false
	end
	updateAvailability()
end

function BuildModeController.attach(playerGui: PlayerGui, button: FireButtonViewHandle)
	fireButton = button
	if toggleView == nil then
		toggleView = BuildToggleView.new(playerGui, button.screenGui, toggle)
	end
	refresh()
end

function BuildModeController.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		if remotes == nil then
			warn("[BlocoPuff] Build mode controller: remotes not found")
			return
		end
		local feedback = remotes:WaitForChild(PuffadorConstants.PuffFeedbackRemoteName, WAIT_TIMEOUT)
		if feedback ~= nil and feedback:IsA("RemoteEvent") then
			feedback.OnClientEvent:Connect(onFeedback)
		end
		local remote = remotes:WaitForChild(PuffadorConstants.RequestBuildRemoteName, WAIT_TIMEOUT)
		if remote ~= nil and remote:IsA("RemoteEvent") then
			buildRemote = remote
		else
			warn("[BlocoPuff] Build mode controller: build remote not found")
		end
	end)
end

return table.freeze(BuildModeController)
