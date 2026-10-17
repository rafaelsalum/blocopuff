--!strict

-- Barão do Jardim passeando (Fase 5C.4): de tempos em tempos (com alguém
-- no lobby) ele sai da caminha, faz a volta do BaraoWalk e volta a dormir.
-- O servidor só publica o início do passeio e a pausa do carinho em
-- atributos; o cliente anima (BaraoVisualController) e aqui só o aviso de
-- carinho acompanha ele.
--
-- Carinho: igual de antes (acorda, pula, corações) onde ele estiver;
-- andando, ele para enquanto comemora e depois segue. Cada carinho tem uma
-- pequena chance de presente (tickets), até o limite do dia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MansionLifeConfig = require(ReplicatedStorage.Shared.config.MansionLifeConfig)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local BaraoModel = require(ReplicatedStorage.Shared.modules.BaraoModel)
local BaraoWalk = require(ReplicatedStorage.Shared.modules.BaraoWalk)
local MansionLifeService = require(script.Parent.MansionLifeService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local DailyRules = require(script.Parent.Parent.data.DailyRules)
local MansionLifeRules = require(script.Parent.Parent.data.MansionLifeRules)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)

type Profile = ProfileSchema.Profile

export type Friendly = {
	model: Model,
	-- Peça invisível com o aviso de carinho.
	anchor: BasePart,
	prompt: ProximityPrompt,
	-- Texto em cima dele ("Zzz" dormindo).
	status: TextLabel,
}

local CONFIG = MansionLifeConfig.Barao
local PET_COOLDOWN = 2
-- De quanto em quanto tempo o aviso de carinho acompanha ele (s).
local FOLLOW_STEP = 0.2
-- Altura do aviso acima da raiz dele andando.
local PROMPT_HEIGHT = 1.5
-- Folga da distância do carinho conferida no servidor (studs).
local PET_SLACK = 6

local BaraoWalkService = {}

local started = false
local lastPet: { [Player]: number } = {}
local random = Random.new()

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function anyoneInLobby(): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) ~= true then
			return true
		end
	end
	return false
end

local function grantGift(player: Player)
	local today = DailyRules.dayIndex(os.time())
	local count: number? = nil
	local saved = false
	local before = 0
	local balance = 0
	PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, PlayerDataService.Events?)
		local nextCount = MansionLifeRules.claimDaily(profile.baraoGiftDay, profile.baraoGiftCount, today, CONFIG.GiftDailyLimit)
		if nextCount == nil then
			return nil, nil
		end
		local updated = ProfileSchema.withTickets(profile, CONFIG.GiftTickets)
		-- Carteira no teto: o presente não sai e a cota do dia fica.
		if updated.tickets <= profile.tickets then
			return nil, nil
		end
		updated.baraoGiftDay = today
		updated.baraoGiftCount = nextCount
		count = nextCount
		saved = canSave
		before = profile.tickets
		balance = updated.tickets
		return updated, nil
	end, true)
	local given = count
	if given == nil then
		return
	end
	MansionLifeService.send(player, "BaraoGift", balance - before, given, CONFIG.GiftDailyLimit)
	if saved then
		TelemetryService.lobbyEvent(player, "BaraoGift", given)
		TelemetryService.ticketsEarned(player, before, balance, "BaraoGift")
	end
end

function BaraoWalkService.start(friendly: Friendly)
	if started then
		return
	end
	started = true
	local model = friendly.model
	local route = BaraoWalk.route()
	local restAnchor = friendly.anchor.CFrame
	local happy = false
	model:SetAttribute(CONFIG.StartAttribute, 0)
	model:SetAttribute(CONFIG.PauseAttribute, -1)

	local function walking(): boolean
		return BaraoWalk.elapsed(model, serverNow()) ~= nil
	end

	local function idleText(): string
		return if walking() then "" else "Zzz"
	end

	-- Posição atual da raiz dele (andando ou na caminha).
	local function currentCFrame(): CFrame
		local elapsed = BaraoWalk.elapsed(model, serverNow())
		if elapsed == nil then
			return BaraoWalk.restCFrame()
		end
		local cframe = BaraoWalk.pose(route, elapsed)
		return cframe
	end

	friendly.prompt.Triggered:Connect(function(player: Player)
		local clock = os.clock()
		local last = lastPet[player]
		if happy or (last ~= nil and clock - last < PET_COOLDOWN) or player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			return
		end
		local position = rootPosition(player)
		if position == nil or (position - currentCFrame().Position).Magnitude > friendly.prompt.MaxActivationDistance + PET_SLACK then
			return
		end
		lastPet[player] = clock
		happy = true
		friendly.status.Text = "💜"
		-- Andando: para no lugar enquanto comemora.
		local elapsed = BaraoWalk.elapsed(model, serverNow())
		if elapsed ~= nil then
			model:SetAttribute(CONFIG.PauseAttribute, elapsed)
		end
		TelemetryService.lobbyEvent(player, "BaraoPet", 1)
		model:SetAttribute(BaraoModel.PetAttribute, ((model:GetAttribute(BaraoModel.PetAttribute) :: number?) or 0) + 1)
		if MansionLifeRules.giftRoll(random:NextNumber(), CONFIG.GiftChance) then
			grantGift(player)
		end
		task.delay(BaraoModel.FriendlyHappySeconds, function()
			local paused = model:GetAttribute(CONFIG.PauseAttribute)
			if typeof(paused) == "number" and paused >= 0 then
				model:SetAttribute(CONFIG.StartAttribute, serverNow() - paused)
				model:SetAttribute(CONFIG.PauseAttribute, -1)
			end
			happy = false
			friendly.status.Text = idleText()
		end)
	end)

	-- Volta para a caminha (fim do passeio ou falha). Se o carinho começou
	-- no fim do passeio, a pausa termina dormindo.
	local function resetToBed()
		model:SetAttribute(CONFIG.StartAttribute, 0)
		model:SetAttribute(CONFIG.PauseAttribute, -1)
		friendly.anchor.CFrame = restAnchor
		if not happy then
			friendly.status.Text = "Zzz"
		end
	end

	local function stroll()
		model:SetAttribute(CONFIG.PauseAttribute, -1)
		model:SetAttribute(CONFIG.StartAttribute, serverNow())
		if not happy then
			friendly.status.Text = ""
		end
		while model.Parent ~= nil do
			local elapsed = BaraoWalk.elapsed(model, serverNow())
			if elapsed == nil then
				break
			end
			local cframe, _, done = BaraoWalk.pose(route, elapsed)
			if done then
				break
			end
			friendly.anchor.CFrame = CFrame.new(cframe.Position + Vector3.new(0, PROMPT_HEIGHT, 0))
			task.wait(FOLLOW_STEP)
		end
		resetToBed()
	end

	task.spawn(function()
		task.wait(CONFIG.FirstDelay)
		while model.Parent ~= nil do
			if anyoneInLobby() then
				local ok, failure = pcall(stroll)
				if not ok then
					warn(`[BlocoPuff] Barao walk failed: {failure}`)
					resetToBed()
				end
			end
			task.wait(MansionLifeRules.interval(random:NextNumber(), CONFIG.MinRest, CONFIG.MaxRest))
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastPet[player] = nil
	end)
end

return table.freeze(BaraoWalkService)
