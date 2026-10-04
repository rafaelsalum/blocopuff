--!strict

-- Janela-armadilha (Fase 5). Cada janela sorteia, a cada rodada, uma
-- variação (a cortina muda de cor para dar para ver de longe):
--   * Ventania (5.2, a mais comum): o vidro estoura, uma rajada entra num
--     cone para dentro da arena (forte perto da janela, fraca no fim do
--     cone) e os blocos encostados na parede, debaixo da janela, piscam e
--     caem;
--   * Pombos (5.6): um bando entra e atravessa a arena numa faixa reta;
--     quem está na faixa quando o bando passa leva esbarrões leves (até 3);
--   * Chuva (5.6): o chão em frente à janela fica escorregadio por alguns
--     segundos (pouca tração: difícil frear e mudar de direção).
-- Depois a janela fica aberta e, no fim da recarga, é pregada com tábuas.
-- Quem atirou nunca é afetado; quedas contam como derrubada dele
-- (KnockbackService).
--
-- O servidor só muda o que importa para todos (vidro, tábuas, cortinas,
-- blocos, empurrões e até quando chove); o TrapVisualController desenha
-- trincas, cortinas, vidro, vento, pombos e chuva a partir dos atributos.
-- O escorregão da Chuva é aplicado por quem simula o personagem
-- (SlipperyController no cliente; aqui, só para os bots).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConstants = require(ReplicatedStorage.Shared.modules.ArenaConstants)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SlipperyGround = require(ReplicatedStorage.Shared.modules.SlipperyGround)
local WindowGeometry = require(ReplicatedStorage.Shared.modules.WindowGeometry)
local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local TrapConfig = require(ReplicatedStorage.Shared.config.TrapConfig)
local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local ArenaService = require(script.Parent.Parent.ArenaService)
local KnockbackService = require(script.Parent.Parent.KnockbackService)
local CombatantRegistry = require(script.Parent.Parent.CombatantRegistry)
local TrapBlocks = require(script.Parent.TrapBlocks)

type Combatant = CombatantRegistry.Combatant

local CONFIG = TrapConfig.Window
local MULLION_NAMES = { "MullionV", "MullionH" }

type Frame = WindowGeometry.Frame
type WindowVariant = TrapConfig.WindowVariant

-- Conferência da faixa dos pombos e do chão molhado (s).
local SWEEP_INTERVAL = 0.05
-- De quanto em quanto tempo quem está no chão molhado fica marcado como
-- empurrado por quem atirou (quedas ali contam como derrubada dele).
local RAIN_CREDIT_INTERVAL = 0.5

type Rain = {
	frame: Frame,
	endsAt: number,
	shooter: Combatant?,
	isCurrent: () -> boolean,
	lastCredit: number,
}

local WindowTrap = {}

WindowTrap.rules = CONFIG :: TrapConfig.TrapRules

-- Transparência original de cada peça que some quando a janela quebra.
local originalTransparency: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any

local function setHidden(part: BasePart, hidden: boolean)
	local original = originalTransparency[part]
	if original == nil then
		original = part.Transparency
		originalTransparency[part] = original
	end
	part.Transparency = if hidden then 1 else original
end

local function windowParts(glass: BasePart, names: { string }): { BasePart }
	local parts: { BasePart } = {}
	local model = glass.Parent
	if model == nil then
		return parts
	end
	for _, name in ipairs(names) do
		local part = model:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	return parts
end

local function boards(glass: BasePart): { BasePart }
	local parts: { BasePart } = {}
	local model = glass.Parent
	if model == nil then
		return parts
	end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #TrapConstants.WindowBoardPrefix) == TrapConstants.WindowBoardPrefix then
			table.insert(parts, child)
		end
	end
	return parts
end

-- Vidro (e travessas) visível e acertável, ou quebrado e vazado.
local function setBroken(glass: BasePart, broken: boolean)
	setHidden(glass, broken)
	glass.CanQuery = not broken
	for _, part in ipairs(windowParts(glass, MULLION_NAMES)) do
		setHidden(part, broken)
	end
end

