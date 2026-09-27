--!strict

-- Momentos Puff: jogadas curtas que merecem ser contadas para a partida.
--   * BaraoEscape: pulou por cima do Barão ou escapou de uma perseguição;
--   * VaultConquered: pegou o Puffador do Cofre;
--   * Comeback (Volta por Cima): depois de usar a Segunda Chance, derrubou
--     alguém ou venceu a rodada;
--   * SecretDiscovery: revelou uma passagem secreta.
-- Cada jogador conta no máximo uma vez por tipo por rodada. Cofre e
-- descoberta já têm faixa própria (VaultController/SecretPassageController),
-- então só os outros são anunciados aqui; todos vão para a telemetria.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local TelemetryService = require(script.Parent.TelemetryService)

export type MomentKind = "BaraoEscape" | "VaultConquered" | "Comeback" | "SecretDiscovery"

local ANNOUNCED: { [MomentKind]: boolean } = {
	BaraoEscape = true,
	Comeback = true,
	VaultConquered = false,
	SecretDiscovery = false,
}

local PuffMomentService = {}

local remote: RemoteEvent? = nil
local active = false
local recorded: { [Player]: { [string]: boolean } } = {}

-- Registra um momento; `detail` vai para o anúncio e para a telemetria
-- (ex.: "Jump"/"Run" na fuga do Barão, "Knockout"/"Win" na volta por cima).
function PuffMomentService.record(player: Player, kind: MomentKind, detail: string?)
	if not active or player.Parent == nil then
		return
	end
	local byPlayer = recorded[player]
	if byPlayer == nil then
		byPlayer = {}
		recorded[player] = byPlayer
	end
	if byPlayer[kind] then
		return
	end
	byPlayer[kind] = true
	TelemetryService.event(player, "PuffMoment", nil, kind, detail)
	local current = remote
	if current ~= nil and ANNOUNCED[kind] then
		current:FireAllClients(kind, player.DisplayName, player.UserId, detail)
	end
end

function PuffMomentService.beginRound()
	active = true
	table.clear(recorded)
end

function PuffMomentService.endRound()
	active = false
	table.clear(recorded)
end

function PuffMomentService.start(remotesFolder: Folder?)
	if remote ~= nil or remotesFolder == nil then
		return
	end
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = PuffadorConstants.PuffMomentRemoteName
	newRemote.Parent = remotesFolder
	remote = newRemote
end

function PuffMomentService.stop()
	active = false
	table.clear(recorded)
	local current = remote
	if current ~= nil then
		current:Destroy()
		remote = nil
	end
end

return table.freeze(PuffMomentService)
