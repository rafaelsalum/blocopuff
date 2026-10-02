--!strict

-- Funil da primeira sessão (Funil de Onboarding nativo do Creator
-- Dashboard). Passos e regras em OnboardingRules:
--   Joined → FirstShot → QueueEntered → MatchStarted → FirstBlockDown →
--   MatchFinished → SecondMatch → ReturnedAnotherDay
--
-- Cada passo vai uma vez na vida do jogador e só com o perfil salvo nesta
-- sessão (senão voltaria na próxima). Quem já jogava antes do funil existir
-- fica de fora. Fila e partida vêm dos atributos do jogador; tiro e bloco,
-- do PuffadorService; partidas e volta em outro dia, do próprio perfil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTypes = require(ReplicatedStorage.Shared.types.ProfileTypes)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)
local ProfileSchema = require(script.Parent.Parent.data.ProfileSchema)
local OnboardingRules = require(script.Parent.Parent.data.OnboardingRules)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)

type Profile = ProfileSchema.Profile
type ProfileSnapshot = ProfileTypes.ProfileSnapshot

local Step = OnboardingRules.Step

local OnboardingService = {}

type Known = {
	mask: number,
	createdAt: number,
}

local started = false
-- Passos já marcados de quem tem perfil salvo nesta sessão (nil: ainda não
-- carregou ou perfil não salvo). Evita mexer no perfil a cada tiro.
local known: { [Player]: Known } = {}

-- Marca `steps` no perfil (de uma vez) e envia os passos novos, em ordem.
-- `first`: primeira carga da sessão (decide se é jogador novo).
local function mark(player: Player, steps: { number }, first: boolean)
	local fresh: { number } = {}
	PlayerDataService.update(player, function(profile: Profile, canSave: boolean): (Profile?, any)
		if not canSave then
			return nil, nil
		end
		local mask = OnboardingRules.initial(profile.onboardingSteps, profile.stats.matches)
		local wanted = table.clone(steps)
		if first then
			table.insert(wanted, Step.Joined)
			for _, step in ipairs(OnboardingRules.stepsFromProfile(profile.stats.matches, profile.createdAt, os.time())) do
				table.insert(wanted, step)
			end
		end
		for _, step in ipairs(wanted) do
			local marked, isNew = OnboardingRules.mark(mask, step)
			mask = marked
			if isNew then
				table.insert(fresh, step)
			end
		end
		known[player] = { mask = mask, createdAt = profile.createdAt }
		if mask == profile.onboardingSteps then
			return nil, nil
		end
		local updated = table.clone(profile)
		updated.onboardingSteps = mask
		return updated, nil
	end, true)
	table.sort(fresh)
	for _, step in ipairs(fresh) do
		TelemetryService.onboardingStep(player, step, OnboardingRules.Steps[step])
	end
end

local function reach(player: Player, steps: { number })
	local state = known[player]
	if state == nil then
		return
	end
	for _, step in ipairs(steps) do
		if not OnboardingRules.has(state.mask, step) then
			mark(player, steps, false)
			return
		end
	end
end

local function onProfile(player: Player, snapshot: ProfileSnapshot)
	if player.Parent == nil or not snapshot.saved then
		return
	end
	local state = known[player]
	if state == nil then
		-- Fila e partida que já começaram enquanto o perfil carregava.
		local already: { number } = {}
		if player:GetAttribute(StateAttributeNames.PlayerInMatchQueue) == true then
			table.insert(already, Step.QueueEntered)
		end
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			table.insert(already, Step.MatchStarted)
		end
		mark(player, already, true)
		return
	end
	reach(player, OnboardingRules.stepsFromProfile(snapshot.stats.matches, state.createdAt, os.time()))
end

local function watchAttributes(player: Player)
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerInMatchQueue):Connect(function()
		if player:GetAttribute(StateAttributeNames.PlayerInMatchQueue) == true then
			reach(player, { Step.QueueEntered })
		end
	end)
	player:GetAttributeChangedSignal(StateAttributeNames.PlayerIsParticipant):Connect(function()
		if player:GetAttribute(StateAttributeNames.PlayerIsParticipant) == true then
			reach(player, { Step.MatchStarted })
		end
	end)
end

-- Chamados pelo PuffadorService.
function OnboardingService.shot(player: Player)
	reach(player, { Step.FirstShot })
end

function OnboardingService.blockDown(player: Player)
	reach(player, { Step.FirstBlockDown })
end

function OnboardingService.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(watchAttributes)
	for _, player in ipairs(Players:GetPlayers()) do
		watchAttributes(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		known[player] = nil
	end)
	-- Depois do aviso atual: a atualização do funil publica um perfil novo,
	-- e os outros ouvintes devem receber os avisos na ordem.
	PlayerDataService.addListener(function(player: Player, snapshot: ProfileSnapshot)
		task.defer(onProfile, player, snapshot)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		local snapshot = PlayerDataService.getSnapshot(player)
		if snapshot ~= nil then
			task.spawn(onProfile, player, snapshot)
		end
	end
end

return table.freeze(OnboardingService)
