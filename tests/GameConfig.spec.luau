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

	it("only has pizza space, range and magnet upgrades (no sell value upgrade)", function()
		for upgradeId in GameConfig.upgrades do
			local known = upgradeId == "PizzaSpace" or upgradeId == "CollectRange" or upgradeId == "Magnet"
			expect(known).toBe(true)
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
