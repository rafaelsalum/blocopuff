--!strict

-- Fachada do HUD: mantém as camadas de rodada, combate e anúncios separadas
-- enquanto oferece ao controller uma única interface tipada.

local AnnouncementView = require(script.Parent.AnnouncementView)
local CombatHudView = require(script.Parent.CombatHudView)
local RoundHudView = require(script.Parent.RoundHudView)

type AnnouncementTone = AnnouncementView.AnnouncementTone
type RoundHudMode = RoundHudView.RoundHudMode

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
	showAnnouncement: (title: string, subtitle: string, tone: AnnouncementTone, duration: number?) -> (),
	hideAnnouncement: () -> (),
	destroy: () -> (),
}

local HudView = {}

function HudView.new(playerGui: PlayerGui): HudViewHandle
	local roundHud = RoundHudView.new(playerGui)
	local combatHud = CombatHudView.new(playerGui)
	local announcements = AnnouncementView.new(playerGui)

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
	handle.showAnnouncement = announcements.show
	handle.hideAnnouncement = announcements.hide

	handle.destroy = function()
		roundHud.destroy()
		combatHud.destroy()
		announcements.destroy()
	end

	return handle
end

return table.freeze(HudView)
