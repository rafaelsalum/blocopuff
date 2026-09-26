--!strict

-- Anima localmente a quebra de um bloco da arena. O servidor continua
-- decidindo a destruição (atributo IsDestroyed replicado); o cliente só
-- reage a ele. Rodar no cliente deixa a animação fluida: tweens feitos no
-- servidor chegam em poucas atualizações por segundo e o bloco parecia
-- simplesmente sumir. Nada aqui colide ou participa de raycasts.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)

local EFFECTS_FOLDER_NAME = "LocalBlockCollapse"
local FRAGMENT_GRID = 2
local FRAGMENT_DURATION = 0.6
local FRAGMENT_FALL = 7
local FRAGMENT_SPREAD = 1.8
local FRAGMENT_MAX_TILT = 55
local FRAGMENT_END_SCALE = 0.35
local POP_DURATION = 0.06
local POP_SCALE = 1.08
local DUST_COUNT = 14
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local BlockCollapseController = {}

local started = false
local effectsFolder: Folder? = nil
local blockConnections: { [Instance]: RBXScriptConnection } = {}
local random = Random.new()

local function getEffectsFolder(): Folder
	local folder = effectsFolder
	if folder ~= nil and folder.Parent ~= nil then
		return folder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = EFFECTS_FOLDER_NAME
	newFolder.Parent = Workspace
	effectsFolder = newFolder
	return newFolder
end

local function createFragment(parent: Instance, block: BasePart, cframe: CFrame, size: Vector3): Part
	local fragment = Instance.new("Part")
	fragment.Name = "BlockFragment"
	fragment.Anchored = true
	fragment.CanCollide = false
	fragment.CanTouch = false
	fragment.CanQuery = false
	fragment.CastShadow = false
	fragment.CFrame = cframe
	fragment.Size = size
	fragment.Color = block.Color
	fragment.Material = block.Material
	fragment.TopSurface = Enum.SurfaceType.Smooth
	fragment.BottomSurface = Enum.SurfaceType.Smooth
	fragment.Parent = parent
	return fragment
end

local function animateFragment(fragment: Part, outward: Vector3)
	local startCFrame = fragment.CFrame
	local startSize = fragment.Size

	-- Pequeno "estalo" antes de cair, para o impacto ser perceptível.
	TweenService:Create(fragment, TweenInfo.new(POP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = startSize * POP_SCALE,
	}):Play()

	local tilt = CFrame.Angles(
		math.rad(random:NextNumber(-FRAGMENT_MAX_TILT, FRAGMENT_MAX_TILT)),
		math.rad(random:NextNumber(-FRAGMENT_MAX_TILT, FRAGMENT_MAX_TILT)),
		math.rad(random:NextNumber(-FRAGMENT_MAX_TILT, FRAGMENT_MAX_TILT))
	)
	local fallOffset = (outward * FRAGMENT_SPREAD) - Vector3.new(0, FRAGMENT_FALL + random:NextNumber(0, 2), 0)
	local fall = TweenService:Create(
		fragment,
		-- Quad In acelera como uma queda sob gravidade.
		TweenInfo.new(FRAGMENT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, POP_DURATION),
		{
			CFrame = (startCFrame + fallOffset) * tilt,
			Size = startSize * FRAGMENT_END_SCALE,
			Transparency = 1,
		}
	)
	fall:Play()
	Debris:AddItem(fragment, POP_DURATION + FRAGMENT_DURATION + 0.05)
end

local function emitDust(parent: Instance, block: BasePart)
	local anchor = Instance.new("Part")
	anchor.Name = "BlockDust"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(block.Size.X, 0.2, block.Size.Z)
	anchor.CFrame = block.CFrame
	anchor.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = DUST_TEXTURE
	emitter.Color = ColorSequence.new(block.Color:Lerp(Color3.new(1, 1, 1), 0.35))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 3),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -6, 0)
	emitter.Drag = 3
	emitter.LightInfluence = 1
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(DUST_COUNT)

	Debris:AddItem(anchor, 1)
end

local function playCollapse(block: BasePart)
	local parent = getEffectsFolder()
	local size = block.Size
	local pieceSize = Vector3.new(size.X / FRAGMENT_GRID, size.Y, size.Z / FRAGMENT_GRID)

	for column = 1, FRAGMENT_GRID do
		for row = 1, FRAGMENT_GRID do
			local localOffset = Vector3.new(
				((column - 0.5) / FRAGMENT_GRID - 0.5) * size.X,
				0,
				((row - 0.5) / FRAGMENT_GRID - 0.5) * size.Z
			)
			local cframe = block.CFrame * CFrame.new(localOffset)
			local fragment = createFragment(parent, block, cframe, pieceSize * 0.96)
			local outward = block.CFrame:VectorToWorldSpace(localOffset)
			outward = if outward.Magnitude > 1e-3 then outward.Unit else Vector3.zero
			animateFragment(fragment, outward)
		end
	end

	emitDust(parent, block)
end

local function watchBlock(instance: Instance)
	if blockConnections[instance] ~= nil or not instance:IsA("BasePart") then
		return
	end

	local block = instance :: BasePart
	blockConnections[instance] = block:GetAttributeChangedSignal(ArenaConstants.IsDestroyedAttribute):Connect(function()
		if block:GetAttribute(ArenaConstants.IsDestroyedAttribute) == true then
			local ok, failure = pcall(playCollapse, block)
			if not ok then
				warn(string.format("[BlocoPuff] Block collapse effect failed: %s", tostring(failure)))
			end
		end
	end)
end

local function unwatchBlock(instance: Instance)
	local connection = blockConnections[instance]
	if connection ~= nil then
		connection:Disconnect()
		blockConnections[instance] = nil
	end
end

function BlockCollapseController.start()
	if started then
		return
	end
	started = true

	for _, instance in ipairs(CollectionService:GetTagged(ArenaConstants.BlockTag)) do
		watchBlock(instance)
	end
	CollectionService:GetInstanceAddedSignal(ArenaConstants.BlockTag):Connect(watchBlock)
	CollectionService:GetInstanceRemovedSignal(ArenaConstants.BlockTag):Connect(unwatchBlock)
end

return table.freeze(BlockCollapseController)
