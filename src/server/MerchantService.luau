--!strict
-- Travelling merchant (#107, feature "travelingMerchant"):
-- * Stand on the reserved spot of the spawn island (#106: Anchors.MerchantAnchor, front =
--   -Z): counter, striped awning, sign "🐪 Reisender Händler" and a ProximityPrompt
--   "MerchantPrompt" that opens the menu on the client. The stand is only there while the
--   merchant visits (clock schedule, GameRules.merchantStatus) or while an online admin
--   called him (admin action "spawnMerchant").
-- * Announcement: RemoteEvent MerchantNotice("soon", minutes) to all players
--   announceSeconds before a visit, MerchantNotice("arrived") when it starts.
-- * Buying: the client wishes BuyMerchant(offerId); the rules check the time window,
--   limits and gems. Answer: MerchantResult(ok, offerIdOrReason, petId?).
-- * Replication: attribute Merchant (JSON, see Net).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnnounceService = require(script.Parent.AnnounceService)
local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local SignText = require(script.Parent.SignText)
local Texts = require(ReplicatedStorage.Shared.Texts)

type PlayerState = GameRules.PlayerState

local BUY_COOLDOWN = 0.4
local WOOD = Color3.fromRGB(150, 95, 55)
local RED = Color3.fromRGB(200, 50, 60)
local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)

local MerchantService = {}

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Builds the stand on the anchor (ground point, front = -Z towards the island middle).
function MerchantService.build(anchor: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "MerchantStand"
	local base = anchor.CFrame
	local floor = part(model, {
		Name = "Floor",
		Size = Vector3.new(9, 0.6, 6),
		CFrame = base * CFrame.new(0, 0.3, 0.5),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	local counter = part(model, {
		Name = "Counter",
		Size = Vector3.new(7, 3, 1.4),
		CFrame = base * CFrame.new(0, 2.1, -1.4),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	for _, x in { -4, 4 } do
		for _, z in { -2.2, 3 } do
			part(model, {
				Name = "Post",
				Size = Vector3.new(0.5, 7, 0.5),
				CFrame = base * CFrame.new(x, 4, z),
				Color = WOOD,
				Material = Enum.Material.Wood,
			})
		end
	end
	-- Striped awning (red/cream), slightly tilted to the front.
	for index = 0, 5 do
		part(model, {
			Name = "Awning",
			Size = Vector3.new(9.6 / 6, 0.3, 6.4),
			CFrame = base * CFrame.new(-4.8 + 9.6 / 12 + index * 9.6 / 6, 7.6, 0.4) * CFrame.Angles(math.rad(-8), 0, 0),
			Color = if index % 2 == 0 then RED else CREAM,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	-- Crates with goods (gem and potion colours) on the counter.
	for index, color in { Color3.fromRGB(120, 70, 220), Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 200, 255) } do
		part(model, {
			Name = "Goods",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			CFrame = base * CFrame.new(-2.5 + index * 1.25, 4.05, -1.4),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	local sign = part(model, {
		Name = "Sign",
		Size = Vector3.new(8, 1.6, 0.3),
		CFrame = base * CFrame.new(0, 8.6, -2.6),
		Color = RED,
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = CREAM
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = DARK
	stroke.Parent = label
	SignText.set(label, "merchant.sign")
	label.Parent = gui
	gui.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MerchantPrompt"
	-- German default; the client shows it in the player's language.
	prompt.ActionText = Texts.format("de", "merchant.prompt")
	prompt.ObjectText = Texts.format("de", "merchant.sign")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.PrimaryPart = floor
	return model
end

local function replicate(player: Player, state: PlayerState)
	local rules = PlayerStates.rules
	local now = os.time()
	local status = rules.merchantStatus(now, state.merchantForcedAt)
	player:SetAttribute(
		"Merchant",
		HttpService:JSONEncode({
			active = status.active,
			startsAt = status.startsAt,
			endsAt = status.endsAt,
			offers = rules.merchantOffers(state, now),
		})
	)
end

function MerchantService.start(spawnIsland: Instance)
	local features = Features.new(GameConfig.features)
	if not features.enabled("travelingMerchant") then
		return
	end
	local rules = PlayerStates.rules
	local anchors = spawnIsland:FindFirstChild("Anchors")
	local anchor = anchors and anchors:FindFirstChild("MerchantAnchor")
	local stand: Model? = nil
	if anchor and anchor:IsA("BasePart") then
		stand = MerchantService.build(anchor)
	else
		warn("[Merchant] Anker MerchantAnchor fehlt auf der Spawn-Insel")
	end

	local notice = Net.event("MerchantNotice")
	local result = Net.event("MerchantResult")
	local random = Random.new()
	local function draw(): number
		return random:NextNumber()
	end
	local lastBuy: { [Player]: number } = {}
	-- Last replicated status per player ("active:visit"), so the attribute only changes
	-- when the visit changes (and with every state change).
	local lastKey: { [Player]: string } = {}

	PlayerStates.onChanged(function(player, state)
		replicate(player, state)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
		lastKey[player] = nil
	end)

	Net.event("BuyMerchant").OnServerEvent
		:Connect(features.guard("travelingMerchant", function(player: Player, offerId: any)
			if type(offerId) ~= "string" then
				return
			end
			local state = PlayerStates.get(player)
			if state == nil then
				return
			end
			local clock = os.clock()
			if lastBuy[player] and clock - lastBuy[player] < BUY_COOLDOWN then
				result:FireClient(player, false, "Busy")
				return
			end
			lastBuy[player] = clock
			local bought = rules.buyFromMerchant(state, offerId, os.time(), draw)
			if not bought.ok then
				result:FireClient(player, false, bought.reason)
				return
			end
			PlayerStates.set(player, bought.state)
			local pet = bought.pet
			result:FireClient(player, true, offerId, pet and pet.petId)
			if pet and GameConfig.pets[pet.petId] and GameConfig.pets[pet.petId].rarity == "Secret" then
				AnnounceService.secretHatched(player, pet.petId)
			end
		end))

	-- Clock loop: stand, announcements, per-player status.
	local wasAnnounced, wasActive = false, false
	task.spawn(function()
		while true do
			local now = os.time()
			local global = rules.merchantStatus(now)
			local anyActive = global.active
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				if state == nil then
					continue
				end
				local status = rules.merchantStatus(now, state.merchantForcedAt)
				anyActive = anyActive or status.active
				local key = `{status.active}:{status.visit}`
				if lastKey[player] ~= key then
					-- An admin visit of its own starts: tell only this player.
					if status.active and not global.active and lastKey[player] ~= nil then
						notice:FireClient(player, "arrived")
					end
					lastKey[player] = key
					replicate(player, state)
				end
			end
			if global.announce and not wasAnnounced then
				notice:FireAllClients("soon", math.max(1, math.ceil((global.startsAt - now) / 60)))
			end
			if global.active and not wasActive then
				notice:FireAllClients("arrived")
			end
			wasAnnounced, wasActive = global.announce, global.active
			if stand then
				local parent = if anyActive then spawnIsland else nil
				if stand.Parent ~= parent then
					stand.Parent = parent
				end
			end
			task.wait(1)
		end
	end)
end

return MerchantService
