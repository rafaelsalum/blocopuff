--!strict

-- Fachada do HUD: mantém as camadas de rodada e combate separadas enquanto
-- oferece ao controller uma única interface tipada. Os anúncios ficam com o
-- NotificationManager.

local CombatHudView = require(script.Parent.CombatHudView)
local RoundHudView = require(script.Parent.RoundHudView)

type RoundHudMode = RoundHudView.RoundHudMode
type LivesState = CombatHudView.LivesState

export type HudViewHandle = {
	setRoundMode: (mode: RoundHudMode) -> (),
	setCountdown: (text: string) -> (),
	setQueue: (title: string, subtitle: string, inQueue: boolean) -> (),
	setCombatVisible: (visible: boolean) -> (),
	setCombatTimer: (text: string) -> (),
	setCombatParticipants: (count: number) -> (),
	setArenaIntegrity: (remaining: number, total: number) -> (),
	setPersonalScore: (count: number, visible: boolean) -> (),
	setLives: (state: LivesState) -> (),
	setTimerDanger: (danger: boolean) -> (),
	destroy: () -> (),
}

local HudView = {}

-- `onJoin`: botão JOGAR da etiqueta da fila (leva ao mirante).
function HudView.new(playerGui: PlayerGui, onJoin: () -> ()): HudViewHandle
	local roundHud = RoundHudView.new(playerGui, onJoin)
	local combatHud = CombatHudView.new(playerGui)

	local handle = {} :: HudViewHandle
	handle.setRoundMode = roundHud.setMode
	handle.setCountdown = roundHud.setCountdown
	handle.setQueue = roundHud.setQueue
	handle.setCombatVisible = combatHud.setVisible
	handle.setCombatTimer = combatHud.setTimer
	handle.setCombatParticipants = combatHud.setParticipants
	handle.setArenaIntegrity = combatHud.setArenaIntegrity
	handle.setPersonalScore = combatHud.setPersonalScore
	handle.setLives = combatHud.setLives
	handle.setTimerDanger = combatHud.setTimerDanger

	handle.destroy = function()
		roundHud.destroy()
		combatHud.destroy()
	end

	return handle
end

return table.freeze(HudView)
