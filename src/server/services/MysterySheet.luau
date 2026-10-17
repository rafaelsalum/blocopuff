--!strict

-- Lençol Voador do Fantasma (Fase 5D.3): voa em linha reta pela Ala, para
-- na primeira parede ou móvel e assusta o primeiro que atingir. Simulado no
-- servidor (o cliente só pede o arremesso e a direção).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type Combatant = CombatantRegistry.Combatant

export type Throw = {
	origin: Vector3,
	direction: Vector3,
	-- Peças que param o lençol (paredes e móveis da Ala).
	obstacles: Instance,
	targets: () -> { Combatant },
	onHit: (victim: Combatant) -> (),
}

local SHEET_SIZE = Vector3.new(4, 3, 0.3)
local SHEET_COLOR = Color3.fromRGB(240, 240, 236)

local MysterySheet = {}

local active: { [Part]: RBXScriptConnection } = {}

local function finish(sheet: Part)
	local connection = active[sheet]
	if connection ~= nil then
		connection:Disconnect()
		active[sheet] = nil
	end
	sheet:Destroy()
end

function MysterySheet.throw(throw: Throw)
	local direction = Vector3.new(throw.direction.X, 0, throw.direction.Z)
	local length = direction.Magnitude
	if length ~= length or length < 1e-3 or length == math.huge or throw.origin ~= throw.origin then
		return
	end
	direction = direction.Unit
	local sheet = Instance.new("Part")
	sheet.Name = "FlyingSheet"
	sheet.Size = SHEET_SIZE
	sheet.Color = SHEET_COLOR
	sheet.Material = Enum.Material.Fabric
	sheet.Transparency = 0.15
	sheet.Anchored = true
	sheet.CanCollide = false
	sheet.CanQuery = false
	sheet.CastShadow = false
	sheet.CFrame = CFrame.lookAt(throw.origin, throw.origin + direction)
	sheet.Parent = throw.obstacles

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { throw.obstacles }

	local travelled = 0
	local position = throw.origin
	active[sheet] = RunService.Heartbeat:Connect(function(dt: number)
		local step = math.min(MysteryModeConfig.SheetSpeed * dt, MysteryModeConfig.SheetRange - travelled)
		local wallHit = workspace:Raycast(position, direction * step, params)
		local nextPosition = if wallHit ~= nil then wallHit.Position else position + direction * step
		-- Quem estiver no trecho percorrido neste quadro é atingido.
		for _, target in ipairs(throw.targets()) do
			local root = CombatantRegistry.getRoot(target)
			if root ~= nil then
				local offset = root.Position - position
				local along = math.clamp(offset:Dot(direction), 0, step)
				local closest = position + direction * along
				local gap = root.Position - closest
				if Vector3.new(gap.X, 0, gap.Z).Magnitude <= MysteryModeConfig.SheetHitRadius and math.abs(gap.Y) <= 4 then
					throw.onHit(target)
					finish(sheet)
					return
				end
			end
		end
		travelled += step
		position = nextPosition
		if wallHit ~= nil or travelled >= MysteryModeConfig.SheetRange then
			finish(sheet)
			return
		end
		sheet.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, 0, travelled * 0.2)
	end)
end

function MysterySheet.clear()
	for sheet in pairs(active) do
		finish(sheet)
	end
end

return table.freeze(MysterySheet)
