-- New potions of the MEGA UPDATE (#96): Shiny (x2 shiny chance), Gold (x2 golden topping
-- chance) and Mega (works like the coin, luck and speed potion at once).
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SHINY = 1 / 200
local GOLD = 0.01

local function potionConfig(features: { [string]: boolean }?): any
	local config = table.clone(TestConfig)
	config.features = features
	config.shinyPets = { chance = SHINY, bonusMultiplier = 1.5 }
	config.goldenToppings = { chance = GOLD, valueMultiplier = 10 }
	config.potions = table.clone(TestConfig.potions)
	config.potions.Luck = table.clone(TestConfig.potions.Luck)
	config.potions.Luck.shinyChanceMultiplier = 2
	config.potions.Shiny =
		{ displayName = "Shiny-Trank", price = 40, durationSeconds = 600, shinyChanceMultiplier = 2, feature = "newPotions" }
	config.potions.Gold =
		{ displayName = "Gold-Trank", price = 40, durationSeconds = 600, goldenChanceMultiplier = 2, feature = "newPotions" }
	config.potions.Mega = {
		displayName = "Mega-Trank",
		price = 120,
		durationSeconds = 600,
		includes = { "Coins", "Luck", "Speed" },
		feature = "newPotions",
		randomReward = false,
	}
	config.codes = {
		RANDOM = { rewards = { { kind = "Potion", amount = 1 } } },
		MEGA = { rewards = { { kind = "Potion", amount = 1, potionId = "Mega" } } },
	}
	config.shops = table.clone(TestConfig.shops)
	config.shops.GemShop = table.clone(TestConfig.shops.GemShop)
	config.shops.GemShop.potions = { "Coins", "Luck", "Speed", "Shiny", "Gold", "Mega" }
	return config
end

local rules = GameRules.new(potionConfig())
local offRules = GameRules.new(potionConfig({ newPotions = false }))

