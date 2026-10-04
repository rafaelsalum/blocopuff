--!strict

-- Traduz para o idioma do jogador os textos que o servidor põe no cenário
-- para todos (placas, painéis da fila, arcos do Casarão, prompts de
-- interação). O servidor escreve em português; aqui, só para quem joga em
-- inglês, cada texto é trocado pela tradução sempre que muda.
--
-- A troca é local: o servidor continua vendo e escrevendo o português, e
-- cada nova escrita dele é traduzida de novo.

local Workspace = game:GetService("Workspace")

local Lang = require(game:GetService("ReplicatedStorage").Shared.i18n.Lang)

local WorldTextLocalizer = {}

local TEXT_PROPERTIES: { [string]: { string } } = {
	TextLabel = { "Text" },
	TextButton = { "Text" },
	ProximityPrompt = { "ActionText", "ObjectText" },
}

-- Último texto que este cliente escreveu em cada propriedade: evita
-- retraduzir a própria escrita.
local written: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any

local function localizeProperty(instance: Instance, property: string)
	local current = (instance :: any)[property] :: string
	local mine = written[instance]
	if current == "" or (mine ~= nil and mine[property] == current) then
		return
	end
	local translated = Lang.localize(current)
	if translated == current then
		return
	end
	if mine == nil then
		mine = {}
		written[instance] = mine
	end
	mine[property] = translated;
	(instance :: any)[property] = translated
end

local function watch(instance: Instance)
	local properties = TEXT_PROPERTIES[instance.ClassName]
	if properties == nil then
		return
	end
	for _, property in properties do
		localizeProperty(instance, property)
		instance:GetPropertyChangedSignal(property):Connect(function()
			localizeProperty(instance, property)
		end)
	end
end

function WorldTextLocalizer.start()
	if Lang.current() == "pt" then
		return
	end
	Workspace.DescendantAdded:Connect(watch)
	for _, descendant in Workspace:GetDescendants() do
		watch(descendant)
	end
end

return WorldTextLocalizer
