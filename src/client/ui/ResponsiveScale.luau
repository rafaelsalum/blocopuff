--!strict

-- Escala painéis em relação a uma resolução de referência sem alterar a
-- área segura do ScreenGui. Mantém texto e alvos de toque dentro de limites.

local Workspace = game:GetService("Workspace")

export type ResponsiveScaleHandle = {
	destroy: () -> (),
}

local ResponsiveScale = {}

function ResponsiveScale.attach(
	target: GuiObject,
	referenceViewport: Vector2,
	minimumScale: number,
	maximumScale: number
): ResponsiveScaleHandle
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale.Parent = target

	local cameraConnection: RBXScriptConnection? = nil
	local workspaceConnection: RBXScriptConnection? = nil

	local function updateScale()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			uiScale.Scale = 1
			return
		end

		local viewport = camera.ViewportSize
		local widthScale = viewport.X / referenceViewport.X
		local heightScale = viewport.Y / referenceViewport.Y
		uiScale.Scale = math.clamp(math.min(widthScale, heightScale), minimumScale, maximumScale)
	end

	local function connectCamera()
		if cameraConnection ~= nil then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end

		local camera = Workspace.CurrentCamera
		if camera ~= nil then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
		updateScale()
	end

	workspaceConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
	connectCamera()

	local handle = {} :: ResponsiveScaleHandle
	handle.destroy = function()
		if cameraConnection ~= nil then
			cameraConnection:Disconnect()
		end
		if workspaceConnection ~= nil then
			workspaceConnection:Disconnect()
		end
		uiScale:Destroy()
	end

	return handle
end

return table.freeze(ResponsiveScale)