local function setBoarded(glass: BasePart, boarded: boolean)
	for _, board in ipairs(boards(glass)) do
		board.Transparency = if boarded then 0 else 1
	end
end

-- Força da rajada em `position` (múltiplo do empurrão do disparo; 0 = fora
-- do cone) e o lado em que a pessoa está (-1 a 1, para abrir o vento).
local function gustAt(frame: Frame, position: Vector3): (number, number)
	local offset = position - frame.base
	if offset.Y < -1 or offset.Y > CONFIG.ConeHeight then
		return 0, 0
	end
	local depth = offset:Dot(frame.inward)
	if depth < 0 or depth > CONFIG.ConeLength then
		return 0, 0
	end
	local halfWidth = CONFIG.ConeBaseHalfWidth + (depth * math.tan(math.rad(CONFIG.ConeHalfAngle)))
	local lateral = offset:Dot(frame.along)
	if math.abs(lateral) > halfWidth then
		return 0, 0
	end
	local progress = depth / CONFIG.ConeLength
	local strength = CONFIG.NearMultiplier + ((CONFIG.FarMultiplier - CONFIG.NearMultiplier) * progress)
	return strength, lateral / halfWidth
end

local function pushPlayers(frame: Frame, shooter: Combatant?): number
	local knockback = GameConfig.Knockback
	local affected = 0
	for _, combatant in ipairs(CombatantRegistry.all()) do
		local root = TrapBlocks.targetRoot(combatant, shooter)
		if root ~= nil then
			local strength, side = gustAt(frame, root.Position)
			if strength > 0 then
				local direction = (frame.inward + (frame.along * side * CONFIG.Spread)).Unit
				local velocity = (direction * knockback.HorizontalSpeed * strength)
					+ Vector3.new(0, knockback.VerticalSpeed * strength * CONFIG.LiftFactor, 0)
				if KnockbackService.push(shooter, combatant, velocity) then
					affected += 1
				end
			end
		end
	end
	return affected
end

-- Blocos inteiros da fileira encostada na parede, debaixo da janela.
local function looseBlocks(frame: Frame): { Part }
	local rowDepth = GameConfig.Arena.BlockSize.X
	local blocks: { Part } = {}
	for _, block in ipairs(ArenaService.getIntactBlocks()) do
		if block:GetAttribute(ArenaConstants.FloorAttribute) == frame.floor then
			local offset = block.Position - frame.base
			local depth = offset:Dot(frame.inward)
			if depth >= 0 and depth <= rowDepth and math.abs(offset:Dot(frame.along)) <= CONFIG.LooseBlocksAlong then
				table.insert(blocks, block)
			end
		end
	end
	return blocks
end

-- Nome na telemetria: a variação junto (Window.Gust, Window.Pigeons...).
function WindowTrap.describe(glass: BasePart): string
	return `{TrapConstants.Window}.{WindowGeometry.variantOf(glass)}`
end

-- Janelas conhecidas (para sortear as variações a cada rodada).
local knownGlasses: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local random = Random.new()
local activeRains: { [BasePart]: Rain } = {}
local slipStates: { [Model]: SlipperyGround.State } = setmetatable({}, { __mode = "k" }) :: any
local rainConnection: RBXScriptConnection? = nil
local RAIN_WARN_INTERVAL = 5
local lastRainWarnAt = -math.huge

local function curtainColorOf(variant: WindowVariant): Color3?
	for _, entry in ipairs(CONFIG.Variants) do
		if entry.variant == variant then
			return entry.curtainColor
		end
	end
	return nil
end

local function setVariant(glass: BasePart, variant: WindowVariant)
	glass:SetAttribute(TrapConstants.WindowVariantAttribute, variant)
	local color = curtainColorOf(variant)
	if color ~= nil then
		for _, curtain in ipairs(windowParts(glass, TrapConstants.WindowCurtainNames)) do
			curtain.Color = color
		end
	end
end

local function rollVariant(): WindowVariant
	local total = 0
	for _, entry in ipairs(CONFIG.Variants) do
		total += math.max(0, entry.weight)
	end
	local pick = random:NextNumber(0, total)
	for _, entry in ipairs(CONFIG.Variants) do
		pick -= math.max(0, entry.weight)
		if pick <= 0 then
			return entry.variant
		end
	end
	return "Gust"
