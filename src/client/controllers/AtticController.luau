--!strict

-- Sótão escuro (Fase 5C.1), só no cliente: cada personagem dentro do Sótão
-- (você, outros jogadores e bots) ganha uma lanterna acesa na mão, e a sua
-- tela escurece um pouco enquanto você está lá. Ao sair, a lanterna some e
-- a tela volta ao normal.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MansionWingConfig = require(ReplicatedStorage.Shared.config.MansionWingConfig)
local MansionWingLayout = require(ReplicatedStorage.Shared.modules.MansionWingLayout)
local StateAttributeNames = require(ReplicatedStorage.Shared.types.StateAttributeNames)

local CONFIG = MansionWingConfig.Attic
local CHECK_INTERVAL = 0.25
local LANTERN_NAME = "AtticLantern"
local EFFECT_NAME = "AtticDark"
local HANDS = { "RightHand", "Right Arm" }

local AtticController = {}

local started = false
local lanterns: { [Model]: BasePart } = {}
local effect: ColorCorrectionEffect? = nil
local darkened = false
local accumulator = 0

local function getEffect(): ColorCorrectionEffect
	local existing = effect
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local newEffect = Instance.new("ColorCorrectionEffect")
	newEffect.Name = EFFECT_NAME
	newEffect.Parent = Lighting
	effect = newEffect
	return newEffect
end

local function setDark(dark: boolean)
	if dark == darkened then
		return
	end
	darkened = dark
	local target = getEffect()
	TweenService:Create(target, TweenInfo.new(CONFIG.FadeTime), {
		Brightness = if dark then CONFIG.DarkBrightness else 0,
		TintColor = if dark then CONFIG.DarkTint else Color3.new(1, 1, 1),
	}):Play()
end

local function findHand(character: Model): BasePart?
	for _, name in ipairs(HANDS) do
		local hand = character:FindFirstChild(name)
		if hand ~= nil and hand:IsA("BasePart") then
			return hand
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Lanterna presa na mão (sem massa nem colisão: não mexe no personagem).
local function addLantern(character: Model)
	local hand = findHand(character)
	if hand == nil then
		return
	end
	local lantern = Instance.new("Part")
	lantern.Name = LANTERN_NAME
	lantern.Size = Vector3.new(0.6, 0.9, 0.6)
	lantern.Color = CONFIG.LanternColor
	lantern.Material = Enum.Material.Neon
	lantern.CanCollide = false
	lantern.CanQuery = false
	lantern.CanTouch = false
	lantern.Massless = true
	lantern.CastShadow = false
	lantern.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = lantern
	weld.Parent = lantern
	local light = Instance.new("PointLight")
	light.Color = CONFIG.LanternColor
	light.Range = CONFIG.LanternRange
	light.Brightness = CONFIG.LanternBrightness
	-- Sem sombra: várias lanternas juntas pesam no celular.
	light.Shadows = false
	light.Parent = lantern
	lantern.Parent = character
	lanterns[character] = lantern
end

local function removeLantern(character: Model)
	local lantern = lanterns[character]
	lanterns[character] = nil
	if lantern ~= nil then
		lantern:Destroy()
	end
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function collectCharacters(): { Model }
	local list: { Model } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character ~= nil then
			table.insert(list, character)
		end
	end
	for _, bot in ipairs(CollectionService:GetTagged(StateAttributeNames.BotTag)) do
		if bot:IsA("Model") then
			table.insert(list, bot)
		end
	end
	return list
end

local function refresh()
	local inside: { [Model]: boolean } = {}
	for _, character in ipairs(collectCharacters()) do
		local root = rootOf(character)
		if root ~= nil and MansionWingLayout.inAttic(root.Position) then
			inside[character] = true
			local lantern = lanterns[character]
			if lantern == nil or lantern.Parent ~= character then
				removeLantern(character)
				addLantern(character)
			end
		end
	end
	for character in pairs(lanterns) do
		if not inside[character] then
			removeLantern(character)
		end
	end
	local localPlayer = Players.LocalPlayer
	local own = if localPlayer ~= nil then localPlayer.Character else nil
	setDark(own ~= nil and inside[own] == true)
end

function AtticController.start()
	if started then
		return
	end
	started = true
	local warned = false
	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0
		local ok, err = pcall(refresh)
		if not ok and not warned then
			warned = true
			warn(`[BlocoPuff] Attic lanterns failed: {err}`)
		end
	end)
end

return table.freeze(AtticController)
