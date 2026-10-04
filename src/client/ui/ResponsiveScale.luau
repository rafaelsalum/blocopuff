--!strict

-- Escala painéis em relação a uma resolução de referência sem alterar a
-- área segura do ScreenGui. Mantém texto e alvos de toque dentro de limites.

local TweenService = game:GetService("TweenService")
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

export type FitOptions = {
	-- Fração da área segura da tela que o painel pode ocupar (largura,
	-- altura).
	fill: Vector2,
	minimumScale: number,
	maximumScale: number,
}

-- Padrão dos modais do lobby (ranking, Puffdex, máquina, desafios, party):
-- quase a tela toda, sem ficar gigante no computador.
local MODAL: FitOptions = table.freeze({
	fill = Vector2.new(0.95, 0.96),
	minimumScale = 0.5,
	maximumScale = 1.5,
})

export type FitHandle = {
	-- Animação de abertura: o painel cresce de `from` (fração do tamanho
	-- final) até o tamanho final.
	pop: (from: number, duration: number) -> (),
	destroy: () -> (),
}

ResponsiveScale.Modal = MODAL

-- Modais: o painel (desenhado em `panelSize`) cresce até ocupar `fill` da
-- área segura da ScreenGui em que está (o `target` já precisa estar nela),
-- sem passar dos limites (o `target` não deve trocar de pai depois). Um
-- único UIScale faz o ajuste e a animação de
-- abertura (dois UIScales no mesmo objeto não se somam).
function ResponsiveScale.fit(target: GuiObject, panelSize: Vector2, options: FitOptions): FitHandle
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale.Parent = target

	local fitScale = 1
	local popFactor = Instance.new("NumberValue")
	popFactor.Value = 1
	local connections: { RBXScriptConnection } = {}
	local popTween: Tween? = nil

	local function apply()
		uiScale.Scale = fitScale * popFactor.Value
	end

	local function room(): Vector2
		local container = target.Parent
		if container ~= nil and container:IsA("GuiBase2d") and container.AbsoluteSize.X > 0 and container.AbsoluteSize.Y > 0 then
			return container.AbsoluteSize
		end
		local camera = Workspace.CurrentCamera
		return if camera ~= nil then camera.ViewportSize else panelSize
	end

	local function updateScale()
		local area = room()
		local widthScale = (area.X * options.fill.X) / panelSize.X
		local heightScale = (area.Y * options.fill.Y) / panelSize.Y
		fitScale = math.clamp(math.min(widthScale, heightScale), options.minimumScale, options.maximumScale)
		apply()
	end

	local container = target.Parent
	if container ~= nil and container:IsA("GuiBase2d") then
		table.insert(connections, container:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale))
	end
	table.insert(connections, popFactor.Changed:Connect(apply))
	updateScale()

	local handle = {} :: FitHandle
	handle.pop = function(from: number, duration: number)
		if popTween ~= nil then
			popTween:Cancel()
		end
		-- A ScreenGui pode ter acabado de ser ligada: confere o tamanho.
		updateScale()
		popFactor.Value = from
		local tween = TweenService:Create(popFactor, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
		popTween = tween
		tween:Play()
	end
	handle.destroy = function()
		if popTween ~= nil then
			popTween:Cancel()
		end
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		popFactor:Destroy()
		uiScale:Destroy()
	end
	return handle
end

return table.freeze(ResponsiveScale)
