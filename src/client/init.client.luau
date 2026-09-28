--!strict

local HudController = require(script.controllers.HudController)
local PuffadorController = require(script.controllers.PuffadorController)
local SpectatorController = require(script.controllers.SpectatorController)
local AdminController = require(script.controllers.AdminController)
local BlockCollapseController = require(script.controllers.BlockCollapseController)
local MusicController = require(script.controllers.MusicController)
local VaultController = require(script.controllers.VaultController)
local KnockbackController = require(script.controllers.KnockbackController)
local ResultsController = require(script.controllers.ResultsController)
local TelemetryController = require(script.controllers.TelemetryController)
local SecretPassageController = require(script.controllers.SecretPassageController)
local BaraoController = require(script.controllers.BaraoController)
local BaraoTensionController = require(script.controllers.BaraoTensionController)
local PuffMomentController = require(script.controllers.PuffMomentController)
local ProfileController = require(script.controllers.ProfileController)

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

local vaultOk, vaultErr = pcall(function()
	VaultController.start()
end)
if not vaultOk then
	warn(string.format("[BlocoPuff] Failed to start vault controller: %s", tostring(vaultErr)))
end

local knockbackOk, knockbackErr = pcall(function()
	KnockbackController.start()
end)
if not knockbackOk then
	warn(string.format("[BlocoPuff] Failed to start knockback controller: %s", tostring(knockbackErr)))
end

local resultsOk, resultsErr = pcall(function()
	ResultsController.start()
end)
if not resultsOk then
	warn(string.format("[BlocoPuff] Failed to start results controller: %s", tostring(resultsErr)))
end

local telemetryOk, telemetryErr = pcall(function()
	TelemetryController.start()
end)
if not telemetryOk then
	warn(string.format("[BlocoPuff] Failed to start telemetry controller: %s", tostring(telemetryErr)))
end

local secretOk, secretErr = pcall(function()
	SecretPassageController.start()
end)
if not secretOk then
	warn(string.format("[BlocoPuff] Failed to start secret passage controller: %s", tostring(secretErr)))
end

local baraoOk, baraoErr = pcall(function()
	BaraoController.start()
end)
if not baraoOk then
	warn(string.format("[BlocoPuff] Failed to start Barao controller: %s", tostring(baraoErr)))
end

local tensionOk, tensionErr = pcall(function()
	BaraoTensionController.start()
end)
if not tensionOk then
	warn(string.format("[BlocoPuff] Failed to start Barao tension controller: %s", tostring(tensionErr)))
end

local momentOk, momentErr = pcall(function()
	PuffMomentController.start()
end)
if not momentOk then
	warn(string.format("[BlocoPuff] Failed to start Puff moment controller: %s", tostring(momentErr)))
end

local profileOk, profileErr = pcall(function()
	ProfileController.start()
end)
if not profileOk then
	warn(string.format("[BlocoPuff] Failed to start profile controller: %s", tostring(profileErr)))
end
