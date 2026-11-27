--!strict
-- Hidden chests (#100), purely cosmetic on the client:
-- * the chest sparkles (ParticleEmitter "Sparkle", built off by ChestService) while this
--   player is within GameConfig.hiddenChests.sparkleDistance studs and has not opened it
--   today (attribute SecretChestsOpened). GraphicsQuality scales the particle rate on "Low".
-- * an opened chest hides its prompt for this player; prompt texts in the player's language.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Lang = require(script.Parent.Lang)

local TAG = "SecretChest"
local PROMPT_NAME = "SecretChestPrompt"

local SecretChests = {}

function SecretChests.start()
	local features = Features.new(GameConfig.features)
	local chests = GameConfig.hiddenChests
	if not features.enabled("hiddenChests") or chests == nil then
		return
	end
	local player = Players.LocalPlayer

	local function openedToday(): { [string]: boolean }
		local set = {}
		local raw = player:GetAttribute("SecretChestsOpened")
		if type(raw) == "string" then
			local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and type(list) == "table" then
				for _, worldId in list do
					set[worldId] = true
				end
			end
		end
		return set
	end

	local function update()
		local opened = openedToday()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, chest in CollectionService:GetTagged(TAG) do
			local base = (chest :: Model).PrimaryPart
			if base == nil then
				continue
			end
			local closed = not opened[chest:GetAttribute("WorldId") :: string]
			local near = root ~= nil and (root.Position - base.Position).Magnitude <= chests.sparkleDistance
			local sparkle = base:FindFirstChild("Sparkle", true) :: ParticleEmitter?
			if sparkle then
				sparkle.Enabled = closed and near
			end
			local prompt = base:FindFirstChild(PROMPT_NAME) :: ProximityPrompt?
			if prompt then
				prompt.Enabled = closed
			end
		end
	end

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == PROMPT_NAME then
			prompt.ActionText = Lang.t("sign.secretChestPrompt")
			prompt.ObjectText = Lang.t("sign.secretChest")
		end
	end)
	player:GetAttributeChangedSignal("SecretChestsOpened"):Connect(update)
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end

return SecretChests
