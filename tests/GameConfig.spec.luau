local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")
local ToppingField = require("../src/shared/ToppingField")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("GameConfig", function()
	it("starts world 1 (Pizzeria-Garten) with 60 toppings, respawning after 5 seconds", function()
		local field = ToppingField.new(GameConfig, "PizzeriaGarden", TestKit.sequenceRandom({ 0.5 }))

		expect(field.slotCount).toBe(60)
		expect(GameConfig.toppingField.respawnSeconds).toBe(5)
	end)

	it("starts players with a pizza of 2 and a collect range of 10 studs", function()
		local rules = GameRules.new(GameConfig)
		local state = rules.newPlayerState()

		expect(rules.pizzaCapacity(state)).toBe(2)
		expect(rules.collectRange(state)).toBe(10)
	end)

	it("gives auto-collect a pickup radius smaller than the click range", function()
		local rules = GameRules.new(GameConfig)
		local radius = rules.autoCollectRadius(rules.newPlayerState())

		expect(radius > 0).toBe(true)
		expect(radius < rules.collectRange(rules.newPlayerState())).toBe(true)
	end)

	it("only spawns toppings that exist in the topping list", function()
		for _, world in GameConfig.worlds do
			for _, spawn in world.toppingSpawns do
				expect(GameConfig.toppings[spawn.topping] ~= nil).toBe(true)
			end
		end
	end)

	it("makes rarer toppings in a world worth more", function()
		for _, world in GameConfig.worlds do
			local spawns = table.clone(world.toppingSpawns)
			table.sort(spawns, function(a, b)
				return a.weight > b.weight
			end)
			for i = 2, #spawns do
				local commoner = GameConfig.toppings[spawns[i - 1].topping].value
				local rarer = GameConfig.toppings[spawns[i].topping].value
				expect(rarer > commoner).toBe(true)
			end
		end
	end)

	it("puts world 2 (Bauernhof) behind a 1.500 coin barrier with its own four toppings", function()
		local farm = GameConfig.worlds[2]

		expect(farm.id).toBe("Farm")
		expect(farm.unlockPrice).toBe(1500)
		local toppings = {}
		for _, spawn in farm.toppingSpawns do
			table.insert(toppings, GameConfig.toppings[spawn.topping].displayName)
		end
		table.sort(toppings)
		expect(toppings).toEqual({ "Mais", "Paprika", "Schinken", "Zwiebel" })
	end)

	local function toppingNames(world): { string }
		local names = {}
		for _, spawn in world.toppingSpawns do
			table.insert(names, GameConfig.toppings[spawn.topping].displayName)
		end
		table.sort(names)
		return names
	end

	it("puts world 3 (Strand) behind a 15.000 coin barrier with tuna, shrimp and pineapple", function()
		local beach = GameConfig.worlds[3]

		expect(beach.id).toBe("Beach")
		expect(beach.displayName).toBe("Strand")
		expect(beach.unlockPrice).toBe(15000)
		expect(toppingNames(beach)).toEqual({ "Ananas", "Garnele", "Thunfisch" })
	end)

	it("puts world 4 (Eisberge) behind a 150.000 coin barrier with frozen peas, salmon and iceberg lettuce", function()
		local icebergs = GameConfig.worlds[4]

		expect(icebergs.id).toBe("Icebergs")
		expect(icebergs.displayName).toBe("Eisberge")
		expect(icebergs.unlockPrice).toBe(150000)
		expect(toppingNames(icebergs)).toEqual({ "Eisberg-Salat", "Gefrorene Erbsen", "Lachs" })
	end)

	it("puts world 5 (Vulkan) behind a 1,5 Mio coin barrier with chili, pepperoni and jalapeño", function()
		local volcano = GameConfig.worlds[5]

		expect(volcano.id).toBe("Volcano")
		expect(volcano.displayName).toBe("Vulkan")
		expect(volcano.unlockPrice).toBe(1500000)
		expect(toppingNames(volcano)).toEqual({ "Chili", "Jalapeño", "Peperoni" })
	end)

	it(
		"puts world 6 (Süßigkeitenland) behind a 15 Mio coin barrier with chocolate chips, gummy bears and marshmallow",
		function()
			local candy = GameConfig.worlds[6]

			expect(candy.id).toBe("CandyLand")
			expect(candy.displayName).toBe("Süßigkeitenland")
			expect(candy.unlockPrice).toBe(15000000)
			expect(toppingNames(candy)).toEqual({ "Gummibärchen", "Marshmallow", "Schoko-Stücke" })
		end
	)

	it(
		"puts world 7 (Weltraum) behind a 150 Mio coin barrier with moon cheese, star olives and alien mushroom",
		function()
			local space = GameConfig.worlds[7]

			expect(#GameConfig.worlds).toBe(7)
			expect(space.id).toBe("Space")
			expect(space.displayName).toBe("Weltraum")
			expect(space.unlockPrice).toBe(150000000)
			expect(toppingNames(space)).toEqual({ "Alien-Pilz", "Mond-Käse", "Sternen-Oliven" })
		end
	)

	it("lets a player unlock worlds 5-7 one after another and teleport to all of them", function()
		local rules = GameRules.new(GameConfig)
		local state = rules.newPlayerState()
		state.unlockedWorlds = { "Farm", "Beach", "Icebergs" }
		state.coins = 1500000 + 15000000 + 150000000
		for index = 5, 7 do
			local result = rules.unlockWorld(state, GameConfig.worlds[index].id)
			expect(result.ok).toBe(true)
			state = result.state
		end

		expect(state.coins).toBe(0)
		for _, world in GameConfig.worlds do
			expect(rules.teleport(state, world.id).ok).toBe(true)
		end
	end)

	it("lets a player unlock worlds 2-4 one after another at their barriers", function()
		local rules = GameRules.new(GameConfig)
		local state = rules.newPlayerState()
		state.coins = 1500 + 15000 + 150000
		for index = 2, 4 do
			local result = rules.unlockWorld(state, GameConfig.worlds[index].id)
			expect(result.ok).toBe(true)
			state = result.state
		end

		expect(state.coins).toBe(0)
		expect(rules.isWorldUnlocked(state, "Icebergs")).toBe(true)
	end)

	it("makes every world cost more to unlock than the one before, starting free", function()
		expect(GameConfig.worlds[1].unlockPrice).toBe(0)
		for i = 2, #GameConfig.worlds do
			expect(GameConfig.worlds[i].unlockPrice > GameConfig.worlds[i - 1].unlockPrice).toBe(true)
		end
	end)

	it("makes toppings of a later world worth about 4x those of the world before", function()
		local function averageValue(world): number
			local total = 0
			for _, spawn in world.toppingSpawns do
				total += GameConfig.toppings[spawn.topping].value
			end
			return total / #world.toppingSpawns
		end
		for i = 2, #GameConfig.worlds do
			local ratio = averageValue(GameConfig.worlds[i]) / averageValue(GameConfig.worlds[i - 1])
			expect(ratio >= 3 and ratio <= 5).toBe(true)
		end
	end)
end)

describe("GameConfig balancing", function()
	-- Rough income model of a player who plays world k-1 to save for the barrier of world k:
	-- they sell world k-1 toppings (spawn-weighted average), carry the biggest pizza the shops
	-- in worlds 1..k-1 sell, need 1.5 s per topping plus 10 s per trip to the oven, and have
	-- the starting pet slots filled with "Selten" pets from world k-1's egg.
	local SECONDS_PER_TOPPING = 1.5
	local SECONDS_PER_SELL_TRIP = 10

	local function averageToppingValue(world): number
		local weight, value = 0, 0
		for _, spawn in world.toppingSpawns do
			weight += spawn.weight
			value += spawn.weight * GameConfig.toppings[spawn.topping].value
		end
		return value / weight
	end

	local function biggestPizza(upToWorld: number): number
		local reachable = {}
		for i = 1, upToWorld do
			reachable[GameConfig.worlds[i].id] = true
		end
		local capacity = GameConfig.pizza.startCapacity
		for _, shop in GameConfig.shops do
			if reachable[shop.worldId] then
				for _, offer in shop.offers do
					if offer.upgrade == "PizzaSpace" then
						capacity = math.max(capacity, GameConfig.upgrades.PizzaSpace.levels[offer.maxLevel].value)
					end
				end
			end
		end
		return capacity
	end

	local function rarePetBonus(world): number
		for _, entry in GameConfig.eggs[world.eggs[1]].pets do
			local pet = GameConfig.pets[entry.pet]
			if pet.rarity == "Rare" then
				return pet.bonus
			end
		end
		error(`no rare pet in {world.eggs[1]}`)
	end

	local function coinsPerMinute(worldIndex: number, pizza: number?): number
		local world = GameConfig.worlds[worldIndex]
		local capacity = pizza or biggestPizza(worldIndex)
		local toppingsPerMinute = 60 * capacity / (capacity * SECONDS_PER_TOPPING + SECONDS_PER_SELL_TRIP)
		local multiplier = 1 + GameConfig.petSlots.start * rarePetBonus(world)
		return averageToppingValue(world) * toppingsPerMinute * multiplier
	end

	it("makes every world reachable with the income of the world before in 10-60 minutes", function()
		for i = 2, #GameConfig.worlds do
			local minutes = GameConfig.worlds[i].unlockPrice / coinsPerMinute(i - 1)
			if minutes < 10 or minutes > 60 then
				error(`{GameConfig.worlds[i].id}: {math.floor(minutes)} min`)
			end
		end
	end)

	it("prices the coin levels only shop 3 sells at 5-60 minutes of world 7 income each", function()
		local shop2Max = {}
		for _, offer in GameConfig.shops.World4Shop.offers do
			shop2Max[offer.upgrade] = offer.maxLevel
		end
		-- Before shop 3 the player still carries the biggest pizza from shop 2.
		local income = coinsPerMinute(7, biggestPizza(6))
		local checked = 0
		for _, offer in GameConfig.shops.World7Shop.offers do
			local upgrade = GameConfig.upgrades[offer.upgrade]
			if upgrade.currency ~= "Gems" then
				for level = shop2Max[offer.upgrade] + 1, offer.maxLevel do
					local minutes = upgrade.levels[level].price / income
					if minutes < 5 or minutes > 60 then
						error(`{offer.upgrade} level {level}: {math.floor(minutes)} min`)
					end
					checked += 1
				end
			end
		end
		expect(checked).toBe(6)
	end)
end)

describe("GameConfig shops", function()
	local rules = GameRules.new(GameConfig)

	local function buyUntilRejected(upgradeId: string): ({ number }, string?)
		local state = rules.newPlayerState()
		state.coins = 1e12
		local values = {}
		while true do
			local result = rules.buyUpgrade(state, "World1Shop", upgradeId)
			if not result.ok then
				return values, result.reason
			end
			state = result.state
			table.insert(
				values,
				if upgradeId == "PizzaSpace"
					then rules.pizzaCapacity(state)
					elseif upgradeId == "CollectRange" then rules.upgradeLevel(state, upgradeId)
					else rules.magnetRange(state)
			)
		end
	end

	it("shop 1 in world 1 grows the pizza 2 -> 3 -> 4 -> 6, then needs a bigger shop", function()
		local capacities, reason = buyUntilRejected("PizzaSpace")

		expect(GameConfig.shops.World1Shop.worldId).toBe("PizzeriaGarden")
		expect(capacities).toEqual({ 3, 4, 6 })
		expect(reason).toBe("ShopLevelLimit")
	end)

	it("shop 1 sells collect range levels 1-3 and magnet level 1, more only in bigger shops", function()
		local rangeLevels, rangeReason = buyUntilRejected("CollectRange")
		local magnet, magnetReason = buyUntilRejected("Magnet")

		expect(rangeLevels).toEqual({ 1, 2, 3 })
		expect(rangeReason).toBe("ShopLevelLimit")
		expect(#magnet).toBe(1)
		expect(magnet[1] > GameConfig.collect.autoRadius).toBe(true)
		expect(magnetReason).toBe("ShopLevelLimit")
	end)

	it("shop 2 in world 4 sells everything shop 1 does, up to pizza 12, range level 6 and magnet level 3", function()
		local shop2 = GameConfig.shops.World4Shop
		local state = rules.newPlayerState()
		state.coins = 1e12
		state.unlockedWorlds = { "Farm", "Beach", "Icebergs" }
		local function buyAll(shopId: string, upgradeId: string): string?
			while true do
				local result = rules.buyUpgrade(state, shopId, upgradeId)
				if not result.ok then
					return result.reason
				end
				state = result.state
			end
		end

		expect(shop2.worldId).toBe("Icebergs")
		local reasons = {}
		for _, offer in GameConfig.shops.World1Shop.offers do
			buyAll("World1Shop", offer.upgrade)
			reasons[offer.upgrade] = buyAll("World4Shop", offer.upgrade)
		end
		-- Pizza 15 and 20 are left for shop 3 in world 7.
		expect(reasons.PizzaSpace).toBe("ShopLevelLimit")
		expect(rules.pizzaCapacity(state)).toBe(12)
		expect(rules.upgradeLevel(state, "CollectRange")).toBe(6)
		expect(rules.upgradeLevel(state, "Magnet")).toBe(3)
	end)

	it("shop 2 only sells to players who unlocked world 4", function()
		local state = rules.newPlayerState()
		state.coins = 1e6

		expect(rules.buyUpgrade(state, "World4Shop", "PizzaSpace").reason).toBe("WorldLocked")
	end)

	it("shop 3 in world 7 sells every upgrade up to its last level, with pizza space up to 20", function()
		local shop3 = GameConfig.shops.World7Shop
		local state = rules.newPlayerState()
		state.coins = 1e15
		state.gems = 1e9
		state.unlockedWorlds = { "Farm", "Beach", "Icebergs", "Volcano", "CandyLand", "Space" }

		expect(shop3.worldId).toBe("Space")
		for upgradeId, upgrade in GameConfig.upgrades do
			local reason
			repeat
				local result = rules.buyUpgrade(state, "World7Shop", upgradeId)
				state = result.state
				reason = result.reason
			until not result.ok
			expect(reason).toBe("MaxLevel")
			expect(rules.upgradeLevel(state, upgradeId)).toBe(#upgrade.levels)
		end
		expect(rules.pizzaCapacity(state)).toBe(20)
		expect(rules.petSlots(state)).toBe(8)
	end)

	it("gives shop 3 higher range and magnet levels than shop 2", function()
		local function maxLevel(shopId: string, upgradeId: string): number
			for _, offer in GameConfig.shops[shopId].offers do
				if offer.upgrade == upgradeId then
					return offer.maxLevel
				end
			end
			return 0
		end

		for upgradeId in GameConfig.upgrades do
			expect(maxLevel("World7Shop", upgradeId) >= maxLevel("World4Shop", upgradeId)).toBe(true)
		end
		for _, upgradeId in { "PizzaSpace", "CollectRange", "Magnet" } do
			expect(maxLevel("World7Shop", upgradeId) > maxLevel("World4Shop", upgradeId)).toBe(true)
		end
	end)

	it("shop 3 only sells to players who unlocked world 7", function()
		local state = rules.newPlayerState()
		state.coins = 1e12
		state.unlockedWorlds = { "Farm", "Beach", "Icebergs", "Volcano", "CandyLand" }

		expect(rules.buyUpgrade(state, "World7Shop", "PizzaSpace").reason).toBe("WorldLocked")
	end)

	it("only has pizza space, range and magnet as coin upgrades (no sell value upgrade)", function()
		for upgradeId, upgrade in GameConfig.upgrades do
			if upgrade.currency ~= "Gems" then
				local known = upgradeId == "PizzaSpace" or upgradeId == "CollectRange" or upgradeId == "Magnet"
				expect(known).toBe(true)
			end
		end
	end)

	it("makes every upgrade level cost more and do more than the one before", function()
		for _, upgrade in GameConfig.upgrades do
			for i = 2, #upgrade.levels do
				expect(upgrade.levels[i].price > upgrade.levels[i - 1].price).toBe(true)
				expect(upgrade.levels[i].value > upgrade.levels[i - 1].value).toBe(true)
			end
		end
	end)

	it("only lets shops offer existing upgrades up to their last level", function()
		for _, shop in GameConfig.shops do
			for _, offer in shop.offers do
				local upgrade = GameConfig.upgrades[offer.upgrade]
				expect(upgrade ~= nil).toBe(true)
				expect(offer.maxLevel >= 1 and offer.maxLevel <= #upgrade.levels).toBe(true)
			end
		end
	end)
end)

describe("GameConfig pets and eggs", function()
	local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

	it("has the 6 rarities from Gewöhnlich to Mythisch, each with its own color", function()
		for order, rarityId in RARITIES do
			local rarity = GameConfig.rarities[rarityId]
			expect(rarity ~= nil).toBe(true)
			expect(rarity.order).toBe(order)
			expect(#rarity.color).toBe(3)
		end
		expect(GameConfig.rarities.Common.displayName).toBe("Gewöhnlich")
		expect(GameConfig.rarities.Mythic.displayName).toBe("Mythisch")
	end)

	it("starts players with 3 pet slots", function()
		local rules = GameRules.new(GameConfig)
		expect(rules.petSlots(rules.newPlayerState())).toBe(3)
	end)

	it("starts players with 50 inventory slots", function()
		local rules = GameRules.new(GameConfig)
		expect(rules.inventorySlots(rules.newPlayerState())).toBe(50)
	end)

	it("gives world 1 an egg", function()
		local world1 = GameConfig.worlds[1]
		expect(#world1.eggs >= 1).toBe(true)
		expect(GameConfig.eggs[world1.eggs[1]] ~= nil).toBe(true)
	end)

	it("fills every egg with 5-6 known pets whose chances add up to 100 %, one of them a ~0.5 % dream drop", function()
		for _, egg in GameConfig.eggs do
			expect(#egg.pets >= 5 and #egg.pets <= 6).toBe(true)
			expect(egg.price > 0).toBe(true)
			local total, rarest = 0, math.huge
			for _, entry in egg.pets do
				local pet = GameConfig.pets[entry.pet]
				expect(pet ~= nil).toBe(true)
				expect(GameConfig.rarities[pet.rarity] ~= nil).toBe(true)
				expect(pet.bonus > 0).toBe(true)
				total += entry.chance
				rarest = math.min(rarest, entry.chance)
			end
			expect(math.abs(total - 100) < 1e-9).toBe(true)
			expect(rarest <= 0.5).toBe(true)
		end
	end)

	it("makes rarer pets in an egg give a bigger bonus", function()
		for _, egg in GameConfig.eggs do
			local entries = table.clone(egg.pets)
			table.sort(entries, function(a, b)
				return a.chance > b.chance
			end)
			for i = 2, #entries do
				local commoner = GameConfig.pets[entries[i - 1].pet].bonus
				local rarer = GameConfig.pets[entries[i].pet].bonus
				expect(rarer > commoner).toBe(true)
			end
		end
	end)
end)

describe("GameConfig worlds and eggs", function()
	it("gives every world its own egg", function()
		local seen = {}
		for _, world in GameConfig.worlds do
			expect(world.eggs ~= nil and #world.eggs >= 1).toBe(true)
			for _, eggId in world.eggs do
				expect(GameConfig.eggs[eggId] ~= nil).toBe(true)
				expect(seen[eggId] == nil).toBe(true)
				seen[eggId] = true
			end
		end
	end)

	it("makes the pets of a later world's egg about 2x stronger and the egg pricier", function()
		local function averageBonus(eggId: string): number
			local total = 0
			for _, entry in GameConfig.eggs[eggId].pets do
				total += GameConfig.pets[entry.pet].bonus
			end
			return total / #GameConfig.eggs[eggId].pets
		end
		for i = 2, #GameConfig.worlds do
			local previous = GameConfig.worlds[i - 1].eggs[1]
			local current = GameConfig.worlds[i].eggs[1]
			local ratio = averageBonus(current) / averageBonus(previous)
			expect(ratio >= 1.5 and ratio <= 2.5).toBe(true)
			expect(GameConfig.eggs[current].price > GameConfig.eggs[previous].price).toBe(true)
		end
	end)
end)

describe("GameConfig gems", function()
	local rules = GameRules.new(GameConfig)

	it("makes about 1 in 150 toppings a gem topping worth 1-3 gems", function()
		expect(math.abs(GameConfig.gems.toppingChance - 1 / 150) < 1e-9).toBe(true)
		expect(GameConfig.gems.toppingMin).toBe(1)
		expect(GameConfig.gems.toppingMax).toBe(3)
		expect(GameConfig.toppings[GameConfig.gems.toppingId]).toBeNil()
	end)

	it("gives 1 gem per 15 minutes of play time", function()
		local state = rules.addPlayTime(rules.newPlayerState(), 15 * 60).state

		expect(state.gems).toBe(1)
	end)

	it("has a gem counter for pet slots, inventory, walk speed and opening 3 eggs", function()
		for _, upgradeId in { "PetSlots", "InventorySpace", "WalkSpeed", "TripleOpen" } do
			expect(GameConfig.upgrades[upgradeId].currency).toBe("Gems")
		end
	end)

	it("sells pet slots 3 -> 8 for about 50 / 150 / 400 / 1.000 gems, staged per shop", function()
		local levels = GameConfig.upgrades.PetSlots.levels
		local prices, slots = {}, {}
		for _, level in levels do
			table.insert(prices, level.price)
			table.insert(slots, level.value)
		end

		expect(GameConfig.petSlots.start).toBe(3)
		expect(slots).toEqual({ 4, 5, 6, 7, 8 })
		expect(prices[1]).toBe(50)
		expect(prices[2]).toBe(150)
		expect(prices[3]).toBe(400)
		expect(prices[4]).toBe(1000)

		local state = rules.newPlayerState()
		state.gems = 1e9
		state = rules.buyUpgrade(state, "World1Shop", "PetSlots").state
		state = rules.buyUpgrade(state, "World1Shop", "PetSlots").state
		expect(rules.petSlots(state)).toBe(5)
		expect(rules.buyUpgrade(state, "World1Shop", "PetSlots").reason).toBe("ShopLevelLimit")
	end)

	it("lets shop 2 in world 4 sell pet slots up to 7, leaving 8 for shop 3", function()
		local state = rules.newPlayerState()
		state.gems = 1e9
		state.unlockedWorlds = { "Farm", "Beach", "Icebergs" }
		local reason
		repeat
			local result = rules.buyUpgrade(state, "World4Shop", "PetSlots")
			state = result.state
			reason = result.reason
		until not result.ok

		expect(rules.petSlots(state)).toBe(7)
		expect(reason).toBe("ShopLevelLimit")
		for _, upgradeId in { "InventorySpace", "WalkSpeed", "TripleOpen" } do
			expect(rules.buyUpgrade(state, "World4Shop", upgradeId).ok).toBe(true)
		end
	end)

	it("lets the world 1 shop sell every gem upgrade, opening 3 eggs at once included", function()
		local state = rules.newPlayerState()
		state.gems = 1e9
		for _, upgradeId in { "InventorySpace", "WalkSpeed", "TripleOpen" } do
			state = rules.buyUpgrade(state, "World1Shop", upgradeId).state
		end

		expect(rules.inventorySlots(state) > GameConfig.inventory.start).toBe(true)
		expect(rules.walkSpeed(state) > GameConfig.movement.walkSpeed).toBe(true)
		expect(rules.eggsPerOpen(state)).toBe(3)
	end)
end)

describe("GameConfig tutorial", function()
	it("asks new players to collect 2 toppings, which fit on the starting pizza", function()
		local rules = GameRules.new(GameConfig)
		local state = rules.newPlayerState()

		expect(rules.tutorial(state).goal).toBe(2)
		expect(rules.tutorial(state).goal <= rules.pizzaCapacity(state)).toBe(true)
	end)

	it("prices the first pizza space upgrade at 12 coins, the garden egg stays at 25", function()
		expect(GameConfig.upgrades.PizzaSpace.levels[1].price).toBe(12)
		expect(GameConfig.eggs.GardenEgg.price).toBe(25)
	end)

	it("lets new players afford the first upgrade after 3-4 rounds on average", function()
		local world = GameConfig.worlds[1]
		local totalWeight, weightedValue = 0, 0
		for _, spawn in world.toppingSpawns do
			totalWeight += spawn.weight
			weightedValue += spawn.weight * GameConfig.toppings[spawn.topping].value
		end
		local coinsPerRound = weightedValue / totalWeight * GameConfig.pizza.startCapacity
		local rounds = math.ceil(GameConfig.upgrades.PizzaSpace.levels[1].price / coinsPerRound)

		expect(rounds >= 3 and rounds <= 4).toBe(true)
	end)

	it("reaches the 'buy an upgrade' step and finishes it with the first pizza space upgrade", function()
		local rules = GameRules.new(GameConfig)
		local state = rules.newPlayerState()
		-- Four average rounds: salami + mushroom (1 + 2 coins) each.
		for _ = 1, 4 do
			state = rules.collectTopping(state, "Salami", 1).state
			state = rules.collectTopping(state, "Mushroom", 1).state
			state = rules.sellPizza(state).state
		end
		expect(rules.tutorial(state).step).toBe("BuyUpgrade")
		expect(state.coins).toBe(12)

		local result = rules.buyUpgrade(state, "World1Shop", "PizzaSpace")

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(0)
		expect(rules.pizzaCapacity(result.state)).toBe(3)
		expect(rules.tutorial(result.state).step).toBe("OpenEgg")
	end)
end)

describe("GameConfig potions", function()
	local rules = GameRules.new(GameConfig)

	it("has a coin, a luck and a speed potion that each run for 10 minutes and cost gems", function()
		for _, potionId in { "Coins", "Luck", "Speed" } do
			local potion = GameConfig.potions[potionId]
			expect(potion.durationSeconds).toBe(600)
			expect(potion.price > 0).toBe(true)
			expect(type(potion.displayName)).toBe("string")
		end
	end)

	it("doubles coins with the coin potion and makes the speed potion faster", function()
		local state = rules.newPlayerState()
		state.activePotions = { Coins = 600, Speed = 600 }

		expect(rules.potionCoinMultiplier(state)).toBe(2)
		expect(rules.walkSpeed(state) > GameConfig.movement.walkSpeed).toBe(true)
	end)

	it("makes every rarer pet more likely with the luck potion", function()
		local state = rules.newPlayerState()
		state.activePotions = { Luck = 600 }
		for eggId in GameConfig.eggs do
			local plain = rules.eggPreview(eggId).pets
			local lucky = rules.eggPreview(eggId, state).pets
			-- Both lists go from most common to rarest; the rarest gets more, the most common less.
			expect(lucky[#lucky].chancePercent > plain[#plain].chancePercent).toBe(true)
			expect(lucky[1].chancePercent < plain[1].chancePercent).toBe(true)
		end
	end)

	it("sells all three potions at the gem counter of every shop", function()
		for shopId, shop in GameConfig.shops do
			local state = rules.newPlayerState()
			state.gems = 1000
			state.unlockedWorlds = {}
			for _, world in GameConfig.worlds do
				table.insert(state.unlockedWorlds, world.id)
			end
			for _, potionId in { "Coins", "Luck", "Speed" } do
				expect(rules.buyPotion(state, shopId, potionId).ok).toBe(true)
			end
			expect(#shop.potions).toBe(3)
		end
	end)
end)

describe("GameConfig delivery", function()
	local rules = GameRules.new(GameConfig)

	-- A player who finished the tutorial, with every world unlocked up to `worldCount`.
	local function progressed(worldCount: number)
		local state = rules.newPlayerState()
		state.tutorialStep = 1000
		for index = 2, worldCount do
			table.insert(state.unlockedWorlds, GameConfig.worlds[index].id)
		end
		return state
	end

	it("rings every few minutes and gives about 3 minutes to deliver", function()
		expect(GameConfig.delivery.timeLimitSeconds).toBe(180)
		expect(GameConfig.delivery.callIntervalSeconds >= 60).toBe(true)
		expect(GameConfig.delivery.callIntervalSeconds <= 300).toBe(true)
	end)

	it("orders toppings of the highest unlocked world in every world", function()
		for worldCount, world in GameConfig.worlds do
			local state = progressed(worldCount)
			local call = rules.deliveryCall(rules.ringPhone(state, 0, TestKit.sequenceRandom({ 0.99, 0.5 })).state)
			expect(call.worldId).toBe(world.id)
			for toppingId in call.toppings do
				expect(GameConfig.toppings[toppingId] ~= nil).toBe(true)
			end
		end
	end)

	it("pays 3 to 10 gems for gem orders, slow or fast", function()
		local slowest = { 0, 0.5, 0.5, 0.5, 0 }
		local fastest = { 0, 0.5, 0.5, 0.5, 0.999 }
		local gemRoll = 0
		-- Find a reward roll that picks gems with the real weights.
		local total, before = 0, 0
		for _, entry in GameConfig.delivery.rewardWeights do
			total += entry.weight
		end
		for _, entry in GameConfig.delivery.rewardWeights do
			if entry.reward == "Gems" then
				gemRoll = (before + entry.weight / 2) / total
			end
			before += entry.weight
		end
		slowest[4], fastest[4] = gemRoll, gemRoll
		for _, case in { { rolls = slowest, now = 180, gems = 3 }, { rolls = fastest, now = 0, gems = 10 } } do
			local state = rules.ringPhone(progressed(1), 0, TestKit.sequenceRandom(case.rolls)).state
			state = rules.acceptOrder(state, 0).state
			expect(rules.orderReward(state, case.now - 1e-3)).toEqual({ reward = "Gems", amount = case.gems })
		end
	end)
end)

describe("GameConfig save", function()
	it("expires a session lock after about 5 minutes, well after the next periodic save renews it", function()
		local save = GameConfig.save

		expect(save.lockExpirySeconds).toBe(300)
		expect(save.autosaveSeconds * 2 <= save.lockExpirySeconds).toBe(true)
	end)

	it("retries a locked load a few times before giving up", function()
		local save = GameConfig.save

		expect(save.lockRetrySeconds > 0).toBe(true)
		expect(save.lockWaitSeconds >= save.lockRetrySeconds * 3).toBe(true)
	end)
end)
