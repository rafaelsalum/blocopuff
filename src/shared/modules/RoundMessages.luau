--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lang = require(ReplicatedStorage.Shared.i18n.Lang)

export type RoundMessagesModule = {
	WaitingForPlayers: string,
	Active: string,
	EndedNoWinner: string,
	countdown: (secondsRemaining: number) -> string,
	winner: (winnerName: string) -> string,
}

local RoundMessages: RoundMessagesModule = {
	WaitingForPlayers = Lang.t("Entre no mirante para jogar"),
	Active = Lang.t("Partida em andamento"),
	EndedNoWinner = Lang.t("Partida encerrada"),

	-- O número da contagem regressiva já aparece no badge do cronômetro do
	-- HUD; esta mensagem não o repete para evitar mostrar o mesmo valor
	-- duas vezes na tela ao mesmo tempo.
	countdown = function(_secondsRemaining: number): string
		return Lang.t("A partida vai começar")
	end,

	winner = function(winnerName: string): string
		return Lang.t("%s venceu", winnerName)
	end,
}

return table.freeze(RoundMessages)
