local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function playerWithCoins(coins: number)
	local state = rules.newPlayerState()
	state.coins = coins
	return state
end

describe("buyUpgrade", function()
	it("buys the next pizza space level, takes the price and grows the pizza", function()
		local result = rules.buyUpgrade(playerWithCoins(15), "SmallShop", "PizzaSpace")

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(5)
		expect(rules.upgradeLevel(result.state, "PizzaSpace")).toBe(1)
		expect(rules.pizzaCapacity(result.state)).toBe(3)
	end)

	it("rejects a purchase without enough coins and keeps coins and level", function()
		local result = rules.buyUpgrade(playerWithCoins(9), "SmallShop", "PizzaSpace")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEnoughCoins")
		expect(result.state.coins).toBe(9)
		expect(rules.upgradeLevel(result.state, "PizzaSpace")).toBe(0)
	end)

	it("stops at the shop's max level, while a bigger shop sells the next level", function()
		local state = playerWithCoins(1000)
		state = rules.buyUpgrade(state, "SmallShop", "PizzaSpace").state
		state = rules.buyUpgrade(state, "SmallShop", "PizzaSpace").state

		local small = rules.buyUpgrade(state, "SmallShop", "PizzaSpace")
		local big = rules.buyUpgrade(state, "BigShop", "PizzaSpace")

		expect(small.ok).toBe(false)
		expect(small.reason).toBe("ShopLevelLimit")
		expect(small.state.coins).toBe(940)
		expect(big.ok).toBe(true)
		expect(rules.pizzaCapacity(big.state)).toBe(6)
	end)

	it("rejects buying beyond the last level that exists at all", function()
		local state = playerWithCoins(5000)
		state = rules.buyUpgrade(state, "BigShop", "Magnet").state
		state = rules.buyUpgrade(state, "BigShop", "Magnet").state

		local result = rules.buyUpgrade(state, "BigShop", "Magnet")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("MaxLevel")
		expect(result.state.coins).toBe(3900)
	end)

	it("rejects an upgrade the shop does not offer", function()
		local result = rules.buyUpgrade(playerWithCoins(1000), "BigShop", "CollectRange")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotOffered")
	end)

	it("rejects buying in a shop whose world is still locked, keeping coins and level", function()
		local result = rules.buyUpgrade(playerWithCoins(1000), "BeachShop", "PizzaSpace")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("WorldLocked")
		expect(result.state.coins).toBe(1000)
		expect(rules.upgradeLevel(result.state, "PizzaSpace")).toBe(0)
	end)

	it("sells in a shop once its world is unlocked", function()
		local state = playerWithCoins(1000)
		state.unlockedWorlds = { "Farm", "Beach" }

		local result = rules.buyUpgrade(state, "BeachShop", "PizzaSpace")

		expect(result.ok).toBe(true)
		expect(rules.pizzaCapacity(result.state)).toBe(3)
	end)

	it("rejects unknown shops and upgrades", function()
		expect(rules.buyUpgrade(playerWithCoins(1000), "NoShop", "PizzaSpace").reason).toBe("UnknownShop")
		expect(rules.buyUpgrade(playerWithCoins(1000), "SmallShop", "SellValue").reason).toBe("UnknownUpgrade")
	end)
end)

describe("upgrade effects", function()
	it("collect range upgrade lets the player collect toppings farther away", function()
		local state = rules.buyUpgrade(playerWithCoins(20), "SmallShop", "CollectRange").state

		expect(rules.collectRange(state)).toBe(14)
		expect(rules.collectTopping(state, "Salami", 13).ok).toBe(true)
		expect(rules.collectTopping(rules.newPlayerState(), "Salami", 13).reason).toBe("OutOfRange")
	end)

	it("a new player has no magnet; the magnet level sets the pull radius", function()
		local state = rules.buyUpgrade(playerWithCoins(100), "SmallShop", "Magnet").state

		expect(rules.magnetRange(rules.newPlayerState())).toBe(0)
		expect(rules.magnetRange(state)).toBe(8)
	end)

	it("the magnet pulls in toppings from its radius while auto-collect is on", function()
		local state = rules.buyUpgrade(playerWithCoins(100), "SmallShop", "Magnet").state
		state = rules.setAutoCollect(state, true).state

		expect(rules.autoCollectRadius(state)).toBe(8)
		expect(rules.autoCollectTopping(state, "Salami", 7).ok).toBe(true)
	end)

	it("an old save without upgrades loads at level 0 for every upgrade", function()
		local fresh = rules.newPlayerState()
		local old = { version = 1, coins = 30, pizza = {} }

		local loaded = SaveData.load(old, fresh).state

		expect(rules.upgradeLevel(loaded, "PizzaSpace")).toBe(0)
		expect(rules.buyUpgrade(loaded, "SmallShop", "PizzaSpace").ok).toBe(true)
	end)
end)

describe("shopOffers", function()
	it("lists the shop's upgrades with level, current and next effect and price", function()
		local offers = rules.shopOffers(rules.newPlayerState(), "SmallShop")

		expect(#offers).toBe(3)
		expect(offers[1]).toEqual({
			upgrade = "PizzaSpace",
			displayName = "Pizza-Platz",
			level = 0,
			shopMaxLevel = 2,
			maxLevel = 3,
			value = 2,
			status = "Available",
			nextPrice = 10,
			nextValue = 3,
		})
		expect(offers[3].upgrade).toBe("Magnet")
		expect(offers[3].value).toBe(0)
	end)

	it("marks a level only sold in a bigger shop, still showing what it would cost", function()
		local state = playerWithCoins(1000)
		state = rules.buyUpgrade(state, "SmallShop", "PizzaSpace").state
		state = rules.buyUpgrade(state, "SmallShop", "PizzaSpace").state

		local offer = rules.shopOffers(state, "SmallShop")[1]

		expect(offer.level).toBe(2)
		expect(offer.value).toBe(4)
		expect(offer.status).toBe("ShopLevelLimit")
		expect(offer.nextPrice).toBe(200)
		expect(offer.nextValue).toBe(6)
	end)

	it("marks a fully upgraded offer as max level without a next price", function()
		local state = rules.buyUpgrade(playerWithCoins(2000), "SmallShop", "Magnet").state
		state = rules.buyUpgrade(state, "BigShop", "Magnet").state

		local offer = rules.shopOffers(state, "BigShop")[2]

		expect(offer.status).toBe("MaxLevel")
		expect(offer.nextPrice).toBeNil()
	end)
end)