local function approx(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-9 then
		error(`expected {expected}, got {actual}`)
	end
end

local function running(potions: { [string]: number })
	local state = rules.newPlayerState()
	state.activePotions = potions
	return state
end

describe("shiny potion", function()
	it("doubles the shiny chance while it runs", function()
		approx(rules.shinyChance(running({})), SHINY)
		approx(rules.shinyChance(running({ Shiny = 600 })), 2 * SHINY)
		approx(rules.shinyChance(running({ Shiny = 0 })), SHINY)
	end)

	it("stacks with the luck potion (1 in 50)", function()
		approx(rules.shinyChance(running({ Shiny = 600, Luck = 600 })), 4 * SHINY)
	end)

	it("does not touch the golden chance or the coins", function()
		local state = running({ Shiny = 600 })
		approx(rules.goldenChance(state), GOLD)
		expect(rules.potionCoinMultiplier(state)).toBe(1)
	end)
end)

describe("gold potion", function()
	it("doubles the golden topping chance while it runs", function()
		approx(rules.goldenChance(running({})), GOLD)
		approx(rules.goldenChance(running({ Gold = 600 })), 2 * GOLD)
	end)

	it("doubles on top of Gold Luck", function()
		local state = running({ Gold = 600 })
		state.upgrades = { GoldLuck = 5 }
		approx(rules.goldenChance(state), 2 * TestConfig.upgrades.GoldLuck.levels[5].value)
	end)

	it("does not touch the shiny chance", function()
		approx(rules.shinyChance(running({ Gold = 600 })), SHINY)
	end)
end)

describe("mega potion", function()
	it("works like the coin, luck and speed potion at once", function()
		local mega = running({ Mega = 600 })
		local all = running({ Coins = 600, Luck = 600, Speed = 600 })

		expect(rules.potionCoinMultiplier(mega)).toBe(2)
		expect(rules.walkSpeed(mega)).toBe(rules.walkSpeed(all))
		expect(rules.walkSpeed(mega) > rules.walkSpeed(running({}))).toBe(true)
		approx(rules.shinyChance(mega), 2 * SHINY)
		local megaEgg, allEgg = rules.eggPreview("TestEgg", mega), rules.eggPreview("TestEgg", all)
		for index, entry in megaEgg.pets do
			approx(entry.chancePercent, allEgg.pets[index].chancePercent)
		end
		expect(megaEgg.pets[3].chancePercent > rules.eggPreview("TestEgg").pets[3].chancePercent).toBe(true)
	end)

	it("does not stack with the potions it contains (an effect counts once)", function()
		local both = running({ Mega = 600, Coins = 600, Luck = 600 })

		expect(rules.potionCoinMultiplier(both)).toBe(2)
		approx(rules.shinyChance(both), 2 * SHINY)
	end)

	it("stacks with the shiny and gold potion", function()
		local state = running({ Mega = 600, Shiny = 600, Gold = 600 })

		approx(rules.shinyChance(state), 4 * SHINY)
		approx(rules.goldenChance(state), 2 * GOLD)
	end)

	it("has no effect once its time is up", function()
		local state = running({ Mega = 0 })

		expect(rules.potionCoinMultiplier(state)).toBe(1)
		approx(rules.shinyChance(state), SHINY)
	end)

	it("tells which effects run and which potion gives them (for the potion display)", function()
		local state = running({ Mega = 600, Luck = 300 })

		expect(rules.isPotionEffectActive(state, "Coins")).toBe(true)
		expect(rules.isPotionEffectActive(state, "Shiny")).toBe(false)
		expect(rules.potionCoveredBy(state, "Coins")).toBe("Mega")
		expect(rules.potionCoveredBy(state, "Speed")).toBe("Mega")
		-- Luck runs itself, too: still covered by Mega for the display.
		expect(rules.potionCoveredBy(state, "Luck")).toBe("Mega")
		expect(rules.potionCoveredBy(state, "Shiny")).toBe(nil)
		expect(rules.potionCoveredBy(running({ Coins = 600 }), "Coins")).toBe(nil)
		expect(rules.potionIncludes("Mega")).toEqual({ "Coins", "Luck", "Speed" })
		expect(rules.potionIncludes("Coins")).toEqual({})
	end)

	it("costs much more than the three potions it contains", function()
		local config = potionConfig()
		local sum = config.potions.Coins.price + config.potions.Luck.price + config.potions.Speed.price
		expect(config.potions.Mega.price > sum).toBe(true)
	end)
end)

describe("buying and drinking the new potions", function()
	it("are sold at the gem counter and land in the potion inventory", function()
		local state = rules.newPlayerState()
		state.gems = 200
		for _, potionId in { "Shiny", "Gold", "Mega" } do
			local result = rules.buyPotion(state, "GemShop", potionId)
			expect(result.ok).toBe(true)
			state = result.state
			expect(rules.potionCount(state, potionId)).toBe(1)
		end
		expect(state.gems).toBe(0)
		local ids = {}
		for _, offer in rules.potionOffers(state, "GemShop") do
			table.insert(ids, offer.potionId)
		end
		expect(ids).toEqual({ "Coins", "Luck", "Speed", "Shiny", "Gold", "Mega" })
	end)

	it("drinking the Mega potion starts it with its own timer", function()
		local state = rules.newPlayerState()
		state.potions = { Mega = 2 }
		local result = rules.drinkPotion(state, "Mega")
		expect(result.ok).toBe(true)
		expect(rules.potionTimeLeft(result.state, "Mega")).toBe(600)
		expect(rules.potionTimeLeft(result.state, "Coins")).toBe(0)
		expect(rules.potionCoinMultiplier(result.state)).toBe(2)
		result = rules.drinkPotion(result.state, "Mega")
		expect(rules.potionTimeLeft(result.state, "Mega")).toBe(1200)
	end)

	it("stays running through a rebirth", function()
		local state = running({ Mega = 500, Shiny = 400, Gold = 300 })
		state.coins = 1e9
		local result = rules.rebirth(state, 0)
		expect(result.ok).toBe(true)
		expect(result.state.activePotions).toEqual({ Mega = 500, Shiny = 400, Gold = 300 })
	end)
end)

describe("random potion rewards", function()
	local function drawn(r: any): { [string]: boolean }
		local seen = {}
		for i = 0, 59 do
			local value = (i + 0.5) / 60
			local result = r.redeemCode(r.newPlayerState(), "RANDOM", 0, function()
				return value
			end)
			expect(result.ok).toBe(true)
			for _, reward in result.rewards do
				seen[reward.potionId] = true
			end
		end
		return seen
	end

	it("can be the shiny or gold potion, never the expensive Mega potion", function()
		local seen = drawn(rules)
		expect(seen.Shiny).toBe(true)
		expect(seen.Gold).toBe(true)
		expect(seen.Coins).toBe(true)
		expect(seen.Mega).toBe(nil)
	end)

	it("a fixed Mega reward (quest streak) still pays the Mega potion", function()
		local state = rules.newPlayerState()
		local result = rules.redeemCode(state, "MEGA", 0, function()
			return 0.5
		end)
		expect(result.ok).toBe(true)
		expect(result.rewards[1].potionId).toBe("Mega")
	end)
end)

describe("feature switch newPotions", function()
	it("switched off, the new potions are neither offered nor sold", function()
		local state = offRules.newPlayerState()
		state.gems = 1000
		expect(offRules.buyPotion(state, "GemShop", "Mega").reason).toBe("NotOffered")
		expect(offRules.buyPotion(state, "GemShop", "Shiny").reason).toBe("NotOffered")
		expect(offRules.buyPotion(state, "GemShop", "Coins").ok).toBe(true)
		local ids = {}
		for _, offer in offRules.potionOffers(state, "GemShop") do
			table.insert(ids, offer.potionId)
		end
		expect(ids).toEqual({ "Coins", "Luck", "Speed" })
		expect(offRules.isPotionOffered("Gold")).toBe(false)
		expect(rules.isPotionOffered("Gold")).toBe(true)
	end)

	it("switched off, they cannot be drunk and are not handed out", function()
		local state = offRules.newPlayerState()
		state.potions = { Shiny = 1 }
		expect(offRules.drinkPotion(state, "Shiny").reason).toBe("FeatureOff")
		for i = 0, 59 do
			local value = (i + 0.5) / 60
			local result = offRules.redeemCode(offRules.newPlayerState(), "RANDOM", 0, function()
				return value
			end)
			local potionId = result.rewards[1].potionId
			expect(potionId == "Coins" or potionId == "Luck" or potionId == "Speed").toBe(true)
		end
		-- A fixed Mega reward turns into a random potion while the switch is off.
		local mega = offRules.redeemCode(offRules.newPlayerState(), "MEGA", 0, function()
			return 0
		end)
		expect(mega.rewards[1].potionId).toBe("Coins")
	end)
end)
