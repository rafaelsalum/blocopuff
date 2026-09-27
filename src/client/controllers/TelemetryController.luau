--!strict

-- Informa ao servidor o tipo de dispositivo do jogador (Mobile, Desktop ou
-- Gamepad), usado só para separar a telemetria por dispositivo. Reenvia
-- quando o jogador troca de forma de controle (ex.: conecta um gamepad),
-- com limite de frequência igual ao do servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)

local WAIT_TIMEOUT = 15
local REPORT_COOLDOWN = 6

local TelemetryController = {}

local started = false

local function classify(inputType: Enum.UserInputType?): string
	if inputType ~= nil then
		if inputType == Enum.UserInputType.Touch then
			return "Mobile"
		elseif inputType.Name:match("^Gamepad") ~= nil then
			return "Gamepad"
		elseif
			inputType == Enum.UserInputType.Keyboard
			or inputType == Enum.UserInputType.MouseButton1
			or inputType == Enum.UserInputType.MouseMovement
		then
			return "Desktop"
		end
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	end
	return "Desktop"
end

function TelemetryController.start()
	if started or Players.LocalPlayer == nil then
		return
	end
	started = true

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(PuffadorConstants.RemotesContainerName, WAIT_TIMEOUT)
		local remote = if remotes ~= nil then remotes:WaitForChild(PuffadorConstants.ReportDeviceRemoteName, WAIT_TIMEOUT) else nil
		if remote == nil or not remote:IsA("RemoteEvent") then
			return
		end

		local lastSent = ""
		local lastClock = -math.huge
		local function report(device: string)
			local now = os.clock()
			if device == lastSent or now - lastClock < REPORT_COOLDOWN then
				return
			end
			lastSent = device
			lastClock = now
			remote:FireServer(device)
		end

		report(classify(UserInputService:GetLastInputType()))
		UserInputService.LastInputTypeChanged:Connect(function(inputType)
			local device = classify(inputType)
			if device ~= lastSent then
				task.delay(REPORT_COOLDOWN, function()
					report(classify(UserInputService:GetLastInputType()))
				end)
			end
		end)
	end)
end

return table.freeze(TelemetryController)
