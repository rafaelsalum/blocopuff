--!strict

local HudController = require(script.controllers.HudController)
local PuffadorController = require(script.controllers.PuffadorController)
local SpectatorController = require(script.controllers.SpectatorController)

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
