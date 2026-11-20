--!strict
-- Shop stands: walking into a stand's zone opens its menu on the client, walking out
-- closes it. Purchases (upgrades and potions) are wishes from the client; the server checks that the player
-- is standing in that shop and lets the game rules decide (price, shop level limit).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local GroundMarker = require(script.Parent.GroundMarker)
local PlayerStates = require(script.Parent.PlayerStates)
local SignText = require(script.Parent.SignText)

local CHECK_SECONDS = 0.2
-- Width of the pizzeria stand model (#28) = width of the placeholder awning.
local STAND_MODEL_WIDTH = 13

export type Stand = { shopId: string, zone: BasePart }

local ShopService = {}

local function isInside(zone: BasePart, position: Vector3): boolean
	local relative = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Builds a shop stand facing -Z at `groundPosition` and returns it with the zone in
-- front of the counter: the pizzeria stand model or, until it is imported, a counter
-- with a striped awning from parts (kept invisible under the model for collisions).
-- `scale` (default 1) makes the whole building bigger, e.g. for the shops in later worlds.
function ShopService.buildStand(parent: Instance, shopId: string, groundPosition: Vector3, scale: number?): Stand
	local shop = GameConfig.shops[shopId]
	assert(shop, `unknown shop "{shopId}"`)
	local k = scale or 1
	-- Position relative to the stand's ground point, scaled with the building.
	local function at(x: number, y: number, z: number): Vector3
		return groundPosition + Vector3.new(x, y, z) * k
	end

	local model = Instance.new("Model")
	model.Name = `Shop_{shopId}`

	local counter = part({
		Name = "Counter",
		Size = Vector3.new(12, 3.5, 3) * k,
		Position = at(0, 1.75, 0),
		Color = Color3.fromRGB(160, 105, 60),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	part({
		Name = "CounterTop",
		Size = Vector3.new(12.6, 0.4, 3.6) * k,
		Position = at(0, 3.7, 0),
		Color = Color3.fromRGB(250, 235, 200),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	for _, x in { -5.8, 5.8 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.6, 9, 0.6) * k,
			Position = at(x, 4.5, 1.2),
			Color = Color3.fromRGB(120, 75, 40),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	-- Striped awning (red/white), tilted towards the front.
	local stripes = 6
	for i = 1, stripes do
		local stripe = part({
			Name = "Awning",
			Size = Vector3.new(13 / stripes, 0.3, 5) * k,
			Color = if i % 2 == 0 then Color3.fromRGB(255, 250, 240) else Color3.fromRGB(220, 60, 50),
			Material = Enum.Material.Fabric,
			Parent = model,
		})
		stripe.CFrame = CFrame.new(at(-6.5 + (i - 0.5) * 13 / stripes, 9.3, 0)) * CFrame.Angles(math.rad(-15), 0, 0)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(12 * k, 3 * k)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 10 * k, 0)
	billboard.MaxDistance = 150
	billboard.Adornee = counter
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	SignText.set(label, "sign.shopUpgrades", { shop = shop.displayName })
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = model

	-- Invisible detection volume; the floor marking shows it (#60).
	local zone = part({
		Name = "ShopZone",
		Size = Vector3.new(14 * k, 6, 9 * k),
		Position = groundPosition + Vector3.new(0, 3, -6.5 * k),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = model,
	})

	GroundMarker.build(
		model,
		CFrame.new(groundPosition + Vector3.new(0, 0, -6.5 * k)),
		14 * k,
		9 * k,
		Color3.fromRGB(90, 200, 120),
		"sign.shop"
	)

	ModelLibrary.dressPlaceholder(
		model,
		"PizzaStand",
		STAND_MODEL_WIDTH * k,
		CFrame.new(groundPosition),
		{ "Counter", "CounterTop", "Post", "Awning" }
	)

	model.Parent = parent
	return { shopId = shopId, zone = zone }
end

function ShopService.start(stands: { Stand })
	local shopOpen = Net.event("ShopOpen")
	local shopUpdate = Net.event("ShopUpdate")
	local shopClose = Net.event("ShopClose")
	local shopPurchase = Net.event("ShopPurchase")

	-- Shop each player is currently standing in.
	local insideShop: { [Player]: string } = {}

	local function offersFor(player: Player, shopId: string)
		local state = PlayerStates.get(player)
		if state == nil then
			return nil, nil
		end
		return PlayerStates.rules.shopOffers(state, shopId), PlayerStates.rules.potionOffers(state, shopId)
	end

	-- Upgrades and potions are bought the same way: only while standing at that shop;
	-- the game rules decide (price, shop level limit, what the shop sells).
	local function handlePurchase(buy: (GameRules.PlayerState, string, string) -> GameRules.Result)
		return function(player: Player, shopId: unknown, itemId: unknown)
			if typeof(shopId) ~= "string" or typeof(itemId) ~= "string" then
				return
			end
			local state = PlayerStates.get(player)
			if state == nil or insideShop[player] ~= shopId then
				return
			end
			local result = buy(state, shopId, itemId)
			if result.ok then
				PlayerStates.set(player, result.state)
				shopPurchase:FireClient(player, true, itemId)
			else
				shopPurchase:FireClient(player, false, result.reason)
			end
		end
	end
	Net.event("BuyUpgrade").OnServerEvent:Connect(handlePurchase(PlayerStates.rules.buyUpgrade))
	Net.event("BuyPotion").OnServerEvent:Connect(handlePurchase(PlayerStates.rules.buyPotion))

	-- Keep an open menu current (coins earned elsewhere, levels or potions bought).
	-- Only sent when something the menu shows changed: running potions tick every few seconds.
	local shownFor: { [Player]: string } = {}
	PlayerStates.onChanged(function(player, state)
		local shopId = insideShop[player]
		if shopId then
			local offers = PlayerStates.rules.shopOffers(state, shopId)
			local potions = PlayerStates.rules.potionOffers(state, shopId)
			local key = HttpService:JSONEncode({ state.coins, state.gems, offers, potions })
			if shownFor[player] ~= key then
				shownFor[player] = key
				shopUpdate:FireClient(player, shopId, offers, potions)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		insideShop[player] = nil
		shownFor[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local current: string? = nil
				if root then
					for _, stand in stands do
						if isInside(stand.zone, root.Position) then
							current = stand.shopId
							break
						end
					end
				end

				local previous = insideShop[player]
				if current ~= previous then
					if previous then
						shopClose:FireClient(player)
					end
					shownFor[player] = nil
					local offers, potions = nil, nil
					if current then
						offers, potions = offersFor(player, current)
					end
					if current and offers then
						insideShop[player] = current
						shopOpen:FireClient(player, current, offers, potions)
					else
						insideShop[player] = nil
					end
				end
			end
		end
	end)
end

return ShopService
