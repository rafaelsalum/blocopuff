--!strict

-- Gerenciador único de alertas do cliente. Todo aviso de tela passa por aqui,
-- o que garante que dois alertas nunca se sobreponham.
--
-- Canais (cada um mostra um alerta por vez, em regiões diferentes da tela):
--   Center: anúncio grande no meio (rodada, eliminação, Caos Final, vitória).
--   Banner: faixa no topo (cofre, avisos de administrador).
--
-- Regras de cada canal:
--   • Prioridade: Critical > High > Normal > Low. Um alerta mais importante
--     interrompe o atual; o interrompido volta para a fila se for High ou
--     Critical e ainda tiver tempo, senão é descartado.
--   • Fila: ordenada por prioridade e, na mesma prioridade, por chegada.
--     Guarda no máximo MAX_QUEUE alertas (descarta o menos importante).
--   • Validade: um alerta que espera mais que `maxWait` na fila é descartado,
--     para não mostrar notícia velha (ex.: "VALENDO!" 10 s depois).
--   • Substituição: mesma `key` substitui o alerta atual (reinicia o tempo)
--     ou o que estava na fila, em vez de duplicar.
--   • `clear` remove alertas de um canal, opcionalmente de uma categoria.

local AnnouncementView = require(script.Parent.Parent.ui.AnnouncementView)
local BannerView = require(script.Parent.Parent.ui.BannerView)

export type Channel = "Center" | "Banner"
export type Priority = "Low" | "Normal" | "High" | "Critical"
export type Tone = "Info" | "Warning" | "Danger" | "Winner" | "Gold"

export type Notification = {
	channel: Channel,
	category: string,
	priority: Priority,
	title: string,
	subtitle: string,
	tone: Tone,
	duration: number,
	key: string?,
	icon: string?,
	maxWait: number?,
}

type Entry = {
	notification: Notification,
	enqueuedAt: number,
	remaining: number,
}

type ChannelState = {
	current: Entry?,
	startedAt: number,
	generation: number,
	queue: { Entry },
}

type Renderer = {
	show: (notification: Notification) -> (),
	hide: () -> (),
}

local MAX_QUEUE = 4
local GAP_BETWEEN = 0.25
local MIN_REQUEUE_TIME = 1
local DEFAULT_MAX_WAIT: { [Priority]: number } = {
	Low = 2,
	Normal = 3,
	High = 6,
	Critical = 8,
}
local RANK: { [Priority]: number } = {
	Low = 1,
	Normal = 2,
	High = 3,
	Critical = 4,
}

local NotificationManager = {}

local renderers: { [Channel]: Renderer } = {}
local channels: { [Channel]: ChannelState } = {
	Center = { current = nil, startedAt = 0, generation = 0, queue = {} },
	Banner = { current = nil, startedAt = 0, generation = 0, queue = {} },
}
local initialized = false

local function rank(entry: Entry): number
	return RANK[entry.notification.priority]
end

local function maxWait(notification: Notification): number
	return notification.maxWait or DEFAULT_MAX_WAIT[notification.priority]
end

local function sameKey(entry: Entry?, key: string?): boolean
	return entry ~= nil and key ~= nil and entry.notification.key == key
end

local function insertSorted(state: ChannelState, entry: Entry)
	local position = #state.queue + 1
	for index, queued in ipairs(state.queue) do
		if rank(entry) > rank(queued) then
			position = index
			break
		end
	end
	table.insert(state.queue, position, entry)

	-- Fila cheia: sai o menos importante (o último da fila ordenada).
	while #state.queue > MAX_QUEUE do
		table.remove(state.queue)
	end
end

local showEntry: (channel: Channel, entry: Entry) -> ()

local function showNext(channel: Channel)
	local state = channels[channel]
	local now = os.clock()
	while #state.queue > 0 do
		local entry = table.remove(state.queue, 1) :: Entry
		if now - entry.enqueuedAt <= maxWait(entry.notification) then
			showEntry(channel, entry)
			return
		end
	end
end

local function finishCurrent(channel: Channel)
	local state = channels[channel]
	state.current = nil
	state.generation += 1
	local renderer = renderers[channel]
	if renderer ~= nil then
		renderer.hide()
	end
	local generation = state.generation
	task.delay(GAP_BETWEEN, function()
		if state.generation == generation and state.current == nil then
			showNext(channel)
		end
	end)
end

showEntry = function(channel: Channel, entry: Entry)
	local state = channels[channel]
	state.current = entry
	state.startedAt = os.clock()
	state.generation += 1
	local generation = state.generation

	local renderer = renderers[channel]
	if renderer ~= nil then
		renderer.show(entry.notification)
	end

	task.delay(entry.remaining, function()
		if state.generation == generation then
			finishCurrent(channel)
		end
	end)
end

function NotificationManager.notify(notification: Notification)
	if not initialized then
		return
	end
	local channel = notification.channel
	local state = channels[channel]
	local entry: Entry = {
		notification = notification,
		enqueuedAt = os.clock(),
		remaining = math.max(notification.duration, 0.5),
	}

	-- Mesma chave: atualiza o que está na tela ou substitui o da fila.
	if sameKey(state.current, notification.key) then
		showEntry(channel, entry)
		return
	end
	if notification.key ~= nil then
		for index = #state.queue, 1, -1 do
			if sameKey(state.queue[index], notification.key) then
				table.remove(state.queue, index)
			end
		end
	end

	local current = state.current
	if current == nil then
		showEntry(channel, entry)
	elseif rank(entry) > rank(current) then
		local left = current.remaining - (os.clock() - state.startedAt)
		if rank(current) >= RANK.High and left > MIN_REQUEUE_TIME then
			current.remaining = left
			current.enqueuedAt = os.clock()
			insertSorted(state, current)
		end
		showEntry(channel, entry)
	else
		insertSorted(state, entry)
	end
end

-- Remove alertas do canal. Com `category`, só os daquela categoria.
function NotificationManager.clear(channel: Channel, category: string?)
	if not initialized then
		return
	end
	local state = channels[channel]
	for index = #state.queue, 1, -1 do
		if category == nil or state.queue[index].notification.category == category then
			table.remove(state.queue, index)
		end
	end
	local current = state.current
	if current ~= nil and (category == nil or current.notification.category == category) then
		finishCurrent(channel)
	end
end

local function toAnnouncementTone(tone: Tone): AnnouncementView.AnnouncementTone
	if tone == "Warning" then
		return "Warning"
	elseif tone == "Danger" then
		return "Danger"
	elseif tone == "Winner" or tone == "Gold" then
		return "Winner"
	end
	return "Info"
end

local function toBannerTone(tone: Tone): BannerView.BannerTone
	if tone == "Danger" then
		return "Danger"
	elseif tone == "Info" then
		return "Info"
	end
	return "Gold"
end

-- Cria as telas dos canais. Idempotente: vários controllers podem chamar.
function NotificationManager.init(playerGui: PlayerGui)
	if initialized then
		return
	end
	initialized = true

	local announcements = AnnouncementView.new(playerGui)
	renderers.Center = {
		show = function(notification: Notification)
			announcements.show(notification.title, notification.subtitle, toAnnouncementTone(notification.tone), nil)
		end,
		hide = announcements.hide,
	}

	local banner = BannerView.new(playerGui)
	renderers.Banner = {
		show = function(notification: Notification)
			banner.show(notification.icon or "", notification.title, notification.subtitle, toBannerTone(notification.tone), nil)
		end,
		hide = banner.hide,
	}
end

return table.freeze(NotificationManager)
