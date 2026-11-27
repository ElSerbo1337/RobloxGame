--!strict
-- Hidden chests (#100, feature "hiddenChests"):
-- * A small scripted chest (wood box, lid, gold bands, lock) on the station "SecretChest"
--   of every world in GameConfig.hiddenChests.worlds (spot = theme.secretChest, kept
--   free by IslandPlan). Tag "SecretChest", attribute WorldId, a ProximityPrompt
--   "SecretChestPrompt" and a disabled ParticleEmitter "Sparkle" (the client switches it
--   on within sparkleDistance while the chest is closed for that player today).
-- * Opening: the prompt fires on the server; the server checks the player's distance to
--   the chest (hiddenChests.reach), the rules decide (once per German day and chest) and
--   pay the gems. Answer via Notify "SecretChest" (gems) or "SecretChestOpened".
-- * Replication: attribute SecretChestsOpened (JSON list of world ids opened today),
--   refreshed on every state change and once a minute (new German day).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local Texts = require(ReplicatedStorage.Shared.Texts)
local WorldMap = require(script.Parent.WorldMap)

type PlayerState = GameRules.PlayerState

local TAG = "SecretChest"
local WOOD = Color3.fromRGB(150, 95, 55)
local WOOD_DARK = Color3.fromRGB(112, 68, 38)
local GOLD = Color3.fromRGB(255, 200, 40)

local ChestService = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Builds the chest standing on `ground` (front = -Z of the station, towards the middle).
function ChestService.build(ground: CFrame, worldId: string): Model
	local model = Instance.new("Model")
	model.Name = "SecretChest"
	model:SetAttribute("WorldId", worldId)
	local base = part(model, "Box", Vector3.new(3.2, 2, 2.2), ground * CFrame.new(0, 1, 0), WOOD)
	part(model, "Lid", Vector3.new(3.4, 0.8, 2.4), ground * CFrame.new(0, 2.4, 0), WOOD_DARK)
	for _, x in { -1.1, 1.1 } do
		part(model, "Band", Vector3.new(0.3, 2.9, 2.5), ground * CFrame.new(x, 1.45, 0), GOLD)
	end
	part(model, "Lock", Vector3.new(0.6, 0.7, 0.2), ground * CFrame.new(0, 1.9, -1.25), GOLD)

	local glow = Instance.new("Attachment")
	glow.Name = "SparkleAt"
	glow.Position = Vector3.new(0, 1.8, 0)
	glow.Parent = base
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Enabled = false
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 255, 220))
	sparkle.LightEmission = 0.8
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Parent = glow

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SecretChestPrompt"
	-- German default; the client shows it in the player's language.
	prompt.ActionText = Texts.format("de", "sign.secretChestPrompt")
	prompt.ObjectText = Texts.format("de", "sign.secretChest")
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	model.PrimaryPart = base
	CollectionService:AddTag(model, TAG)
	return model
end

local function replicate(player: Player, state: PlayerState)
	local rules = PlayerStates.rules
	local opened = {}
	for _, worldId in GameConfig.hiddenChests.worlds do
		if rules.isWorldUnlocked(state, worldId) and not rules.secretChestReady(state, worldId, os.time()) then
			table.insert(opened, worldId)
		end
	end
	local value = HttpService:JSONEncode(opened)
	if player:GetAttribute("SecretChestsOpened") ~= value then
		player:SetAttribute("SecretChestsOpened", value)
	end
end

function ChestService.start(worlds: { WorldMap.Layout })
	local features = Features.new(GameConfig.features)
	local chests = GameConfig.hiddenChests
	if not features.enabled("hiddenChests") or chests == nil then
		return
	end
	local rules = PlayerStates.rules
	local notify = Net.event("Notify")

	for _, world in worlds do
		if table.find(chests.worlds, world.worldId) == nil then
			continue
		end
		local spot = WorldMap.station(world.index, "SecretChest")
		if spot == nil then
			warn(`[Chest] Kein Truhen-Platz (theme.secretChest) in {world.worldId}`)
			continue
		end
		local chest = ChestService.build(spot, world.worldId)
		chest.Parent = world.folder
		local center = (chest.PrimaryPart :: BasePart).Position
		local prompt = (chest.PrimaryPart :: BasePart):FindFirstChild("SecretChestPrompt") :: ProximityPrompt
		prompt.Triggered:Connect(function(player: Player)
			local state = PlayerStates.get(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- Never trust the prompt alone: the player has to stand at the chest.
			if state == nil or root == nil or (root.Position - center).Magnitude > chests.reach then
				return
			end
			local result = rules.openSecretChest(state, world.worldId, os.time())
			if result.ok then
				PlayerStates.set(player, result.state)
				notify:FireClient(player, "SecretChest", chests.gems)
			elseif result.reason == "AlreadyOpened" then
				notify:FireClient(player, "SecretChestOpened")
			end
		end)
	end

	PlayerStates.onChanged(replicate)
	local function refresh(player: Player)
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end
	Players.PlayerAdded:Connect(refresh)
	for _, player in Players:GetPlayers() do
		refresh(player)
	end
	-- A new German day opens the chests again.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

return ChestService
