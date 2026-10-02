--!strict

-- Comandos de teste da partida no painel admin: começar já, pular para o
-- Caos Final, encerrar a partida, ligar/desligar os bots RoboPuff e fixar o
-- nível deles. Valem só para o servidor atual. Quem confere se é admin e
-- limita a frequência é o AdminService; aqui só vêm pedidos de admins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConstants = require(ReplicatedStorage.Shared.modules.AdminConstants)
local BotConfig = require(ReplicatedStorage.Shared.config.BotConfig)
local AdminService = require(script.Parent.AdminService)
local RoundService = require(script.Parent.RoundService)
local BotFillService = require(script.Parent.BotFillService)
local BotBrainService = require(script.Parent.BotBrainService)

type AdminRequest = AdminConstants.AdminRequest
type AdminResponse = AdminConstants.AdminResponse

local LEVEL_LABELS: { [string]: string } = {
	Auto = "automático",
	Easy = "Fácil",
	Normal = "Normal",
	Hard = "Esperto",
}

local MatchTestControls = {}

local function forceStart(_player: Player, _request: AdminRequest): AdminResponse
	if not RoundService.requestForceStart() then
		return AdminService.reply(false, "Já há uma partida em andamento.")
	end
	BotFillService.rush()
	return AdminService.reply(true, "A contagem cai para 3 s assim que houver gente na fila (bots chegando agora, se ligados). Vale por 30 s.")
end

local function skipToChaos(_player: Player, _request: AdminRequest): AdminResponse
	if not RoundService.requestSkipToFinalChaos() then
		return AdminService.reply(false, "Só durante a partida, antes do Caos Final.")
	end
	return AdminService.reply(true, "Pulando para o Caos Final.")
end

local function endRound(_player: Player, _request: AdminRequest): AdminResponse
	if not RoundService.requestEndRound() then
		return AdminService.reply(false, "Nenhuma partida em andamento.")
	end
	return AdminService.reply(true, "Partida encerrada sem vencedor.")
end

local function botsOn(_player: Player, _request: AdminRequest): AdminResponse
	BotFillService.setEnabled(true)
	return AdminService.reply(true, "Bots ligados neste servidor.")
end

local function botsOff(_player: Player, _request: AdminRequest): AdminResponse
	BotFillService.setEnabled(false)
	return AdminService.reply(true, "Bots desligados neste servidor.")
end

local function botLevel(_player: Player, request: AdminRequest): AdminResponse
	local option = request.option
	if option == nil or table.find(AdminConstants.BotLevelOptions, option) == nil then
		return AdminService.reply(false, "Nível de bot inválido.")
	end
	if option == "Auto" then
		BotBrainService.setLevelOverride(nil)
	elseif BotConfig.Levels[option :: BotConfig.LevelName] ~= nil then
		BotBrainService.setLevelOverride(option :: BotConfig.LevelName)
	end
	return AdminService.reply(true, `Bots no nível {LEVEL_LABELS[option]} a partir da próxima partida.`)
end

function MatchTestControls.start()
	AdminService.registerAction("ForceStart", forceStart)
	AdminService.registerAction("SkipToChaos", skipToChaos)
	AdminService.registerAction("EndRound", endRound)
	AdminService.registerAction("BotsOn", botsOn)
	AdminService.registerAction("BotsOff", botsOff)
	AdminService.registerAction("BotLevel", botLevel)
end

return table.freeze(MatchTestControls)
