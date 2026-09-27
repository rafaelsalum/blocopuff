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
	setRoundStatus: (text: string) -> (),
	setRoundParticipants: (text: string) -> (),
	setCountdown: (text: string) -> (),
	setQueueText: (text: string) -> (),
	setQueueVisible: (visible: boolean) -> (),
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

function HudView.new(playerGui: PlayerGui): HudViewHandle
	local roundHud = RoundHudView.new(playerGui)
	local combatHud = CombatHudView.new(playerGui)

	local handle = {} :: HudViewHandle
	handle.setRoundMode = roundHud.setMode
	handle.setRoundStatus = roundHud.setStatus
	handle.setRoundParticipants = roundHud.setParticipants
	handle.setCountdown = roundHud.setCountdown
	handle.setQueueText = roundHud.setQueueText
	handle.setQueueVisible = roundHud.setQueueVisible
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
