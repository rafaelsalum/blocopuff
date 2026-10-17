--!strict

-- Lustres do Casarão balançando (Fase 5C.4, parte 2): quando uma porta bate
-- perto, cada lustre (tag MansionChandelier no "…Body") balança para longe
-- da porta, preso no alto da corrente, e vai parando aos poucos, com um
-- tilintar de cristais. Só no cliente: as peças voltam ao lugar no fim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MansionAmbienceConfig = require(ReplicatedStorage.Shared.config.MansionAmbienceConfig)
local AmbienceMath = require(ReplicatedStorage.Shared.modules.AmbienceMath)

local CONFIG = MansionAmbienceConfig.Chandelier
-- Altura máxima (studs) entre a porta e o lustre (mesmo andar).
local MAX_HEIGHT = 30
-- Abaixo deste ângulo (graus) o balanço termina (sem "pulo" visível).
local SETTLE_ANGLE = 0.05
local SOUND_DISTANCE = 60
-- Por batida: só os lustres mais perto balançam e tilintam.
local MAX_SWINGS = 4
local MAX_TINKLES = 2
-- Intervalo mínimo entre dois tilintares quaisquer.
local TINKLE_GAP = 2.5
-- Tempo (s) para um reforço de balanço entrar por inteiro (sem tranco).
local BOOST_TIME = 0.3
-- Cada lustre tilinta num tom um pouco diferente.
local PITCH_SPREAD = 0.08

type Piece = { part: BasePart, rest: CFrame }

type Swing = {
	pieces: { Piece },
	pivot: Vector3,
	axis: Vector3,
	amplitude: number,
	elapsed: number,
	-- Força (graus de envelope) ainda a somar aos poucos.
	pending: number,
}

type Entry = {
	body: BasePart,
	swing: Swing?,
	lastSound: number,
	sound: Sound?,
}

local ChandelierSwing = {}

local entries: { [BasePart]: Entry } = {}
local lastTinkle = -math.huge
local random = Random.new()

function ChandelierSwing.add(instance: Instance)
	if instance:IsA("BasePart") and entries[instance] == nil then
		entries[instance] = { body = instance, swing = nil, lastSound = -math.huge, sound = nil }
	end
end

function ChandelierSwing.remove(instance: Instance)
	local entry = if instance:IsA("BasePart") then entries[instance] else nil
	if entry == nil then
		return
	end
	local swing = entry.swing
	if swing ~= nil then
		for _, piece in ipairs(swing.pieces) do
			piece.part.CFrame = piece.rest
		end
	end
	entries[instance :: BasePart] = nil
end

