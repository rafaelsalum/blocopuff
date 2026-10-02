--!strict

-- Desenha as armadilhas do Casarão (Fase 5) neste cliente. Acompanha as
-- peças com a tag CasaraoTrap e cria o efeito de cada tipo (effects/*); um
-- único loop anima todas. O servidor decide tudo (TrapService); aqui só se
-- lê o estado publicado em atributos.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TrapConstants = require(ReplicatedStorage.Shared.modules.TrapConstants)
local RugTrapFx = require(script.Parent.Parent.effects.RugTrapFx)
local WindowTrapFx = require(script.Parent.Parent.effects.WindowTrapFx)

type Handle = WindowTrapFx.Handle

local EFFECTS_FOLDER_NAME = "LocalTrapFx"

local TrapVisualController = {}

local started = false
local handles: { [Instance]: Handle } = {}

local function getEffectsFolder(): Folder
	local existing = Workspace:FindFirstChild(EFFECTS_FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = EFFECTS_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function track(instance: Instance)
	if handles[instance] ~= nil or not instance:IsA("BasePart") then
		return
	end
	local kind = instance:GetAttribute(TrapConstants.KindAttribute)
	if kind == TrapConstants.Window then
		handles[instance] = WindowTrapFx.new(instance, getEffectsFolder())
	elseif kind == TrapConstants.Rug then
		handles[instance] = RugTrapFx.new(instance, getEffectsFolder())
	end
end

local function untrack(instance: Instance)
	local handle = handles[instance]
	if handle ~= nil then
		handles[instance] = nil
		handle.destroy()
	end
end

local function step(dt: number)
	for instance, handle in pairs(handles) do
		local ok, failure = pcall(handle.update, dt)
		if not ok then
			warn(`[BlocoPuff] Trap effect failed: {failure}`)
			untrack(instance)
		end
	end
end

function TrapVisualController.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(TrapConstants.Tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TrapConstants.Tag):Connect(untrack)
	for _, instance in ipairs(CollectionService:GetTagged(TrapConstants.Tag)) do
		track(instance)
	end
	RunService.RenderStepped:Connect(step)
end

return table.freeze(TrapVisualController)
