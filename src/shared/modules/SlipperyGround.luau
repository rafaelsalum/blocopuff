--!strict

-- Chão escorregadio (Chuva, Fase 5.6) num personagem: com pouca tração, a
-- velocidade horizontal só chega aos poucos à velocidade que o jogador
-- quer andar (difícil frear e mudar de direção). Quem chama é quem simula
-- o personagem, como no CharacterImpulse: o cliente para o próprio
-- personagem e o servidor para os bots. Um empurrão, o escorregão do
-- tapete ou o impulso em andamento têm prioridade; no ar não muda nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterImpulse = require(ReplicatedStorage.Shared.modules.CharacterImpulse)

local SLIP_NAME = CharacterImpulse.SlipName
-- Abaixo desta fração da velocidade lembrada, o personagem foi barrado.
local BLOCKED_RATIO = 0.6

export type State = {
	attachment: Attachment?,
	constraint: LinearVelocity?,
	-- Velocidade horizontal atual no chão molhado (nil: acabou de entrar).
	velocity: Vector3?,
}

local SlipperyGround = {}

function SlipperyGround.new(): State
	return { attachment = nil, constraint = nil, velocity = nil }
end

local function ensureConstraint(state: State, root: BasePart): LinearVelocity
	local constraint = state.constraint
	local attachment = state.attachment
	if constraint ~= nil and attachment ~= nil and attachment.Parent == root then
		return constraint
	end
	SlipperyGround.release(state)
	local newAttachment = Instance.new("Attachment")
	newAttachment.Name = SLIP_NAME
	newAttachment.Parent = root
	local newConstraint = Instance.new("LinearVelocity")
	newConstraint.Attachment0 = newAttachment
	newConstraint.RelativeTo = Enum.ActuatorRelativeTo.World
	newConstraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	newConstraint.PrimaryTangentAxis = Vector3.xAxis
	newConstraint.SecondaryTangentAxis = Vector3.zAxis
	newConstraint.MaxForce = math.huge
	newConstraint.Enabled = false
	newConstraint.Parent = newAttachment
	state.attachment = newAttachment
	state.constraint = newConstraint
	return newConstraint
end

-- Desliga o escorregão (o personagem volta ao andar normal).
local function pause(state: State)
	local constraint = state.constraint
	if constraint ~= nil then
		constraint.Enabled = false
	end
	state.velocity = nil
end

-- Um quadro: `slippery` diz se o personagem está no chão molhado agora;
-- `grip` é a tração (por segundo).
function SlipperyGround.step(state: State, root: BasePart, humanoid: Humanoid, dt: number, slippery: boolean, grip: number)
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if not slippery or humanoid.Health <= 0 or CharacterImpulse.isBeingPushed(root) then
		pause(state)
		return
	end
	if not grounded then
		-- No ar o pulo segue normal; ao cair de volta, parte da velocidade
		-- que tiver.
		pause(state)
		return
	end
	local current = root.AssemblyLinearVelocity
	local actual = Vector3.new(current.X, 0, current.Z)
	local velocity = state.velocity or actual
	-- Bateu em algo (parede, borda): segue a velocidade de verdade, sem
	-- empurrar contra o obstáculo.
	if actual.Magnitude < velocity.Magnitude * BLOCKED_RATIO then
		velocity = actual
	end
	local move = humanoid.MoveDirection
	local desired = Vector3.new(move.X, 0, move.Z) * humanoid.WalkSpeed
	local alpha = 1 - math.exp(-grip * math.max(dt, 0))
	velocity += (desired - velocity) * alpha
	state.velocity = velocity
	local constraint = ensureConstraint(state, root)
	constraint.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	constraint.Enabled = true
end

-- Remove o escorregão de vez (personagem trocado, chuva acabou).
function SlipperyGround.release(state: State)
	local attachment = state.attachment
	if attachment ~= nil then
		attachment:Destroy()
	end
	state.attachment = nil
	state.constraint = nil
	state.velocity = nil
end

return table.freeze(SlipperyGround)