-- Corrente e bolinhas do mesmo lustre ("HallChandelierBody" →
-- "HallChandelierChain" e "HallChandelierBulb01".."06").
local function piecesOf(body: BasePart): ({ Piece }, Vector3?)
	local parent = body.Parent
	local prefix = string.sub(body.Name, 1, #body.Name - #"Body")
	local pieces: { Piece } = { { part = body, rest = body.CFrame } }
	local pivot: Vector3? = nil
	if parent == nil then
		return pieces, nil
	end
	for _, sibling in ipairs(parent:GetChildren()) do
		if sibling ~= body and sibling:IsA("BasePart") and string.sub(sibling.Name, 1, #prefix) == prefix then
			local rest = string.sub(sibling.Name, #prefix + 1)
			if rest == "Chain" then
				pivot = sibling.Position + Vector3.yAxis * (sibling.Size.Y / 2)
				table.insert(pieces, { part = sibling, rest = sibling.CFrame })
			elseif string.match(rest, "^Bulb%d+$") ~= nil then
				table.insert(pieces, { part = sibling, rest = sibling.CFrame })
			end
		end
	end
	return pieces, pivot
end

local function tinkle(entry: Entry, volume: number)
	local clock = os.clock()
	if clock - entry.lastSound < CONFIG.SoundCooldown or clock - lastTinkle < TINKLE_GAP then
		return
	end
	entry.lastSound = clock
	lastTinkle = clock
	local sound = entry.sound
	if sound == nil or sound.Parent == nil then
		local created = Instance.new("Sound")
		created.Name = "ChandelierTinkle"
		created.SoundId = CONFIG.SoundId
		created.RollOffMaxDistance = SOUND_DISTANCE
		created.PlaybackSpeed = 1 + random:NextNumber(-PITCH_SPREAD, PITCH_SPREAD)
		created.Parent = entry.body
		entry.sound = created
		sound = created
	end
	local current = sound :: Sound
	current.Volume = CONFIG.SoundVolume * volume
	current.TimePosition = 0
	current:Play()
end

-- Envelope atual (graus) do balanço: amplitude inicial já amortecida.
local function envelope(swing: Swing): number
	return swing.amplitude * math.exp(-swing.elapsed / CONFIG.Damping)
end

type Candidate = { entry: Entry, distance: number, away: Vector3 }

local function swing(entry: Entry, candidate: Candidate, strength: number)
	local current = entry.swing
	if current ~= nil then
		-- Já balançando: ganha força aos poucos, sem mudar a fase (nem o
		-- eixo), então o lustre não "pula" de volta ao centro.
		current.pending = math.min(CONFIG.MaxAngle, current.pending + CONFIG.MaxAngle * strength * 0.5)
		return
	end
	local pieces, pivot = piecesOf(entry.body)
	if pivot == nil then
		return
	end
	entry.swing = {
		pieces = pieces,
		pivot = pivot,
		-- Gira em volta do eixo deitado de lado: o lustre vai para longe da porta.
		axis = Vector3.yAxis:Cross(candidate.away),
		amplitude = CONFIG.MaxAngle * strength,
		elapsed = 0,
		pending = 0,
	}
end

-- Uma porta bateu em `position`: balança os lustres mais perto.
function ChandelierSwing.push(position: Vector3)
	local candidates: { Candidate } = {}
	for body, entry in pairs(entries) do
		local offset = body.Position - position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local distance = flat.Magnitude
		if distance <= CONFIG.Radius and math.abs(offset.Y) <= MAX_HEIGHT then
			table.insert(candidates, {
				entry = entry,
				distance = distance,
				away = if distance > 0.01 then flat.Unit else Vector3.xAxis,
			})
		end
	end
	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		return a.distance < b.distance
	end)
	for index = 1, math.min(#candidates, MAX_SWINGS) do
		local candidate = candidates[index]
		local strength = AmbienceMath.swingStrength(candidate.distance, CONFIG.Radius)
		swing(candidate.entry, candidate, strength)
		if index <= MAX_TINKLES and candidate.entry.swing ~= nil then
			tinkle(candidate.entry, 0.5 + strength * 0.5)
		end
	end
end

function ChandelierSwing.step(dt: number)
	for _, entry in pairs(entries) do
		local current = entry.swing
		if current == nil then
			continue
		end
		current.elapsed += dt
		if current.pending > 0 then
			local add = math.min(current.pending, CONFIG.MaxAngle * dt / BOOST_TIME)
			current.pending -= add
			local grown = math.min(CONFIG.MaxAngle, envelope(current) + add)
			-- Volta o tempo para dentro de um período (mesma fase do seno):
			-- reforços seguidos não deixam exp() crescer sem limite.
			current.elapsed %= CONFIG.Period
			current.amplitude = grown * math.exp(current.elapsed / CONFIG.Damping)
		end
		local done = current.pending <= 0 and envelope(current) < SETTLE_ANGLE
		local angle = if done then 0 else math.rad(AmbienceMath.swingAngle(current.amplitude, current.elapsed, CONFIG.Damping, CONFIG.Period))
		local turn = CFrame.new(current.pivot) * CFrame.fromAxisAngle(current.axis, angle) * CFrame.new(-current.pivot)
		for _, piece in ipairs(current.pieces) do
			if piece.part.Parent ~= nil then
				piece.part.CFrame = turn * piece.rest
			end
		end
		if done then
			entry.swing = nil
		end
	end
end

return table.freeze(ChandelierSwing)
