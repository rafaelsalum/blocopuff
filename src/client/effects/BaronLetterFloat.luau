--!strict

-- Cartas do Barão flutuando (Assassinato no Casarão): cada carta (tag
-- BaronLetter) sobe e desce devagar e gira em volta do próprio eixo, cada
-- uma num compasso, para chamar o olho sem piscar. Só no cliente e só as
-- que estão perto; o servidor nunca move as cartas. Quando o próprio
-- jogador pega uma, toca o som de papel (MysteryModeController avisa).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local MysteryModeConfig = require(ReplicatedStorage.Shared.config.MysteryModeConfig)

local TAG = "BaronLetter"
-- Sobe e desce (studs) e quanto tempo leva uma ida e volta (s).
local BOB_HEIGHT = 0.25
local BOB_PERIOD = 2.4
-- Giro (radianos por segundo).
local SPIN_SPEED = 1.2
-- Só anima as cartas até esta distância da câmera.
local ANIMATE_RANGE = 90
local SOUND_LIFETIME = 3

type Letter = {
	model: Model,
	rest: CFrame,
	phase: number,
}

local BaronLetterFloat = {}

local letters: { [Model]: Letter } = {}
local started = false

local function add(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	letters[instance] = { model = instance, rest = instance:GetPivot(), phase = math.random() * math.pi * 2 }
end

local function remove(instance: Instance)
	if instance:IsA("Model") then
		letters[instance] = nil
	end
end

local function step()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local now = os.clock()
	for model, letter in pairs(letters) do
		if model.Parent == nil then
			letters[model] = nil
		elseif (letter.rest.Position - eye).Magnitude <= ANIMATE_RANGE then
			local bob = math.sin(now * 2 * math.pi / BOB_PERIOD + letter.phase) * BOB_HEIGHT
			local spin = now * SPIN_SPEED + letter.phase
			-- Gira em volta do eixo vertical do mundo, sem perder a inclinação.
			local position = letter.rest.Position + Vector3.new(0, bob, 0)
			model:PivotTo(CFrame.new(position) * CFrame.Angles(0, spin, 0) * letter.rest.Rotation)
		end
	end
end

-- Som de papel ao pegar uma carta (só quem pegou ouve).
function BaronLetterFloat.playPickup()
	local config = MysteryModeConfig.Sounds.LetterPickup
	local sound = Instance.new("Sound")
	sound.SoundId = config.Id
	sound.Volume = config.Volume
	sound.PlaybackSpeed = config.Speed
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, SOUND_LIFETIME)
end

function BaronLetterFloat.start()
	if started then
		return
	end
	started = true
	for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	RunService.RenderStepped:Connect(step)
end

return table.freeze(BaronLetterFloat)
