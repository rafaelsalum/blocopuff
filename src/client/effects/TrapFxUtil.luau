--!strict

-- Peças comuns aos efeitos das armadilhas do Casarão (só no cliente, sem
-- colisão nem raycast).

local TrapFxUtil = {}

TrapFxUtil.SparkleTexture = "rbxasset://textures/particles/sparkles_main.dds"
TrapFxUtil.SmokeTexture = "rbxasset://textures/particles/smoke_main.dds"

function TrapFxUtil.newSound(parent: Instance, soundId: string, speed: number, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.RollOffMaxDistance = 160
	sound.Parent = parent
	return sound
end

function TrapFxUtil.newEmitter(parent: Attachment, texture: string, color: Color3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.Enabled = false
	emitter.LightEmission = 0.4
	emitter.Parent = parent
	return emitter
end

-- Peça invisível que segura os pontos de emissão e os sons.
function TrapFxUtil.newAnchor(parent: Instance, name: string, cframe: CFrame): Part
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = cframe
	anchor.Parent = parent
	return anchor
end

-- Brilho leve de "pronta para atirar" (Rate baixo, parado no lugar).
function TrapFxUtil.newReadySparkle(parent: Attachment, color: Color3): ParticleEmitter
	local sparkle = TrapFxUtil.newEmitter(parent, TrapFxUtil.SparkleTexture, color)
	sparkle.Rate = 1.2
	sparkle.Lifetime = NumberRange.new(0.8, 1.2)
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Speed = NumberRange.new(0)
	sparkle.SpreadAngle = Vector2.new(0, 0)
	return sparkle
end

return table.freeze(TrapFxUtil)
