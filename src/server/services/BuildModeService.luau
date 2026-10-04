--!strict

-- Modo Construir do Puffador do Cofre. O cliente pede uma construção com o
-- ponto e a origem da mira; o servidor refaz a mira, escolhe o bloco (o
-- primeiro buraco da grade da arena que o raio atravessa, via
-- BuildTargeting) e só reconstrói se:
--   * o jogador está com o Puffador do Cofre na mão e ainda tem construções;
--   * respeitou a recarga entre construções;
--   * o bloco está a até BuildRange studs dele;
--   * não há ninguém dentro do espaço do bloco (nem logo acima), para não
--     prender nem enterrar jogadores.
-- Só existem os lugares originais da grade: não dá para criar paredes nem
-- blocos soltos, e as construções são limitadas por posse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local BuildTargeting = require(ReplicatedStorage.Shared.modules.BuildTargeting)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ArenaService = require(script.Parent.ArenaService)
local PuffadorService = require(script.Parent.PuffadorService)
local TelemetryService = require(script.Parent.TelemetryService)
local RoundStatsService = require(script.Parent.RoundStatsService)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Cell = BuildTargeting.Cell

-- Folga lateral da checagem de ocupação (quem está no bloco vizinho não
-- impede) e altura extra acima do bloco (pés de quem está caindo no buraco).
local OCCUPANCY_INSET = 0.4
local OCCUPANCY_HEADROOM = 5
local SOUND_BUILD = "rbxassetid://120925282182940"

local BuildModeService = {}

local remote: RemoteEvent? = nil
local connections: { RBXScriptConnection } = {}
local lastBuild: { [Player]: number } = {}

local function isFiniteVector3(vector: Vector3): boolean
	for _, value in ipairs({ vector.X, vector.Y, vector.Z }) do
		if value ~= value or value == math.huge or value == -math.huge then
			return false
		end
	end
	return true
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isOccupied(cell: Cell): boolean
	local size = GameConfig.Arena.BlockSize
	local characters: { Instance } = {}
	for _, combatant in ipairs(CombatantRegistry.all()) do
		local character = CombatantRegistry.getCharacter(combatant)
		if character ~= nil then
			table.insert(characters, character)
		end
	end
	if #characters == 0 then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = characters
	local boxSize = Vector3.new(size.X - (OCCUPANCY_INSET * 2), size.Y + OCCUPANCY_HEADROOM, size.Z - (OCCUPANCY_INSET * 2))
	local boxCenter = cell.center + Vector3.new(0, OCCUPANCY_HEADROOM / 2, 0)
	return #Workspace:GetPartBoundsInBox(CFrame.new(boxCenter), boxSize, params) > 0
end

local function playBuildSound(position: Vector3)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = SOUND_BUILD
	sound.PlaybackSpeed = 1
	sound.Volume = 0.8
	sound.RollOffMaxDistance = 90
	sound.Parent = anchor
	sound.Ended:Once(function()
		anchor:Destroy()
	end)
	sound:Play()
end

local function findTarget(player: Player, rawAimTarget: Vector3, rawAimOrigin: unknown): Cell?
	local origin = PuffadorService.resolveAimOrigin(player, rawAimOrigin)
	if origin == nil then
		return nil
	end
	local delta = rawAimTarget - origin
	if delta.Magnitude < 1e-3 then
		return nil
	end
	local direction = delta.Unit
	local reach = GameConfig.SecretRoom.BuildRange + GameConfig.Puffador.MaximumAimOriginDistance

	-- O raio para no que a mira acertou de verdade (paredes, blocos inteiros).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	params.FilterDescendantsInstances = if character ~= nil then { character } else {}
	params.IgnoreWater = true
	local hit = Workspace:Raycast(origin, direction * reach, params)
	local stopDistance = if hit ~= nil then (hit.Position - origin).Magnitude else reach

	return BuildTargeting.findTarget(GameConfig.Arena, origin, direction, reach, stopDistance, ArenaService.getCellState)
end

local function onRequestBuild(player: Player, rawAimTarget: unknown, rawAimOrigin: unknown)
	if typeof(rawAimTarget) ~= "Vector3" or not isFiniteVector3(rawAimTarget) then
		return
	end
	if not PuffadorService.isHoldingPuffador(player) or PuffadorService.getBuildCharges(player) <= 0 then
		return
	end
	local now = os.clock()
	local last = lastBuild[player]
	if last ~= nil and now - last < GameConfig.SecretRoom.BuildCooldown then
		return
	end
	lastBuild[player] = now

	local root = getRoot(player)
	local cell = findTarget(player, rawAimTarget, rawAimOrigin)
	if root == nil or cell == nil or (cell.center - root.Position).Magnitude > GameConfig.SecretRoom.BuildRange then
		PuffadorService.sendFeedback(player, "BuildBlocked", "NoTarget")
		return
	end
	if isOccupied(cell) then
		PuffadorService.sendFeedback(player, "BuildBlocked", "Occupied")
		return
	end
	if not ArenaService.rebuildBlock(cell.floor, cell.row, cell.column) then
		PuffadorService.sendFeedback(player, "BuildBlocked", "NoTarget")
		return
	end

	PuffadorService.consumeBuildCharge(player)
	PuffadorService.sendFeedback(player, "BuildDone", cell.floor)
	playBuildSound(cell.center)
	TelemetryService.blockBuilt(player, cell.floor)
	RoundStatsService.blockBuilt(CombatantRegistry.forPlayer(player))
end

function BuildModeService.start()
	if remote ~= nil then
		return
	end
	local remotes = PuffadorService.getRemotesFolder()
	if remotes == nil then
		warn("[BlocoPuff] BuildModeService: remotes folder not found; build mode disabled")
		return
	end
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = PuffadorConstants.RequestBuildRemoteName
	newRemote.Parent = remotes
	remote = newRemote
	table.insert(connections, newRemote.OnServerEvent:Connect(onRequestBuild))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		lastBuild[player] = nil
	end))
end

function BuildModeService.stop()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(lastBuild)
	local current = remote
	if current ~= nil then
		current:Destroy()
		remote = nil
	end
end

return table.freeze(BuildModeService)
