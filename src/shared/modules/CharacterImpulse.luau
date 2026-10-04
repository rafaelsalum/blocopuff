--!strict

-- Física dos empurrões num personagem: o empurrão do Puffador (e das
-- armadilhas), o escorregão do Tapete Puxado, o impulso e a parada da queda
-- na Segunda Chance. Quem chama é quem simula o personagem: o cliente para o próprio
-- personagem (KnockbackController) e o servidor para os bots RoboPuff
-- (KnockbackService). Os valores já chegam validados.

local GameConfig = require(script.Parent.Parent.config.GameConfig)

local MAX_SPEED = 200
local PUSH_NAME = "BlocoPuffKnockback"
-- Anexo do chão escorregadio da Chuva (SlipperyGround).
local SLIP_NAME = "BlocoPuffSlip"

local CharacterImpulse = {}

CharacterImpulse.SlipName = SLIP_NAME

local function clampSpeed(velocity: Vector3): Vector3
	if velocity.Magnitude > MAX_SPEED then
		return velocity.Unit * MAX_SPEED
	end
	return velocity
end

-- Troca o empurrão em andamento (se houver) por um novo anexo.
local function freshAttachment(root: BasePart): Attachment
	-- O empurrão manda já neste quadro: o escorregão da Chuva se desliga
	-- (o SlipperyGround religa quando o empurrão acabar).
	local slip = root:FindFirstChild(SLIP_NAME)
	local slipConstraint = if slip ~= nil then slip:FindFirstChildOfClass("LinearVelocity") else nil
	if slipConstraint ~= nil then
		slipConstraint.Enabled = false
	end
	local existing = root:FindFirstChild(PUSH_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = PUSH_NAME
	attachment.Parent = root
	return attachment
end

local function removeAfter(attachment: Attachment, duration: number)
	task.delay(duration, function()
		if attachment.Parent ~= nil then
			attachment:Destroy()
		end
	end)
end

-- Um LinearVelocity curto garante o empurrão mesmo com o Humanoid no chão
-- (ele anularia uma velocidade horizontal escrita diretamente). Ao terminar,
-- o personagem segue com o impulso e cai normalmente.
function CharacterImpulse.knockback(root: BasePart, humanoid: Humanoid, velocity: Vector3)
	local attachment = freshAttachment(root)
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = clampSpeed(velocity)
	push.MaxForce = math.huge
	push.Parent = attachment

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	removeAfter(attachment, GameConfig.Knockback.Duration)
end

-- Escorregão: segura só a velocidade horizontal por `duration` segundos,
-- sem mudar o estado do Humanoid. A vertical fica livre, então quem passa
-- por cima de um buraco cai.
function CharacterImpulse.slide(root: BasePart, velocity: Vector3, duration: number)
	local flat = clampSpeed(Vector3.new(velocity.X, 0, velocity.Z))
	local attachment = freshAttachment(root)
	local slide = Instance.new("LinearVelocity")
	slide.Attachment0 = attachment
	slide.RelativeTo = Enum.ActuatorRelativeTo.World
	slide.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	slide.PrimaryTangentAxis = Vector3.xAxis
	slide.SecondaryTangentAxis = Vector3.zAxis
	slide.PlaneVelocity = Vector2.new(flat.X, flat.Z)
	slide.MaxForce = math.huge
	slide.Parent = attachment

	removeAfter(attachment, duration)
end

-- Sendo empurrado ou escorregando agora (o impulso não serve para fugir
-- de um empurrão no meio).
function CharacterImpulse.isBeingPushed(root: BasePart): boolean
	return root:FindFirstChild(PUSH_NAME) ~= nil
end

-- Impulso: arrancada horizontal na direção `direction` por `duration`
-- segundos. No ar, a queda para no início da arrancada (ela não afunda).
-- Um empurrão que chegar no meio substitui o impulso.
function CharacterImpulse.dash(root: BasePart, direction: Vector3, speed: number, duration: number)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local current = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(current.X, math.max(current.Y, 0), current.Z)
	CharacterImpulse.slide(root, flat.Unit * speed, duration)
end

-- Segunda Chance: cancela o empurrão e zera a queda. Se o personagem ainda
-- estiver longe de `cframe`, leva-o até lá.
function CharacterImpulse.stopFalling(root: BasePart, cframe: CFrame)
	local existing = root:FindFirstChild(PUSH_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if (root.Position - cframe.Position).Magnitude > 8 then
		local character = root.Parent
		if character ~= nil and character:IsA("Model") then
			character:PivotTo(cframe)
		end
	end
end

return table.freeze(CharacterImpulse)
