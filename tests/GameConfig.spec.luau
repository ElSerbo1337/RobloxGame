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
end)
