local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

-- TestConfig: world 1 averages 1.7 coins per topping (Salami 1 x6, Mushroom 2 x3,
-- Mozzarella 5 x1), the farm 8 (Onion 4 x3, Ham 20 x1); 2 rounds per minute.
local function near(actual: number, expected: number)
	expect(math.abs(actual - expected) < 1e-6).toBe(true)
end

describe("income estimate", function()
	it("is average topping value x pizza space x rounds per minute for a new player", function()
		near(rules.incomePerMinute(rules.newPlayerState()), 1.7 * 2 * 2)
	end)

	it("follows the highest unlocked world", function()
		local state = rules.newPlayerState()
		state.unlockedWorlds = { "Farm" }

		near(rules.incomePerMinute(state), 8 * 2 * 2)
	end)

	it("grows with pizza space", function()
		local state = rules.newPlayerState()
		state.upgrades = { PizzaSpace = 1 }

		near(rules.incomePerMinute(state), 1.7 * 3 * 2)
	end)

	it("grows with equipped pets", function()
		local state = rules.newPlayerState()
		state.pets = { { uid = 1, petId = "Cat" }, { uid = 2, petId = "Dragon" } }
		state.nextPetUid = 3
		state.equipped = { 1 }

		near(rules.incomePerMinute(state), 1.7 * 2 * 2 * 1.2)
	end)

	it("grows with rebirths (through the coin multiplier)", function()
		local state = rules.newPlayerState()
		state.rebirths = 2 -- x2 coins (TestConfig: +0.5 per rebirth)

		near(rules.incomePerMinute(state), 1.7 * 2 * 2 * 2)
	end)

	it("ignores running potions and what is on the pizza (deterministic)", function()
		local state = rules.newPlayerState()
		state.activePotions = { Coins = 300 }
		state.pizza = { "Mozzarella" }

		near(rules.incomePerMinute(state), 1.7 * 2 * 2)
	end)

	it("coins for N minutes of income are rounded down", function()
		expect(rules.incomeCoins(rules.newPlayerState(), 2)).toBe(13) -- 2 x 6.8
	end)
end)
