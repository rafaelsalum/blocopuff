--!strict

local HudController = require(script.controllers.HudController)

print("[BlocoPuff] Client initialized")

local ok, err = pcall(function()
	HudController.start()
end)

if not ok then
	warn(string.format("[BlocoPuff] Failed to start HUD: %s", tostring(err)))
end
