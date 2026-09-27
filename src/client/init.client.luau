--!strict

local HudController = require(script.controllers.HudController)
local PuffadorController = require(script.controllers.PuffadorController)
local SpectatorController = require(script.controllers.SpectatorController)
local AdminController = require(script.controllers.AdminController)
local BlockCollapseController = require(script.controllers.BlockCollapseController)
local MusicController = require(script.controllers.MusicController)

print("[BlocoPuff] Client initialized")

local hudOk, hudErr = pcall(function()
	HudController.start()
end)
if not hudOk then
	warn(string.format("[BlocoPuff] Failed to start HUD: %s", tostring(hudErr)))
end

local puffadorOk, puffadorErr = pcall(function()
	PuffadorController.start()
end)
if not puffadorOk then
	warn(string.format("[BlocoPuff] Failed to start Puffador controller: %s", tostring(puffadorErr)))
end

local spectatorOk, spectatorErr = pcall(function()
	SpectatorController.start()
end)
if not spectatorOk then
	warn(string.format("[BlocoPuff] Failed to start Spectator controller: %s", tostring(spectatorErr)))
end

local adminOk, adminErr = pcall(function()
	AdminController.start()
end)
if not adminOk then
	warn(string.format("[BlocoPuff] Failed to start Admin controller: %s", tostring(adminErr)))
end

local collapseOk, collapseErr = pcall(function()
	BlockCollapseController.start()
end)
if not collapseOk then
	warn(string.format("[BlocoPuff] Failed to start block collapse effects: %s", tostring(collapseErr)))
end

local musicOk, musicErr = pcall(function()
	MusicController.start()
end)
if not musicOk then
	warn(string.format("[BlocoPuff] Failed to start background music: %s", tostring(musicErr)))
end
