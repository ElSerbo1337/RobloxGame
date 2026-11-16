local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

describe("collectTopping", function()
	it("puts a topping within range onto the pizza", function()
		local result = rules.collectTopping(rules.newPlayerState(), "Salami", 4)

		expect(result.ok).toBe(true)
		expect(result.state.pizza).toEqual({ "Salami" })
	end)

	it("rejects a topping when the pizza is full and keeps the state unchanged", function()
		local state = rules.newPlayerState()
		state = rules.collectTopping(state, "Salami", 1).state
		state = rules.collectTopping(state, "Mushroom", 1).state

		local result = rules.collectTopping(state, "Mozzarella", 1)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("PizzaFull")
		expect(result.state.pizza).toEqual({ "Salami", "Mushroom" })
	end)

	it("accepts a topping exactly at the collect range", function()
		local result = rules.collectTopping(rules.newPlayerState(), "Salami", 10)

		expect(result.ok).toBe(true)
	end)

	it("rejects a topping beyond the collect range", function()
		local result = rules.collectTopping(rules.newPlayerState(), "Salami", 10.5)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("OutOfRange")
		expect(result.state.pizza).toEqual({})
	end)

	it("rejects a topping that is not in the config", function()
		local result = rules.collectTopping(rules.newPlayerState(), "Pineapple", 1)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownTopping")
	end)
end)

describe("sellPizza", function()
	it("sells all toppings at once for the sum of their configured values", function()
		local state = rules.newPlayerState()
		state = rules.collectTopping(state, "Mushroom", 1).state
		state = rules.collectTopping(state, "Mozzarella", 1).state

		local result = rules.sellPizza(state)

		expect(result.ok).toBe(true)
		expect(result.coinsEarned).toBe(7)
		expect(result.state.coins).toBe(7)
		expect(result.state.pizza).toEqual({})
	end)

	it("adds to the coins the player already has", function()
		local state = rules.newPlayerState()
		state = rules.collectTopping(state, "Salami", 1).state
		state = rules.sellPizza(state).state
		state = rules.collectTopping(state, "Mozzarella", 1).state

		local result = rules.sellPizza(state)

		expect(result.state.coins).toBe(6)
	end)

	it("rejects selling an empty pizza", function()
		local result = rules.sellPizza(rules.newPlayerState())

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("PizzaEmpty")
		expect(result.state.coins).toBe(0)
	end)

	it("frees the pizza so the player can collect again", function()
		local state = rules.newPlayerState()
		state = rules.collectTopping(state, "Salami", 1).state
		state = rules.collectTopping(state, "Salami", 1).state
		state = rules.sellPizza(state).state

		expect(rules.collectTopping(state, "Salami", 1).ok).toBe(true)
	end)
end)
