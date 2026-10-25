--!strict

-- Móveis prontos da Ala do Assassinato (Fase 5I): vieram da Creator Store,
-- foram inspecionados no Studio (só entram modelos sem nenhum script; os
-- que traziam scripts foram rejeitados, ver docs/FASE_5I_ASSASSINATO_JOGAVEL.md),
-- limpos (sem assentos, câmeras ou interfaces) e salvos no repositório em
-- `src/shared/assets/MurderModels.rbxm`. Todos com a frente virada para -Z,
-- o pivô no centro da base e o tamanho original no atributo BaseSize:
--   * Bookshelf e TallBookshelf (estantes com livros), FourPosterBed (cama
--     de dossel: peças "Blanket", "Canopy", "Mattress" e "Frame"),
--     StoneFireplace, ChesterfieldSofa, DiningChair, GothicChair, Cauldron,
--     KnightArmor, LongTable, RoundTable, SideTable, Bench, Counter, Chest,
--     BarrelRack e Vase.
-- Posicionar e bloquear passagem é com MysteryAssets.place e .blocker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "MurderModels"

local MurderAssets = {}

local warned = false

local function folder(): Instance?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local assets = if shared ~= nil then shared:FindFirstChild("assets") else nil
	local found = if assets ~= nil then assets:FindFirstChild(FOLDER_NAME) else nil
	if found == nil and not warned then
		warned = true
		warn("[BlocoPuff] Murder models not found (assets/MurderModels.rbxm): using the simple props")
	end
	return found
end

-- Cópia do modelo `name`, ou nil se não existir.
function MurderAssets.clone(name: string): Model?
	local root = folder()
	local model = if root ~= nil then root:FindFirstChild(name) else nil
	if model == nil or not model:IsA("Model") then
		return nil
	end
	return model:Clone()
end

-- Pinta as peças de nome `partName` (cobertas e dossel da cama de cada
-- quarto, por exemplo).
function MurderAssets.tint(model: Model, partName: string, color: Color3)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == partName then
			descendant.Color = color
		end
	end
end

return table.freeze(MurderAssets)