end

-- Ventania: rajada e blocos soltos. Devolve quantos empurrou.
local function gust(frame: Frame, shooter: Combatant?, isCurrent: () -> boolean): number
	local affected = pushPlayers(frame, shooter)
	TrapBlocks.drop(looseBlocks(frame), shooter, CONFIG.LooseBlockDelay, isCurrent)
	return affected
end

-- Pombos: o bando atravessa a faixa em PigeonFlightTime (o cliente desenha
-- o voo pelo mesmo relógio). Quem está no trecho da faixa onde o bando
-- está leva esbarrões. Devolve quantos estavam na faixa no começo.
local function pigeons(frame: Frame, shooter: Combatant?, isCurrent: () -> boolean): number
	local knockback = GameConfig.Knockback
	local bumps: { [number]: number } = {}
	local lastBump: { [number]: number } = {}
	local startedAt = os.clock()
	local function sweep()
		local now = os.clock()
		local progress = math.clamp((now - startedAt) / CONFIG.PigeonFlightTime, 0, 1)
		local head = progress * (CONFIG.PigeonLaneLength + CONFIG.PigeonFlockLength)
		local tail = head - CONFIG.PigeonFlockLength
		for _, combatant in ipairs(CombatantRegistry.all()) do
			local root = TrapBlocks.targetRoot(combatant, shooter)
			local count = bumps[combatant.id] or 0
			local last = lastBump[combatant.id]
			if root ~= nil and count < CONFIG.PigeonMaxBumps and (last == nil or now - last >= CONFIG.PigeonBumpInterval) then
				local depth = WindowGeometry.local3(frame, root.Position)
				if WindowGeometry.inPigeonLane(frame, root.Position) and depth >= tail and depth <= head then
					local side = random:NextNumber(-0.35, 0.35)
					local direction = (frame.inward + (frame.along * side)).Unit
					local velocity = (direction * knockback.HorizontalSpeed * CONFIG.PigeonBumpMultiplier)
						+ Vector3.new(0, knockback.VerticalSpeed * CONFIG.PigeonBumpLift, 0)
					if KnockbackService.push(shooter, combatant, velocity) then
						bumps[combatant.id] = count + 1
						lastBump[combatant.id] = now
					end
				end
			end
		end
	end
	local inLane = 0
	for _, combatant in ipairs(CombatantRegistry.all()) do
		local root = TrapBlocks.targetRoot(combatant, shooter)
		if root ~= nil and WindowGeometry.inPigeonLane(frame, root.Position) then
			inLane += 1
		end
	end
	task.spawn(function()
		while os.clock() - startedAt <= CONFIG.PigeonFlightTime and isCurrent() do
			local ok, failure = pcall(sweep)
			if not ok then
				warn(`[BlocoPuff] Pigeon bumps failed: {failure}`)
				return
			end
			task.wait(SWEEP_INTERVAL)
		end
	end)
	return inLane
end

