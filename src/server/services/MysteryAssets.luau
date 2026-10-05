--!strict

-- Modelos prontos dos Mistérios do Barão e do piano de cauda (Fase 5C.3):
-- vieram da Creator Store, limpos (sem scripts) e salvos no repositório em
-- `src/shared/assets/MysteryModels.rbxm`. Todos com a frente virada para -Z
-- e o pivô no centro da base:
--   * Candelabra: velas "Candle" e chamas "Flame" (fogo e luz desligados);
--   * StainedWindow: vidro principal no modelo "MainGlass";
--   * GrandfatherClock: "HourHand", "MinuteHand", "HandCenter", "Pendulum"
--     e "PendulumHinge" (parado nas 12h);
--   * Safe: "Body", "Door" (dobradiça no lado -X) e o dinheiro "Money";
--   * Frame: moldura com a tela "Canvas" (face no atributo CanvasFace);
--   * MusicStand: estante com a folha "Sheet";
--   * GrandPiano: "Body", teclados "WhiteKeys"/"BlackKeys", "Pedal" e as
--     medidas do teclado em atributos (Keyboard*, KeyTopY, KeyFrontZ).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "MysteryModels"

local MysteryAssets = {}

local warned = false

local function folder(): Instance?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local assets = if shared ~= nil then shared:FindFirstChild("assets") else nil
	local found = if assets ~= nil then assets:FindFirstChild(FOLDER_NAME) else nil
	if found == nil and not warned then
		warned = true
		warn("[BlocoPuff] Mystery models not found (assets/MysteryModels.rbxm): using the simple props")
	end
	return found
end

-- Todos os modelos de `names` existem?
function MysteryAssets.has(names: { string }): boolean
	local root = folder()
	if root == nil then
		return false
	end
	for _, name in ipairs(names) do
		local model = root:FindFirstChild(name)
		if model == nil or not model:IsA("Model") then
			return false
		end
	end
	return true
end

-- Cópia do modelo `name`, ou nil se não existir.
function MysteryAssets.clone(name: string): Model?
	local root = folder()
	local model = if root ~= nil then root:FindFirstChild(name) else nil
	if model == nil or not model:IsA("Model") then
		return nil
	end
	return model:Clone()
end

-- Põe o modelo em `at` (centro da base), com a frente para `facing` e no
-- tamanho `scale`. Tudo ancorado e sem colisão (enfeite); quem precisa
-- bloquear passagem ganha uma caixa própria.
function MysteryAssets.place(model: Model, at: Vector3, facing: Vector3, scale: number, parent: Instance): Model
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local direction = if flat.Magnitude > 0.01 then flat.Unit else -Vector3.zAxis
	model:PivotTo(CFrame.lookAt(at, at + direction))
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	model.Parent = parent
	return model
end

-- Caixa invisível que bloqueia a passagem (no lugar da colisão das malhas).
function MysteryAssets.blocker(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local box = Instance.new("Part")
	box.Name = name
	box.Size = size
	box.CFrame = cframe
	box.Anchored = true
	box.CanCollide = true
	box.CanTouch = false
	box.Transparency = 1
	box.Parent = parent
	return box
end

-- Frame de referência no centro `center`, com a rotação do modelo (o eixo
-- Z local atravessa a frente): ponteiros e pêndulo giram nele.
function MysteryAssets.frameAt(model: Model, center: Vector3): CFrame
	local pivot = model:GetPivot()
	return CFrame.new(center) * pivot.Rotation
end

return table.freeze(MysteryAssets)