-- Chão molhado: escorregão dos bots (os jogadores aplicam no próprio
-- cliente) e crédito de quem atirou para quem está nele.
local function stepRains(dt: number)
	local now = os.clock()
	for glass, entry in pairs(activeRains) do
		if now >= entry.endsAt or not entry.isCurrent() then
			activeRains[glass] = nil
		end
	end
	for _, bot in ipairs(CombatantRegistry.getBots()) do
		local model = bot.model
		local root = CombatantRegistry.getRoot(bot)
		local humanoid = CombatantRegistry.getHumanoid(bot)
		if model ~= nil and root ~= nil and humanoid ~= nil then
			local slippery = false
			for _, entry in pairs(activeRains) do
				if WindowGeometry.inRain(entry.frame, root.Position) then
					slippery = true
					break
				end
			end
			local state = slipStates[model]
			if slippery and state == nil then
				state = SlipperyGround.new()
				slipStates[model] = state
			end
			if state ~= nil then
				SlipperyGround.step(state, root, humanoid, dt, slippery, CONFIG.RainGrip)
			end
		end
	end
	for _, entry in pairs(activeRains) do
		local shooter = entry.shooter
		if shooter ~= nil and CombatantRegistry.isPresent(shooter) and now - entry.lastCredit >= RAIN_CREDIT_INTERVAL then
			entry.lastCredit = now
			for _, combatant in ipairs(CombatantRegistry.all()) do
				local root = TrapBlocks.targetRoot(combatant, shooter)
				-- Não tira o crédito de quem empurrou por último.
				local recent = KnockbackService.getRecentAttacker(combatant)
				if root ~= nil and (recent == nil or recent == shooter) and WindowGeometry.inRain(entry.frame, root.Position) then
					KnockbackService.markAttacker(combatant, shooter)
				end
			end
		end
	end
	if next(activeRains) == nil then
		for model, state in pairs(slipStates) do
			SlipperyGround.release(state)
			slipStates[model] = nil
		end
		local connection = rainConnection
		if connection ~= nil then
			connection:Disconnect()
			rainConnection = nil
		end
	end
end

-- Chuva: o chão em frente fica escorregadio por RainDuration. Devolve
-- quantos estavam nele no começo.
local function startRain(glass: BasePart, frame: Frame, shooter: Combatant?, isCurrent: () -> boolean): number
	glass:SetAttribute(TrapConstants.WindowRainUntilAttribute, Workspace:GetServerTimeNow() + CONFIG.RainDuration)
	activeRains[glass] = { frame = frame, endsAt = os.clock() + CONFIG.RainDuration, shooter = shooter, isCurrent = isCurrent, lastCredit = 0 }
	if rainConnection == nil then
		rainConnection = RunService.Heartbeat:Connect(function(dt: number)
			local ok, failure = pcall(stepRains, dt)
			if not ok and os.clock() - lastRainWarnAt >= RAIN_WARN_INTERVAL then
				lastRainWarnAt = os.clock()
				warn(`[BlocoPuff] Rain step failed: {failure}`)
			end
		end)
	end
	local wet = 0
	for _, combatant in ipairs(CombatantRegistry.all()) do
		local root = TrapBlocks.targetRoot(combatant, shooter)
		if root ~= nil and WindowGeometry.inRain(frame, root.Position) then
			wet += 1
		end
	end
	return wet
end

-- Efeito ao fim do aviso, conforme a variação da rodada. Devolve quantos
-- jogadores foram atingidos.
function WindowTrap.trigger(glass: BasePart, shooter: Combatant?, isCurrent: () -> boolean): number
	setBroken(glass, true)
	task.delay(CONFIG.RechargeTime * (1 - CONFIG.BoardedFraction), function()
		if isCurrent() then
			setBoarded(glass, true)
		end
	end)
	local frame = WindowGeometry.frameOf(glass)
	if frame == nil then
		warn(`[BlocoPuff] Window trap {glass:GetFullName()} has no floor/inward attributes`)
		return 0
	end
	local variant = WindowGeometry.variantOf(glass)
	if variant == "Pigeons" then
		return pigeons(frame, shooter, isCurrent)
	elseif variant == "Rain" then
		return startRain(glass, frame, shooter, isCurrent)
	end
	return gust(frame, shooter, isCurrent)
end

-- Vidro inteiro, sem tábuas e sem chuva. A primeira vez, sorteia a
-- variação.
function WindowTrap.restore(glass: BasePart)
	setBoarded(glass, false)
	setBroken(glass, false)
	glass:SetAttribute(TrapConstants.WindowRainUntilAttribute, nil)
	activeRains[glass] = nil
	if not knownGlasses[glass] then
		knownGlasses[glass] = true
		setVariant(glass, rollVariant())
	end
end

-- Começo e fim de rodada: cada janela sorteia a variação de novo.
function WindowTrap.roundReset()
	table.clear(activeRains)
	for glass in pairs(knownGlasses) do
		if glass.Parent ~= nil then
			setVariant(glass, rollVariant())
		end
	end
end

return table.freeze(WindowTrap)
